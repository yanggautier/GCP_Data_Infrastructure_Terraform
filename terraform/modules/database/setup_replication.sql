/* setup_replication.sql */
-- Pour gérer l'idempotence, vous pouvez ajouter des vérifications
-- Supprimer la publication si elle existe (pour les re-runs)
DROP PUBLICATION IF EXISTS datastream_publication;
CREATE PUBLICATION datastream_publication FOR ALL TABLES;

-- Supprimer le slot de réplication si il existe (pour les re-runs)
SELECT pg_drop_replication_slot('datastream_slot') WHERE EXISTS (SELECT 1 FROM pg_replication_slots WHERE slot_name = 'datastream_slot');
SELECT pg_create_logical_replication_slot('datastream_slot', 'pgoutput');

-- Optional: Vérifier le setup (pour debug)
-- SELECT slot_name, plugin, slot_type, active FROM pg_replication_slots;
-- SELECT pubname FROM pg_publication;