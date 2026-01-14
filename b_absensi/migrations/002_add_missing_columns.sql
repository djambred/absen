-- ====================================================================
-- Migration: Update leaves table with task management fields
-- Version: 002
-- Date: 2026-01-14
-- Description: This migration is now deprecated - all changes are in 000_initial_schema.sql
--              Kept for reference only. Will be skipped if schema already exists.
-- ====================================================================
-- NOTE: This migration only runs if the columns don't exist yet

-- Set SQL mode to be more permissive for migration
SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='';

-- ====================================================================
-- STEP 1: Add columns to leaves table
-- ====================================================================

-- Add rejected_by column
SET @s = (SELECT IF(
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS 
     WHERE table_schema=DATABASE() 
     AND table_name='leaves' 
     AND column_name='rejected_by') > 0,
    'SELECT "Column rejected_by already exists, skipping..." as message',
    'ALTER TABLE leaves ADD COLUMN rejected_by VARCHAR(36) NULL COMMENT "User who rejected the leave"'
));
PREPARE stmt FROM @s;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- Add rejected_at column
SET @s = (SELECT IF(
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS 
     WHERE table_schema=DATABASE() 
     AND table_name='leaves' 
     AND column_name='rejected_at') > 0,
    'SELECT "Column rejected_at already exists, skipping..." as message',
    'ALTER TABLE leaves ADD COLUMN rejected_at DATETIME NULL COMMENT "Timestamp when leave was rejected"'
));
PREPARE stmt FROM @s;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- Add assigned_to_id column
SET @s = (SELECT IF(
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS 
     WHERE table_schema=DATABASE() 
     AND table_name='leaves' 
     AND column_name='assigned_to_id') > 0,
    'SELECT "Column assigned_to_id already exists, skipping..." as message',
    'ALTER TABLE leaves ADD COLUMN assigned_to_id VARCHAR(36) NULL COMMENT "User assigned to handle tasks during leave"'
));
PREPARE stmt FROM @s;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- Add task_description column
SET @s = (SELECT IF(
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS 
     WHERE table_schema=DATABASE() 
     AND table_name='leaves' 
     AND column_name='task_description') > 0,
    'SELECT "Column task_description already exists, skipping..." as message',
    'ALTER TABLE leaves ADD COLUMN task_description TEXT NULL COMMENT "Description of tasks to be handled during leave"'
));
PREPARE stmt FROM @s;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- ====================================================================
-- STEP 2: Add foreign key constraints
-- ====================================================================

-- Add foreign key for rejected_by
SET @s = (SELECT IF(
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS 
     WHERE table_schema=DATABASE() 
     AND table_name='leaves' 
     AND constraint_name='fk_leaves_rejected_by') > 0,
    'SELECT "Foreign key fk_leaves_rejected_by already exists, skipping..." as message',
    'ALTER TABLE leaves ADD CONSTRAINT fk_leaves_rejected_by FOREIGN KEY (rejected_by) REFERENCES users(id) ON DELETE SET NULL'
));
PREPARE stmt FROM @s;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- Add foreign key for assigned_to_id
SET @s = (SELECT IF(
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS 
     WHERE table_schema=DATABASE() 
     AND table_name='leaves' 
     AND constraint_name='fk_leaves_assigned_to') > 0,
    'SELECT "Foreign key fk_leaves_assigned_to already exists, skipping..." as message',
    'ALTER TABLE leaves ADD CONSTRAINT fk_leaves_assigned_to FOREIGN KEY (assigned_to_id) REFERENCES users(id) ON DELETE SET NULL'
));
PREPARE stmt FROM @s;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- ====================================================================
-- STEP 3: Create tasks table
-- ====================================================================

CREATE TABLE IF NOT EXISTS tasks (
    id VARCHAR(36) PRIMARY KEY COMMENT 'UUID for task',
    title VARCHAR(255) NOT NULL COMMENT 'Task title',
    description TEXT NULL COMMENT 'Detailed task description',
    assigned_by_id VARCHAR(36) NOT NULL COMMENT 'User who created/assigned the task',
    assigned_to_id VARCHAR(36) NOT NULL COMMENT 'User assigned to complete the task',
    due_date DATETIME NULL COMMENT 'Task due date',
    start_date DATETIME NULL COMMENT 'When task was started',
    end_date DATETIME NULL COMMENT 'When task should be completed',
    status ENUM('PENDING', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED') NOT NULL DEFAULT 'PENDING' COMMENT 'Current task status',
    priority VARCHAR(20) NOT NULL DEFAULT 'normal' COMMENT 'Task priority: low, normal, high, urgent',
    notes TEXT NULL COMMENT 'Additional notes or instructions',
    completion_notes TEXT NULL COMMENT 'Notes added when completing the task',
    created_at DATETIME NOT NULL COMMENT 'Task creation timestamp',
    updated_at DATETIME NOT NULL COMMENT 'Last update timestamp',
    completed_at DATETIME NULL COMMENT 'Task completion timestamp',
    CONSTRAINT fk_tasks_assigned_by FOREIGN KEY (assigned_by_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT fk_tasks_assigned_to FOREIGN KEY (assigned_to_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_tasks_assigned_to (assigned_to_id),
    INDEX idx_tasks_assigned_by (assigned_by_id),
    INDEX idx_tasks_status (status),
    INDEX idx_tasks_due_date (due_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Task management table';

-- ====================================================================
-- STEP 4: Verify migration
-- ====================================================================

SELECT 'Migration 002 completed successfully!' as Status;

-- Show added columns in leaves table
SELECT 
    COLUMN_NAME, 
    DATA_TYPE, 
    IS_NULLABLE,
    COLUMN_COMMENT
FROM INFORMATION_SCHEMA.COLUMNS 
WHERE table_schema=DATABASE() 
AND table_name='leaves' 
AND COLUMN_NAME IN ('rejected_by', 'rejected_at', 'assigned_to_id', 'task_description')
ORDER BY COLUMN_NAME;

-- Show tasks table structure
DESCRIBE tasks;

-- Restore SQL mode
SET SQL_MODE=@OLD_SQL_MODE;
