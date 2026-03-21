-- ==========================================
-- Migration Phase 3: Employee Store Assignment
-- ==========================================

-- 1. Add store_id to profiles so employees can be assigned to a specific store
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS store_id UUID REFERENCES locations(id) ON DELETE SET NULL;

-- 2. Add store_id and custom_role_name to company_invitations to carry over during signup
ALTER TABLE company_invitations ADD COLUMN IF NOT EXISTS store_id UUID REFERENCES locations(id) ON DELETE SET NULL;
ALTER TABLE company_invitations ADD COLUMN IF NOT EXISTS custom_role_name TEXT;

-- Force PostgREST to reload schema cache so Flutter app sees the new columns instantly
NOTIFY pgrst, 'reload schema';
