# Supabase Schema Architecture: Multi-tenant SaaS E-Commerce

This architecture outlines the database design for a multi-tenant Warehouse Management & SaaS E-commerce system built directly on Supabase PostgreSQL.

## 1. Table Relations (ERD Map)

- **`stores`**: The core tenant.
  - `stores.id` <---`profiles.store_id` (1:N)
  - `stores.id` <---`products.store_id` (1:N)
  - `stores.id` <---`orders.store_id` (1:N)
- **`profiles`**: Extends Supabase Auth (`auth.users`).
  - `profiles.id` <---`inventory_logs.performed_by` (1:N)
  - `profiles.id` <---`orders.customer_id` (1:N)
- **`products`**: The catalog belonging to a specific store.
  - `products.id` <---`inventory_logs.product_id` (1:N)
  - `products.id` <---`order_items.product_id` (1:N)
- **`orders` & `order_items`**: The transactional records.
  - `orders.id` <---`order_items.order_id` (1:N)

> **Note**: An `order_items` table was introduced to safely map individual products to an order. This is required to properly automate the deduction of `products.stock_qty`.

## 2. Row Level Security (RLS) Strategy

Row Level Security is enabled on all tables to enforce strict multi-tenant boundaries.

### Helper Functions
To avoid infinite recursion when querying the `profiles` table within a policy, two lightweight `SECURITY DEFINER` functions were added:
- `get_user_role()`: Returns the enum role of the currently authenticated user.
- `get_user_store_id()`: Returns the store ID of the currently authenticated user.

### Policies Enforced:
* **Stores**: Publicly readable (so customers can see store names/logos).
* **Profiles**: Users can read their own profiles. Store Owners/Staff can read all profiles assigned to their store.
* **Products**: Customers can only view active products (`is_active = true`). Owners/Staff have full CRUD access to products belonging to their store.
* **Inventory Logs**: Owners/Staff have full CRUD access to logs for products belonging to their store. Customers have no access.
* **Orders & Order Items**: Customers can insert and read their own orders. Owners/Staff have full CRUD access to all orders within their store.

## 3. Automation (PostgreSQL Triggers)

The schema relies on database-level triggers to guarantee data integrity without complex server-side code:

1. **`trg_inventory_update_stock`**:
   - Fires **AFTER INSERT** on `inventory_logs`.
   - Checks the `change_type` enum (`in` or `out`).
   - Automatically adds or subtracts the requested `quantity` from the parent `products.stock_qty`.
2. **`trg_order_deduct_stock`**:
   - Fires **AFTER INSERT** on `order_items`.
   - Automatically deducts the `quantity` ordered from the parent `products.stock_qty`.
