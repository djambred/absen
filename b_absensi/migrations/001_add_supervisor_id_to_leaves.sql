-- Migration: Add supervisor_id column to leaves table
-- This allows tracking which supervisor should approve the leave request

ALTER TABLE leaves ADD COLUMN IF NOT EXISTS supervisor_id VARCHAR(36) REFERENCES users(id);

-- Create index for better query performance
CREATE INDEX IF NOT EXISTS idx_leaves_supervisor_id ON leaves(supervisor_id);

COMMENT ON COLUMN leaves.supervisor_id IS 'ID of the supervisor who should approve this leave request';
