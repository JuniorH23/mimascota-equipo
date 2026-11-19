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
