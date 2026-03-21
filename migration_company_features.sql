-- ==========================================
-- Migration: Company Features (Invitations, Audit Logs, Subscriptions)
-- ==========================================

-- 1. Add subscription_plan and onboarding_completed to companies
ALTER TABLE companies ADD COLUMN IF NOT EXISTS subscription_plan TEXT DEFAULT 'free' CHECK (subscription_plan IN ('free', 'basic', 'premium'));
ALTER TABLE companies ADD COLUMN IF NOT EXISTS max_warehouses INTEGER DEFAULT 1;
ALTER TABLE companies ADD COLUMN IF NOT EXISTS max_stores INTEGER DEFAULT 1;
ALTER TABLE companies ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT true;
ALTER TABLE companies ADD COLUMN IF NOT EXISTS email_domain TEXT; -- For auto-join by domain (e.g. 'company.com')
ALTER TABLE companies ADD COLUMN IF NOT EXISTS onboarding_completed BOOLEAN DEFAULT false;

-- 2. Company Invitations Table
CREATE TABLE IF NOT EXISTS company_invitations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    company_id UUID REFERENCES companies(id) ON DELETE CASCADE NOT NULL,
    invited_email TEXT NOT NULL,
    role user_role DEFAULT 'cashier'::user_role NOT NULL,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'expired', 'cancelled')),
    invited_by UUID REFERENCES profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    expires_at TIMESTAMP WITH TIME ZONE DEFAULT (timezone('utc'::text, now()) + INTERVAL '7 days')
);

-- 3. Audit Logs Table
CREATE TABLE IF NOT EXISTS audit_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    company_id UUID REFERENCES companies(id) ON DELETE CASCADE NOT NULL,
    user_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
    action TEXT NOT NULL, -- e.g. 'product_created', 'sale_completed', 'stock_adjusted'
    entity_type TEXT, -- e.g. 'product', 'transaction', 'location'
    entity_id UUID,
    details JSONB, -- any extra metadata
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 4. Enable RLS on new tables
ALTER TABLE company_invitations ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;

-- 5. Policies for company_invitations
CREATE POLICY "Admin can manage invitations" ON company_invitations FOR ALL USING (
    company_id = get_user_company_id() AND get_user_role() = 'admin'
);
CREATE POLICY "Users can view their invitation" ON company_invitations FOR SELECT USING (
    invited_email = (SELECT email FROM auth.users WHERE id = auth.uid())
);

-- 6. Policies for audit_logs
CREATE POLICY "Company-wide read audit_logs" ON audit_logs FOR SELECT USING (
    company_id = get_user_company_id()
);
CREATE POLICY "Insert audit_logs" ON audit_logs FOR INSERT WITH CHECK (
    company_id = get_user_company_id()
);

-- 7. Update companies policy so admin can update their own company
CREATE POLICY "Admin can update company" ON companies FOR UPDATE USING (
    id = get_user_company_id() AND get_user_role() = 'admin'
);

-- 8. Allow self-registration: new users can insert their own profile during signup
-- (The auth_screen creates a company then a profile in one go)
CREATE POLICY "Users can insert own profile" ON profiles FOR INSERT WITH CHECK (
    id = auth.uid()
);

-- 9. Allow new companies to be inserted by any authenticated user (for signup)
CREATE POLICY "Authenticated users can create company" ON companies FOR INSERT WITH CHECK (
    auth.uid() IS NOT NULL
);
