## create_user_for_company

Supabase Edge Function to create a **supplier user** for the current company.

### What it does
- Validates the caller is authenticated and has `profiles.role = 'admin'`.
- Creates a new Auth user (Admin API).
- Inserts into `profiles` with `role = 'warehouse_worker'` under the caller's `company_id`.
- Assigns a single warehouse in `profile_locations`.

### Deploy (example)
From your Supabase project directory:

```bash
supabase functions deploy create_user_for_company
```

Ensure these secrets exist in your project:
- `SUPABASE_SERVICE_ROLE_KEY`
- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`

