// Read-only: calls the live service code's get_view/get_now for the one account and compares with the transcript's own lists.
// Prints counts and booleans only, never a title or id.
import pg from "pg";
const { mcpHandler } = await import("/app/src/mcp.ts");
const pool = new pg.Pool({ connectionString: process.env.DATABASE_URL });
const { rows: accts } = await pool.query("select account_id, doc from transcripts");
if (accts.length !== 1) { console.log("transcripts", accts.length); process.exit(1); }
const account = accts[0].account_id, doc = accts[0].doc;
const handler = mcpHandler(pool);
const authInfo = { token: "check", clientId: "check", scopes: [], extra: { account } };
let n = 0;
async function rpc(method, params) {
  const res = await handler.fetch(new Request("http://check/mcp", { method: "POST",
    headers: { "content-type": "application/json", accept: "application/json, text/event-stream", "mcp-protocol-version": "2025-06-18" },
    body: JSON.stringify({ jsonrpc: "2.0", id: ++n, method, params }) }), { authInfo });
  const text = await res.text();
  const line = text.split("\n").find((l) => l.startsWith("data:"));
  return JSON.parse(line ? line.slice(5) : text);
}
await rpc("initialize", { protocolVersion: "2025-06-18", capabilities: {}, clientInfo: { name: "check", version: "1" } });
const tool = async (name, args = {}) => {
  const r = await rpc("tools/call", { name, arguments: args });
  if (r.error || r.result.isError) throw new Error(name + " " + JSON.stringify(r.error ?? r.result.content));
  return JSON.parse(r.result.content[0].text);
};
const out = { generatedAt: doc.generatedAt, tasks: doc.tasks.length, nowCountApp: doc.nowCount };
const appNow = [...(doc.now.knaeuel ? [doc.now.knaeuel] : []), ...doc.now.today, ...doc.now.lined, ...doc.now.waiting];
const gn = await tool("get_now");
const vnow = await tool("get_view", { view: "now" });
const same = (a, b) => JSON.stringify(a) === JSON.stringify(b);
out.now = { appRows: appNow.length, getNowRows: gn.rows.length, getViewRows: vnow.count, nowCountTool: vnow.nowCount,
  sameOrder: same(vnow.rows.map((r) => r.id), appNow) && same(gn.rows.map((r) => r.id), appNow),
  sameGeneratedAt: vnow.generatedAt === doc.generatedAt };
const ids = new Set(doc.tasks.map((t) => t.id));
for (const v of ["due", "next", "open"]) {
  const r = await tool("get_view", { view: v });
  out[v] = { appRows: doc.views[v].length, getViewRows: r.count, missingInTasks: doc.views[v].filter((id) => !ids.has(id)).length,
    sameOrder: same(r.rows.map((x) => x.id), doc.views[v]) };
}
console.log(JSON.stringify(out, null, 1));
await handler.close?.();
await pool.end();
