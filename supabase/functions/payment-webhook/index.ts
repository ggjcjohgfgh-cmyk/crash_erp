// Deploy: supabase functions deploy payment-webhook --no-verify-jwt
// Stripe endpoint : https://<ref>.functions.supabase.co/payment-webhook?gateway=stripe   (secret: STRIPE_WEBHOOK_SECRET)
// Paymob callback : https://<ref>.functions.supabase.co/payment-webhook?gateway=paymob   (secret: PAYMOB_HMAC)
import { activate, hmac } from "../_shared/common.ts";

const ok = () => new Response("ok");
const bad = (m: string, s = 400) => new Response(m, { status: s });

Deno.serve(async (req) => {
  const url = new URL(req.url);
  const gateway = url.searchParams.get("gateway");
  const raw = await req.text();

  if (gateway === "stripe") {
    const sig = req.headers.get("stripe-signature") ?? "";
    const t = /t=(\d+)/.exec(sig)?.[1];
    const v1 = /v1=([a-f0-9]+)/.exec(sig)?.[1];
    if (!t || !v1) return bad("no signature");
    const expected = await hmac("SHA-256", Deno.env.get("STRIPE_WEBHOOK_SECRET")!, `${t}.${raw}`);
    if (expected !== v1) return bad("invalid signature", 401);
    const ev = JSON.parse(raw);
    if (ev.type === "checkout.session.completed" && ev.data.object.payment_status === "paid") {
      const o = ev.data.object;
      await activate(o.metadata.org_id, o.metadata.plan, "stripe", o.id);
    }
    return ok();
  }

  if (gateway === "paymob") {
    const body = JSON.parse(raw);
    const o = body.obj;
    const get = (path: string) => path.split(".").reduce((a: any, k) => a?.[k], o);
    const fields = ["amount_cents", "created_at", "currency", "error_occured", "has_parent_transaction", "id", "integration_id",
      "is_3d_secure", "is_auth", "is_capture", "is_refunded", "is_standalone_payment", "is_voided", "order.id", "owner", "pending",
      "source_data.pan", "source_data.sub_type", "source_data.type", "success"];
    const concat = fields.map((f) => String(get(f))).join("");
    const expected = await hmac("SHA-512", Deno.env.get("PAYMOB_HMAC")!, concat);
    if (expected !== url.searchParams.get("hmac")) return bad("invalid hmac", 401);
    if (o.success === true && o.pending === false) {
      const [orgId, plan] = String(o.order.merchant_order_id).split("|");
      await activate(orgId, plan, "paymob", String(o.id));
    }
    return ok();
  }
  return bad("unknown gateway");
});
