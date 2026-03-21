-- ==========================================
-- Fix: Allow companies to link stores to General Manager (Befine) warehouses
-- ==========================================

DROP POLICY IF EXISTS "Company-wide read Locations" ON locations;

CREATE POLICY "Company-wide read Locations" ON locations FOR SELECT USING (
    -- Normal users read their own company locations
    company_id = get_user_company_id()
    OR
    -- Super Admin (Befine admin) can read ALL locations
    (get_user_company_id() = '00000000-0000-0000-0000-000000000001' AND get_user_role() = 'admin')
    OR
    -- ALL users can read locations that belong to Befine AND are of type 'warehouse'
    (company_id = '00000000-0000-0000-0000-000000000001' AND type = 'warehouse')
);
