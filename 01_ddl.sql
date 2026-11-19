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