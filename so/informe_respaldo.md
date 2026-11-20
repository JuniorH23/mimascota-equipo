# Informe de respaldo y monitoreo

## Comparación de procesos y cuentas

### Windows

En la captura de estado del 20 de noviembre de 2026, el servicio `MySQL80` estaba
activo y configurado para iniciar como `NT AUTHORITY\NetworkService`. El
`mysqld.exe` del servicio depende del Administrador de control de servicios
(`services.exe`); también se observó otro `mysqld.exe` iniciado por
`xampp-control.exe`. La configuración de respaldo usa `127.0.0.1:3306`, por lo
que conviene confirmar siempre qué instancia atiende ese puerto antes de
restaurar datos.

No había procesos `python.exe` en ejecución al tomar la muestra; por eso no se
puede afirmar un proceso padre o una cuenta de ejecución de Python en Windows a
partir de esa observación.

### VM Linux

La muestra de la VM mostró `mysqld` con cuenta `mysql` y padre PID 1 (el
administrador de servicios del sistema). Los procesos `python3` observados
corrían como `root`; uno era hijo de PID 1 y otro hijo del primer proceso
`python3`. Para una aplicación permanente se recomienda ejecutar Python con una
cuenta de servicio dedicada y permisos mínimos, no como `root`.

En Windows el servicio MySQL corre con una identidad de servicio de Windows; en
Linux el servidor corre con la cuenta del sistema `mysql`. En ambos casos la
aplicación debería tener una identidad separada y limitada. La cuenta
`mimascota_backup` se usa para leer y volcar la base, no para ejecutar la
aplicación.

## Umbrales iniciales

El monitor se ejecuta cada cinco minutos y registra CPU, memoria disponible,
espacio libre, servicio y procesos MySQL, y antigüedad del último ZIP local.

- **CPU >= 85%:** indica carga alta que puede retrasar consultas o respaldos.
- **RAM libre < 15%:** conserva un margen para el sistema operativo y la caché
  de MySQL; por debajo de ese nivel aumenta el riesgo de paginación.
- **Disco libre < 10%:** permite detectar falta de espacio antes de que el
  volcado o los registros fallen.
- **Respaldo > 26 horas:** detecta una ejecución diaria omitida más un margen
  para retrasos de inicio o transferencia.
- **MySQL80 detenido o sin `mysqld.exe`:** indica que la base local no está
  disponible.

Estos son umbrales de partida, no mediciones de capacidad. Deben revisarse si
cambia el tamaño de la base o la carga habitual. La VM está en UTC; la tarea
cron de las 02:30 se interpreta en UTC.

## Estado de verificación

El monitor local se ejecutó y la tarea `MiMascota-Monitor` quedó registrada.
El script `verificar_respaldo.sh` quedó desplegado en la cuenta `respaldo`, pero
cron no se programó: falta la configuración privada de MySQL para
`mimascota_verif` y permisos de escritura del usuario en `verificados/` y
`rechazados/`. El respaldo local tampoco pudo ejecutarse porque `DB_PASS` seguía
vacío al verificar la configuración; por eso no se afirma una verificación de
archivo real. Se confirmó que el verificador sale con error y deja un registro
claro si falta `verify.cnf`; no se importó ni se movió ningún respaldo.
