-- ==========================================
-- Fix Missing RLS Policies for Registration
-- ==========================================

DO $$ 
BEGIN
    -- 1. Allow authenticated users to create a company
    DROP POLICY IF EXISTS "Authenticated users can create company" ON companies;
    CREATE POLICY "Authenticated users can create company" ON companies 
    FOR INSERT 
    WITH CHECK (auth.uid() IS NOT NULL);

    -- 2. Allow users to insert their own profile
    DROP POLICY IF EXISTS "Users can insert own profile" ON profiles;
    CREATE POLICY "Users can insert own profile" ON profiles 
    FOR INSERT 
    WITH CHECK (id = auth.uid());

    -- 3. Allow admins to update their own company
    DROP POLICY IF EXISTS "Admin can update company" ON companies;
    CREATE POLICY "Admin can update company" ON companies 
    FOR UPDATE 
    USING (id = (SELECT company_id FROM profiles WHERE id = auth.uid() LIMIT 1));
	
	-- 4. Audit logs insert policy safely
	DROP POLICY IF EXISTS "Insert audit_logs" ON audit_logs;
	CREATE POLICY "Insert audit_logs" ON audit_logs 
	FOR INSERT 
	WITH CHECK (
		company_id = (SELECT company_id FROM profiles WHERE id = auth.uid() LIMIT 1)
		OR
		auth.uid() = user_id -- Backup check for edge cases during registration
	);

END $$;
