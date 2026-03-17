-- ==========================================
-- Supabase Policies for Supplier Role
-- ==========================================

-- Allow suppliers to insert products
CREATE POLICY "Supplier can insert products" ON products FOR INSERT WITH CHECK (
    company_id = get_user_company_id() AND get_user_role() = 'supplier'
);

-- Note: Transactions already have an overarching INSERT policy for all roles:
-- CREATE POLICY "Insert Transactions via POS/App" ON transactions FOR INSERT WITH CHECK (company_id = get_user_company_id());
-- Therefore, suppliers can naturally insert transactions (Imports, Sales, etc.).

-- For UI features to work properly, ensure the supplier role is explicitly handled
-- in Flutter to hide Edit/Delete buttons on screens.

-- Apply this script via the Supabase SQL Editor.
