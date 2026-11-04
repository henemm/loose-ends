-- The client id an Apple refresh token was issued for (#615 Schnitt 3a); the revocation must send exactly this one.
-- No BEGIN or COMMIT here: the migration runner wraps this file in its own transaction.
-- Additive and nullable: a row stored before 003 has no value, which means no revocation is possible for it.
ALTER TABLE apple_tokens ADD COLUMN client_id text;
