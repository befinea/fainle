-- ==========================================
-- Migration: Add max_stores and store_categories
-- Run this in the Supabase SQL Editor
-- ==========================================

-- 1. Add max_stores column to locations (for warehouses)
ALTER TABLE locations ADD COLUMN IF NOT EXISTS max_stores INTEGER;

-- 2. Create store_categories junction table
CREATE TABLE IF NOT EXISTS store_categories (
    location_id UUID REFERENCES locations(id) ON DELETE CASCADE,
    category_id UUID REFERENCES categories(id) ON DELETE CASCADE,
    PRIMARY KEY (location_id, category_id)
);

-- 3. Enable RLS
ALTER TABLE store_categories ENABLE ROW LEVEL SECURITY;

-- 4. RLS Policies for store_categories
CREATE POLICY "Company-wide read store_categories" ON store_categories FOR SELECT USING (
    EXISTS (SELECT 1 FROM locations l WHERE l.id = location_id AND l.company_id = get_user_company_id())
);
CREATE POLICY "Insert store_categories" ON store_categories FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM locations l WHERE l.id = location_id AND l.company_id = get_user_company_id())
);
CREATE POLICY "Delete store_categories" ON store_categories FOR DELETE USING (
    EXISTS (SELECT 1 FROM locations l WHERE l.id = location_id AND l.company_id = get_user_company_id())
);
