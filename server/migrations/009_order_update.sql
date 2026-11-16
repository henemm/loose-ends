-- One more kind of order from Claude (#932 Schnitt 3): update changes title and details of an existing task.
-- The generated `kind` column keeps its CHECK; it is replaced by one that knows update as well.
-- No BEGIN or COMMIT here: the migration runner wraps this file in its own transaction.
DO $$
DECLARE old_name text;
BEGIN
  SELECT conname INTO STRICT old_name FROM pg_constraint
  WHERE conrelid = 'orders'::regclass AND contype = 'c' AND pg_get_constraintdef(oid) LIKE '%capture%';
  EXECUTE format('ALTER TABLE orders DROP CONSTRAINT %I', old_name);
END $$;

ALTER TABLE orders ADD CONSTRAINT orders_kind_known
  CHECK (kind IN ('capture', 'complete', 'setDue', 'setNext', 'park', 'addSubtask', 'update'));
