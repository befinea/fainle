// Supabase Edge Function: create_user_for_company
// Creates an auth user + profile, and assigns one warehouse via profile_locations.
// Requires calling user to be an admin (profiles.role = 'admin').

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

type Payload = {
  email: string;
  password: string;
  full_name: string;
  phone_number?: string;
  warehouse_id: string;
};

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

function json(status: number, body: unknown) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  if (req.method !== "POST") return json(405, { error: "Method not allowed" });

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceRoleKey) {
    return json(500, { error: "Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY" });
  }

  const authHeader = req.headers.get("Authorization") ?? "";
  const callerClient = createClient(supabaseUrl, Deno.env.get("SUPABASE_ANON_KEY") ?? "", {
    global: { headers: { Authorization: authHeader } },
  });

  const adminClient = createClient(supabaseUrl, serviceRoleKey);

  // Verify caller is authenticated and is admin in profiles
  const { data: caller, error: callerErr } = await callerClient.auth.getUser();
  if (callerErr || !caller?.user) return json(401, { error: "Unauthorized" });

  const { data: callerProfile, error: profErr } = await callerClient
    .from("profiles")
    .select("company_id, role")
    .eq("id", caller.user.id)
    .single();

  if (profErr) return json(403, { error: `Cannot read caller profile: ${profErr.message}` });
  if (callerProfile.role !== "admin") return json(403, { error: "Only admin can create supplier users" });

  let payload: Payload;
  try {
    payload = await req.json();
  } catch {
    return json(400, { error: "Invalid JSON body" });
  }

  const email = (payload.email ?? "").trim().toLowerCase();
  const password = payload.password ?? "";
  const full_name = (payload.full_name ?? "").trim();
  const phone_number = (payload.phone_number ?? "").trim();
  const warehouse_id = payload.warehouse_id;

  if (!email || !email.includes("@")) return json(400, { error: "Invalid email" });
  if (!password || password.length < 6) return json(400, { error: "Password must be at least 6 chars" });
  if (!full_name) return json(400, { error: "full_name is required" });
  if (!warehouse_id) return json(400, { error: "warehouse_id is required" });

  // Create Auth user
  const { data: created, error: createErr } = await adminClient.auth.admin.createUser({
    email,
    password,
    email_confirm: true,
  });
  if (createErr || !created.user) return json(400, { error: createErr?.message ?? "Failed to create user" });

  const newUserId = created.user.id;

  // Insert profile
  const { error: insertProfileErr } = await adminClient.from("profiles").insert({
    id: newUserId,
    company_id: callerProfile.company_id,
    full_name,
    role: "supplier",
    phone_number: phone_number || null,
  });
  if (insertProfileErr) {
    return json(400, { error: `Failed to insert profile: ${insertProfileErr.message}` });
  }

  // Assign warehouse via profile_locations (single warehouse)
  const { error: deleteErr } = await adminClient.from("profile_locations").delete().eq("profile_id", newUserId);
  if (deleteErr) {
    return json(400, { error: `Failed to clear locations: ${deleteErr.message}` });
  }

  const { error: assignErr } = await adminClient.from("profile_locations").insert({
    profile_id: newUserId,
    location_id: warehouse_id,
  });
  if (assignErr) {
    return json(400, { error: `Failed to assign warehouse: ${assignErr.message}` });
  }

  return json(200, { ok: true, user_id: newUserId });
});

