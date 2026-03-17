-- Since your old tables exist, we cannot recreate them fully.
-- Let's just add the missing columns to the existing tables safely:

-- 1. Add phone_number to profiles
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS phone_number TEXT;

-- 2. Add parent_id to locations (so a Store can belong to a Warehouse)
ALTER TABLE locations ADD COLUMN IF NOT EXISTS parent_id UUID REFERENCES locations(id) ON DELETE CASCADE;

-- 3. In products, we had added factory_barcode and generated_sku
ALTER TABLE products ADD COLUMN IF NOT EXISTS factory_barcode TEXT;
ALTER TABLE products ADD COLUMN IF NOT EXISTS generated_sku TEXT UNIQUE;
ALTER TABLE products ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT true;

-- The system will now be able to run without errors because the necessary columns are added!

-- 4. Add 'supplier' to user_role ENUM (if it doesn't already exist)
ALTER TYPE user_role ADD VALUE IF NOT EXISTS 'supplier';
