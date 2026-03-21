-- ==========================================
-- FINAL FIX for RLS "permission denied for table users"
-- ==========================================

-- 1. Fix company_invitations policies
DROP POLICY IF EXISTS "Users can view their invitation" ON company_invitations;
CREATE POLICY "Users can view their invitation" ON company_invitations FOR SELECT USING (
    invited_email = auth.jwt()->>'email'
);

-- 2. Ensure get_user_role and get_user_company_id are truly SECURITY DEFINER
-- (They already are in the schema, but let's be sure as they are the core of RLS)
CREATE OR REPLACE FUNCTION get_user_company_id()
RETURNS UUID AS $$
    SELECT company_id FROM profiles WHERE id = auth.uid() LIMIT 1;
$$ LANGUAGE sql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_user_role()
RETURNS user_role AS $$
    SELECT role FROM profiles WHERE id = auth.uid() LIMIT 1;
$$ LANGUAGE sql SECURITY DEFINER;

-- 3. Fix potential issues in audit_logs if any
-- (Currently audit_logs policies look okay, but let's ensure they don't break)
DROP POLICY IF EXISTS "Admin manage store_categories" ON store_categories;
CREATE POLICY "Admin manage store_categories" ON store_categories FOR ALL USING (
    EXISTS (SELECT 1 FROM locations l WHERE l.id = store_categories.store_id AND l.company_id = get_user_company_id()) 
    AND get_user_role() = 'admin'
);

-- 4. Reload schema cache
NOTIFY pgrst, 'reload schema';
