-- Migration 034: seed procurement.packaging_meta with the unique packaging sizes
-- observed in design/Opening Stock 15-Jul-2026.pdf.
--
-- Labels are kept EXACTLY as they appear in the source report (e.g. '1 LT',
-- '100 GM (B)', '50 GM BOX'). sort_order is ascending = top-to-bottom, ordered by
-- descending physical size within each unit type (largest on top; Box variant right
-- after its plain size). Idempotent — ON CONFLICT (unit_type, label) DO NOTHING.
--
-- Applied MANUALLY via psql over the SSM bastion tunnel (see migration 026 header).

INSERT INTO procurement.packaging_meta (unit_type, label, sort_order) VALUES
  -- KG (weight)
  ('KG',  '1 KG',       10),
  ('KG',  '500 GM',     20),
  ('KG',  '250 GM',     30),
  ('KG',  '133.2 GM',   40),
  ('KG',  '125 GM',     50),
  ('KG',  '120 GM',     60),
  ('KG',  '100 GM',     70),
  ('KG',  '100 GM (B)', 80),
  ('KG',  '50 GM',      90),
  ('KG',  '50 GM BOX', 100),
  ('KG',  '40 GM',     110),
  ('KG',  '8 GM',      120),
  -- LTR (volume)
  ('LTR', '1400 ML',    10),
  ('LTR', '1 LT',       20),
  ('LTR', '700 ML',     30),
  ('LTR', '500 ML',     40),
  ('LTR', '250 ML',     50),
  ('LTR', '230 ML',     60),
  ('LTR', '200 ML',     70),
  ('LTR', '150 ML',     80),
  ('LTR', '115 ML',     90),
  ('LTR', '100 ML',    100),
  ('LTR', '60 ML',     110),
  ('LTR', '30 ML',     120),
  ('LTR', '10 ML',     130)
ON CONFLICT (unit_type, label) DO NOTHING;
