-- Storage for the OAuth authorization server (#621 Schnitt 2): one table for every model of oidc-provider.
-- No BEGIN or COMMIT here: the migration runner wraps this file in its own transaction.
-- Ids are stored only as their SHA-256 and jti never in the payload, so no token is kept in plain text.
-- grant_id, uid and account_id are identifiers, not credentials; account_id is null for rows without an account.
CREATE TABLE oauth_records (
  model text NOT NULL,
  id_hash bytea NOT NULL,
  payload jsonb NOT NULL,
  grant_id text,
  uid text,
  account_id text REFERENCES accounts (id) ON DELETE CASCADE,
  expires_at timestamptz,
  consumed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (model, id_hash)
);
CREATE INDEX oauth_records_grant_id ON oauth_records (grant_id);
CREATE INDEX oauth_records_uid ON oauth_records (uid);
CREATE INDEX oauth_records_account_id ON oauth_records (account_id);
CREATE INDEX oauth_records_expires_at ON oauth_records (expires_at);
