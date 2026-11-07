-- One Apple refresh token per account and client (#621 Schnitt 4c-1): the app and the web sign-in each keep their own,
-- and a deletion revokes each with the client id it was issued for.
-- No BEGIN or COMMIT here: the migration runner wraps this file in its own transaction.
-- Rows without client_id (stored before 003) go: they can never be revoked, and production has none.
DELETE FROM apple_tokens WHERE client_id IS NULL;
ALTER TABLE apple_tokens ALTER COLUMN client_id SET NOT NULL;
ALTER TABLE apple_tokens DROP CONSTRAINT apple_tokens_pkey;
ALTER TABLE apple_tokens ADD PRIMARY KEY (account_id, client_id);
