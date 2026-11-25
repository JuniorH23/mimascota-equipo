# MiMascota — interfaz de escritorio

Aplicación de escritorio en Python/Tkinter para administrar la base MySQL `mimascota`.
Incluye propietarios, mascotas, citas, atención clínica, vacunación, inventario y un
resumen de la agenda del día. La pestaña **Consulta personalizada** permite buscar
el expediente y la información relacionada ingresando el ID de la mascota.

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

En la pantalla de conexión se proponen `127.0.0.1`, puerto `3307`, base `mimascota`
y usuario `mimascota_app`. Escribe la contraseña de ese usuario; la aplicación no
la guarda. El puerto `3307` evita el conflicto con otro servicio MySQL que pueda
estar configurado en el puerto `3306`.

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

La pestaña **Eliminar mascota** elimina la mascota seleccionada y, tras confirmación,
sus citas, atenciones, recetas, vacunas y cambios de propietario dentro de una
transacción. La acción es permanente; queda una entrada de auditoría en `bitacora`.
En instalaciones existentes, importa la versión actualizada de `05_logica.sql` como
administrador y concede `EXECUTE` sobre `sp_eliminar_mascota` a `mimascota_app`
para `localhost` y `127.0.0.1`.

## Organización, respaldos y restauración en Windows

Los scripts de MySQL 8.0 y la VM están en `scripts\backup`. La configuración
privada, los registros y los ZIP se mantienen fuera del repositorio en `C:\mimascota`:

- Configuración MySQL 8.0: `C:\mimascota\config\mysql80-backup.env`
- Respaldos: `C:\mimascota\respaldos`
- Registros: `C:\mimascota\logs`

En PowerShell abierto como Administrador, ejecuta primero `preparar_mysql80.ps1`.
Solicita localmente el host y usuario SSH de la VM y la clave de root, verifica
el SHA-256 del ZIP más reciente
en la VM, e importa ese ZIP solo si la base `mimascota` no existe en MySQL 8.0.
Si ya existe, no la modifica. Crea una cuenta limitada de respaldo y guarda su
clave en el archivo privado con permisos para SYSTEM y Administradores; no la
envíes por chat ni la subas a Git.

Después ejecuta `tarea.ps1` como Administrador. Registra
`MiMascota-Backup-03AM` como SYSTEM, diariamente a las 03:00, con tres
reintentos. Despliega el verificador SHA-256 en la VM y realiza una prueba
inmediata de extremo a extremo bajo SYSTEM; si pasa, deshabilita las dos tareas
anteriores para evitar respaldos duplicados. El ciclo monitorea/inicia
`MySQL80`, crea un ZIP con SHA-256, lo sube por SCP y confirma que la VM lo
verificó en `/var/backups/mimascota/verificados/`. Los registros están en
`C:\mimascota\logs`.

La restauración sigue siendo manual y pide confirmación explícita. Descarga el
ZIP verificado más reciente, valida su SHA-256 y luego importa en MySQL 8.0:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File C:\Proyecto\scripts\backup\restaurar.ps1
```

La restauración reemplaza las tablas incluidas. Para probar el flujo de
demostración sin alterar la base real, ejecuta:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File C:\Proyecto\prueba_restauracion.ps1
```

La demostración usa una base temporal, simula allí una alteración y restaura el
contenido desde el ZIP.
