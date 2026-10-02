-- ============================================================
-- HealthSync - Database Refactoring & Business Flow Simulation
-- MySQL 8.x
-- File: healthsync_db.sql
-- ============================================================

DROP DATABASE IF EXISTS healthsync_db;
CREATE DATABASE healthsync_db
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE healthsync_db;

-- ------------------------------------------------------------
-- 1. LEGACY STRUCTURE (mô phỏng thiết kế cũ)
-- ------------------------------------------------------------

CREATE TABLE Patients (
    patient_id INT AUTO_INCREMENT PRIMARY KEY,
    full_name VARCHAR(100) NOT NULL,
    phone VARCHAR(15) NOT NULL
);

CREATE TABLE Doctors (
    doctor_id INT AUTO_INCREMENT PRIMARY KEY,
    full_name VARCHAR(100) NOT NULL,
    specialty VARCHAR(50)
);

CREATE TABLE Appointments (
    appointment_id INT AUTO_INCREMENT PRIMARY KEY,
    patient_id INT NOT NULL,
    doctor_id INT NOT NULL,
    appointment_date DATETIME NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,

    CONSTRAINT fk_appointments_patient
        FOREIGN KEY (patient_id)
        REFERENCES Patients(patient_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_appointments_doctor
        FOREIGN KEY (doctor_id)
        REFERENCES Doctors(doctor_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT
);

-- ------------------------------------------------------------
-- 2. REFACTOR APPOINTMENTS ĐỂ KHỚP NGHIỆP VỤ
-- ------------------------------------------------------------

ALTER TABLE Appointments
    DROP COLUMN is_active,
    ADD COLUMN status ENUM(
        'PENDING',
        'CONFIRMED',
        'CHECKED_IN',
        'COMPLETED',
        'CANCELLED'
    ) NOT NULL DEFAULT 'PENDING' AFTER appointment_date,
    ADD COLUMN deposit_amount DECIMAL(12,2) NOT NULL DEFAULT 0.00 AFTER status,
    ADD COLUMN penalty_fee DECIMAL(12,2) NOT NULL DEFAULT 0.00 AFTER deposit_amount,
    ADD COLUMN cancel_reason VARCHAR(255) NULL AFTER penalty_fee,
    ADD CONSTRAINT chk_deposit_non_negative
        CHECK (deposit_amount >= 0),
    ADD CONSTRAINT chk_penalty_non_negative
        CHECK (penalty_fee >= 0),
    ADD CONSTRAINT chk_penalty_not_over_deposit
        CHECK (penalty_fee <= deposit_amount),
    ADD CONSTRAINT chk_cancelled_has_reason
        CHECK (
            status <> 'CANCELLED'
            OR (cancel_reason IS NOT NULL AND TRIM(cancel_reason) <> '')
        );

-- ------------------------------------------------------------
-- 3. PRESCRIPTIONS
-- Mỗi lịch hẹn hoàn tất có tối đa 1 đơn thuốc trong thiết kế này.
-- UNIQUE(appointment_id) tạo quan hệ 1-1.
-- ------------------------------------------------------------

CREATE TABLE Prescriptions (
    prescription_id INT AUTO_INCREMENT PRIMARY KEY,
    appointment_id INT NOT NULL UNIQUE,
    medication_details TEXT NOT NULL,
    issued_date DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_prescriptions_appointment
        FOREIGN KEY (appointment_id)
        REFERENCES Appointments(appointment_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT
);

-- ------------------------------------------------------------
-- 4. TRIGGER BẢO VỆ NGHIỆP VỤ
-- Chỉ cho phép kê đơn nếu lịch hẹn đã COMPLETED.
-- ------------------------------------------------------------

DELIMITER $$

CREATE TRIGGER trg_prescription_only_completed_insert
BEFORE INSERT ON Prescriptions
FOR EACH ROW
BEGIN
    DECLARE appointment_status VARCHAR(20);

    SELECT status
      INTO appointment_status
      FROM Appointments
     WHERE appointment_id = NEW.appointment_id;

    IF appointment_status IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Appointment does not exist.';
    END IF;

    IF appointment_status <> 'COMPLETED' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Prescription can only be created for a COMPLETED appointment.';
    END IF;
END$$

CREATE TRIGGER trg_prescription_only_completed_update
BEFORE UPDATE ON Prescriptions
FOR EACH ROW
BEGIN
    DECLARE appointment_status VARCHAR(20);

    SELECT status
      INTO appointment_status
      FROM Appointments
     WHERE appointment_id = NEW.appointment_id;

    IF appointment_status IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Appointment does not exist.';
    END IF;

    IF appointment_status <> 'COMPLETED' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Prescription can only reference a COMPLETED appointment.';
    END IF;
END$$

DELIMITER ;

-- ------------------------------------------------------------
-- 5. DỮ LIỆU MẪU
-- ------------------------------------------------------------

INSERT INTO Patients (full_name, phone) VALUES
('Nguyen Van A', '0901000001'),
('Tran Thi B', '0901000002');

INSERT INTO Doctors (full_name, specialty) VALUES
('Dr. Le Minh', 'Noi tong quat'),
('Dr. Pham An', 'Tim mach');

-- ------------------------------------------------------------
-- KỊCH BẢN 1: THÀNH CÔNG
-- PENDING, cọc 500.000 -> CONFIRMED -> CHECKED_IN -> COMPLETED
-- -> kê đơn thuốc
-- ------------------------------------------------------------

INSERT INTO Appointments (
    patient_id,
    doctor_id,
    appointment_date,
    status,
    deposit_amount
)
VALUES (
    1,
    1,
    '2026-10-05 09:00:00',
    'PENDING',
    500000.00
);

UPDATE Appointments
SET status = 'CONFIRMED'
WHERE appointment_id = 1;

UPDATE Appointments
SET status = 'CHECKED_IN'
WHERE appointment_id = 1;

UPDATE Appointments
SET status = 'COMPLETED'
WHERE appointment_id = 1;

INSERT INTO Prescriptions (
    appointment_id,
    medication_details,
    issued_date
)
VALUES (
    1,
    'Paracetamol 500mg: 2 vien/ngay sau an trong 3 ngay.',
    '2026-10-05 09:45:00'
);

-- ------------------------------------------------------------
-- KỊCH BẢN 2: HỦY VÀ PHẠT
-- CONFIRMED, cọc 300.000 -> CANCELLED
-- lý do: Bận việc đột xuất
-- phí phạt: 150.000
-- ------------------------------------------------------------

INSERT INTO Appointments (
    patient_id,
    doctor_id,
    appointment_date,
    status,
    deposit_amount
)
VALUES (
    2,
    2,
    '2026-10-06 14:00:00',
    'CONFIRMED',
    300000.00
);

UPDATE Appointments
SET
    status = 'CANCELLED',
    cancel_reason = 'Bận việc đột xuất',
    penalty_fee = 150000.00
WHERE appointment_id = 2;

-- ------------------------------------------------------------
-- 6. TRUY VẤN KIỂM TRA
-- ------------------------------------------------------------

-- Kiểm tra toàn bộ lịch hẹn, tiền cọc, phí phạt và trạng thái
SELECT
    a.appointment_id,
    p.full_name AS patient_name,
    d.full_name AS doctor_name,
    a.appointment_date,
    a.status,
    a.deposit_amount,
    a.penalty_fee,
    (a.deposit_amount - a.penalty_fee) AS remaining_deposit,
    a.cancel_reason
FROM Appointments a
JOIN Patients p ON p.patient_id = a.patient_id
JOIN Doctors d ON d.doctor_id = a.doctor_id
ORDER BY a.appointment_id;

-- Danh sách bệnh nhân đã hoàn tất khám và chi tiết đơn thuốc
SELECT
    a.appointment_id,
    p.full_name AS patient_name,
    d.full_name AS doctor_name,
    a.status,
    pr.prescription_id,
    pr.medication_details,
    pr.issued_date
FROM Appointments a
JOIN Patients p ON p.patient_id = a.patient_id
JOIN Doctors d ON d.doctor_id = a.doctor_id
JOIN Prescriptions pr ON pr.appointment_id = a.appointment_id
WHERE a.status = 'COMPLETED'
ORDER BY a.appointment_id;

-- Đối soát các lịch đã hủy và số tiền phạt
SELECT
    a.appointment_id,
    p.full_name AS patient_name,
    a.deposit_amount,
    a.penalty_fee,
    (a.deposit_amount - a.penalty_fee) AS refundable_amount,
    a.cancel_reason
FROM Appointments a
JOIN Patients p ON p.patient_id = a.patient_id
WHERE a.status = 'CANCELLED';

-- ------------------------------------------------------------
-- 7. TEST TRIGGER (TÙY CHỌN)
-- Bỏ comment để kiểm thử: câu lệnh phải bị từ chối vì appointment 2 CANCELLED.
-- ------------------------------------------------------------

-- INSERT INTO Prescriptions (appointment_id, medication_details)
-- VALUES (2, 'Thuoc khong hop le vi lich hen chua COMPLETED');
