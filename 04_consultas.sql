-- 04_consultas.sql · BD4 · 15 consultas de negocio
USE mimascota;


-- 01. Mascotas por propietario con especie y raza (JOIN de 4 tablas)
SELECT p.nombre AS propietario, m.nombre AS mascota, m.especie, m.raza, m.estado,
       COUNT(c.id_cita) AS total_citas,
       COALESCE(SUM(s.precio), 0) AS valor_servicios
FROM propietarios p
JOIN mascotas m ON m.id_propietario = p.id_propietario
LEFT JOIN citas c ON c.id_mascota = m.id_mascota AND c.estado = 'atendida'
LEFT JOIN servicios s ON s.id_servicio = c.id_servicio
GROUP BY p.id_propietario, p.nombre, m.id_mascota, m.nombre, m.especie, m.raza, m.estado
ORDER BY p.nombre, m.nombre;

-- 02. Citas de la próxima semana por veterinario
SELECT v.nombre AS veterinario, c.fecha_hora, m.nombre AS mascota, s.nombre AS servicio, c.estado
FROM citas c
JOIN veterinarios v ON v.id_veterinario = c.id_veterinario
JOIN mascotas m ON m.id_mascota = c.id_mascota
JOIN servicios s ON s.id_servicio = c.id_servicio
WHERE c.fecha_hora BETWEEN NOW() AND DATE_ADD(NOW(), INTERVAL 7 DAY)
  AND c.estado = 'agendada'
ORDER BY v.nombre, c.fecha_hora;

-- 03. Atenciones por especie en el último año (GROUP BY)
SELECT m.especie, COUNT(h.id_historial) AS total_atenciones
FROM historial_clinico h
JOIN mascotas m ON m.id_mascota = h.id_mascota
WHERE h.fecha_registro >= DATE_SUB(CURDATE(), INTERVAL 1 YEAR)
GROUP BY m.especie
ORDER BY total_atenciones DESC;

-- 04. Ingresos por servicio y por mes
SELECT s.nombre AS servicio,
       DATE_FORMAT(c.fecha_hora, '%Y-%m') AS mes,
       COUNT(c.id_cita) AS cantidad_atendidas,
       SUM(s.precio) AS ingresos_totales
FROM citas c
JOIN servicios s ON s.id_servicio = c.id_servicio
WHERE c.estado = 'atendida'
GROUP BY s.nombre, DATE_FORMAT(c.fecha_hora, '%Y-%m')
ORDER BY mes DESC, ingresos_totales DESC;

-- 05. Veterinarios con más de 10 citas atendidas en el mes (HAVING)
SELECT v.id_veterinario, v.nombre AS veterinario, COUNT(c.id_cita) AS citas_atendidas_mes
FROM veterinarios v
JOIN citas c ON c.id_veterinario = v.id_veterinario
WHERE c.estado = 'atendida'
  AND YEAR(c.fecha_hora) = YEAR(CURDATE())
  AND MONTH(c.fecha_hora) = MONTH(CURDATE())
GROUP BY v.id_veterinario, v.nombre
HAVING COUNT(c.id_cita) > 10;

-- 06. Vacunas vencidas o por vencer en 15 días
SELECT p.nombre AS propietario, p.telefono, m.nombre AS mascota,
       vac.nombre AS vacuna, v.fecha_proxima_dosis,
       CASE 
           WHEN v.fecha_proxima_dosis < CURDATE() THEN 'Vencida'
           ELSE 'Por vencer (<= 15 días)'
       END AS estado_vacuna
FROM vacunacion v
JOIN mascotas m ON m.id_mascota = v.id_mascota
JOIN propietarios p ON p.id_propietario = m.id_propietario
JOIN vacunas vac ON vac.id_vacuna = v.id_vacuna
WHERE m.estado = 'activa'
  AND v.fecha_proxima_dosis <= DATE_ADD(CURDATE(), INTERVAL 15 DAY)
ORDER BY v.fecha_proxima_dosis ASC;

-- 07. Propietarios sin citas en 6 meses (LEFT JOIN / NOT EXISTS)
SELECT p.id_propietario, p.nombre, p.telefono, p.email
FROM propietarios p
WHERE p.activo = 1
  AND NOT EXISTS (
      SELECT 1
      FROM mascotas m
      JOIN citas c ON c.id_mascota = m.id_mascota
      WHERE m.id_propietario = p.id_propietario
        AND c.fecha_hora >= DATE_SUB(NOW(), INTERVAL 6 MONTH)
  );

-- 08. Mascota con más atenciones por especie (subconsulta correlacionada)
SELECT m1.especie, m1.nombre AS mascota, COUNT(h1.id_historial) AS total_atenciones
FROM mascotas m1
JOIN historial_clinico h1 ON h1.id_mascota = m1.id_mascota
GROUP BY m1.id_mascota, m1.especie, m1.nombre
HAVING COUNT(h1.id_historial) >= ALL (
    SELECT COUNT(h2.id_historial)
    FROM mascotas m2
    JOIN historial_clinico h2 ON h2.id_mascota = m2.id_mascota
    WHERE m2.especie = m1.especie
    GROUP BY m2.id_mascota
)
ORDER BY m1.especie, m1.nombre;

-- 09. Evolución del peso de una mascota (cambie @id_mascota por la mascota a consultar)
SET @id_mascota = 1;
SELECT m.nombre AS mascota, h.fecha_registro, h.peso AS peso_kg, h.diagnostico
FROM historial_clinico h
JOIN mascotas m ON m.id_mascota = h.id_mascota
WHERE h.id_mascota = @id_mascota
ORDER BY h.fecha_registro ASC;

-- 10. Porcentaje de citas canceladas por veterinario
SELECT v.nombre AS veterinario,
       COUNT(c.id_cita) AS total_citas,
       SUM(CASE WHEN c.estado = 'cancelada' THEN 1 ELSE 0 END) AS canceladas,
       ROUND(
           (SUM(CASE WHEN c.estado = 'cancelada' THEN 1 ELSE 0 END) * 100.0) / NULLIF(COUNT(c.id_cita), 0),
           2
       ) AS porcentaje_canceladas
FROM veterinarios v
LEFT JOIN citas c ON c.id_veterinario = v.id_veterinario
GROUP BY v.id_veterinario, v.nombre
ORDER BY porcentaje_canceladas DESC;

-- 11. Servicios nunca vendidos
SELECT s.id_servicio, s.nombre, s.precio
FROM servicios s
LEFT JOIN citas c ON c.id_servicio = s.id_servicio AND c.estado = 'atendida'
WHERE c.id_cita IS NULL;

-- 12. Top 5 de medicamentos más formulados
SELECT med.nombre AS medicamento, med.presentacion,
       COUNT(pr.id_prescripcion) AS veces_formulado,
       SUM(pr.cantidad) AS unidades_totales
FROM prescripciones pr
JOIN medicamentos med ON med.id_medicamento = pr.id_medicamento
GROUP BY med.id_medicamento, med.nombre, med.presentacion
ORDER BY unidades_totales DESC, veces_formulado DESC
LIMIT 5;

-- 13. Edad promedio de las mascotas por especie
SELECT especie,
       COUNT(*) AS cantidad_mascotas,
       ROUND(AVG(TIMESTAMPDIFF(MONTH, fecha_nacimiento, CURDATE()) / 12.0), 1) AS edad_promedio_anios
FROM mascotas
WHERE estado = 'activa'
GROUP BY especie
ORDER BY edad_promedio_anios DESC;

-- 14. Agenda del día con propietario, mascota, servicio y teléfono
SELECT TIME(c.fecha_hora) AS hora,
       p.nombre AS propietario,
       p.telefono,
       m.nombre AS mascota,
       s.nombre AS servicio,
       v.nombre AS veterinario,
       c.estado
FROM citas c
JOIN mascotas m ON m.id_mascota = c.id_mascota
JOIN propietarios p ON p.id_propietario = m.id_propietario
JOIN servicios s ON s.id_servicio = c.id_servicio
JOIN veterinarios v ON v.id_veterinario = c.id_veterinario
WHERE DATE(c.fecha_hora) = CURDATE()
ORDER BY c.fecha_hora ASC;

-- 15. Consulta propia con UNION, CASE y subconsulta en FROM (Resumen ejecutivo de alertas)
SELECT tipo_alerta, prioridad, cantidad
FROM (
    SELECT 'Vacunas vencidas o próximas (15 días)' AS tipo_alerta,
           CASE WHEN COUNT(*) > 5 THEN 'Alta' ELSE 'Media' END AS prioridad,
           COUNT(*) AS cantidad
    FROM vacunacion
    WHERE fecha_proxima_dosis <= DATE_ADD(CURDATE(), INTERVAL 15 DAY)
    UNION ALL
    SELECT 'Medicamentos con stock bajo (<= 15 unid.)' AS tipo_alerta,
           CASE WHEN COUNT(*) > 0 THEN 'Alta' ELSE 'Normal' END AS prioridad,
           COUNT(*) AS cantidad
    FROM medicamentos
    WHERE stock <= 15 AND activo = 1
) AS resumen_alertas;