-- ============================================
-- MediOps Demo Seed Data
-- Author: VinCloudOps
-- Date: 20 Sept 2025
-- ============================================

-- 👩‍⚕️ Patients
INSERT INTO patients (name, age, diagnosis, status) VALUES
  ('John Doe', 45, 'Diabetes', 'Ongoing'),
  ('Jane Smith', 32, 'Flu', 'Recovered'),
  ('Raj Patel', 60, 'Hypertension', 'Critical'),
  ('Mary Johnson', 28, 'Asthma', 'Ongoing'),
  ('Ali Khan', 52, 'Heart Disease', 'Ongoing'),
  ('Emily Brown', 41, 'Migraine', 'Recovered'),
  ('Carlos Gomez', 36, 'Tuberculosis', 'Critical'),
  ('Sophia Lee', 29, 'Thyroid', 'Ongoing'),
  ('David Chen', 65, 'Arthritis', 'Ongoing'),
  ('Ananya Iyer', 38, 'Anemia', 'Recovered');

-- 🩺 Doctors
INSERT INTO doctors (name, specialization) VALUES
  ('Dr. Alice Williams', 'Cardiologist'),
  ('Dr. Bob Martin', 'General Physician'),
  ('Dr. Clara Singh', 'Neurologist'),
  ('Dr. Daniel Kim', 'Endocrinologist'),
  ('Dr. Eva Rodriguez', 'Pulmonologist');

-- 📅 Appointments
INSERT INTO appointments (patient_id, doctor_id, date, status) VALUES
  (1, 1, '2025-09-25', 'Scheduled'),
  (2, 2, '2025-09-26', 'Completed'),
  (3, 1, '2025-09-27', 'Ongoing'),
  (4, 5, '2025-09-28', 'Scheduled'),
  (5, 1, '2025-09-29', 'Ongoing'),
  (6, 3, '2025-09-30', 'Completed'),
  (7, 5, '2025-10-01', 'Critical'),
  (8, 4, '2025-10-02', 'Scheduled'),
  (9, 2, '2025-10-03', 'Ongoing'),
  (10, 3, '2025-10-04', 'Completed');
