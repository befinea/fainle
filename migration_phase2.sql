-- ==========================================
-- Migration Phase 2: Custom Roles, Task Priority, Store Assignment
-- ==========================================

-- 1. Add custom_role_name to profiles (for custom employee titles)
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS custom_role_name TEXT;

-- 2. Add priority to tasks
ALTER TABLE tasks ADD COLUMN IF NOT EXISTS priority TEXT DEFAULT 'normal' CHECK (priority IN ('normal', 'important', 'urgent'));

-- 3. Add location_id (store) to tasks for store-specific assignment
ALTER TABLE tasks ADD COLUMN IF NOT EXISTS store_id UUID REFERENCES locations(id) ON DELETE SET NULL;

-- 4. Add max_stores to locations (warehouse) for store limits
ALTER TABLE locations ADD COLUMN IF NOT EXISTS max_stores INTEGER DEFAULT 5;

-- 5. Add store categories support
DROP TABLE IF EXISTS store_categories CASCADE;
CREATE TABLE store_categories (
    store_id UUID REFERENCES locations(id) ON DELETE CASCADE,
    category_id UUID REFERENCES categories(id) ON DELETE CASCADE,
    PRIMARY KEY (store_id, category_id)
);
ALTER TABLE store_categories ENABLE ROW LEVEL SECURITY;

DO $$ 
BEGIN
    DROP POLICY IF EXISTS "Company-wide read store_categories" ON store_categories;
    CREATE POLICY "Company-wide read store_categories" ON store_categories FOR SELECT USING (
        EXISTS (SELECT 1 FROM locations l WHERE l.id = store_categories.store_id AND l.company_id = get_user_company_id())
    );

    DROP POLICY IF EXISTS "Admin manage store_categories" ON store_categories;
    CREATE POLICY "Admin manage store_categories" ON store_categories FOR ALL USING (
        EXISTS (SELECT 1 FROM locations l WHERE l.id = store_categories.store_id AND l.company_id = get_user_company_id()) AND get_user_role() = 'admin'
    );

    DROP POLICY IF EXISTS "Admin can manage locations" ON locations;
    CREATE POLICY "Admin can manage locations" ON locations FOR ALL USING (
        company_id = get_user_company_id() AND get_user_role() = 'admin'
    );

    DROP POLICY IF EXISTS "Admins can manage all tasks" ON tasks;
    CREATE POLICY "Admins can manage all tasks" ON tasks FOR ALL USING (
        company_id = get_user_company_id() AND get_user_role() = 'admin'
    );
END $$;

-- Force PostgREST to reload schema cache so Flutter app sees the new columns instantly
NOTIFY pgrst, 'reload schema';
