-- Adding missing permissions for Locations (Warehouses & Stores)
CREATE POLICY "Admin/Manager edit Locations" ON locations FOR ALL USING (
    company_id = get_user_company_id() AND get_user_role() IN ('admin', 'store_manager')
);

-- Adding missing permissions for Stock Levels
CREATE POLICY "Admin/Manager edit Stock" ON stock_levels FOR ALL USING (
    EXISTS (SELECT 1 FROM locations l WHERE l.id = location_id AND l.company_id = get_user_company_id())
    AND get_user_role() IN ('admin', 'store_manager')
);
