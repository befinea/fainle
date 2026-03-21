-- ==========================================
-- Fix Super Admin RLS Policies
-- Allows admin of company '00000000-0000-0000-0000-000000000001' (Befine)
-- to view and manage ALL companies, profiles, and locations.
-- ==========================================

-- ==========================================
-- 1. COMPANIES TABLE
-- ==========================================
DROP POLICY IF EXISTS "Users can view their own company" ON companies;
DROP POLICY IF EXISTS "Admin can update company" ON companies;

-- Select: normal users see own company, super admin sees all
CREATE POLICY "Users can view companies" ON companies FOR SELECT USING (
    id = get_user_company_id()
    OR
    (get_user_company_id() = '00000000-0000-0000-0000-000000000001' AND get_user_role() = 'admin')
);

-- Update: normal admins update own company, super admin updates all
CREATE POLICY "Admins can update companies" ON companies FOR UPDATE USING (
    (id = get_user_company_id() AND get_user_role() = 'admin')
    OR
    (get_user_company_id() = '00000000-0000-0000-0000-000000000001' AND get_user_role() = 'admin')
);

-- ==========================================
-- 2. PROFILES TABLE
-- ==========================================
DROP POLICY IF EXISTS "Users can view company profiles" ON profiles;

-- Select: normal users see own company profiles, super admin sees all
CREATE POLICY "Users can view company profiles" ON profiles FOR SELECT USING (
    company_id = get_user_company_id()
    OR
    (get_user_company_id() = '00000000-0000-0000-0000-000000000001' AND get_user_role() = 'admin')
);

-- ==========================================
-- 3. LOCATIONS TABLE
-- ==========================================
DROP POLICY IF EXISTS "Company-wide read Locations" ON locations;

-- Select: normal users see own company locations, super admin sees all
CREATE POLICY "Company-wide read Locations" ON locations FOR SELECT USING (
    company_id = get_user_company_id()
    OR
    (get_user_company_id() = '00000000-0000-0000-0000-000000000001' AND get_user_role() = 'admin')
);
