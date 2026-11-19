-- 03_vistas.sql · BD4 · 3 vistas que usa la aplicación
USE mimascota;

-- Vista 1: Ficha completa de la mascota y su propietario
CREATE OR REPLACE VIEW v_mascota_ficha AS
SELECT m.id_mascota,
       m.nombre AS mascota,
       m.especie,
       m.raza,
       m.sexo,
       m.fecha_nacimiento,
       TIMESTAMPDIFF(YEAR, m.fecha_nacimiento, CURDATE()) AS edad_anios,
       m.estado,
       p.id_propietario,
       p.nombre AS propietario,
       p.telefono,
       p.email
FROM mascotas m
JOIN propietarios p ON p.id_propietario = m.id_propietario;

-- Vista 2: Agenda completa de citas (une 5 tablas)
CREATE OR REPLACE VIEW v_agenda AS
SELECT c.id_cita,
       c.fecha_hora,
       c.estado,
       m.id_mascota,
       m.nombre AS mascota,
       m.especie,
       p.nombre AS propietario,
       p.telefono AS telefono_propietario,
       v.id_veterinario,
       v.nombre AS veterinario,
       s.id_servicio,
       s.nombre AS servicio,
       s.precio
FROM citas c
JOIN mascotas m ON m.id_mascota = c.id_mascota
JOIN propietarios p ON p.id_propietario = m.id_propietario
JOIN veterinarios v ON v.id_veterinario = c.id_veterinario
JOIN servicios s ON s.id_servicio = c.id_servicio;

-- Vista 3: Resumen de propietarios y cantidad de mascotas activas
CREATE OR REPLACE VIEW v_propietario_resumen AS
SELECT p.id_propietario,
       p.nombre,
       p.telefono,
       p.email,
       COUNT(m.id_mascota) AS mascotas_activas
FROM propietarios p
LEFT JOIN mascotas m 
       ON m.id_propietario = p.id_propietario 
      AND m.estado = 'activa'
WHERE p.activo = 1
GROUP BY p.id_propietario, p.nombre, p.telefono, p.email;
