# Instalar MiMascota en local (XAMPP + phpMyAdmin)

1. Abra XAMPP e inicie **Apache** y **MySQL**.
2. Entre a http://localhost/phpmyadmin con el usuario `root` (en XAMPP no tiene clave por defecto).
3. Pestaña **Importar** → elija `instalar_todo_local.sql` → **Importar**.
   - Borra y recrea la base `mimascota`, así que puede repetirse las veces que quiera.
   - Crea 12 tablas, 3 vistas, 1 función, 2 procedimientos, 7 disparadores y 3 usuarios.
4. Las **consultas** están en `04_consultas.sql`: ábralo, copie **una consulta a la vez** y ejecútela en la pestaña **SQL** (si lo importa completo, phpMyAdmin solo muestra el último resultado).
5. Claves de los usuarios: están en `06_usuarios.sql` (`CAMBIAR_clave_...`). Cámbielas antes de entregar y use las mismas en su `.env` (ver `.env.example`).

## Si phpMyAdmin se queja al importar
- **Tamaño máximo:** el archivo pesa ~45 KB, no debería haber problema.
- **Error con DELIMITER:** importe los archivos por separado en este orden: `01_ddl.sql`, `02_datos.sql`, `03_vistas.sql`, `05_logica.sql`, `06_usuarios.sql`.
- **Permisos al crear usuarios:** importe con `root`, no con otro usuario.
