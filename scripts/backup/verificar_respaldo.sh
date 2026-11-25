#!/usr/bin/env bash
set -Eeuo pipefail

BACKUP_ROOT="${BACKUP_ROOT:-/var/backups/mimascota}"
INCOMING_DIR="$BACKUP_ROOT/entrantes"
VERIFIED_DIR="$BACKUP_ROOT/verificados"
REJECTED_DIR="$BACKUP_ROOT/rechazados"
LOG_DIR="$BACKUP_ROOT/logs"
LOG_DIR="${HOME}/logs/mimascota"
LOG_FILE="$LOG_DIR/verificar_respaldo.log"
TEMP_ROOT="${HOME}/.cache/mimascota"
MYSQL_CNF="${MYSQL_CNF:-${HOME}/.config/mimascota/verify.cnf}"
VERIFY_DB="${VERIFY_DB:-mimascota_verif}"
MIN_TABLES="${MIN_TABLES:-12}"

mkdir -p "$LOG_DIR" "$TEMP_ROOT"

log() {
    printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >>"$LOG_FILE"
}

if [[ ! -r "$MYSQL_CNF" ]]; then
    log "[ERROR] No se puede leer MYSQL_CNF: $MYSQL_CNF"
    exit 1
fi
if [[ ! "$VERIFY_DB" =~ ^[A-Za-z0-9_]+$ || ! "$MIN_TABLES" =~ ^[0-9]+$ ]]; then
    log '[ERROR] VERIFY_DB o MIN_TABLES no tiene un valor valido.'
    exit 1
fi
if ! command -v unzip >/dev/null 2>&1 || ! command -v mysql >/dev/null 2>&1 || ! command -v sed >/dev/null 2>&1; then
    log '[ERROR] Se requieren unzip, mysql y sed en PATH.'
    exit 1
fi
for directory in "$INCOMING_DIR" "$VERIFIED_DIR" "$REJECTED_DIR"; do
    if [[ ! -d "$directory" || ! -w "$directory" ]]; then
        log "[ERROR] El usuario $(id -un) necesita escritura en $directory."
        exit 1
    fi
done

mode="$(stat -c '%a' "$MYSQL_CNF")"
if (( (8#$mode & 077) != 0 )); then
    log '[ERROR] MYSQL_CNF debe tener permisos 0600.'
    exit 1
fi

shopt -s nullglob
archives=("$INCOMING_DIR"/*.zip)
if (( ${#archives[@]} == 0 )); then
    log '[INFO] No hay respaldos pendientes.'
    exit 0
fi

process_archive() {
    local archive="$1"
    local tmpdir=''
    local entry=''
    local tables=''
    local mysql_error=''
    local checksum_file="$archive.sha256"
    local normalized_checksum="$VERIFIED_DIR/.$(basename "$archive").sha256.$$"
    tmpdir="$(mktemp -d "$TEMP_ROOT/.verify.XXXXXX")"

    reject_archive() {
        local reason="$1"
        rm -f -- "$normalized_checksum"
        if [[ -e "$archive" ]]; then
                local destination="$REJECTED_DIR/$(basename "$archive")"
                if [[ -e "$destination" ]]; then
                    destination="${destination%.zip}_$(date '+%Y%m%d_%H%M%S').zip"
                fi
                mv -- "$archive" "$destination"
        fi
        if [[ -e "$checksum_file" ]]; then
            local checksum_destination="$REJECTED_DIR/$(basename "$checksum_file")"
            if [[ -e "$checksum_destination" ]]; then
                checksum_destination="${checksum_destination%.sha256}_$(date '+%Y%m%d_%H%M%S').sha256"
            fi
            mv -- "$checksum_file" "$checksum_destination"
        fi
        log "[ERROR] $(basename "$archive"): $reason"
        rm -rf -- "$tmpdir"
        return 1
    }

    if [[ ! -s "$checksum_file" ]]; then
        reject_archive 'Falta el archivo SHA-256.'
        return 1
    fi
    if ! sed 's/\r$//' "$checksum_file" >"$normalized_checksum"; then
        reject_archive 'No se pudo normalizar el archivo SHA-256.'
        return 1
    fi
    if ! grep -Eq '^[[:xdigit:]]{64}  [A-Za-z0-9._-]+\.zip$' "$normalized_checksum" ||
        [[ "$(awk '{print $2}' "$normalized_checksum")" != "$(basename "$archive")" ]]; then
        reject_archive 'El archivo SHA-256 no tiene el formato esperado.'
        return 1
    fi
    if ! (cd "$INCOMING_DIR" && sha256sum --check --status "$normalized_checksum"); then
        reject_archive 'La suma SHA-256 no coincide.'
        return 1
    fi

    if ! unzip -Z1 "$archive" >"$tmpdir/entries.txt"; then
        reject_archive 'ZIP ilegible.'
        return 1
    fi
    if [[ "$(wc -l <"$tmpdir/entries.txt")" -ne 1 ]]; then
        reject_archive 'El ZIP debe contener un solo archivo.'
        return 1
    fi
    entry="$(cat "$tmpdir/entries.txt")"
    if [[ ! "$entry" =~ ^[A-Za-z0-9._-]+\.sql$ || "$entry" == *'..'* ]]; then
        reject_archive 'Nombre de SQL no permitido.'
        return 1
    fi
    if ! unzip -p "$archive" "$entry" >"$tmpdir/dump.sql" || [[ ! -s "$tmpdir/dump.sql" ]]; then
        reject_archive 'No se pudo extraer un SQL no vacio.'
        return 1
    fi
    if ! grep -Fq 'Dump completed' "$tmpdir/dump.sql"; then
        reject_archive "Falta el marcador 'Dump completed'."
        return 1
    fi
    if ! sed -E -i 's/DEFINER=`[^`]*`@`[^`]*`//g' "$tmpdir/dump.sql"; then
        reject_archive 'No se pudieron retirar los DEFINER del SQL temporal.'
        return 1
    fi
    if grep -Eq 'DEFINER[[:space:]]*=' "$tmpdir/dump.sql"; then
        reject_archive 'El SQL contiene un DEFINER no reconocido.'
        return 1
    fi

    if ! mysql --defaults-extra-file="$MYSQL_CNF" --connect-timeout=10 \
        --batch --skip-column-names \
        -e "SELECT SCHEMA_NAME FROM information_schema.SCHEMATA WHERE SCHEMA_NAME='$VERIFY_DB';" \
        2>"$tmpdir/mysql.err" | grep -Fxq "$VERIFY_DB"; then
        mysql_error="$(tail -n 3 "$tmpdir/mysql.err" | tr '\n' ' ')"
        reject_archive "La base de verificacion $VERIFY_DB no existe o no es accesible. $mysql_error"
        return 1
    fi
    if ! mysql --defaults-extra-file="$MYSQL_CNF" --connect-timeout=10 --batch --skip-column-names \
        -e "SELECT CONCAT('DROP VIEW IF EXISTS \`', REPLACE(TABLE_NAME, '\`', '\`\`'), '\`;') FROM information_schema.VIEWS WHERE TABLE_SCHEMA='$VERIFY_DB';" \
        2>"$tmpdir/views-query.err" |
        mysql --defaults-extra-file="$MYSQL_CNF" --connect-timeout=10 "$VERIFY_DB" 2>"$tmpdir/views-apply.err"; then
        mysql_error="$(cat "$tmpdir/views-query.err" "$tmpdir/views-apply.err" | tail -n 3 | tr '\n' ' ')"
        reject_archive "No se pudieron limpiar las vistas previas. $mysql_error"
        return 1
    fi
    if ! mysql --defaults-extra-file="$MYSQL_CNF" --connect-timeout=10 --batch --skip-column-names \
        -e "SELECT CONCAT('DROP ', ROUTINE_TYPE, ' IF EXISTS \`', REPLACE(ROUTINE_NAME, '\`', '\`\`'), '\`;') FROM information_schema.ROUTINES WHERE ROUTINE_SCHEMA='$VERIFY_DB';" \
        2>"$tmpdir/routines-query.err" |
        mysql --defaults-extra-file="$MYSQL_CNF" --connect-timeout=10 "$VERIFY_DB" 2>"$tmpdir/routines-apply.err"; then
        mysql_error="$(cat "$tmpdir/routines-query.err" "$tmpdir/routines-apply.err" | tail -n 3 | tr '\n' ' ')"
        reject_archive "No se pudieron limpiar las rutinas previas. $mysql_error"
        return 1
    fi
    if ! {
        printf 'SET FOREIGN_KEY_CHECKS=0;\n'
        mysql --defaults-extra-file="$MYSQL_CNF" --connect-timeout=10 --batch --skip-column-names \
            -e "SELECT CONCAT('DROP TABLE IF EXISTS \`', REPLACE(TABLE_NAME, '\`', '\`\`'), '\`;') FROM information_schema.TABLES WHERE TABLE_SCHEMA='$VERIFY_DB' AND TABLE_TYPE='BASE TABLE';" \
            2>"$tmpdir/tables-query.err"
        printf 'SET FOREIGN_KEY_CHECKS=1;\n'
    } | mysql --defaults-extra-file="$MYSQL_CNF" --connect-timeout=10 "$VERIFY_DB" 2>"$tmpdir/tables-apply.err"; then
        mysql_error="$(cat "$tmpdir/tables-query.err" "$tmpdir/tables-apply.err" | tail -n 3 | tr '\n' ' ')"
        reject_archive "No se pudieron limpiar las tablas previas. $mysql_error"
        return 1
    fi
    if ! mysql --defaults-extra-file="$MYSQL_CNF" --connect-timeout=10 "$VERIFY_DB" \
        <"$tmpdir/dump.sql" 2>"$tmpdir/mysql.err"; then
        mysql_error="$(tail -n 3 "$tmpdir/mysql.err" | tr '\n' ' ')"
        reject_archive "La importacion fallo. $mysql_error"
        return 1
    fi
    tables="$(mysql --defaults-extra-file="$MYSQL_CNF" --batch --skip-column-names \
        -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='$VERIFY_DB' AND table_type='BASE TABLE';" \
        2>"$tmpdir/mysql.err")" || {
        mysql_error="$(tail -n 3 "$tmpdir/mysql.err" | tr '\n' ' ')"
        reject_archive "No se pudo contar las tablas. $mysql_error"
        return 1
    }
    if [[ ! "$tables" =~ ^[0-9]+$ ]] || (( tables < MIN_TABLES )); then
        reject_archive "Conteo de tablas invalido: $tables; minimo esperado: $MIN_TABLES."
        return 1
    fi

    destination="$VERIFIED_DIR/$(basename "$archive")"
    if [[ -e "$destination" ]]; then
        destination="${destination%.zip}_$(date '+%Y%m%d_%H%M%S').zip"
    fi
    mv -- "$archive" "$destination"
    if ! mv -- "$normalized_checksum" "$destination.sha256"; then
        mv -- "$destination" "$archive"
        reject_archive 'No se pudo mover el checksum al directorio verificados.'
        return 1
    fi
    rm -f -- "$checksum_file"
    log "[OK] $(basename "$archive"): importado en $VERIFY_DB; tablas=$tables."
    rm -rf -- "$tmpdir"
    return 0
}

errors=0
for archive in "${archives[@]}"; do
    if ! process_archive "$archive"; then
        errors=$((errors + 1))
    fi
done
if (( errors > 0 )); then
    log "[ERROR] $errors respaldo(s) no pudieron verificarse."
    exit 1
fi
