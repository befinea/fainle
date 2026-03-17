--------------------------------------------------------------------------------
-- CAUTION: THIS WILL DELETE ALL EXISTING DATA AND TABLES IN YOUR SUPABASE
-- RUN THIS SCRIPT ONLY IF YOUR DATABASE IS CORRUPTED AND YOU WANT A FRESH START
--------------------------------------------------------------------------------

-- 1. DROP EVERYTHING FIRST TO AVOID "ALREADY EXISTS" ERRORS
DROP TABLE IF EXISTS tasks CASCADE;
DROP TABLE IF EXISTS transaction_items CASCADE;
DROP TABLE IF EXISTS transactions CASCADE;
DROP TABLE IF EXISTS external_entities CASCADE;
DROP TABLE IF EXISTS stock_levels CASCADE;
DROP TABLE IF EXISTS products CASCADE;
DROP TABLE IF EXISTS categories CASCADE;
DROP TABLE IF EXISTS profile_locations CASCADE;
DROP TABLE IF EXISTS locations CASCADE;
DROP TABLE IF EXISTS profiles CASCADE;
DROP TABLE IF EXISTS companies CASCADE;

DROP TYPE IF EXISTS task_status CASCADE;
DROP TYPE IF EXISTS transaction_type CASCADE;
DROP TYPE IF EXISTS location_type CASCADE;
DROP TYPE IF EXISTS user_role CASCADE;

DROP FUNCTION IF EXISTS update_stock_levels CASCADE;
DROP FUNCTION IF EXISTS get_user_company_id CASCADE;
DROP FUNCTION IF EXISTS get_user_role CASCADE;


-- ==========================================
-- Supabase Schema v2 for Mobile ERP & POS
-- ==========================================

-- 1. Enums
CREATE TYPE user_role AS ENUM ('admin', 'store_manager', 'cashier', 'warehouse_worker');
CREATE TYPE location_type AS ENUM ('warehouse', 'store');
CREATE TYPE transaction_type AS ENUM ('import', 'export', 'transfer_out', 'transfer_in', 'sale', 'adjustment');
CREATE TYPE task_status AS ENUM ('pending', 'in_progress', 'completed', 'cancelled');

-- 2. Companies (The root workspace)
CREATE TABLE companies (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 3. Profiles (Users linked to a company and role)
CREATE TABLE profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    company_id UUID REFERENCES companies(id) ON DELETE CASCADE NOT NULL,
    full_name TEXT NOT NULL,
    role user_role DEFAULT 'cashier'::user_role NOT NULL,
    phone_number TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 4. Locations (Warehouses and Stores)
CREATE TABLE locations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    company_id UUID REFERENCES companies(id) ON DELETE CASCADE NOT NULL,
    parent_id UUID REFERENCES locations(id) ON DELETE CASCADE, -- Link a store to a warehouse
    name TEXT NOT NULL,
    type location_type NOT NULL,
    address TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 5. Profile Locations (Which user can access which warehouse/store)
-- Admins can access all by default.
CREATE TABLE profile_locations (
    profile_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
    location_id UUID REFERENCES locations(id) ON DELETE CASCADE,
    PRIMARY KEY (profile_id, location_id)
);

-- 6. Categories
CREATE TABLE categories (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    company_id UUID REFERENCES companies(id) ON DELETE CASCADE NOT NULL,
    name TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 7. Products
CREATE TABLE products (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    company_id UUID REFERENCES companies(id) ON DELETE CASCADE NOT NULL,
    category_id UUID REFERENCES categories(id) ON DELETE SET NULL,
    name TEXT NOT NULL,
    description TEXT,
    purchase_price NUMERIC(10, 2) NOT NULL DEFAULT 0,
    sale_price NUMERIC(10, 2) NOT NULL DEFAULT 0,
    factory_barcode TEXT, -- The barcode printed by the manufacturer (can be scanned)
    generated_sku TEXT UNIQUE, -- Our internal auto-generated barcode
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 8. Stock Levels (Tracks quantity per location)
CREATE TABLE stock_levels (
    location_id UUID REFERENCES locations(id) ON DELETE CASCADE,
    product_id UUID REFERENCES products(id) ON DELETE CASCADE,
    quantity INTEGER NOT NULL DEFAULT 0,
    min_threshold INTEGER DEFAULT 5, -- Alert if stock goes below this
    last_updated TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
    PRIMARY KEY (location_id, product_id)
);

-- 9. External Entities (Suppliers / Delegates)
CREATE TABLE external_entities (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    company_id UUID REFERENCES companies(id) ON DELETE CASCADE NOT NULL,
    name TEXT NOT NULL,
    contact_info TEXT,
    type TEXT NOT NULL CHECK (type IN ('supplier', 'delegate', 'customer')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 10. Transactions (Imports, Exports, Sales, Transfers)
CREATE TABLE transactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    company_id UUID REFERENCES companies(id) ON DELETE CASCADE NOT NULL,
    location_id UUID REFERENCES locations(id) ON DELETE CASCADE NOT NULL,
    performed_by UUID REFERENCES profiles(id) ON DELETE SET NULL,
    external_entity_id UUID REFERENCES external_entities(id) ON DELETE SET NULL, -- Supplier for import, Customer/Delegate for sale
    type transaction_type NOT NULL,
    reference_id UUID, -- Useful for linking transfer_out to transfer_in, or linking items to an invoice
    status TEXT DEFAULT 'completed',
    total_amount NUMERIC(12, 2) DEFAULT 0, -- Set during sales
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 11. Transaction Items (The products in a transaction)
CREATE TABLE transaction_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    transaction_id UUID REFERENCES transactions(id) ON DELETE CASCADE NOT NULL,
    product_id UUID REFERENCES products(id) ON DELETE RESTRICT NOT NULL,
    quantity INTEGER NOT NULL,
    unit_price NUMERIC(10, 2) NOT NULL, -- The price at the time of transaction
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 12. Tasks
CREATE TABLE tasks (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    company_id UUID REFERENCES companies(id) ON DELETE CASCADE NOT NULL,
    assigned_to UUID REFERENCES profiles(id) ON DELETE SET NULL,
    title TEXT NOT NULL,
    description TEXT,
    status task_status DEFAULT 'pending'::task_status,
    due_date TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- ==========================================
-- Triggers for Automatic Stock Syncing
-- ==========================================

CREATE OR REPLACE FUNCTION update_stock_levels()
RETURNS TRIGGER AS $$
DECLARE
    loc_id UUID;
    trans_type transaction_type;
BEGIN
    -- Get the location and type from the parent transaction
    SELECT location_id, type INTO loc_id, trans_type FROM transactions WHERE id = NEW.transaction_id;

    -- Ensure a row exists in stock levels for this product at this location
    INSERT INTO stock_levels (location_id, product_id, quantity)
    VALUES (loc_id, NEW.product_id, 0)
    ON CONFLICT (location_id, product_id) DO NOTHING;

    -- Update stock based on transaction type
    IF trans_type = 'import' OR trans_type = 'transfer_in' THEN
        -- Increase Stock
        UPDATE stock_levels 
        SET quantity = quantity + NEW.quantity, last_updated = timezone('utc'::text, now())
        WHERE location_id = loc_id AND product_id = NEW.product_id;
        
    ELSIF trans_type = 'export' OR trans_type = 'transfer_out' OR trans_type = 'sale' THEN
        -- Decrease Stock
        UPDATE stock_levels 
        SET quantity = quantity - NEW.quantity, last_updated = timezone('utc'::text, now())
        WHERE location_id = loc_id AND product_id = NEW.product_id;
        
    ELSIF trans_type = 'adjustment' THEN
        -- Override Stock (NEW.quantity becomes the absolute value)
        UPDATE stock_levels 
        SET quantity = NEW.quantity, last_updated = timezone('utc'::text, now())
        WHERE location_id = loc_id AND product_id = NEW.product_id;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER trg_update_stock_on_transaction
AFTER INSERT ON transaction_items
FOR EACH ROW EXECUTE FUNCTION update_stock_levels();


-- ==========================================
-- Row Level Security (RLS) & Policies
-- ==========================================

-- Enable RLS
ALTER TABLE companies ENABLE ROW LEVEL SECURITY;
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE locations ENABLE ROW LEVEL SECURITY;
ALTER TABLE categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE products ENABLE ROW LEVEL SECURITY;
ALTER TABLE stock_levels ENABLE ROW LEVEL SECURITY;
ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE transaction_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE external_entities ENABLE ROW LEVEL SECURITY;
ALTER TABLE tasks ENABLE ROW LEVEL SECURITY;

-- Helper Function to get Current User's Company ID
CREATE OR REPLACE FUNCTION get_user_company_id()
RETURNS UUID AS $$
    SELECT company_id FROM profiles WHERE id = auth.uid() LIMIT 1;
$$ LANGUAGE sql SECURITY DEFINER;

-- Helper Function to get Current User's Role
CREATE OR REPLACE FUNCTION get_user_role()
RETURNS user_role AS $$
    SELECT role FROM profiles WHERE id = auth.uid() LIMIT 1;
$$ LANGUAGE sql SECURITY DEFINER;


-- 1. Company Policies
CREATE POLICY "Users can view their own company" ON companies FOR SELECT USING (id = get_user_company_id());

-- 2. Profiles
CREATE POLICY "Users can view company profiles" ON profiles FOR SELECT USING (company_id = get_user_company_id());
CREATE POLICY "Admins can insert profiles" ON profiles FOR INSERT WITH CHECK (get_user_role() = 'admin');

-- 3. Products & Categories
CREATE POLICY "Company-wide read Products" ON products FOR SELECT USING (company_id = get_user_company_id());
CREATE POLICY "Admin/Manager edit Products" ON products FOR ALL USING (
    company_id = get_user_company_id() AND get_user_role() IN ('admin', 'store_manager')
);

CREATE POLICY "Company-wide read Categories" ON categories FOR SELECT USING (company_id = get_user_company_id());
CREATE POLICY "Admin/Manager edit Categories" ON categories FOR ALL USING (
    company_id = get_user_company_id() AND get_user_role() IN ('admin', 'store_manager')
);

-- 4. Locations & Stock
CREATE POLICY "Company-wide read Locations" ON locations FOR SELECT USING (company_id = get_user_company_id());
CREATE POLICY "Admin/Manager edit Locations" ON locations FOR ALL USING (
    company_id = get_user_company_id() AND get_user_role() IN ('admin', 'store_manager')
);

CREATE POLICY "Company-wide read Stock" ON stock_levels FOR SELECT USING (
    EXISTS (SELECT 1 FROM locations l WHERE l.id = location_id AND l.company_id = get_user_company_id())
);
CREATE POLICY "Admin/Manager edit Stock" ON stock_levels FOR ALL USING (
    EXISTS (SELECT 1 FROM locations l WHERE l.id = location_id AND l.company_id = get_user_company_id())
    AND get_user_role() IN ('admin', 'store_manager')
);

-- 5. Transactions
CREATE POLICY "Company-wide read Transactions" ON transactions FOR SELECT USING (company_id = get_user_company_id());
CREATE POLICY "Insert Transactions via POS/App" ON transactions FOR INSERT WITH CHECK (company_id = get_user_company_id());

CREATE POLICY "Company-wide read Transaction Items" ON transaction_items FOR SELECT USING (
    EXISTS (SELECT 1 FROM transactions t WHERE t.id = transaction_id AND t.company_id = get_user_company_id())
);
CREATE POLICY "Insert Transaction Items via POS/App" ON transaction_items FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM transactions t WHERE t.id = transaction_id AND t.company_id = get_user_company_id())
);

-- 6. Tasks
CREATE POLICY "Users can read company tasks" ON tasks FOR SELECT USING (company_id = get_user_company_id());
CREATE POLICY "Users can update their tasks" ON tasks FOR UPDATE USING (assigned_to = auth.uid());
CREATE POLICY "Admins can manage all tasks" ON tasks FOR ALL USING (
    company_id = get_user_company_id() AND get_user_role() = 'admin'
);


-- ==========================================
-- ADMIN ACCOUNT SEED
-- ==========================================
-- 
-- STEP 1: Create the admin user via Supabase Auth Dashboard:
--   Email:    admin@befine.app
--   Password: (set your desired password)
--   After creation, copy the generated UUID from auth.users.
--
-- STEP 2: Replace 'PASTE_ADMIN_UUID_HERE' below with your admin's UUID, then run:

INSERT INTO companies (id, name)
VALUES ('00000000-0000-0000-0000-000000000001', 'Befine Company')
ON CONFLICT DO NOTHING;

INSERT INTO profiles (id, company_id, full_name, role, phone_number)
VALUES (
    'PASTE_ADMIN_UUID_HERE',                 -- ⚠️ UUID from auth.users
    '00000000-0000-0000-0000-000000000001',  -- Company ID above
    'المدير العام',                           -- Admin display name
    'admin',                                 -- Full admin role
    '+9647700000000'                         -- Phone number
)
ON CONFLICT (id) DO UPDATE
SET 
  full_name = EXCLUDED.full_name,
  role = EXCLUDED.role,
  phone_number = EXCLUDED.phone_number;
