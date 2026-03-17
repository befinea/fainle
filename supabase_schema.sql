-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Define Enums
CREATE TYPE user_role AS ENUM ('super_admin', 'owner', 'staff', 'customer');
CREATE TYPE inventory_change_type AS ENUM ('in', 'out');
CREATE TYPE order_status AS ENUM ('pending', 'processing', 'completed', 'cancelled');

-- 1. stores
CREATE TABLE public.stores (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    slug TEXT UNIQUE NOT NULL,
    logo_url TEXT,
    settings JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. profiles
CREATE TABLE public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    full_name TEXT NOT NULL,
    role user_role NOT NULL DEFAULT 'customer',
    store_id UUID REFERENCES public.stores(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. products
CREATE TABLE public.products (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    store_id UUID NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    barcode_data TEXT,
    sku TEXT,
    price NUMERIC(10, 2) NOT NULL DEFAULT 0.00,
    stock_qty INTEGER NOT NULL DEFAULT 0,
    images TEXT[] DEFAULT '{}',
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. inventory_logs
CREATE TABLE public.inventory_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    product_id UUID NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
    change_type inventory_change_type NOT NULL,
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    performed_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 5. orders
CREATE TABLE public.orders (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    customer_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    store_id UUID NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
    total_amount NUMERIC(10, 2) NOT NULL DEFAULT 0.00,
    status order_status NOT NULL DEFAULT 'pending',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 6. order_items (Core necessity to map orders to products to trigger stock deductions)
CREATE TABLE public.order_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    order_id UUID NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES public.products(id) ON DELETE RESTRICT,
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    price NUMERIC(10, 2) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- -----------------------------------------------------
-- ROW LEVEL SECURITY (RLS)
-- -----------------------------------------------------

ALTER TABLE public.stores ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.inventory_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_items ENABLE ROW LEVEL SECURITY;

-- Utility Secure Functions for Role & Store checks (Optimized for RLS)
CREATE OR REPLACE FUNCTION public.get_user_role() RETURNS user_role AS $$
    SELECT role FROM public.profiles WHERE id = auth.uid() LIMIT 1;
$$ LANGUAGE sql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.get_user_store_id() RETURNS UUID AS $$
    SELECT store_id FROM public.profiles WHERE id = auth.uid() LIMIT 1;
$$ LANGUAGE sql SECURITY DEFINER;

-- STORES RLS
CREATE POLICY "Public can view all stores" 
ON public.stores FOR SELECT USING (true);

-- PROFILES RLS
CREATE POLICY "Users can view their own profile" 
ON public.profiles FOR SELECT USING (id = auth.uid());

CREATE POLICY "Owners/Staff can view profiles in their store" 
ON public.profiles FOR SELECT USING (
    store_id = public.get_user_store_id() 
    AND public.get_user_role() IN ('owner', 'staff')
);

-- PRODUCTS RLS
CREATE POLICY "Customers can view active products" 
ON public.products FOR SELECT USING (is_active = true);

CREATE POLICY "Owners/Staff can manage store products" 
ON public.products FOR ALL USING (
    store_id = public.get_user_store_id() 
    AND public.get_user_role() IN ('owner', 'staff')
);

-- INVENTORY LOGS RLS
CREATE POLICY "Owners/Staff can manage store inventory logs" 
ON public.inventory_logs FOR ALL USING (
    EXISTS (
        SELECT 1 FROM public.products p 
        WHERE p.id = public.inventory_logs.product_id 
        AND p.store_id = public.get_user_store_id()
    )
    AND public.get_user_role() IN ('owner', 'staff')
);

-- ORDERS RLS
CREATE POLICY "Customers can view own orders" 
ON public.orders FOR SELECT USING (customer_id = auth.uid());

CREATE POLICY "Customers can insert own orders" 
ON public.orders FOR INSERT WITH CHECK (customer_id = auth.uid());

CREATE POLICY "Owners/Staff can manage store orders" 
ON public.orders FOR ALL USING (
    store_id = public.get_user_store_id() 
    AND public.get_user_role() IN ('owner', 'staff')
);

-- ORDER ITEMS RLS
CREATE POLICY "Customers can view own order items" 
ON public.order_items FOR SELECT USING (
    EXISTS (
        SELECT 1 FROM public.orders o 
        WHERE o.id = public.order_items.order_id 
        AND o.customer_id = auth.uid()
    )
);

CREATE POLICY "Customers can insert own order items" 
ON public.order_items FOR INSERT WITH CHECK (
    EXISTS (
        SELECT 1 FROM public.orders o 
        WHERE o.id = public.order_items.order_id 
        AND o.customer_id = auth.uid()
    )
);

CREATE POLICY "Owners/Staff can manage store order items" 
ON public.order_items FOR ALL USING (
    EXISTS (
        SELECT 1 FROM public.orders o 
        WHERE o.id = public.order_items.order_id 
        AND o.store_id = public.get_user_store_id()
    )
    AND public.get_user_role() IN ('owner', 'staff')
);

-- -----------------------------------------------------
-- TRIGGERS / AUTOMATION
-- -----------------------------------------------------

-- Trigger 1: Update product.stock_qty from manual inventory_logs
CREATE OR REPLACE FUNCTION update_stock_from_inventory() RETURNS TRIGGER AS $$
BEGIN
    IF NEW.change_type = 'in' THEN
        UPDATE public.products 
        SET stock_qty = stock_qty + NEW.quantity 
        WHERE id = NEW.product_id;
    ELSIF NEW.change_type = 'out' THEN
        UPDATE public.products 
        SET stock_qty = stock_qty - NEW.quantity 
        WHERE id = NEW.product_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_inventory_update_stock
AFTER INSERT ON public.inventory_logs
FOR EACH ROW EXECUTE FUNCTION update_stock_from_inventory();

-- Trigger 2: Deduct product.stock_qty when an order_item is created
CREATE OR REPLACE FUNCTION deduct_stock_on_order() RETURNS TRIGGER AS $$
BEGIN
    UPDATE public.products 
    SET stock_qty = stock_qty - NEW.quantity 
    WHERE id = NEW.product_id;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_order_deduct_stock
AFTER INSERT ON public.order_items
FOR EACH ROW EXECUTE FUNCTION deduct_stock_on_order();
