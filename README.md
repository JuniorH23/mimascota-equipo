# MiMascota — interfaz de escritorio

Aplicación de escritorio en Python/Tkinter para administrar la base MySQL `mimascota`.
Incluye propietarios, mascotas, citas, atención clínica, vacunación, inventario y un
resumen de la agenda del día.

## Requisitos

- Windows con Python 3.10 o posterior.
- MySQL/MariaDB iniciado localmente y la base `mimascota` creada.
- Las vistas (`03_vistas.sql`) y los procedimientos (`05_logica.sql`) instalados.
- Un usuario MySQL con los permisos requeridos por los módulos que se usarán.

## Instalación y ejecución

Desde PowerShell, en esta carpeta:

```powershell
python -m pip install -r requirements.txt
python app.py
```

En la pantalla de conexión se proponen `127.0.0.1`, puerto `3306`, base `mimascota`
y usuario `mimascota_app`. Escribe la contraseña de ese usuario; la aplicación no
la guarda.

## Preparar la base de datos

Si aún no creaste la base, importa los scripts en este orden:

1. `01_ddl.sql`
2. `02_datos.sql` (solo si quieres cargar los datos de demostración y todavía no los tienes)
3. `03_vistas.sql`
4. `05_logica.sql`
5. `06_usuarios.sql` (opcional, para crear los usuarios de aplicación y reportes)

No vuelvas a importar `02_datos.sql` sobre una base que ya tiene esos datos: sus
registros pueden duplicarse o chocar con claves existentes. Antes de ejecutar
`06_usuarios.sql`, cambia las contraseñas `CAMBIAR_*` por contraseñas propias;
ese script reemplaza las cuentas de aplicación existentes.

La app usa `sp_agendar_cita` para validar cruces de horario y `sp_registrar_atencion`
para crear el historial clínico y descontar medicamentos dentro de la lógica de la
base. Las citas se cancelan desde la agenda; no se marca una cita como atendida sin
registrar su atención clínica.

## Respaldos diarios en Windows y VM Linux

Los scripts operativos están en `scripts/backup/`. El respaldo local usa
`mysqldump` con la cuenta dedicada `mimascota_backup`, crea un `.zip` local y
puede enviarlo por `scp` a una VM Linux. La cuenta y la contraseña se configuran
fuera del repositorio en `C:\mimascota\config\db.env`; nunca agregues ese archivo,
llaves SSH, registros ni archivos de respaldo a Git.

1. Copia `scripts/backup/db.env.example` a `C:\mimascota\config\db.env` y completa
   los valores localmente. Usa `DB_USER=mimascota_backup` y la contraseña que
   asignaste a esa cuenta al instalar `06_usuarios.sql`.
2. Copia los scripts PowerShell a `C:\mimascota\` y valida primero con
   `.\respaldo.ps1 -LocalOnly`. Sin `-LocalOnly`, el script necesita una llave SSH
   ya autorizada y una entrada verificada en `known_hosts`.
3. Registra las tareas con
   `powershell.exe -NoProfile -File C:\mimascota\install_tasks.ps1 -MonitorOnly`.
   Cuando el respaldo local ya funcione, registra también el respaldo diario a
   las 06:00: `powershell.exe -NoProfile -File C:\mimascota\install_tasks.ps1 -BackupOnly`.
   La tarea corre con la sesión del usuario y usa `StartWhenAvailable`; el usuario
   debe iniciar sesión para que Windows pueda acceder a la llave SSH.
4. En la VM, instala `unzip` y MySQL client. Configura
   `~/.config/mimascota/verify.cnf` a partir de
   `scripts/backup/verify.cnf.example` y aplica `chmod 600` al archivo. El usuario
   de cron necesita permiso de escritura en `verificados/` y `rechazados/`; si
   hace falta, un administrador debe asignarle esos directorios. Luego programa
   `30 2 * * * /home/respaldo/.local/bin/verificar_respaldo.sh`. El script solo
   acepta ZIP con un `.sql` completo y al menos 12 tablas; importa en
   `mimascota_verif` y registra el resultado en `~/logs/mimascota/`.

   Por ejemplo, con autorización administrativa en la VM:

   ```sh
   sudo chown respaldo:respaldo /var/backups/mimascota/verificados /var/backups/mimascota/rechazados
   sudo chmod 750 /var/backups/mimascota/verificados /var/backups/mimascota/rechazados
   ```

   Un administrador puede preparar la base de verificación y el usuario limitado
   (reemplaza el marcador por una clave propia y no guardes este SQL en el repo):

   ```sql
   CREATE DATABASE IF NOT EXISTS mimascota_verif CHARACTER SET utf8mb4;
   CREATE USER IF NOT EXISTS 'mimascota_verifier'@'localhost'
     IDENTIFIED BY 'CAMBIAR_por_una_clave_propia';
   GRANT SELECT, CREATE, DROP, ALTER, INDEX, REFERENCES, INSERT, UPDATE, DELETE,
     CREATE VIEW, SHOW VIEW, TRIGGER, CREATE ROUTINE, ALTER ROUTINE, EXECUTE
     ON mimascota_verif.* TO 'mimascota_verifier'@'localhost';
   ```
5. `restaurar.ps1` descarga el ZIP verificado más reciente y exige escribir una
   confirmación exacta antes de importar. La restauración es manual y destructiva
   para las tablas que contiene el volcado.
6. `monitor.ps1` registra cada muestra y alerta si CPU llega a 85%, RAM libre baja
   de 15%, disco libre baja de 10%, MySQL80 no está activo o el respaldo local
   tiene más de 26 horas.

Los umbrales son valores iniciales conservadores para supervisar cada cinco
minutos; ajústalos a la carga y capacidad reales. Mantén la VM encendida para que
el cron y la recepción diaria funcionen. Estos scripts no crean ni imprimen
contraseñas y no sustituyen las copias administradas/PITR que ofrece Azure.
