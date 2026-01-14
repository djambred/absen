-- ====================================================================
-- Migration: Initial Database Schema
-- Version: 000
-- Date: 2026-01-14
-- Description: Creates all tables for absensi system
-- ====================================================================

SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='TRADITIONAL,ALLOW_INVALID_DATES';
SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0;

-- ====================================================================
-- POSITIONS TABLE
-- ====================================================================
CREATE TABLE IF NOT EXISTS positions (
    id VARCHAR(36) PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    category ENUM('dosen', 'tendik', 'admin', 'other') NOT NULL,
    created_at DATETIME NOT NULL,
    updated_at DATETIME NOT NULL,
    INDEX idx_category (category)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ====================================================================
-- USERS TABLE
-- ====================================================================
CREATE TABLE IF NOT EXISTS users (
    id VARCHAR(36) PRIMARY KEY,
    email VARCHAR(255) NOT NULL UNIQUE,
    name VARCHAR(255) NOT NULL,
    password VARCHAR(255) NOT NULL,
    nip VARCHAR(50),
    phone VARCHAR(20),
    address TEXT,
    department VARCHAR(100),
    role ENUM('admin', 'user', 'hr', 'kepala_it', 'dekan', 'kaprodi') DEFAULT 'user',
    is_active BOOLEAN DEFAULT TRUE,
    created_at DATETIME NOT NULL,
    updated_at DATETIME NOT NULL,
    fcm_token VARCHAR(255),
    INDEX idx_email (email),
    INDEX idx_nip (nip),
    INDEX idx_role (role),
    INDEX idx_department (department)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ====================================================================
-- USER_POSITIONS TABLE (Many-to-Many)
-- ====================================================================
CREATE TABLE IF NOT EXISTS user_positions (
    user_id VARCHAR(36) NOT NULL,
    position_id VARCHAR(36) NOT NULL,
    PRIMARY KEY (user_id, position_id),
    INDEX idx_user (user_id),
    INDEX idx_position (position_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ====================================================================
-- ATTENDANCE TABLE
-- ====================================================================
CREATE TABLE IF NOT EXISTS attendance (
    id VARCHAR(36) PRIMARY KEY,
    user_id VARCHAR(36) NOT NULL,
    check_in_time DATETIME NOT NULL,
    check_out_time DATETIME,
    check_in_location_lat DECIMAL(10, 8),
    check_in_location_lng DECIMAL(11, 8),
    check_out_location_lat DECIMAL(10, 8),
    check_out_location_lng DECIMAL(11, 8),
    check_in_photo VARCHAR(500),
    check_out_photo VARCHAR(500),
    status ENUM('hadir', 'terlambat', 'pulang_cepat', 'alpha') DEFAULT 'hadir',
    notes TEXT,
    is_auto_checkout BOOLEAN DEFAULT FALSE,
    created_at DATETIME NOT NULL,
    updated_at DATETIME NOT NULL,
    INDEX idx_user_id (user_id),
    INDEX idx_user_date (user_id, check_in_time),
    INDEX idx_check_in_time (check_in_time),
    INDEX idx_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ====================================================================
-- LEAVE_QUOTA TABLE
-- ====================================================================
CREATE TABLE IF NOT EXISTS leave_quota (
    id VARCHAR(36) PRIMARY KEY,
    user_id VARCHAR(36) NOT NULL,
    year INT NOT NULL,
    total_quota INT DEFAULT 12,
    remaining_quota INT DEFAULT 12,
    created_at DATETIME NOT NULL,
    updated_at DATETIME NOT NULL,
    UNIQUE KEY unique_user_year (user_id, year),
    INDEX idx_user_id (user_id),
    INDEX idx_user_year (user_id, year)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ====================================================================
-- LEAVES TABLE
-- ====================================================================
CREATE TABLE IF NOT EXISTS leaves (
    id VARCHAR(36) PRIMARY KEY,
    user_id VARCHAR(36) NOT NULL,
    leave_type ENUM('cuti', 'izin', 'sakit') NOT NULL,
    category ENUM('cuti_tahunan', 'cuti_penting', 'izin_pribadi', 'izin_dinas', 'sakit_dengan_surat', 'sakit_tanpa_surat') NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    total_days INT NOT NULL,
    reason TEXT NOT NULL,
    attachment_url VARCHAR(500),
    status ENUM('PENDING', 'APPROVED_BY_SUPERVISOR', 'APPROVED_BY_HR', 'REJECTED') DEFAULT 'PENDING',
    supervisor_id VARCHAR(36),
    approved_by_level_1 VARCHAR(36),
    approved_at_level_1 DATETIME,
    approval_notes_level_1 TEXT,
    approved_by_level_2 VARCHAR(36),
    approved_at_level_2 DATETIME,
    approval_notes_level_2 TEXT,
    rejected_by VARCHAR(36),
    rejected_at DATETIME,
    rejection_reason TEXT,
    deducted_from_quota BOOLEAN DEFAULT FALSE,
    quota_year INT,
    assigned_to_id VARCHAR(36),
    task_description TEXT,
    created_at DATETIME NOT NULL,
    updated_at DATETIME NOT NULL,
    INDEX idx_user_id (user_id),
    INDEX idx_user_date (user_id, start_date, end_date),
    INDEX idx_status (status),
    INDEX idx_supervisor (supervisor_id),
    INDEX idx_leave_type (leave_type)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ====================================================================
-- TASKS TABLE
-- ====================================================================
CREATE TABLE IF NOT EXISTS tasks (
    id VARCHAR(36) PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    assigned_by_id VARCHAR(36) NOT NULL,
    assigned_to_id VARCHAR(36) NOT NULL,
    due_date DATETIME,
    start_date DATETIME,
    end_date DATETIME,
    status ENUM('PENDING', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED') NOT NULL DEFAULT 'PENDING',
    priority VARCHAR(20) NOT NULL DEFAULT 'normal',
    notes TEXT,
    completion_notes TEXT,
    created_at DATETIME NOT NULL,
    updated_at DATETIME NOT NULL,
    completed_at DATETIME,
    INDEX idx_assigned_by (assigned_by_id),
    INDEX idx_assigned_to (assigned_to_id),
    INDEX idx_tasks_status (status),
    INDEX idx_tasks_due_date (due_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ====================================================================
-- ADD FOREIGN KEY CONSTRAINTS (if not already exist)
-- ====================================================================

-- User positions foreign keys
SET @s = (SELECT IF(
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS 
     WHERE table_schema=DATABASE() 
     AND table_name='user_positions' 
     AND constraint_name='fk_user_positions_user') > 0,
    'SELECT "FK fk_user_positions_user exists" as message',
    'ALTER TABLE user_positions ADD CONSTRAINT fk_user_positions_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE'
));
PREPARE stmt FROM @s;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @s = (SELECT IF(
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS 
     WHERE table_schema=DATABASE() 
     AND table_name='user_positions' 
     AND constraint_name='fk_user_positions_position') > 0,
    'SELECT "FK fk_user_positions_position exists" as message',
    'ALTER TABLE user_positions ADD CONSTRAINT fk_user_positions_position FOREIGN KEY (position_id) REFERENCES positions(id) ON DELETE CASCADE'
));
PREPARE stmt FROM @s;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- Attendance foreign keys
SET @s = (SELECT IF(
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS 
     WHERE table_schema=DATABASE() 
     AND table_name='attendance' 
     AND constraint_name='fk_attendance_user') > 0,
    'SELECT "FK fk_attendance_user exists" as message',
    'ALTER TABLE attendance ADD CONSTRAINT fk_attendance_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE'
));
PREPARE stmt FROM @s;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- Leave quota foreign keys
SET @s = (SELECT IF(
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS 
     WHERE table_schema=DATABASE() 
     AND table_name='leave_quota' 
     AND constraint_name='fk_leave_quota_user') > 0,
    'SELECT "FK fk_leave_quota_user exists" as message',
    'ALTER TABLE leave_quota ADD CONSTRAINT fk_leave_quota_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE'
));
PREPARE stmt FROM @s;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- Leaves foreign keys
SET @s = (SELECT IF(
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS 
     WHERE table_schema=DATABASE() 
     AND table_name='leaves' 
     AND constraint_name='fk_leaves_user') > 0,
    'SELECT "FK fk_leaves_user exists" as message',
    'ALTER TABLE leaves ADD CONSTRAINT fk_leaves_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE'
));
PREPARE stmt FROM @s;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @s = (SELECT IF(
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS 
     WHERE table_schema=DATABASE() 
     AND table_name='leaves' 
     AND constraint_name='fk_leaves_supervisor') > 0,
    'SELECT "FK fk_leaves_supervisor exists" as message',
    'ALTER TABLE leaves ADD CONSTRAINT fk_leaves_supervisor FOREIGN KEY (supervisor_id) REFERENCES users(id) ON DELETE SET NULL'
));
PREPARE stmt FROM @s;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @s = (SELECT IF(
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS 
     WHERE table_schema=DATABASE() 
     AND table_name='leaves' 
     AND constraint_name='fk_leaves_approved_by_1') > 0,
    'SELECT "FK fk_leaves_approved_by_1 exists" as message',
    'ALTER TABLE leaves ADD CONSTRAINT fk_leaves_approved_by_1 FOREIGN KEY (approved_by_level_1) REFERENCES users(id) ON DELETE SET NULL'
));
PREPARE stmt FROM @s;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @s = (SELECT IF(
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS 
     WHERE table_schema=DATABASE() 
     AND table_name='leaves' 
     AND constraint_name='fk_leaves_approved_by_2') > 0,
    'SELECT "FK fk_leaves_approved_by_2 exists" as message',
    'ALTER TABLE leaves ADD CONSTRAINT fk_leaves_approved_by_2 FOREIGN KEY (approved_by_level_2) REFERENCES users(id) ON DELETE SET NULL'
));
PREPARE stmt FROM @s;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @s = (SELECT IF(
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS 
     WHERE table_schema=DATABASE() 
     AND table_name='leaves' 
     AND constraint_name='fk_leaves_rejected_by') > 0,
    'SELECT "FK fk_leaves_rejected_by exists" as message',
    'ALTER TABLE leaves ADD CONSTRAINT fk_leaves_rejected_by FOREIGN KEY (rejected_by) REFERENCES users(id) ON DELETE SET NULL'
));
PREPARE stmt FROM @s;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @s = (SELECT IF(
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS 
     WHERE table_schema=DATABASE() 
     AND table_name='leaves' 
     AND constraint_name='fk_leaves_assigned_to') > 0,
    'SELECT "FK fk_leaves_assigned_to exists" as message',
    'ALTER TABLE leaves ADD CONSTRAINT fk_leaves_assigned_to FOREIGN KEY (assigned_to_id) REFERENCES users(id) ON DELETE SET NULL'
));
PREPARE stmt FROM @s;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- Tasks foreign keys
SET @s = (SELECT IF(
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS 
     WHERE table_schema=DATABASE() 
     AND table_name='tasks' 
     AND constraint_name='fk_tasks_assigned_by') > 0,
    'SELECT "FK fk_tasks_assigned_by exists" as message',
    'ALTER TABLE tasks ADD CONSTRAINT fk_tasks_assigned_by FOREIGN KEY (assigned_by_id) REFERENCES users(id) ON DELETE CASCADE'
));
PREPARE stmt FROM @s;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @s = (SELECT IF(
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS 
     WHERE table_schema=DATABASE() 
     AND table_name='tasks' 
     AND constraint_name='fk_tasks_assigned_to') > 0,
    'SELECT "FK fk_tasks_assigned_to exists" as message',
    'ALTER TABLE tasks ADD CONSTRAINT fk_tasks_assigned_to FOREIGN KEY (assigned_to_id) REFERENCES users(id) ON DELETE CASCADE'
));
PREPARE stmt FROM @s;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- ====================================================================
-- VERIFICATION
-- ====================================================================
SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS;
SET SQL_MODE=@OLD_SQL_MODE;

SELECT 'Initial schema migration completed successfully!' as Status;
