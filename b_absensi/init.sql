-- Create database
CREATE DATABASE IF NOT EXISTS absensi_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE absensi_db;

-- Create users table
CREATE TABLE users (
  id INT AUTO_INCREMENT PRIMARY KEY,
  email VARCHAR(100) UNIQUE NOT NULL,
  password VARCHAR(255) NOT NULL,
  nama VARCHAR(100) NOT NULL,
  departemen VARCHAR(100),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_email (email),
  INDEX idx_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Create absensi table
CREATE TABLE absensi (
  id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  tipe VARCHAR(20) NOT NULL,
  waktu TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  lokasi VARCHAR(100),
  latitude FLOAT NOT NULL,
  longitude FLOAT NOT NULL,
  foto_path VARCHAR(255),
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  INDEX idx_user_id (user_id),
  INDEX idx_waktu (waktu),
  INDEX idx_user_waktu (user_id, waktu),
  INDEX idx_tipe (tipe)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Insert sample data (optional)
INSERT INTO users (email, password, nama, departemen) VALUES 
('admin@example.com', '$2b$12$example_bcrypt_hash_here', 'Admin User', 'IT'),
('user1@example.com', '$2b$12$example_bcrypt_hash_here', 'User One', 'HR');

-- Create indexes for better performance
ALTER TABLE absensi ADD INDEX idx_composite (user_id, tipe, waktu);