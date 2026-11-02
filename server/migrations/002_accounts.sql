-- Accounts and sessions for the app (#615 Schnitt 1). apple_sub is the one account key, never the e-mail.
-- No BEGIN or COMMIT here: the migration runner wraps this file in its own transaction.
-- transcripts and orders stay untouched (no foreign key yet); deleteAccount removes their rows itself.

-- id is text, because transcripts.account_id and orders.account_id are text; it stays a UUID in text form.
CREATE TABLE accounts (
  id text PRIMARY KEY DEFAULT gen_random_uuid()::text,
  apple_sub text NOT NULL UNIQUE,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Only the SHA-256 of a session token is stored, never the token.
CREATE TABLE sessions (
  token_hash bytea PRIMARY KEY,
  account_id text NOT NULL REFERENCES accounts (id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  last_used_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX sessions_account_id ON sessions (account_id);

-- The encrypted Apple refresh token for the revocation on delete; encrypting and redeeming come in S2.
CREATE TABLE apple_tokens (
  account_id text PRIMARY KEY REFERENCES accounts (id) ON DELETE CASCADE,
  refresh_token_enc bytea NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);
