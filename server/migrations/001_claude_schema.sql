-- Transcript, orders and results for Claude, contract v1 (docs/reference/claude-abschrift-vertrag.md, #613 Schnitt C1b).
-- The jsonb document is the one source: ids, kind and result fields are generated from it, never set beside it.
-- No BEGIN or COMMIT here: the migration runner wraps this file in its own transaction.

-- One transcript per account, no history. generated_at is bound to the document by a CHECK, because a
-- timestamptz cast from text is not immutable and so cannot be a generated column.
CREATE TABLE transcripts (
  account_id text PRIMARY KEY,
  doc jsonb NOT NULL,
  generated_at timestamptz NOT NULL,
  received_at timestamptz NOT NULL DEFAULT now(),
  CHECK (generated_at = (doc->>'generatedAt')::timestamptz),
  -- generatedAt must be there and end in a zone (Z or +hh:mm), or the cast above, and with it the
  -- comparison, would depend on the time zone of the session.
  CHECK (jsonb_path_exists(doc, '$.generatedAt ? (@ like_regex "(Z|[+-][0-9]{2}:[0-9]{2})$")')),
  CHECK (doc @> '{"version":1}'),
  -- The privacy line (#625): only these keys on top and per task, so no raw text, note, attachment or revision
  -- gets in. A non-object in tasks makes keyvalue() raise a 2203x error, so it is refused as well.
  CHECK (NOT jsonb_path_exists(doc,
    '$.keyvalue() ? (!(@.key like_regex "^(version|generatedAt|nowCount|now|tasks)$"))')),
  CHECK (NOT jsonb_path_exists(doc,
    '$.tasks[*].keyvalue() ? (!(@.key like_regex "^(id|title|status|dueDate|dueHasTime|contexts|project|nextRank|isKnaeuel)$"))'))
);

-- Orders from Claude. account_id has no foreign key until the account table arrives (C6); claiming
-- (FOR UPDATE SKIP LOCKED) is C3, here only "both or neither".
CREATE TABLE orders (
  doc jsonb NOT NULL,
  id uuid GENERATED ALWAYS AS ((doc->>'id')::uuid) STORED PRIMARY KEY,
  kind text GENERATED ALWAYS AS (doc->>'kind') STORED NOT NULL CHECK (kind IN ('capture', 'complete', 'setDue')),
  account_id text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  claimed_by text,
  claimed_at timestamptz,
  CHECK (doc @> '{"version":1}'),
  CHECK ((claimed_by IS NULL) = (claimed_at IS NULL))
);

-- At most one result per order, and only for an existing one (primary key = foreign key). The account
-- follows from the order. A reason exactly when rejected.
CREATE TABLE order_results (
  doc jsonb NOT NULL,
  order_id uuid GENERATED ALWAYS AS ((doc->>'orderID')::uuid) STORED PRIMARY KEY REFERENCES orders (id),
  outcome text GENERATED ALWAYS AS (doc->>'outcome') STORED NOT NULL CHECK (outcome IN ('done', 'rejected')),
  reason text GENERATED ALWAYS AS (doc->>'reason') STORED CHECK (reason IN ('invalid', 'missing', 'stale')),
  task_id uuid GENERATED ALWAYS AS ((doc->>'taskID')::uuid) STORED,
  reported_by text NOT NULL,
  reported_at timestamptz NOT NULL DEFAULT now(),
  CHECK ((outcome = 'rejected') = (reason IS NOT NULL))
);
