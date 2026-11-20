# Informe de respaldo y monitoreo

## Comparación de procesos y cuentas

### Windows

En la captura de estado del 20 de noviembre de 2026, el servicio `MySQL80` estaba
activo y configurado para iniciar como `NT AUTHORITY\NetworkService`. El
`mysqld.exe` del servicio depende del Administrador de control de servicios
(`services.exe`); también se observó otro `mysqld.exe` iniciado por
`xampp-control.exe`. Ambas instancias usaban el puerto 3306 en direcciones
distintas: MySQL80 en `127.0.0.1` y XAMPP/MariaDB 10.4.32 en `::1`. La base
`mimascota` usada por el respaldo está en XAMPP; por eso la configuración apunta
a `::1` y usa los clientes de XAMPP.

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
cambia el tamaño de la base o la carga habitual. La VM está en UTC; el cron de
verificación quedó programado a las 12:30 UTC, después del respaldo Windows de
las 06:00 hora local (UTC-5).

## Estado de verificación

El monitor local y las tareas `MiMascota-Monitor` y `MiMascota-RespaldoDiario`
quedaron registradas. El respaldo diario se ejecutó con resultado 0 y se
transfirió a la VM. La configuración de verificación está en
`/home/respaldo/.config/mimascota/verify.cnf` con permisos 0600; el usuario
`respaldo` puede escribir en `verificados/` y `rechazados/`.

La importación de prueba falló inicialmente porque MariaDB incluyó
`DEFINER=root@localhost` y el usuario de verificación no tenía `SET_USER_ID`.
El verificador se ajustó para retirar `DEFINER` solo del SQL temporal de prueba,
sin alterar los ZIP originales ni conceder privilegios globales. Luego los ZIP
se importaron en `mimascota_verif` con 12 tablas y quedaron en `verificados/`;
el cron corre diariamente a las 12:30 UTC.

El 20 de noviembre de 2026 se restauró en la base local `mimascota` el ZIP
verificado más reciente. La comprobación posterior encontró 12 tablas, 7
triggers y 3 vistas, y el log local registró `[OK]`. La VM permanece encendida
según la preferencia del usuario.
