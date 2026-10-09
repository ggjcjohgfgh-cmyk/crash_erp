// Deploy: supabase functions deploy create-payment
// Secrets: STRIPE_SECRET_KEY, PAYMOB_API_KEY, PAYMOB_INTEGRATION_ID, PAYMOB_IFRAME_ID, RETURN_URL
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { PLANS, cors } from "../_shared/common.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  const json = (b: unknown, s = 200) => new Response(JSON.stringify(b), { status: s, headers: { ...cors, "Content-Type": "application/json" } });
  try {
    const { plan, gateway } = await req.json();
    const p = PLANS[plan];
    if (!p) return json({ error: "invalid plan" }, 400);

    // identify the caller and its organization from the JWT
    const userClient = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_ANON_KEY")!, {
      global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } },
    });
    const { data: u } = await userClient.auth.getUser();
    if (!u.user) return json({ error: "unauthorized" }, 401);
    const { data: m } = await userClient.from("org_members").select("org_id, role").eq("user_id", u.user.id).maybeSingle();
    if (!m || m.role !== "admin") return json({ error: "only admin can subscribe" }, 403);

    const ret = Deno.env.get("RETURN_URL") ?? "https://example.com/paid";
    const cents = p.price * 100;

    if (gateway === "stripe") {
      const body = new URLSearchParams({
        mode: "payment", success_url: ret, cancel_url: ret, client_reference_id: m.org_id,
        "line_items[0][quantity]": "1", "line_items[0][price_data][currency]": "egp",
        "line_items[0][price_data][unit_amount]": String(cents), "line_items[0][price_data][product_data][name]": p.name,
        "metadata[org_id]": m.org_id, "metadata[plan]": plan,
      });
      const r = await fetch("https://api.stripe.com/v1/checkout/sessions", {
        method: "POST", body,
        headers: { Authorization: `Bearer ${Deno.env.get("STRIPE_SECRET_KEY")}`, "Content-Type": "application/x-www-form-urlencoded" },
      });
      const d = await r.json();
      if (!d.url) return json({ error: d.error?.message ?? "stripe error" }, 502);
      return json({ url: d.url });
    }

    if (gateway === "paymob") {
      const post = (url: string, b: unknown) => fetch(url, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(b) }).then((x) => x.json());
      const { token } = await post("https://accept.paymob.com/api/auth/tokens", { api_key: Deno.env.get("PAYMOB_API_KEY") });
      const order = await post("https://accept.paymob.com/api/ecommerce/orders", {
        auth_token: token, delivery_needed: false, amount_cents: cents, currency: "EGP", items: [],
        merchant_order_id: `${m.org_id}|${plan}|${Date.now()}`,
      });
      const pk = await post("https://accept.paymob.com/api/acceptance/payment_keys", {
        auth_token: token, amount_cents: cents, expiration: 3600, order_id: order.id, currency: "EGP",
        integration_id: Number(Deno.env.get("PAYMOB_INTEGRATION_ID")),
        billing_data: {
          apartment: "NA", email: u.user.email ?? "na@na.com", floor: "NA", first_name: "Crash", street: "NA", building: "NA",
          phone_number: "+201000000000", shipping_method: "NA", postal_code: "NA", city: "Cairo", country: "EG", last_name: "ERP", state: "NA",
        },
      });
      if (!pk.token) return json({ error: "paymob error", details: pk }, 502);
      return json({ url: `https://accept.paymob.com/api/acceptance/iframes/${Deno.env.get("PAYMOB_IFRAME_ID")}?payment_token=${pk.token}` });
    }

    if (gateway === "fawry") {
      // Fawry needs merchant-specific signature/checkout settings: complete this after you get merchantCode + secureKey
      // and follow the current FawryPay docs, then return { url } the same way as above.
      return json({ error: "Fawry is not configured yet" }, 501);
    }
    return json({ error: "unknown gateway" }, 400);
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
