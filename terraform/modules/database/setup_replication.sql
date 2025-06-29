/* setup_replication.sql */

-- Drop and create publication - these can be in one transaction
DROP PUBLICATION IF EXISTS datastream_publication;
CREATE PUBLICATION datastream_publication FOR ALL TABLES;

-- Commit the transaction so the next statements start a new, clean one
COMMIT; -- Or BEGIN; ... COMMIT; for explicit transactions

-- Drop replication slot - this might also need to be in its own transaction context
-- The SELECT ... WHERE EXISTS ensures idempotency for dropping
SELECT pg_drop_replication_slot('datastream_slot') WHERE EXISTS (SELECT 1 FROM pg_replication_slots WHERE slot_name = 'datastream_slot');

-- Commit this transaction before creating the new slot
COMMIT;

-- Create logical replication slot - THIS MUST BE IN A TRANSACTION WITH NO PRIOR WRITES
SELECT pg_create_logical_replication_slot('datastream_slot', 'pgoutput');

-- Commit the final transaction
COMMIT; -- Essential for the slot creation to be persistent