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
