import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// price in piasters (EGP * 100) and subscription length
export const PLANS: Record<string, { name: string; price: number }> = {
  starter: { name: "Crash ERP Starter", price: 199 },
  business: { name: "Crash ERP Business", price: 499 },
  enterprise: { name: "Crash ERP Enterprise", price: 999 },
};

export const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

export const admin = () =>
  createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);

/** Extends (or starts) a 30-day subscription for an organization. */
export async function activate(orgId: string, plan: string, gateway: string, ref: string) {
  const db = admin();
  const { data: cur } = await db.from("subscriptions").select("expires_at, last_payment_ref").eq("org_id", orgId).maybeSingle();
  if (cur?.last_payment_ref === ref) return; // idempotent: same payment delivered twice
  const base = cur?.expires_at && new Date(cur.expires_at) > new Date() ? new Date(cur.expires_at) : new Date();
  base.setDate(base.getDate() + 30);
  await db.from("subscriptions").upsert({
    org_id: orgId, plan, expires_at: base.toISOString(), gateway, last_payment_ref: ref, updated_at: new Date().toISOString(),
  });
}

export const hex = (buf: ArrayBuffer) => [...new Uint8Array(buf)].map((b) => b.toString(16).padStart(2, "0")).join("");

export async function hmac(algo: "SHA-256" | "SHA-512", key: string, data: string) {
  const k = await crypto.subtle.importKey("raw", new TextEncoder().encode(key), { name: "HMAC", hash: algo }, false, ["sign"]);
  return hex(await crypto.subtle.sign("HMAC", k, new TextEncoder().encode(data)));
}
