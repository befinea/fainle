-- 1. Add email column
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS email TEXT;

-- 2. Backfill existing profile emails from auth.users
UPDATE profiles
SET email = auth.users.email
FROM auth.users
WHERE profiles.id = auth.users.id;
