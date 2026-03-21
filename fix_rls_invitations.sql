-- Fix for "permission denied for table users" in company_invitations
DROP POLICY IF EXISTS "Users can view their invitation" ON company_invitations;

CREATE POLICY "Users can view their invitation" ON company_invitations FOR SELECT USING (
    invited_email = auth.jwt()->>'email'
);

-- Reload schema cache
NOTIFY pgrst, 'reload schema';
