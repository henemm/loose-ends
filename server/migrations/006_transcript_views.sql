-- The transcript may carry `views` (#621 Schnitt 5): the ids of "Due", "Next up" and "Loose ends" in the app's order,
-- so Claude shows what the app shows. Ids only, nothing new about a task. The privacy CHECK on the top-level keys
-- (migration 001) allows exactly the old keys, so it is replaced by one that also allows `views`.
-- No BEGIN or COMMIT here: the migration runner wraps this file in its own transaction.
DO $$
DECLARE old_name text;
BEGIN
  SELECT conname INTO STRICT old_name FROM pg_constraint
  WHERE conrelid = 'transcripts'::regclass AND contype = 'c' AND pg_get_constraintdef(oid) LIKE '%nowCount%';
  EXECUTE format('ALTER TABLE transcripts DROP CONSTRAINT %I', old_name);
END $$;

ALTER TABLE transcripts ADD CONSTRAINT transcripts_top_keys CHECK (NOT jsonb_path_exists(doc,
  '$.keyvalue() ? (!(@.key like_regex "^(version|generatedAt|nowCount|now|tasks|views)$"))'));
ALTER TABLE transcripts ADD CONSTRAINT transcripts_view_keys CHECK (NOT jsonb_path_exists(doc,
  '$.views.keyvalue() ? (!(@.key like_regex "^(due|next|open)$"))'));
