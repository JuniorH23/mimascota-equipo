-- ==========================================================
-- MiMascota · instalación LOCAL completa (XAMPP / phpMyAdmin)
-- Ejecuta 01_ddl, 02_datos, 03_vistas, 05_logica y 06_usuarios en orden.
-- ATENCIÓN: borra y recrea la base 'mimascota'. Las consultas (04_consultas.sql)
-- se ejecutan aparte, de una en una, desde la pestaña SQL.
-- ==========================================================
DROP DATABASE IF EXISTS mimascota;


-- >>>>>>>>>> 01_ddl.sql
-- 01_ddl.sql · BD2 · Ejecutar sobre una base vacía
CREATE DATABASE IF NOT EXISTS mimascota CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE mimascota;

-- 1. Propietarios (Módulo 1 y Regla 5: borrado lógico con 'activo')
CREATE TABLE propietarios (
    id_propietario INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    telefono VARCHAR(20) NOT NULL,
    email VARCHAR(100) UNIQUE,
    direccion VARCHAR(150),
    activo TINYINT(1) NOT NULL DEFAULT 1,
    CONSTRAINT chk_propietario_activo CHECK (activo IN (0, 1))
) ENGINE=InnoDB;

-- 2. Veterinarios (Módulo 3 y Regla 5)
CREATE TABLE veterinarios (
    id_veterinario INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    especialidad VARCHAR(60) NOT NULL,
    telefono VARCHAR(20),
    email VARCHAR(100) UNIQUE,
    activo TINYINT(1) NOT NULL DEFAULT 1,
    CONSTRAINT chk_veterinario_activo CHECK (activo IN (0, 1))
) ENGINE=InnoDB;

-- 3. Servicios (Módulo 3)
CREATE TABLE servicios (
    id_servicio INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL UNIQUE,
    precio DECIMAL(10,2) NOT NULL,
    descripcion VARCHAR(255),
    activo TINYINT(1) NOT NULL DEFAULT 1,
    CONSTRAINT chk_servicio_precio CHECK (precio > 0),
    CONSTRAINT chk_servicio_activo CHECK (activo IN (0, 1))
) ENGINE=InnoDB;

-- 4. Medicamentos (Módulo 5 con control de stock)
CREATE TABLE medicamentos (
    id_medicamento INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL UNIQUE,
    presentacion VARCHAR(60) NOT NULL,
    stock INT NOT NULL DEFAULT 0,
    activo TINYINT(1) NOT NULL DEFAULT 1,
    CONSTRAINT chk_medicamento_stock CHECK (stock >= 0),
    CONSTRAINT chk_medicamento_activo CHECK (activo IN (0, 1))
) ENGINE=InnoDB;

-- 5. Catálogo de vacunas (Módulo 6)
CREATE TABLE vacunas (
    id_vacuna INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL UNIQUE,
    descripcion VARCHAR(150),
    intervalo_dias INT NOT NULL DEFAULT 365,
    CONSTRAINT chk_vacuna_intervalo CHECK (intervalo_dias > 0)
) ENGINE=InnoDB;

-- 6. Mascotas (Módulo 2: especie, raza, nacimiento, sexo y estado)
CREATE TABLE mascotas (
    id_mascota INT AUTO_INCREMENT PRIMARY KEY,
    id_propietario INT NOT NULL,
    nombre VARCHAR(60) NOT NULL,
    especie VARCHAR(30) NOT NULL,
    raza VARCHAR(60),
    sexo CHAR(1) NOT NULL,
    fecha_nacimiento DATE NOT NULL,
    estado VARCHAR(15) NOT NULL DEFAULT 'activa',
    CONSTRAINT chk_mascota_sexo CHECK (sexo IN ('M', 'H')),
    CONSTRAINT chk_mascota_estado CHECK (estado IN ('activa', 'fallecida', 'adoptada')),
    CONSTRAINT fk_mascotas_propietario
        FOREIGN KEY (id_propietario) REFERENCES propietarios(id_propietario)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

-- 7. Historial de cambio de propietario (Regla de negocio 1)
CREATE TABLE historial_propietarios (
    id_cambio INT AUTO_INCREMENT PRIMARY KEY,
    id_mascota INT NOT NULL,
    id_propietario_anterior INT NOT NULL,
    id_propietario_nuevo INT NOT NULL,
    fecha_cambio DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    motivo VARCHAR(150),
    CONSTRAINT fk_hist_prop_mascota
        FOREIGN KEY (id_mascota) REFERENCES mascotas(id_mascota)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_hist_prop_anterior
        FOREIGN KEY (id_propietario_anterior) REFERENCES propietarios(id_propietario)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_hist_prop_nuevo
        FOREIGN KEY (id_propietario_nuevo) REFERENCES propietarios(id_propietario)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

-- 8. Citas (Módulo 4)
CREATE TABLE citas (
    id_cita INT AUTO_INCREMENT PRIMARY KEY,
    id_mascota INT NOT NULL,
    id_veterinario INT NOT NULL,
    id_servicio INT NOT NULL,
    fecha_hora DATETIME NOT NULL,
    estado VARCHAR(15) NOT NULL DEFAULT 'agendada',
    CONSTRAINT chk_cita_estado CHECK (estado IN ('agendada', 'atendida', 'cancelada')),
    CONSTRAINT fk_citas_mascota
        FOREIGN KEY (id_mascota) REFERENCES mascotas(id_mascota)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_citas_veterinario
        FOREIGN KEY (id_veterinario) REFERENCES veterinarios(id_veterinario)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_citas_servicio
        FOREIGN KEY (id_servicio) REFERENCES servicios(id_servicio)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

-- 9. Historial clínico (Módulo 5 y Regla 3: 1 cita atendida = 1 historial clínico)
CREATE TABLE historial_clinico (
    id_historial INT AUTO_INCREMENT PRIMARY KEY,
    id_cita INT NOT NULL UNIQUE,
    id_mascota INT NOT NULL,
    id_veterinario INT NOT NULL,
    fecha_registro DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    diagnostico TEXT NOT NULL,
    tratamiento TEXT,
    peso DECIMAL(5,2) NOT NULL,
    CONSTRAINT chk_historial_peso CHECK (peso > 0),
    CONSTRAINT fk_historial_cita
        FOREIGN KEY (id_cita) REFERENCES citas(id_cita)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_historial_mascota
        FOREIGN KEY (id_mascota) REFERENCES mascotas(id_mascota)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_historial_veterinario
        FOREIGN KEY (id_veterinario) REFERENCES veterinarios(id_veterinario)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

-- 10. Prescripciones / Fórmula médica (Módulo 5)
CREATE TABLE prescripciones (
    id_prescripcion INT AUTO_INCREMENT PRIMARY KEY,
    id_historial INT NOT NULL,
    id_medicamento INT NOT NULL,
    dosis VARCHAR(100) NOT NULL,
    cantidad INT NOT NULL,
    CONSTRAINT chk_prescripcion_cantidad CHECK (cantidad > 0),
    CONSTRAINT fk_prescripciones_historial
        FOREIGN KEY (id_historial) REFERENCES historial_clinico(id_historial)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_prescripciones_medicamento
        FOREIGN KEY (id_medicamento) REFERENCES medicamentos(id_medicamento)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

-- 11. Carné de vacunación (Módulo 6)
CREATE TABLE vacunacion (
    id_vacunacion INT AUTO_INCREMENT PRIMARY KEY,
    id_mascota INT NOT NULL,
    id_vacuna INT NOT NULL,
    id_veterinario INT NOT NULL,
    fecha_aplicacion DATE NOT NULL,
    fecha_proxima_dosis DATE NOT NULL,
    lote VARCHAR(40),
    CONSTRAINT chk_vacunacion_fechas CHECK (fecha_proxima_dosis >= fecha_aplicacion),
    CONSTRAINT fk_vacunacion_mascota
        FOREIGN KEY (id_mascota) REFERENCES mascotas(id_mascota)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_vacunacion_vacuna
        FOREIGN KEY (id_vacuna) REFERENCES vacunas(id_vacuna)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_vacunacion_veterinario
        FOREIGN KEY (id_veterinario) REFERENCES veterinarios(id_veterinario)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

-- 12. Bitácora de auditoría del sistema
CREATE TABLE bitacora (
    id_bitacora INT AUTO_INCREMENT PRIMARY KEY,
    fecha DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    tabla VARCHAR(50) NOT NULL,
    id_registro INT NOT NULL,
    detalle VARCHAR(255) NOT NULL,
    usuario VARCHAR(100) NOT NULL
) ENGINE=InnoDB;

-- 3 Índices requeridos por BD2 para optimizar consultas frecuentes
CREATE INDEX idx_citas_vet_fecha ON citas(id_veterinario, fecha_hora);
CREATE INDEX idx_vacunacion_proxima ON vacunacion(fecha_proxima_dosis);
CREATE INDEX idx_mascotas_propietario ON mascotas(id_propietario);
-- >>>>>>>>>> 02_datos.sql
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

-- >>>>>>>>>> 03_vistas.sql
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

-- >>>>>>>>>> 05_logica.sql
-- ==========================================================
-- PROYECTO: MiMascota - Lógica en el Servidor (05_logica.sql)
-- Cumple BD5: 1 función, 3 procedimientos (2 con transacción) y disparadores
-- ==========================================================

USE mimascota;

DROP FUNCTION IF EXISTS fn_edad_mascota;
DROP PROCEDURE IF EXISTS sp_agendar_cita;
DROP PROCEDURE IF EXISTS sp_registrar_atencion;
DROP PROCEDURE IF EXISTS sp_eliminar_mascota;
DROP TRIGGER IF EXISTS tr_vacunacion_bi_validar;
DROP TRIGGER IF EXISTS tr_servicios_au_precio;
DROP TRIGGER IF EXISTS tr_mascotas_au_propietario;
DROP TRIGGER IF EXISTS tr_mascotas_bd_proteger;
DROP TRIGGER IF EXISTS tr_citas_bi_cruce;
DROP TRIGGER IF EXISTS tr_citas_bu_cruce;
DROP TRIGGER IF EXISTS tr_citas_bu_atendida;

DELIMITER //

-- ==========================================================
-- 1. FUNCIÓN: fn_edad_mascota (edad en años y meses)
-- ==========================================================
CREATE FUNCTION fn_edad_mascota(p_fecha_nacimiento DATE)
RETURNS VARCHAR(30)
NO SQL
BEGIN
    DECLARE v_meses_totales INT;
    DECLARE v_anios INT;
    DECLARE v_meses INT;

    SET v_meses_totales = TIMESTAMPDIFF(MONTH, p_fecha_nacimiento, CURDATE());
    SET v_anios = FLOOR(v_meses_totales / 12);
    SET v_meses = MOD(v_meses_totales, 12);

    RETURN CONCAT(v_anios, ' años, ', v_meses, ' meses');
END //

-- ==========================================================
-- 2. PROCEDIMIENTO 1: sp_agendar_cita (valida cruce de horarios)
-- ==========================================================
CREATE PROCEDURE sp_agendar_cita (
    IN p_id_mascota INT,
    IN p_id_veterinario INT,
    IN p_id_servicio INT,
    IN p_fecha_hora DATETIME
)
BEGIN
    DECLARE v_estado_mascota VARCHAR(15);
    DECLARE v_cruce INT DEFAULT 0;

    -- Validar que la mascota exista y esté activa
    SELECT estado INTO v_estado_mascota
    FROM mascotas
    WHERE id_mascota = p_id_mascota;

    IF v_estado_mascota IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Error: La mascota indicada no existe.';
    END IF;

    IF v_estado_mascota <> 'activa' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Error: No se pueden agendar citas a mascotas inactivas.';
    END IF;

    -- Regla de negocio 2: Validar cruce de horario del veterinario (ventana de 30 minutos)
    SELECT COUNT(*) INTO v_cruce
    FROM citas
    WHERE id_veterinario = p_id_veterinario
      AND estado <> 'cancelada'
      AND ABS(TIMESTAMPDIFF(MINUTE, fecha_hora, p_fecha_hora)) < 30;

    IF v_cruce > 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Error: El veterinario ya tiene una cita programada en ese horario.';
    END IF;

    INSERT INTO citas (id_mascota, id_veterinario, id_servicio, fecha_hora, estado)
    VALUES (p_id_mascota, p_id_veterinario, p_id_servicio, p_fecha_hora, 'agendada');
END //

-- ==========================================================
-- 3. PROCEDIMIENTO 2 + TRANSACCIÓN: sp_registrar_atencion
-- ==========================================================
CREATE PROCEDURE sp_registrar_atencion (
    IN p_id_cita INT,
    IN p_diagnostico TEXT,
    IN p_tratamiento TEXT,
    IN p_peso DECIMAL(5,2),
    IN p_id_medicamento INT,
    IN p_dosis VARCHAR(100),
    IN p_cantidad INT
)
BEGIN
    DECLARE v_id_mascota INT;
    DECLARE v_id_veterinario INT;
    DECLARE v_estado_cita VARCHAR(15);
    DECLARE v_id_historial INT;
    DECLARE v_stock_actual INT;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

        SELECT id_mascota, id_veterinario, estado
          INTO v_id_mascota, v_id_veterinario, v_estado_cita
        FROM citas
        WHERE id_cita = p_id_cita
        FOR UPDATE;

        IF v_estado_cita IS NULL THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Error: La cita no existe.';
        END IF;

        IF v_estado_cita <> 'agendada' THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Error: Solo se pueden atender citas en estado agendada.';
        END IF;

        -- Paso 1: Crear registro único en historial clínico (Regla 3)
        INSERT INTO historial_clinico (id_cita, id_mascota, id_veterinario, diagnostico, tratamiento, peso)
        VALUES (p_id_cita, v_id_mascota, v_id_veterinario, p_diagnostico, p_tratamiento, p_peso);

        SET v_id_historial = LAST_INSERT_ID();

        -- Paso 2: Marcar la cita como atendida (el disparador exige que ya exista su historial)
        UPDATE citas
        SET estado = 'atendida'
        WHERE id_cita = p_id_cita;

        -- Paso 3: Si se formuló medicamento, registrar prescripción y descontar stock
        IF p_id_medicamento IS NOT NULL THEN
            SELECT stock INTO v_stock_actual
            FROM medicamentos
            WHERE id_medicamento = p_id_medicamento
            FOR UPDATE;

            IF v_stock_actual IS NULL OR v_stock_actual < p_cantidad THEN
                SIGNAL SQLSTATE '45000'
                    SET MESSAGE_TEXT = 'Error: Stock insuficiente del medicamento formulado.';
            END IF;

            INSERT INTO prescripciones (id_historial, id_medicamento, dosis, cantidad)
            VALUES (v_id_historial, p_id_medicamento, p_dosis, p_cantidad);

            UPDATE medicamentos
            SET stock = stock - p_cantidad
            WHERE id_medicamento = p_id_medicamento;
        END IF;

    COMMIT;
END //

-- ==========================================================
-- 4. PROCEDIMIENTO TRANSACCIONAL: eliminación de mascota y datos dependientes
-- ==========================================================
CREATE PROCEDURE sp_eliminar_mascota(IN p_id_mascota INT)
SQL SECURITY DEFINER
BEGIN
    DECLARE v_mascota INT DEFAULT NULL;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF p_id_mascota IS NULL OR p_id_mascota <= 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Error: El ID de mascota debe ser un entero positivo.';
    END IF;

    START TRANSACTION;

    SELECT id_mascota INTO v_mascota
    FROM mascotas
    WHERE id_mascota = p_id_mascota
    FOR UPDATE;

    IF v_mascota IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Error: La mascota indicada no existe.';
    END IF;

    INSERT INTO bitacora (tabla, id_registro, detalle, usuario)
    VALUES ('mascotas', p_id_mascota, 'Eliminación permanente de mascota y registros relacionados', USER());

    DELETE FROM prescripciones
    WHERE id_historial IN (
        SELECT h.id_historial
        FROM historial_clinico h
        WHERE h.id_mascota = p_id_mascota
           OR h.id_cita IN (
               SELECT c.id_cita FROM citas c WHERE c.id_mascota = p_id_mascota
           )
    );

    DELETE FROM historial_clinico
    WHERE id_mascota = p_id_mascota
       OR id_cita IN (
           SELECT c.id_cita FROM citas c WHERE c.id_mascota = p_id_mascota
       );

    DELETE FROM citas WHERE id_mascota = p_id_mascota;
    DELETE FROM vacunacion WHERE id_mascota = p_id_mascota;
    DELETE FROM historial_propietarios WHERE id_mascota = p_id_mascota;
    DELETE FROM mascotas WHERE id_mascota = p_id_mascota;

    COMMIT;
END //

-- ==========================================================
-- 5. DISPARADORES (TRIGGERS)
-- ==========================================================

-- Trigger 1 (Regla 4): Bloquea vacunas con fecha futura o a mascotas inactivas
CREATE TRIGGER tr_vacunacion_bi_validar
BEFORE INSERT ON vacunacion
FOR EACH ROW
BEGIN
    DECLARE v_estado VARCHAR(15);

    IF NEW.fecha_aplicacion > CURDATE() THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Error: No se puede registrar una vacuna con fecha futura.';
    END IF;

    SELECT estado INTO v_estado
    FROM mascotas
    WHERE id_mascota = NEW.id_mascota;

    IF v_estado <> 'activa' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Error: No se puede vacunar a una mascota inactiva (fallecida o adoptada).';
    END IF;
END //

-- Trigger 2 (BD5 sugerido): Auditoría de cambios de precio en servicios
CREATE TRIGGER tr_servicios_au_precio
AFTER UPDATE ON servicios
FOR EACH ROW
BEGIN
    IF OLD.precio <> NEW.precio THEN
        INSERT INTO bitacora (tabla, id_registro, detalle, usuario)
        VALUES (
            'servicios',
            NEW.id_servicio,
            CONCAT('Cambio de precio en ', NEW.nombre, ': ', OLD.precio, ' -> ', NEW.precio),
            USER()
        );
    END IF;
END //

-- Trigger 3 (Regla 1): Registra el cambio de dueño de una mascota
CREATE TRIGGER tr_mascotas_au_propietario
AFTER UPDATE ON mascotas
FOR EACH ROW
BEGIN
    IF OLD.id_propietario <> NEW.id_propietario THEN
        INSERT INTO historial_propietarios (id_mascota, id_propietario_anterior, id_propietario_nuevo, motivo)
        VALUES (NEW.id_mascota, OLD.id_propietario, NEW.id_propietario, 'Transferencia de propietario');
    END IF;
END //

-- Trigger 4 (Regla 5): Bloquea el borrado directo; la rutina controlada elimina referencias primero
CREATE TRIGGER tr_mascotas_bd_proteger
BEFORE DELETE ON mascotas
FOR EACH ROW
BEGIN
    IF EXISTS (SELECT 1 FROM citas WHERE id_mascota = OLD.id_mascota)
       OR EXISTS (SELECT 1 FROM historial_clinico WHERE id_mascota = OLD.id_mascota) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Error: No se puede eliminar una mascota con historial o citas; márquela como inactiva.';
    END IF;
END //

-- Trigger 5 (Regla 2): Un veterinario no puede tener dos citas que se crucen (ventana de 30 min)
CREATE TRIGGER tr_citas_bi_cruce
BEFORE INSERT ON citas
FOR EACH ROW
BEGIN
    IF NEW.estado <> 'cancelada' AND EXISTS (
        SELECT 1 FROM citas
        WHERE id_veterinario = NEW.id_veterinario
          AND estado <> 'cancelada'
          AND ABS(TIMESTAMPDIFF(MINUTE, fecha_hora, NEW.fecha_hora)) < 30
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Error: El veterinario ya tiene una cita programada en ese horario.';
    END IF;
END //

CREATE TRIGGER tr_citas_bu_cruce
BEFORE UPDATE ON citas
FOR EACH ROW
BEGIN
    IF NEW.estado <> 'cancelada'
       AND (NEW.fecha_hora <> OLD.fecha_hora OR NEW.id_veterinario <> OLD.id_veterinario OR OLD.estado = 'cancelada')
       AND EXISTS (
        SELECT 1 FROM citas
        WHERE id_veterinario = NEW.id_veterinario
          AND id_cita <> NEW.id_cita
          AND estado <> 'cancelada'
          AND ABS(TIMESTAMPDIFF(MINUTE, fecha_hora, NEW.fecha_hora)) < 30
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Error: El veterinario ya tiene una cita programada en ese horario.';
    END IF;
END //

-- Trigger 6 (Regla 3): Una cita solo pasa a 'atendida' si ya tiene su registro de historial clínico
CREATE TRIGGER tr_citas_bu_atendida
BEFORE UPDATE ON citas
FOR EACH ROW
BEGIN
    IF NEW.estado = 'atendida' AND OLD.estado <> 'atendida'
       AND NOT EXISTS (SELECT 1 FROM historial_clinico WHERE id_cita = NEW.id_cita) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Error: Una cita atendida debe generar su registro en el historial clínico (use sp_registrar_atencion).';
    END IF;
END //

DELIMITER ;

-- >>>>>>>>>> 06_usuarios.sql
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