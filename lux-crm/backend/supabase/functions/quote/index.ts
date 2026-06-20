// Customer-facing quote portal.
//   GET  /quote?token=<public_token>   → renders the quote with Accept / Request
//                                         changes / Decline buttons
//   POST /quote  (form: token, action) → records the customer's choice; on accept
//                                         calls accept_quote() to create the job
//                                         + invoice + storage.
//
// Deployed as a Supabase Edge Function. Uses the service role key (auto-injected)
// so it can read/update across the org safely, gated only by the secret token.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

const esc = (s: unknown) =>
  String(s ?? "").replace(/[&<>"']/g, (c) =>
    ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]!));

const money = (n: number) =>
  new Intl.NumberFormat("en-US", { style: "currency", currency: "USD" }).format(n || 0);

function page(title: string, body: string): Response {
  const html = `<!doctype html><html><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${esc(title)}</title>
<style>
  :root{color-scheme:light}
  body{font-family:-apple-system,system-ui,Segoe UI,Roboto,sans-serif;margin:0;background:#0b3d2e;color:#111}
  .wrap{max-width:640px;margin:0 auto;padding:16px}
  .card{background:#fff;border-radius:16px;padding:20px;margin-top:16px;box-shadow:0 6px 24px rgba(0,0,0,.15)}
  h1{font-size:20px;margin:0 0 4px} .muted{color:#667085;font-size:14px}
  table{width:100%;border-collapse:collapse;margin:12px 0}
  td{padding:8px 0;border-bottom:1px solid #eee;font-size:14px;vertical-align:top}
  td.r{text-align:right;white-space:nowrap}
  .tot{display:flex;justify-content:space-between;font-weight:700;font-size:18px;margin-top:8px}
  .dep{display:flex;justify-content:space-between;color:#0b6b3a;font-weight:600;margin-top:4px}
  .btn{display:block;width:100%;box-sizing:border-box;text-align:center;padding:14px;border-radius:12px;
       font-size:16px;font-weight:600;border:0;margin-top:10px;cursor:pointer}
  .accept{background:#0b6b3a;color:#fff} .secondary{background:#eef2f1;color:#0b3d2e}
  .decline{background:#fff;color:#b42318;border:1px solid #f1c0bb}
  textarea{width:100%;box-sizing:border-box;border:1px solid #d0d5dd;border-radius:10px;padding:10px;font-size:15px}
  .logo{color:#fff;font-weight:700;font-size:15px;letter-spacing:.04em}
</style></head>
<body><div class="wrap"><div class="logo">LUX LIGHTING SERVICES</div>${body}</div></body></html>`;
  return new Response(html, { headers: { "content-type": "text/html; charset=utf-8" } });
}

async function loadQuote(token: string) {
  const { data: quote } = await supabase.from("quotes").select("*").eq("public_token", token).single();
  if (!quote) return null;
  const { data: items } = await supabase.from("quote_line_items").select("*")
    .eq("quote_id", quote.id).order("sort");
  const { data: client } = await supabase.from("clients").select("name")
    .eq("id", quote.client_id).single();
  return { quote, items: items ?? [], client };
}

function renderQuote(token: string, q: any, items: any[], clientName: string): Response {
  const rows = items.map((it) => {
    const detail = [it.light_type, it.color, it.spacing].filter((x) => x && x !== "None").join(" · ");
    return `<tr><td><b>${esc(it.description)}</b>${detail ? `<br><span class="muted">${esc(detail)}</span>` : ""}
      <br><span class="muted">${esc(it.quantity)} ${esc(it.unit ?? "")} × ${money(it.unit_price)}</span></td>
      <td class="r">${money(it.quantity * it.unit_price)}</td></tr>`;
  }).join("");

  const deposit = Number(q.deposit_amount || 0);
  const decided = ["approved", "declined"].includes(q.status);

  const actions = decided
    ? `<div class="card"><b>${q.status === "approved" ? "Thank you! Your quote is accepted." : "This quote has been declined."}</b></div>`
    : `<form method="post" class="card">
        <input type="hidden" name="token" value="${esc(token)}">
        <button class="btn accept" name="action" value="accept">Accept this quote${deposit > 0 ? ` — deposit ${money(deposit)}` : ""}</button>
        <details style="margin-top:12px"><summary class="muted">Request a change</summary>
          <textarea name="note" rows="3" placeholder="What would you like changed?"></textarea>
          <button class="btn secondary" name="action" value="changes">Send change request</button>
        </details>
        <button class="btn decline" name="action" value="decline">No thanks, decline</button>
      </form>`;

  return page(`Quote ${q.number}`, `
    <div class="card">
      <h1>Quote ${esc(q.number)}</h1>
      <div class="muted">${esc(clientName)}</div>
      <table>${rows}</table>
      <div class="tot"><span>Total</span><span>${money(q.total)}</span></div>
      ${deposit > 0 ? `<div class="dep"><span>Deposit to reserve</span><span>${money(deposit)}</span></div>` : ""}
    </div>
    ${actions}`);
}

Deno.serve(async (req) => {
  try {
    if (req.method === "GET") {
      const token = new URL(req.url).searchParams.get("token") ?? "";
      const data = await loadQuote(token);
      if (!data) return page("Not found", `<div class="card">Sorry, this quote link is invalid.</div>`);
      return renderQuote(token, data.quote, data.items, data.client?.name ?? "");
    }

    if (req.method === "POST") {
      const form = await req.formData();
      const token = String(form.get("token") ?? "");
      const action = String(form.get("action") ?? "");
      const note = String(form.get("note") ?? "");
      const data = await loadQuote(token);
      if (!data) return page("Not found", `<div class="card">Invalid quote link.</div>`);
      const q = data.quote;

      if (action === "accept") {
        await supabase.rpc("accept_quote", { p_quote: q.id });
        return page("Accepted", `<div class="card"><h1>You're all set 🎉</h1>
          <p>Thanks for accepting quote ${esc(q.number)}. LUX Lighting Services will be in touch to schedule your install${Number(q.deposit_amount || 0) > 0 ? `, and about the ${money(q.deposit_amount)} deposit` : ""}.</p></div>`);
      }
      if (action === "changes") {
        await supabase.from("quotes").update({ status: "changes_requested", customer_note: note }).eq("id", q.id);
        return page("Thanks", `<div class="card"><h1>Got it</h1><p>We'll review your requested changes and follow up.</p></div>`);
      }
      if (action === "decline") {
        await supabase.from("quotes").update({ status: "declined" }).eq("id", q.id);
        return page("Declined", `<div class="card"><p>No problem — thanks for considering us.</p></div>`);
      }
      return page("Quote", `<div class="card">Unknown action.</div>`);
    }

    return new Response("Method not allowed", { status: 405 });
  } catch (e) {
    return page("Error", `<div class="card">Something went wrong. Please contact LUX Lighting Services.</div>`);
  }
});
