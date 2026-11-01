import type pg from "pg";
import { type Check, fail, flag, id, reporting, shape, text, time } from "./transcripts.ts";

type Status = "unprocessed" | "unverified" | "active" | "parked" | "done" | "removed";

export type Order = { version: 1; id: string } & (
  | { kind: "capture"; text: string }
  | { kind: "complete"; taskID: string; expectedStatus: Status; expectedDueDate?: string }
  | { kind: "setDue"; taskID: string; hasTime: boolean; date?: string; expectedDueDate?: string }
);

export type OrderResult = {
  orderID: string;
  outcome: "done" | "rejected";
  reason?: "invalid" | "missing" | "stale";
  taskID?: string;
};

const oneOf = (values: string[], reason: string): Check => {
  const allowed = new Set(values);
  return (v, p) => { if (typeof v !== "string" || !allowed.has(v)) fail(p, reason); };
};

// All six statuses of the app: the service checks form, not meaning, so done and removed pass (the app answers invalid).
export const orderStatus = oneOf(["unprocessed", "unverified", "active", "parked", "done", "removed"], "unbekannter Status");
const version: Check = (v, p) => { if (v !== 1) fail(p, "nicht 1"); };
const outcome = oneOf(["done", "rejected"], "unbekanntes Ergebnis");
const reason = oneOf(["invalid", "missing", "stale"], "unbekannter Grund");

// Per kind: required and optional keys beside version, id and kind.
const forms: Record<string, [Record<string, Check>, Record<string, Check>]> = {
  capture: [{ text }, {}],
  complete: [{ taskID: id, expectedStatus: orderStatus }, { expectedDueDate: time }],
  setDue: [{ taskID: id, hasTime: flag }, { date: time, expectedDueDate: time }],
};
const kind: Check = (v, p) => { if (typeof v !== "string" || !Object.hasOwn(forms, v)) fail(p, "unbekannte Art"); };
// With an unknown kind every key of some kind is let through, so the message names kind and not a key.
const anyKey: Record<string, Check> = Object.fromEntries(
  Object.values(forms).flatMap(([required, optional]) => Object.keys({ ...required, ...optional })).map((key) => [key, () => {}]),
);
const field = (doc: unknown, key: string): unknown =>
  typeof doc === "object" && doc !== null && !Array.isArray(doc) ? (doc as Record<string, unknown>)[key] : undefined;

export function checkOrder(doc: unknown): asserts doc is Order {
  reporting("Auftrag", () => {
    const named = field(doc, "kind");
    const [required, optional] = typeof named === "string" && Object.hasOwn(forms, named) ? forms[named] : [{}, anyKey];
    shape(doc, "", { version, id, kind, ...required }, optional);
  });
}

// reason exactly with rejected; with an unknown outcome it is only checked, so the message names outcome.
export function checkResult(doc: unknown): asserts doc is OrderResult {
  reporting("Ergebnis", () => {
    const named = field(doc, "outcome");
    const required: Record<string, Check> = named === "rejected" ? { reason } : {};
    const optional: Record<string, Check> = named === "done" || named === "rejected" ? { taskID: id } : { taskID: id, reason };
    shape(doc, "", { orderID: id, outcome, ...required }, optional);
  });
}

// One statement: a new order is stored, a known id (any case) leaves the row as it is, claimed or not.
export async function putOrder(pool: pg.Pool, account: string, doc: unknown): Promise<"stored" | "duplicate"> {
  checkOrder(doc);
  const result = await pool.query(
    "INSERT INTO orders (doc, account_id) VALUES ($1::jsonb, $2) ON CONFLICT (id) DO NOTHING RETURNING id",
    [JSON.stringify(doc), account],
  );
  return result.rowCount === 1 ? "stored" : "duplicate";
}

// One statement: the next free order of the account goes to exactly one device. Exactly once, no promised order.
export async function claimOrder(pool: pg.Pool, account: string, device: string): Promise<Order | undefined> {
  const result = await pool.query(
    `UPDATE orders SET claimed_by = $2, claimed_at = now()
     WHERE id = (SELECT id FROM orders WHERE account_id = $1 AND claimed_by IS NULL ORDER BY created_at, id FOR UPDATE SKIP LOCKED LIMIT 1)
       AND claimed_by IS NULL
     RETURNING doc`,
    [account, device],
  );
  return result.rows[0]?.doc;
}

// The result is taken only from the device that holds the order; a second one changes nothing.
export async function putResult(pool: pg.Pool, account: string, device: string, doc: unknown): Promise<"stored" | "duplicate" | "refused"> {
  checkResult(doc);
  const json = JSON.stringify(doc);
  const result = await pool.query(
    `INSERT INTO order_results (doc, reported_by) SELECT $1::jsonb, $3
     WHERE EXISTS (SELECT 1 FROM orders WHERE id = ($1::jsonb->>'orderID')::uuid AND account_id = $2 AND claimed_by = $3)
     ON CONFLICT (order_id) DO NOTHING RETURNING order_id`,
    [json, account, device],
  );
  if (result.rowCount === 1) return "stored";
  const known = await pool.query(
    `SELECT 1 FROM order_results r JOIN orders o ON o.id = r.order_id
     WHERE r.order_id = $1::uuid AND o.account_id = $2 AND r.reported_by = $3`,
    [doc.orderID, account, device],
  );
  return known.rowCount === 1 ? "duplicate" : "refused";
}
