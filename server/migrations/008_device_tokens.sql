-- The Apple device token per account and installation (#795 S5a-1), for the wake-up of a later cut.
-- One token belongs to exactly one account and device; deleting the account removes its rows by cascade.
-- No BEGIN or COMMIT here: the migration runner wraps this file in its own transaction.
CREATE TABLE device_tokens (
  account_id  text        NOT NULL REFERENCES accounts (id) ON DELETE CASCADE,
  device      text        NOT NULL,
  token       text        NOT NULL,
  environment text        NOT NULL CHECK (environment IN ('sandbox', 'production')),
  updated_at  timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (account_id, device),
  UNIQUE (token)
);
