import type pg from "pg";

export type TranscriptTask = {
  id: string;
  title: string;
  status: "unprocessed" | "unverified" | "active" | "parked";
  dueDate?: string;
  dueHasTime: boolean;
  contexts: string[];
  project?: string;
  nextRank?: number;
  isKnaeuel: boolean;
};

export type Transcript = {
  version: 1;
  generatedAt: string;
  nowCount: number;
  now: { knaeuel?: string; today: string[]; lined: string[]; waiting: string[] };
  tasks: TranscriptTask[];
};

type Check = (value: unknown, path: string) => void;

const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const iso = /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(?:\.\d+)?(?:Z|[+-](\d{2}):(\d{2}))$/;
const statuses = new Set(["unprocessed", "unverified", "active", "parked"]);

// A form deviation names only path and reason; reporting() puts the subject in front.
export class FormError extends Error {}

function fail(path: string, reason: string): never {
  throw new FormError(`${path}: ${reason}`);
}

// Runs a form check and names its subject ("Abschrift", "Auftrag", "Ergebnis"); any other error passes untouched.
export function reporting<T>(subject: string, run: () => T): T {
  try {
    return run();
  } catch (error) {
    if (error instanceof FormError) throw new Error(`${subject} ungültig: ${error.message}`);
    throw error;
  }
}

const isObject = (value: unknown): value is Record<string, unknown> =>
  typeof value === "object" && value !== null && !Array.isArray(value);
const count = (value: unknown) => Number.isInteger(value) && (value as number) >= 0;

const clean = (s: string) => !s.includes("\u0000") && s.isWellFormed();
const text: Check = (v, p) => {
  if (typeof v !== "string") fail(p, "kein Text");
  if (!clean(v)) fail(p, "ungültiges Zeichen");
};
const flag: Check = (v, p) => { if (typeof v !== "boolean") fail(p, "kein Wahrheitswert"); };
const id: Check = (v, p) => { if (typeof v !== "string" || !uuid.test(v)) fail(p, "keine UUID"); };
const rank: Check = (v, p) => { if (!count(v)) fail(p, "keine ganze Zahl ≥ 0"); };
const status: Check = (v, p) => { if (typeof v !== "string" || !statuses.has(v)) fail(p, "unbekannter Status"); };
// Strict ISO 8601 with zone, a real calendar day from year 1 to 9999, an offset up to ±15:59: what Postgres timestamptz also takes.
const time: Check = (v, p) => {
  const [y, mo, d, h, mi, s, oh, om] = (typeof v === "string" ? iso.exec(v)?.slice(1, 9) ?? [] : []).map((x) => Number(x ?? 0));
  const day = new Date(Date.UTC(y, mo - 1, d));
  day.setUTCFullYear(y);
  const clock = h <= 23 && mi <= 59 && s <= 59 && oh <= 15 && om <= 59;
  if (!(y >= 1 && day.getUTCMonth() === mo - 1 && day.getUTCDate() === d && clock)) {
    fail(p, "kein Zeitpunkt mit Zeitzone");
  }
};
const list = (element: Check): Check => (v, p) => {
  if (!Array.isArray(v)) fail(p, "keine Liste");
  v.forEach((item, index) => element(item, `${p}[${index}]`));
};
const names: Check = (v, p) => {
  if (!Array.isArray(v) || !v.every((item) => typeof item === "string")) fail(p, "keine Liste von Texten");
  if (!v.every(clean)) fail(p, "ungültiges Zeichen");
};

// An object with exactly these keys: every required one present, optional ones checked when there, no other.
function shape(value: unknown, path: string, required: Record<string, Check>, optional: Record<string, Check> = {}): void {
  const at = (key: string) => (path ? `${path}.${key}` : key);
  if (!isObject(value)) fail(path || "Wurzel", "kein Objekt");
  for (const key of Object.keys(value)) {
    if (!Object.hasOwn(required, key) && !Object.hasOwn(optional, key)) fail(at(key), "unbekannter Schlüssel");
  }
  for (const [key, check] of Object.entries(required)) {
    if (!Object.hasOwn(value, key)) fail(at(key), "fehlt");
    check(value[key], at(key));
  }
  for (const [key, check] of Object.entries(optional)) {
    if (Object.hasOwn(value, key)) check(value[key], at(key));
  }
}

// The privacy line (#625, F005): raw text and note are refused wherever they appear, with their full path.
function privacy(value: unknown, path: string): void {
  if (Array.isArray(value)) {
    value.forEach((item, index) => privacy(item, `${path}[${index}]`));
  } else if (isObject(value)) {
    for (const [key, item] of Object.entries(value)) {
      const at = path ? `${path}.${key}` : key;
      if (key === "rawText" || key === "note") fail(at, "Rohtext und Notiz gehören nicht in die Abschrift");
      privacy(item, at);
    }
  }
}

const now: Check = (v, p) => shape(v, p, { today: list(id), lined: list(id), waiting: list(id) }, { knaeuel: id });
const task: Check = (v, p) =>
  shape(v, p, { id, title: text, status, dueHasTime: flag, isKnaeuel: flag, contexts: names }, { dueDate: time, project: text, nextRank: rank });
const version: Check = (v, p) => { if (v !== 1) fail(p, "nicht 1"); };

// The form of the contract (version 1); the service does not recount nowCount or match now against tasks.
export function checkTranscript(doc: unknown): asserts doc is Transcript {
  reporting("Abschrift", () => {
    privacy(doc, "");
    shape(doc, "", { version, generatedAt: time, nowCount: rank, now, tasks: list(task) });
  });
}

// One statement: the first transcript is stored, a newer one replaces it, an older or equally old one leaves it.
export async function putTranscript(pool: pg.Pool, account: string, doc: unknown): Promise<"stored" | "older"> {
  checkTranscript(doc);
  const result = await pool.query(
    `INSERT INTO transcripts (account_id, doc, generated_at) VALUES ($1, $2::jsonb, $3)
     ON CONFLICT (account_id) DO UPDATE SET doc = excluded.doc, generated_at = excluded.generated_at, received_at = now()
     WHERE transcripts.generated_at < excluded.generated_at
     RETURNING account_id`,
    [account, JSON.stringify(doc), doc.generatedAt],
  );
  return result.rowCount === 1 ? "stored" : "older";
}

// One statement: the stored transcript of this account, or undefined; its form was checked when it was taken in.
export async function getTranscript(pool: pg.Pool, account: string): Promise<Transcript | undefined> {
  const result = await pool.query<{ doc: Transcript }>("SELECT doc FROM transcripts WHERE account_id = $1", [account]);
  return result.rows[0]?.doc;
}

export { shape, id, text, flag, time, list, fail, type Check };
