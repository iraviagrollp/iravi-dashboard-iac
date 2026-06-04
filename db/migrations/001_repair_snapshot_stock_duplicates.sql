-- Migration: 001_repair_snapshot_stock_duplicates
-- Applied: 2026-06-03 (manually via pgAdmin)
--
-- Context: snapshot_stock rows were inserted before the uix_stock_active partial
-- unique index existed. This left multiple out_z IS NULL rows for the same natural
-- key. The index (added in schema.sql) now prevents this going forward, but
-- existing duplicates had to be closed first.
--
-- Safe to re-run: the subquery returns NULL when there is only one active row,
-- so the WHERE condition never matches and no rows are updated.

UPDATE snapshot_stock s
SET out_z = NOW()
WHERE out_z IS NULL
  AND in_z < (
      SELECT MAX(in_z)
      FROM snapshot_stock s2
      WHERE s2.brand                   = s.brand
        AND s2.technical               = s.technical
        AND s2.packing_size            = s.packing_size
        AND s2.packing_configuration   = s.packing_configuration
        AND s2.branch                  = s.branch
        AND s2.special_packing_mention = s.special_packing_mention
        AND s2.out_z IS NULL
  );
