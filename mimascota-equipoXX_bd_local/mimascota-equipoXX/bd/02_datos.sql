-- 02_datos.sql · BD3 · Datos ficticios (20 propietarios, 30 mascotas, 60 citas, 50 vacunas)
USE mimascota;

-- 1. 20 Propietarios ficticios (cumple mínimo 20)
INSERT INTO propietarios (id_propietario, nombre, telefono, email, direccion) VALUES
(1, 'Ana Ruiz', '3001112233', 'ana.ruiz@ejemplo.com', 'Calle 5 # 10-20'),
(2, 'Carlos Díaz', '3014445566', 'carlos.diaz@ejemplo.com', 'Carrera 9 # 15-40'),
(3, 'Marta López', '3027778899', 'marta.lopez@ejemplo.com', 'Transversal 4 # 2-12'),
(4, 'Luis Gómez', '3101234567', 'luis.gomez@ejemplo.com', 'Calle 18 # 6-30'),
(5, 'Sofía Castro', '3112345678', 'sofia.castro@ejemplo.com', 'Av. Panamericana # 12-05'),
(6, 'Jorge Ramírez', '3123456789', 'jorge.ramirez@ejemplo.com', 'Calle 8 # 4-15'),
(7, 'Elena Torres', '3134567890', 'elena.torres@ejemplo.com', 'Carrera 11 # 20-10'),
(8, 'Andrés Herrera', '3145678901', 'andres.herrera@ejemplo.com', 'Calle 25N # 8-45'),
(9, 'Camila Vargas', '3156789012', 'camila.vargas@ejemplo.com', 'Carrera 6 # 3-50'),
(10, 'Diego Morales', '3167890123', 'diego.morales@ejemplo.com', 'Calle 14 # 9-18'),
(11, 'Valentina Ortiz', '3178901234', 'valentina.ortiz@ejemplo.com', 'Carrera 17 # 11-22'),
(12, 'Sebastián Silva', '3189012345', 'sebastian.silva@ejemplo.com', 'Calle 3 # 7-14'),
(13, 'Natalia Rojas', '3190123456', 'natalia.rojas@ejemplo.com', 'Carrera 4 # 19-08'),
(14, 'Mateo Mendoza', '3201234567', 'mateo.mendoza@ejemplo.com', 'Calle 30N # 5-60'),
(15, 'Isabella Peña', '3212345678', 'isabella.pena@ejemplo.com', 'Carrera 14 # 2-33'),
(16, 'Felipe Ríos', '3223456789', 'felipe.rios@ejemplo.com', 'Calle 10 # 12-41'),
(17, 'Daniela Suárez', '3234567890', 'daniela.suarez@ejemplo.com', 'Carrera 8 # 16-25'),
(18, 'Nicolás Pardo', '3009876543', 'nicolas.pardo@ejemplo.com', 'Calle 22 # 3-19'),
(19, 'Gabriela León', '3018765432', 'gabriela.leon@ejemplo.com', 'Carrera 2 # 8-70'),
(20, 'Ricardo Acosta', '3027654321', 'ricardo.acosta@ejemplo.com', 'Calle 40N # 10-12');

-- 2. 4 Veterinarios
INSERT INTO veterinarios (id_veterinario, nombre, especialidad, telefono, email) VALUES
(1, 'Dra. Paula Vega', 'Medicina Interna', '3109991122', 'paula.vega@mimascota.local'),
(2, 'Dr. Andrés Mora', 'Cirugía General', '3207773344', 'andres.mora@mimascota.local'),
(3, 'Dra. Laura Gil', 'Dermatología y Exóticos', '3146665555', 'laura.gil@mimascota.local'),
(4, 'Dr. Camilo Soto', 'Medicina Preventiva', '3154442211', 'camilo.soto@mimascota.local');

-- 3. 6 Servicios (El servicio 6 queda sin citas para probar la Consulta 11)
INSERT INTO servicios (id_servicio, nombre, precio, descripcion) VALUES
(1, 'Consulta general', 50000.00, 'Valoración clínica completa'),
(2, 'Vacunación', 35000.00, 'Aplicación de biológico según esquema'),
(3, 'Baño y corte medicado', 45000.00, 'Higiene dermatológica'),
(4, 'Profilaxis dental', 120000.00, 'Limpieza dental con ultrasonido'),
(5, 'Cirugía menor', 250000.00, 'Procedimiento quirúrgico ambulatorio'),
(6, 'Ecografía abdominal especializada', 180000.00, 'Diagnóstico por imagen avanzado');

-- 4. 6 Medicamentos con stock
INSERT INTO medicamentos (id_medicamento, nombre, presentacion, stock) VALUES
(1, 'Amoxicilina 250mg', 'Suspensión 100ml', 30),
(2, 'Meloxicam 2mg', 'Caja x 10 tabletas', 40),
(3, 'Doxiciclina 100mg', 'Caja x 20 tabletas', 25),
(4, 'Prednisolona 5mg', 'Frasco x 30 tabletas', 20),
(5, 'Ivermectina Oral', 'Gotero 15ml', 35),
(6, 'Clorhexidina Spray', 'Frasco 120ml', 15);

-- 5. 5 Vacunas del catálogo
INSERT INTO vacunas (id_vacuna, nombre, descripcion, intervalo_dias) VALUES
(1, 'Pentavalente Canina', 'Moquillo, Parvovirus, Hepatitis, Parainfluenza, Leptospira', 365),
(2, 'Antirrábica', 'Prevención virus de la rabia', 365),
(3, 'Triple Felina', 'Panleucopenia, Rinotraqueitis, Calicivirus', 365),
(4, 'Tos de las Perreras', 'Bordetella bronchiseptica', 180),
(5, 'Leucemia Felina', 'Prevención FeLV en gatos', 365);

-- 6. 30 Mascotas (cumple mínimo 30; propietario 4 no tiene mascotas para pruebas LEFT JOIN)
INSERT INTO mascotas (id_mascota, id_propietario, nombre, especie, raza, sexo, fecha_nacimiento, estado) VALUES
(1, 1, 'Luna', 'Perro', 'Criollo', 'H', '2021-04-10', 'activa'),
(2, 1, 'Milo', 'Gato', 'Siamés', 'M', '2022-08-15', 'activa'),
(3, 2, 'Rocky', 'Perro', 'Labrador', 'M', '2020-02-20', 'activa'),
(4, 2, 'Toby', 'Perro', 'Beagle', 'M', '2023-05-12', 'activa'),
(5, 3, 'Kiwi', 'Ave', 'Periquito', 'H', '2023-09-01', 'adoptada'),
(6, 5, 'Max', 'Perro', 'Golden Retriever', 'M', '2019-11-30', 'activa'),
(7, 5, 'Nala', 'Gato', 'Persa', 'H', '2021-06-18', 'activa'),
(8, 6, 'Bruno', 'Perro', 'Bulldog Francés', 'M', '2022-01-25', 'activa'),
(9, 7, 'Mia', 'Gato', 'Criollo', 'H', '2020-10-14', 'activa'),
(10, 8, 'Simba', 'Gato', 'Maine Coon', 'M', '2021-12-03', 'activa'),
(11, 9, 'Coco', 'Perro', 'Poodle', 'M', '2018-07-07', 'fallecida'),
(12, 9, 'Kira', 'Perro', 'Husky Siberiano', 'H', '2022-03-19', 'activa'),
(13, 10, 'Zeus', 'Perro', 'Pastor Alemán', 'M', '2020-09-22', 'activa'),
(14, 11, 'Lola', 'Perro', 'Schnauzer', 'H', '2021-01-11', 'activa'),
(15, 11, 'Oliver', 'Gato', 'Angora', 'M', '2023-02-28', 'activa'),
(16, 12, 'Thor', 'Perro', 'Boxer', 'M', '2019-05-04', 'activa'),
(17, 13, 'Canela', 'Perro', 'Cocker Spaniel', 'H', '2022-11-16', 'activa'),
(18, 13, 'Pelusa', 'Conejo', 'Cabeza de León', 'H', '2024-01-09', 'activa'),
(19, 14, 'Lucas', 'Perro', 'Dachshund', 'M', '2021-08-27', 'activa'),
(20, 15, 'Nina', 'Gato', 'Bengalí', 'H', '2022-04-02', 'activa'),
(21, 15, 'Apolo', 'Perro', 'Rottweiler', 'M', '2020-06-13', 'activa'),
(22, 16, 'Chispa', 'Ave', 'Cacatúa', 'H', '2023-07-21', 'activa'),
(23, 17, 'Dante', 'Perro', 'Dóberman', 'M', '2021-10-30', 'activa'),
(24, 17, 'Sasha', 'Gato', 'Criollo', 'H', '2024-03-14', 'activa'),
(25, 18, 'Boby', 'Perro', 'Pinscher', 'M', '2022-09-08', 'activa'),
(26, 18, 'Motas', 'Conejo', 'Mini Lop', 'M', '2023-12-01', 'activa'),
(27, 19, 'Maya', 'Perro', 'Border Collie', 'H', '2021-05-25', 'activa'),
(28, 19, 'Felix', 'Gato', 'Azul Ruso', 'M', '2020-03-17', 'adoptada'),
(29, 20, 'Rex', 'Perro', 'Pitbull', 'M', '2019-08-19', 'activa'),
(30, 10, 'Bellota', 'Gato', 'Criollo', 'H', '2024-02-10', 'activa');

-- 7. 60 Citas (cumple mínimo 60; Vet 1 tiene >10 atendidas en el mes; dueño 20 sin citas en 6 meses)
INSERT INTO citas (id_cita, id_mascota, id_veterinario, id_servicio, fecha_hora, estado) VALUES
-- 12 citas atendidas de Dra. Paula Vega (id_veterinario = 1) en el mes actual (Consulta 05)
(1, 1, 1, 1, CONCAT(DATE_FORMAT(CURDATE(), '%Y-%m-01'), ' 08:30:00'), 'atendida'),
(2, 2, 1, 2, CONCAT(DATE_FORMAT(CURDATE(), '%Y-%m-01'), ' 09:30:00'), 'atendida'),
(3, 3, 1, 1, CONCAT(DATE_FORMAT(CURDATE(), '%Y-%m-02'), ' 08:30:00'), 'atendida'),
(4, 4, 1, 3, CONCAT(DATE_FORMAT(CURDATE(), '%Y-%m-02'), ' 10:00:00'), 'atendida'),
(5, 6, 1, 1, CONCAT(DATE_FORMAT(CURDATE(), '%Y-%m-03'), ' 09:00:00'), 'atendida'),
(6, 7, 1, 2, CONCAT(DATE_FORMAT(CURDATE(), '%Y-%m-03'), ' 11:00:00'), 'atendida'),
(7, 8, 1, 4, CONCAT(DATE_FORMAT(CURDATE(), '%Y-%m-04'), ' 08:30:00'), 'atendida'),
(8, 9, 1, 1, CONCAT(DATE_FORMAT(CURDATE(), '%Y-%m-04'), ' 10:30:00'), 'atendida'),
(9, 10, 1, 2, CONCAT(DATE_FORMAT(CURDATE(), '%Y-%m-05'), ' 09:00:00'), 'atendida'),
(10, 12, 1, 1, CONCAT(DATE_FORMAT(CURDATE(), '%Y-%m-05'), ' 14:00:00'), 'atendida'),
(11, 13, 1, 3, CONCAT(DATE_FORMAT(CURDATE(), '%Y-%m-06'), ' 09:30:00'), 'atendida'),
(12, 14, 1, 1, CONCAT(DATE_FORMAT(CURDATE(), '%Y-%m-06'), ' 15:00:00'), 'atendida'),
-- Citas atendidas en meses anteriores (último año)
(13, 1, 2, 1, DATE_SUB(NOW(), INTERVAL 40 DAY), 'atendida'),
(14, 1, 1, 4, DATE_SUB(NOW(), INTERVAL 90 DAY), 'atendida'),
(15, 1, 3, 1, DATE_SUB(NOW(), INTERVAL 150 DAY), 'atendida'),
(16, 3, 2, 5, DATE_SUB(NOW(), INTERVAL 35 DAY), 'atendida'),
(17, 6, 2, 5, DATE_SUB(NOW(), INTERVAL 60 DAY), 'atendida'),
(18, 8, 3, 3, DATE_SUB(NOW(), INTERVAL 45 DAY), 'atendida'),
(19, 10, 4, 2, DATE_SUB(NOW(), INTERVAL 70 DAY), 'atendida'),
(20, 13, 2, 4, DATE_SUB(NOW(), INTERVAL 80 DAY), 'atendida'),
(21, 15, 4, 2, DATE_SUB(NOW(), INTERVAL 100 DAY), 'atendida'),
(22, 16, 2, 5, DATE_SUB(NOW(), INTERVAL 110 DAY), 'atendida'),
(23, 17, 3, 1, DATE_SUB(NOW(), INTERVAL 120 DAY), 'atendida'),
(24, 18, 3, 1, DATE_SUB(NOW(), INTERVAL 130 DAY), 'atendida'),
(25, 19, 4, 2, DATE_SUB(NOW(), INTERVAL 140 DAY), 'atendida'),
(26, 20, 1, 1, DATE_SUB(NOW(), INTERVAL 160 DAY), 'atendida'),
(27, 21, 2, 4, DATE_SUB(NOW(), INTERVAL 170 DAY), 'atendida'),
(28, 22, 3, 1, DATE_SUB(NOW(), INTERVAL 180 DAY), 'atendida'),
(29, 23, 4, 2, DATE_SUB(NOW(), INTERVAL 200 DAY), 'atendida'),
(30, 24, 1, 1, DATE_SUB(NOW(), INTERVAL 210 DAY), 'atendida'),
(31, 25, 4, 3, DATE_SUB(NOW(), INTERVAL 220 DAY), 'atendida'),
(32, 26, 3, 1, DATE_SUB(NOW(), INTERVAL 230 DAY), 'atendida'),
(33, 27, 2, 5, DATE_SUB(NOW(), INTERVAL 240 DAY), 'atendida'),
(34, 29, 1, 1, DATE_SUB(NOW(), INTERVAL 250 DAY), 'atendida'), -- Mascota 29 (Dueño 20) hace >6 meses
(35, 30, 4, 2, DATE_SUB(NOW(), INTERVAL 25 DAY), 'atendida'),
-- Citas canceladas (para Consulta 10)
(36, 2, 2, 4, DATE_SUB(NOW(), INTERVAL 15 DAY), 'cancelada'),
(37, 4, 2, 1, DATE_SUB(NOW(), INTERVAL 20 DAY), 'cancelada'),
(38, 7, 3, 3, DATE_SUB(NOW(), INTERVAL 28 DAY), 'cancelada'),
(39, 9, 4, 2, DATE_SUB(NOW(), INTERVAL 32 DAY), 'cancelada'),
(40, 12, 1, 1, DATE_SUB(NOW(), INTERVAL 50 DAY), 'cancelada'),
(41, 14, 3, 3, DATE_SUB(NOW(), INTERVAL 65 DAY), 'cancelada'),
(42, 16, 4, 1, DATE_SUB(NOW(), INTERVAL 75 DAY), 'cancelada'),
(43, 19, 2, 5, DATE_SUB(NOW(), INTERVAL 85 DAY), 'cancelada'),
(44, 21, 1, 1, DATE_SUB(NOW(), INTERVAL 95 DAY), 'cancelada'),
(45, 25, 3, 2, DATE_SUB(NOW(), INTERVAL 105 DAY), 'cancelada'),
-- Citas agendadas para HOY (Consulta 14: Agenda del día)
(46, 1, 1, 1, CONCAT(CURDATE(), ' 09:00:00'), 'agendada'),
(47, 3, 2, 4, CONCAT(CURDATE(), ' 10:30:00'), 'agendada'),
(48, 7, 3, 3, CONCAT(CURDATE(), ' 14:00:00'), 'agendada'),
(49, 10, 4, 2, CONCAT(CURDATE(), ' 16:00:00'), 'agendada'),
-- Citas agendadas para la PRÓXIMA SEMANA (Consulta 02)
(50, 2, 1, 1, DATE_ADD(CONCAT(CURDATE(), ' 09:00:00'), INTERVAL 2 DAY), 'agendada'),
(51, 4, 1, 2, DATE_ADD(CONCAT(CURDATE(), ' 10:00:00'), INTERVAL 3 DAY), 'agendada'),
(52, 6, 2, 5, DATE_ADD(CONCAT(CURDATE(), ' 11:00:00'), INTERVAL 3 DAY), 'agendada'),
(53, 8, 3, 3, DATE_ADD(CONCAT(CURDATE(), ' 14:30:00'), INTERVAL 4 DAY), 'agendada'),
(54, 12, 4, 2, DATE_ADD(CONCAT(CURDATE(), ' 15:00:00'), INTERVAL 4 DAY), 'agendada'),
(55, 13, 1, 1, DATE_ADD(CONCAT(CURDATE(), ' 08:30:00'), INTERVAL 5 DAY), 'agendada'),
(56, 15, 2, 4, DATE_ADD(CONCAT(CURDATE(), ' 10:00:00'), INTERVAL 5 DAY), 'agendada'),
(57, 17, 3, 1, DATE_ADD(CONCAT(CURDATE(), ' 11:30:00'), INTERVAL 6 DAY), 'agendada'),
(58, 20, 4, 2, DATE_ADD(CONCAT(CURDATE(), ' 16:00:00'), INTERVAL 6 DAY), 'agendada'),
(59, 23, 1, 1, DATE_ADD(CONCAT(CURDATE(), ' 09:30:00'), INTERVAL 7 DAY), 'agendada'),
(60, 27, 2, 1, DATE_ADD(CONCAT(CURDATE(), ' 15:30:00'), INTERVAL 7 DAY), 'agendada');

-- 8. Historial clínico (1 registro único por cada cita atendida, incluye evolución de peso de Luna)
INSERT INTO historial_clinico (id_historial, id_cita, id_mascota, id_veterinario, fecha_registro, diagnostico, tratamiento, peso) VALUES
(1, 1, 1, 1, CONCAT(DATE_FORMAT(CURDATE(), '%Y-%m-01'), ' 09:00:00'), 'Control general óptimo', 'Dieta balanceada', 15.20),
(2, 2, 2, 1, CONCAT(DATE_FORMAT(CURDATE(), '%Y-%m-01'), ' 10:00:00'), 'Refuerzo anual', 'Vacuna aplicada', 4.30),
(3, 3, 3, 1, CONCAT(DATE_FORMAT(CURDATE(), '%Y-%m-02'), ' 09:00:00'), 'Otitis externa leve', 'Limpieza y antibiótico', 28.50),
(4, 4, 4, 1, CONCAT(DATE_FORMAT(CURDATE(), '%Y-%m-02'), ' 10:40:00'), 'Dermatitis alérgica', 'Baño medicado', 12.10),
(5, 5, 6, 1, CONCAT(DATE_FORMAT(CURDATE(), '%Y-%m-03'), ' 09:30:00'), 'Dolor articular leve', 'Antiinflamatorio 5 días', 31.00),
(6, 6, 7, 1, CONCAT(DATE_FORMAT(CURDATE(), '%Y-%m-03'), ' 11:20:00'), 'Esquema preventivo', 'Vacunación', 3.90),
(7, 7, 8, 1, CONCAT(DATE_FORMAT(CURDATE(), '%Y-%m-04'), ' 09:30:00'), 'Sarro dental grado 2', 'Profilaxis completada', 13.40),
(8, 8, 9, 1, CONCAT(DATE_FORMAT(CURDATE(), '%Y-%m-04'), ' 11:00:00'), 'Gastritis leve', 'Protector gástrico', 4.10),
(9, 9, 10, 1, CONCAT(DATE_FORMAT(CURDATE(), '%Y-%m-05'), ' 09:30:00'), 'Control anual', 'Vacunación', 6.80),
(10, 10, 12, 1, CONCAT(DATE_FORMAT(CURDATE(), '%Y-%m-05'), ' 14:30:00'), 'Infección respiratoria', 'Antibiótico oral', 22.00),
(11, 11, 13, 1, CONCAT(DATE_FORMAT(CURDATE(), '%Y-%m-06'), ' 10:15:00'), 'Seborrea seca', 'Baño dermatológico', 33.50),
(12, 12, 14, 1, CONCAT(DATE_FORMAT(CURDATE(), '%Y-%m-06'), ' 15:30:00'), 'Chequeo geriátrico', 'Vitaminas', 8.70),
(13, 13, 1, 2, DATE_SUB(NOW(), INTERVAL 40 DAY), 'Control de peso', 'Ajuste calórico', 14.80),
(14, 14, 1, 1, DATE_SUB(NOW(), INTERVAL 90 DAY), 'Limpieza dental', 'Profilaxis', 14.30),
(15, 15, 1, 3, DATE_SUB(NOW(), INTERVAL 150 DAY), 'Alergia estacional', 'Antihistamínico', 13.90),
(16, 16, 3, 2, DATE_SUB(NOW(), INTERVAL 35 DAY), 'Extracción lipoma', 'Cirugía exitosa y analgésico', 28.00),
(17, 17, 6, 2, DATE_SUB(NOW(), INTERVAL 60 DAY), 'Sutura herida en pata', 'Antibiótico y curación', 30.50),
(18, 18, 8, 3, DATE_SUB(NOW(), INTERVAL 45 DAY), 'Prurito cutáneo', 'Corticoides dosis baja', 13.20),
(19, 20, 13, 2, DATE_SUB(NOW(), INTERVAL 80 DAY), 'Cálculo dental', 'Profilaxis', 33.00),
(20, 22, 16, 2, DATE_SUB(NOW(), INTERVAL 110 DAY), 'Castración programada', 'Postoperatorio normal', 29.40),
(21, 23, 17, 3, DATE_SUB(NOW(), INTERVAL 120 DAY), 'Parasitosis interna', 'Desparasitación', 11.80),
(22, 24, 18, 3, DATE_SUB(NOW(), INTERVAL 130 DAY), 'Control dental conejo', 'Desgaste normal', 1.65),
(23, 26, 20, 1, DATE_SUB(NOW(), INTERVAL 160 DAY), 'Control general felino', 'Sin hallazgos', 4.50),
(24, 28, 22, 3, DATE_SUB(NOW(), INTERVAL 180 DAY), 'Revisión plumaje', 'Suplemento vitamínico', 0.12),
(25, 33, 27, 2, DATE_SUB(NOW(), INTERVAL 240 DAY), 'Herida superficial', 'Antibiótico preventivo', 19.20);

-- 9. Prescripciones (para Top 5 medicamentos en Consulta 12)
INSERT INTO prescripciones (id_historial, id_medicamento, dosis, cantidad) VALUES
(3, 1, '5ml cada 12h por 7 días', 1),
(5, 2, '1 tableta cada 24h por 5 días', 1),
(10, 3, '1 tableta cada 12h por 10 días', 1),
(15, 4, 'Media tableta cada 12h por 5 días', 1),
(16, 2, '1 tableta cada 24h por 4 días', 1),
(17, 1, '10ml cada 12h por 7 días', 2),
(18, 4, '1 tableta diaria por 5 días', 1),
(20, 1, '10ml cada 12h por 7 días', 1),
(20, 2, '1 tableta cada 24h por 3 días', 1),
(21, 5, '10 gotas dosis única', 1),
(25, 1, '7ml cada 12h por 7 días', 1),
(25, 3, '1 tableta cada 12h por 7 días', 1),
(8, 5, '5 gotas cada 24h por 3 días', 1);

-- 10. 50 Registros de vacunación (cumple mínimo 50; incluye vencidas y por vencer en 15 días)
INSERT INTO vacunacion (id_vacunacion, id_mascota, id_vacuna, id_veterinario, fecha_aplicacion, fecha_proxima_dosis, lote) VALUES
-- Vencidas (fecha_proxima_dosis < CURDATE())
(1, 1, 1, 4, DATE_SUB(CURDATE(), INTERVAL 380 DAY), DATE_SUB(CURDATE(), INTERVAL 15 DAY), 'LOT-2025-A1'),
(2, 3, 2, 4, DATE_SUB(CURDATE(), INTERVAL 375 DAY), DATE_SUB(CURDATE(), INTERVAL 10 DAY), 'LOT-2025-A2'),
(3, 6, 4, 1, DATE_SUB(CURDATE(), INTERVAL 190 DAY), DATE_SUB(CURDATE(), INTERVAL 10 DAY), 'LOT-2026-B1'),
(4, 9, 3, 4, DATE_SUB(CURDATE(), INTERVAL 370 DAY), DATE_SUB(CURDATE(), INTERVAL 5 DAY), 'LOT-2025-C1'),
(5, 13, 1, 1, DATE_SUB(CURDATE(), INTERVAL 368 DAY), DATE_SUB(CURDATE(), INTERVAL 3 DAY), 'LOT-2025-A1'),
-- Por vencer en los próximos 15 días (Consulta 06)
(6, 2, 3, 4, DATE_SUB(CURDATE(), INTERVAL 360 DAY), DATE_ADD(CURDATE(), INTERVAL 5 DAY), 'LOT-2025-C2'),
(7, 4, 1, 1, DATE_SUB(CURDATE(), INTERVAL 358 DAY), DATE_ADD(CURDATE(), INTERVAL 7 DAY), 'LOT-2025-A3'),
(8, 7, 5, 4, DATE_SUB(CURDATE(), INTERVAL 355 DAY), DATE_ADD(CURDATE(), INTERVAL 10 DAY), 'LOT-2025-D1'),
(9, 8, 2, 1, DATE_SUB(CURDATE(), INTERVAL 353 DAY), DATE_ADD(CURDATE(), INTERVAL 12 DAY), 'LOT-2025-A2'),
(10, 10, 3, 4, DATE_SUB(CURDATE(), INTERVAL 351 DAY), DATE_ADD(CURDATE(), INTERVAL 14 DAY), 'LOT-2025-C2'),
-- Vigentes (fecha_proxima_dosis > CURDATE() + 15 días)
(11, 1, 2, 4, DATE_SUB(CURDATE(), INTERVAL 60 DAY), DATE_ADD(CURDATE(), INTERVAL 305 DAY), 'LOT-2026-R1'),
(12, 2, 2, 4, DATE_SUB(CURDATE(), INTERVAL 60 DAY), DATE_ADD(CURDATE(), INTERVAL 305 DAY), 'LOT-2026-R1'),
(13, 3, 1, 1, DATE_SUB(CURDATE(), INTERVAL 90 DAY), DATE_ADD(CURDATE(), INTERVAL 275 DAY), 'LOT-2026-P1'),
(14, 4, 2, 1, DATE_SUB(CURDATE(), INTERVAL 90 DAY), DATE_ADD(CURDATE(), INTERVAL 275 DAY), 'LOT-2026-R1'),
(15, 6, 1, 4, DATE_SUB(CURDATE(), INTERVAL 120 DAY), DATE_ADD(CURDATE(), INTERVAL 245 DAY), 'LOT-2026-P1'),
(16, 6, 2, 4, DATE_SUB(CURDATE(), INTERVAL 120 DAY), DATE_ADD(CURDATE(), INTERVAL 245 DAY), 'LOT-2026-R1'),
(17, 7, 3, 1, DATE_SUB(CURDATE(), INTERVAL 100 DAY), DATE_ADD(CURDATE(), INTERVAL 265 DAY), 'LOT-2026-T1'),
(18, 8, 1, 4, DATE_SUB(CURDATE(), INTERVAL 110 DAY), DATE_ADD(CURDATE(), INTERVAL 255 DAY), 'LOT-2026-P1'),
(19, 8, 4, 4, DATE_SUB(CURDATE(), INTERVAL 40 DAY), DATE_ADD(CURDATE(), INTERVAL 140 DAY), 'LOT-2026-B2'),
(20, 9, 2, 1, DATE_SUB(CURDATE(), INTERVAL 85 DAY), DATE_ADD(CURDATE(), INTERVAL 280 DAY), 'LOT-2026-R1'),
(21, 10, 5, 4, DATE_SUB(CURDATE(), INTERVAL 70 DAY), DATE_ADD(CURDATE(), INTERVAL 295 DAY), 'LOT-2026-L1'),
(22, 12, 1, 1, DATE_SUB(CURDATE(), INTERVAL 50 DAY), DATE_ADD(CURDATE(), INTERVAL 315 DAY), 'LOT-2026-P2'),
(23, 12, 2, 1, DATE_SUB(CURDATE(), INTERVAL 50 DAY), DATE_ADD(CURDATE(), INTERVAL 315 DAY), 'LOT-2026-R2'),
(24, 13, 2, 4, DATE_SUB(CURDATE(), INTERVAL 45 DAY), DATE_ADD(CURDATE(), INTERVAL 320 DAY), 'LOT-2026-R2'),
(25, 13, 4, 4, DATE_SUB(CURDATE(), INTERVAL 30 DAY), DATE_ADD(CURDATE(), INTERVAL 150 DAY), 'LOT-2026-B2'),
(26, 14, 1, 1, DATE_SUB(CURDATE(), INTERVAL 130 DAY), DATE_ADD(CURDATE(), INTERVAL 235 DAY), 'LOT-2026-P1'),
(27, 14, 2, 1, DATE_SUB(CURDATE(), INTERVAL 130 DAY), DATE_ADD(CURDATE(), INTERVAL 235 DAY), 'LOT-2026-R1'),
(28, 15, 3, 4, DATE_SUB(CURDATE(), INTERVAL 95 DAY), DATE_ADD(CURDATE(), INTERVAL 270 DAY), 'LOT-2026-T1'),
(29, 15, 5, 4, DATE_SUB(CURDATE(), INTERVAL 95 DAY), DATE_ADD(CURDATE(), INTERVAL 270 DAY), 'LOT-2026-L1'),
(30, 16, 1, 1, DATE_SUB(CURDATE(), INTERVAL 140 DAY), DATE_ADD(CURDATE(), INTERVAL 225 DAY), 'LOT-2026-P1'),
(31, 16, 2, 1, DATE_SUB(CURDATE(), INTERVAL 140 DAY), DATE_ADD(CURDATE(), INTERVAL 225 DAY), 'LOT-2026-R1'),
(32, 17, 1, 4, DATE_SUB(CURDATE(), INTERVAL 75 DAY), DATE_ADD(CURDATE(), INTERVAL 290 DAY), 'LOT-2026-P2'),
(33, 17, 2, 4, DATE_SUB(CURDATE(), INTERVAL 75 DAY), DATE_ADD(CURDATE(), INTERVAL 290 DAY), 'LOT-2026-R2'),
(34, 19, 1, 1, DATE_SUB(CURDATE(), INTERVAL 65 DAY), DATE_ADD(CURDATE(), INTERVAL 300 DAY), 'LOT-2026-P2'),
(35, 19, 2, 1, DATE_SUB(CURDATE(), INTERVAL 65 DAY), DATE_ADD(CURDATE(), INTERVAL 300 DAY), 'LOT-2026-R2'),
(36, 20, 3, 4, DATE_SUB(CURDATE(), INTERVAL 55 DAY), DATE_ADD(CURDATE(), INTERVAL 310 DAY), 'LOT-2026-T2'),
(37, 20, 2, 4, DATE_SUB(CURDATE(), INTERVAL 55 DAY), DATE_ADD(CURDATE(), INTERVAL 310 DAY), 'LOT-2026-R2'),
(38, 21, 1, 1, DATE_SUB(CURDATE(), INTERVAL 150 DAY), DATE_ADD(CURDATE(), INTERVAL 215 DAY), 'LOT-2026-P1'),
(39, 21, 2, 1, DATE_SUB(CURDATE(), INTERVAL 150 DAY), DATE_ADD(CURDATE(), INTERVAL 215 DAY), 'LOT-2026-R1'),
(40, 23, 1, 4, DATE_SUB(CURDATE(), INTERVAL 80 DAY), DATE_ADD(CURDATE(), INTERVAL 285 DAY), 'LOT-2026-P2'),
(41, 23, 2, 4, DATE_SUB(CURDATE(), INTERVAL 80 DAY), DATE_ADD(CURDATE(), INTERVAL 285 DAY), 'LOT-2026-R2'),
(42, 24, 3, 1, DATE_SUB(CURDATE(), INTERVAL 35 DAY), DATE_ADD(CURDATE(), INTERVAL 330 DAY), 'LOT-2026-T2'),
(43, 24, 5, 1, DATE_SUB(CURDATE(), INTERVAL 35 DAY), DATE_ADD(CURDATE(), INTERVAL 330 DAY), 'LOT-2026-L2'),
(44, 25, 1, 4, DATE_SUB(CURDATE(), INTERVAL 25 DAY), DATE_ADD(CURDATE(), INTERVAL 340 DAY), 'LOT-2026-P2'),
(45, 25, 2, 4, DATE_SUB(CURDATE(), INTERVAL 25 DAY), DATE_ADD(CURDATE(), INTERVAL 340 DAY), 'LOT-2026-R2'),
(46, 27, 1, 1, DATE_SUB(CURDATE(), INTERVAL 15 DAY), DATE_ADD(CURDATE(), INTERVAL 350 DAY), 'LOT-2026-P2'),
(47, 27, 2, 1, DATE_SUB(CURDATE(), INTERVAL 15 DAY), DATE_ADD(CURDATE(), INTERVAL 350 DAY), 'LOT-2026-R2'),
(48, 29, 1, 4, DATE_SUB(CURDATE(), INTERVAL 200 DAY), DATE_ADD(CURDATE(), INTERVAL 165 DAY), 'LOT-2026-P1'),
(49, 30, 3, 1, DATE_SUB(CURDATE(), INTERVAL 20 DAY), DATE_ADD(CURDATE(), INTERVAL 345 DAY), 'LOT-2026-T2'),
(50, 30, 2, 1, DATE_SUB(CURDATE(), INTERVAL 20 DAY), DATE_ADD(CURDATE(), INTERVAL 345 DAY), 'LOT-2026-R2');

-- 7. Regla 3: toda cita atendida tiene exactamente un registro de historial clínico.
-- Completa las citas atendidas que no tenían historial en los datos anteriores.
INSERT INTO historial_clinico (id_cita, id_mascota, id_veterinario, fecha_registro, diagnostico, tratamiento, peso)
SELECT c.id_cita, c.id_mascota, c.id_veterinario, LEAST(c.fecha_hora, NOW()),
       'Control clínico de rutina', 'Sin tratamiento adicional',
       COALESCE((SELECT h2.peso FROM historial_clinico h2
                 WHERE h2.id_mascota = c.id_mascota
                 ORDER BY h2.fecha_registro DESC LIMIT 1), 10.00)
FROM citas c
WHERE c.estado = 'atendida'
  AND NOT EXISTS (SELECT 1 FROM historial_clinico h WHERE h.id_cita = c.id_cita);
