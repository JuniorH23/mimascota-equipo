-- ==========================================================
-- PROYECTO: MiMascota - Seguridad y Privilegios (06_usuarios.sql)
-- Cumple BD6: Usuarios de aplicación, reportes y respaldo (nunca root)
-- ==========================================================

-- LOCAL (XAMPP): los usuarios se crean para 'localhost' y '127.0.0.1' (socket y TCP).
-- IMPORTANTE: cambie las claves 'CAMBIAR_*' antes de desplegar; deben coincidir con su archivo .env (ver .env.example).
USE mimascota;

DROP USER IF EXISTS 'mimascota_app'@'localhost';
DROP USER IF EXISTS 'mimascota_app'@'127.0.0.1';
DROP USER IF EXISTS 'mimascota_reportes'@'localhost';
DROP USER IF EXISTS 'mimascota_reportes'@'127.0.0.1';
DROP USER IF EXISTS 'mimascota_backup'@'localhost';
DROP USER IF EXISTS 'mimascota_backup'@'127.0.0.1';

-- 1. Usuario de la aplicación (solo operaciones necesarias sobre tablas, vistas y rutinas)
CREATE USER 'mimascota_app'@'localhost' IDENTIFIED BY 'CAMBIAR_clave_app';
CREATE USER 'mimascota_app'@'127.0.0.1' IDENTIFIED BY 'CAMBIAR_clave_app';

GRANT SELECT, INSERT, UPDATE ON mimascota.propietarios TO 'mimascota_app'@'localhost';
GRANT SELECT, INSERT, UPDATE ON mimascota.propietarios TO 'mimascota_app'@'127.0.0.1';
GRANT SELECT, INSERT, UPDATE ON mimascota.mascotas TO 'mimascota_app'@'localhost';
GRANT SELECT, INSERT, UPDATE ON mimascota.mascotas TO 'mimascota_app'@'127.0.0.1';
GRANT DELETE ON mimascota.mascotas TO 'mimascota_app'@'localhost';
GRANT DELETE ON mimascota.mascotas TO 'mimascota_app'@'127.0.0.1';
GRANT SELECT, INSERT, UPDATE ON mimascota.citas TO 'mimascota_app'@'localhost';
GRANT SELECT, INSERT, UPDATE ON mimascota.citas TO 'mimascota_app'@'127.0.0.1';
GRANT SELECT, INSERT ON mimascota.historial_clinico TO 'mimascota_app'@'localhost';
GRANT SELECT, INSERT ON mimascota.historial_clinico TO 'mimascota_app'@'127.0.0.1';
GRANT SELECT, INSERT ON mimascota.prescripciones TO 'mimascota_app'@'localhost';
GRANT SELECT, INSERT ON mimascota.prescripciones TO 'mimascota_app'@'127.0.0.1';
GRANT SELECT, INSERT ON mimascota.vacunacion TO 'mimascota_app'@'localhost';
GRANT SELECT, INSERT ON mimascota.vacunacion TO 'mimascota_app'@'127.0.0.1';
GRANT SELECT ON mimascota.veterinarios TO 'mimascota_app'@'localhost';
GRANT SELECT ON mimascota.veterinarios TO 'mimascota_app'@'127.0.0.1';
GRANT SELECT ON mimascota.servicios TO 'mimascota_app'@'localhost';
GRANT SELECT ON mimascota.servicios TO 'mimascota_app'@'127.0.0.1';
GRANT SELECT ON mimascota.medicamentos TO 'mimascota_app'@'localhost';
GRANT SELECT ON mimascota.medicamentos TO 'mimascota_app'@'127.0.0.1';
GRANT SELECT ON mimascota.vacunas TO 'mimascota_app'@'localhost';
GRANT SELECT ON mimascota.vacunas TO 'mimascota_app'@'127.0.0.1';
GRANT SELECT ON mimascota.v_mascota_ficha TO 'mimascota_app'@'localhost';
GRANT SELECT ON mimascota.v_mascota_ficha TO 'mimascota_app'@'127.0.0.1';
GRANT SELECT ON mimascota.v_agenda TO 'mimascota_app'@'localhost';
GRANT SELECT ON mimascota.v_agenda TO 'mimascota_app'@'127.0.0.1';
GRANT SELECT ON mimascota.v_propietario_resumen TO 'mimascota_app'@'localhost';
GRANT SELECT ON mimascota.v_propietario_resumen TO 'mimascota_app'@'127.0.0.1';

GRANT EXECUTE ON PROCEDURE mimascota.sp_agendar_cita TO 'mimascota_app'@'localhost';
GRANT EXECUTE ON PROCEDURE mimascota.sp_agendar_cita TO 'mimascota_app'@'127.0.0.1';
GRANT EXECUTE ON PROCEDURE mimascota.sp_registrar_atencion TO 'mimascota_app'@'localhost';
GRANT EXECUTE ON PROCEDURE mimascota.sp_registrar_atencion TO 'mimascota_app'@'127.0.0.1';
GRANT EXECUTE ON PROCEDURE mimascota.sp_eliminar_mascota TO 'mimascota_app'@'localhost';
GRANT EXECUTE ON PROCEDURE mimascota.sp_eliminar_mascota TO 'mimascota_app'@'127.0.0.1';
GRANT EXECUTE ON FUNCTION mimascota.fn_edad_mascota TO 'mimascota_app'@'localhost';
GRANT EXECUTE ON FUNCTION mimascota.fn_edad_mascota TO 'mimascota_app'@'127.0.0.1';

-- 2. Usuario de reportes (solo lectura sobre las vistas y función de edad)
CREATE USER 'mimascota_reportes'@'localhost' IDENTIFIED BY 'CAMBIAR_clave_reportes';
CREATE USER 'mimascota_reportes'@'127.0.0.1' IDENTIFIED BY 'CAMBIAR_clave_reportes';

GRANT SELECT ON mimascota.v_mascota_ficha TO 'mimascota_reportes'@'localhost';
GRANT SELECT ON mimascota.v_mascota_ficha TO 'mimascota_reportes'@'127.0.0.1';
GRANT SELECT ON mimascota.v_agenda TO 'mimascota_reportes'@'localhost';
GRANT SELECT ON mimascota.v_agenda TO 'mimascota_reportes'@'127.0.0.1';
GRANT SELECT ON mimascota.v_propietario_resumen TO 'mimascota_reportes'@'localhost';
GRANT SELECT ON mimascota.v_propietario_resumen TO 'mimascota_reportes'@'127.0.0.1';
GRANT EXECUTE ON FUNCTION mimascota.fn_edad_mascota TO 'mimascota_reportes'@'localhost';
GRANT EXECUTE ON FUNCTION mimascota.fn_edad_mascota TO 'mimascota_reportes'@'127.0.0.1';

-- 3. Usuario de respaldo (privilegios mínimos para ejecutar mysqldump)
CREATE USER 'mimascota_backup'@'localhost' IDENTIFIED BY 'CAMBIAR_clave_backup';
CREATE USER 'mimascota_backup'@'127.0.0.1' IDENTIFIED BY 'CAMBIAR_clave_backup';

GRANT SELECT, SHOW VIEW, TRIGGER, LOCK TABLES ON mimascota.* TO 'mimascota_backup'@'localhost';
GRANT SELECT, SHOW VIEW, TRIGGER, LOCK TABLES ON mimascota.* TO 'mimascota_backup'@'127.0.0.1';

FLUSH PRIVILEGES;
