// Helper commands against the throwaway database of local-service.sh (#795 S3b-2), never a real one: session,
// transcript, order <text>, result <id>, due <taskID> <date>, apple-token, rows. Only existing functions; findOrCreate on purpose (no Apple id, no admit rule).
// #615 S4f: `rows` counts every table whole and only reads (never findOrCreate, so it never creates an account); `apple-token`
// stores one undecryptable apple_tokens row for the fixture account (random key, never kept; placeholder plain text).
import { randomBytes, randomUUID } from "node:crypto";
import pg from "pg";
import { createSession, findOrCreate } from "../src/accounts.ts";
import { encryptToken, storeRefreshToken } from "../src/apple-vault.ts";
import { getResult, putOrder } from "../src/orders.ts";
import { getTranscript } from "../src/transcripts.ts";

const stop = (message: string): never => {
  console.error(`local-fixture: ${message}`);
  process.exit(1);
};

const [command, argument, date] = process.argv.slice(2);
const databaseUrl = process.env.DATABASE_URL;
if (databaseUrl === undefined || databaseUrl === "") stop("DATABASE_URL fehlt");
let host = "";
try { host = new URL(databaseUrl as string).hostname; } catch { stop("DATABASE_URL unlesbar"); }
if (host !== "127.0.0.1" && host !== "localhost") stop("nur eine lokale Datenbank (127.0.0.1, localhost)");
// Fixed table names from server/migrations (001, 002, 004, 008), never input in SQL.
const TABLES = ["accounts", "sessions", "transcripts", "orders", "order_results", "apple_tokens", "oauth_records", "device_tokens"];
const commands = ["session", "transcript", "order", "result", "due", "apple-token", "rows"];
if (!commands.includes(command ?? "")) stop("Unterbefehl: session | transcript | order <text> | result <id> | due <taskID> <datum> | apple-token | rows");
if (["order", "result", "due"].includes(command as string) && (argument === undefined || argument === "")) stop(`${command}: Argument fehlt`);
if (command === "due" && (date === undefined || date === "")) stop("due: Datum fehlt");

const pool = new pg.Pool({ connectionString: databaseUrl });
try {
  if (command === "rows") {
    for (const table of TABLES) {
      const result = await pool.query(`SELECT count(*)::int AS n FROM ${table}`);
      console.log(`${table}=${result.rows[0].n}`);
    }
  } else {
    const account = await findOrCreate(pool, "local-fixture");
    await run(pool, account, command as string, argument ?? "", date ?? "");
  }
} catch (error) {
  console.error(`local-fixture: ${command} fehlgeschlagen (${error instanceof Error ? error.name : "Fehler"})`);
  process.exitCode = 1;
} finally {
  await pool.end();
}

async function run(pool: pg.Pool, account: string, command: string, argument: string, date: string): Promise<void> {
  if (command === "session") {
    console.log(await createSession(pool, account));
  } else if (command === "apple-token") {
    const blob = encryptToken(randomBytes(32), account, "local-fixture-placeholder");
    if (!(await storeRefreshToken(pool, account, blob, "local-fixture-client"))) throw new Error("account missing");
    const result = await pool.query("SELECT count(*)::int AS n FROM apple_tokens WHERE account_id = $1", [account]);
    console.log(`apple_tokens=${result.rows[0].n}`);
  } else if (command === "transcript") {
    const transcript = await getTranscript(pool, account);
    if (transcript === undefined) { console.log("none"); return; }
    console.log(`tasks=${transcript.tasks.length}`);
    for (const task of transcript.tasks) console.log(task.title);
  } else if (command === "order") {
    const id = randomUUID();
    await putOrder(pool, account, { version: 1, id, kind: "capture", text: argument });
    console.log(id);
  } else if (command === "due") {
    const id = randomUUID();
    await putOrder(pool, account, { version: 1, id, kind: "setDue", taskID: argument, hasTime: false, date });
    console.log(id);
  } else {
    const state = await getResult(pool, account, argument);
    console.log(state.state);
    if (state.state !== "result") return;
    console.log(`outcome=${state.result.outcome}`);
    if (state.result.reason !== undefined) console.log(`reason=${state.result.reason}`);
    if (state.result.taskID !== undefined) console.log(`taskID=${state.result.taskID}`);
  }
}
