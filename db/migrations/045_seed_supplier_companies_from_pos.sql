-- Migration 045: seed procurement.supplier_companies from the IAL Purchase Order PDFs
--
-- Source: every "IAL PO for ..." / "IAL_2627_*" Purchase Order PDF found under
-- IaC/design/ and IaC/design/POs/** (26 PDF files covering 24 distinct PO numbers;
-- several files are duplicate/regenerated copies of the same PO — e.g.
-- IAL_2627_2.pdf and IAL_2627_2 (4).pdf, and the two copies of
-- "IAL PO for PROPARGITE 57% EC Sunitha.pdf" — those were de-duplicated before
-- extraction). Each PO's Vendor/Supplier block, Bill-To block, and Ship-To block
-- (bold company name + address + GSTIN) was read and every distinct company
-- across all POs was extracted, including IRAVI AGRO LIFE LLP itself (the
-- recurring Bill-To party).
--
-- Idempotent / non-destructive: INSERT ... ON CONFLICT (company_name) DO UPDATE.
-- The only unique constraint on procurement.supplier_companies is
-- uq_supplier_companies_name UNIQUE (company_name), so company_name is the
-- conflict/natural key here. NO DELETE / TRUNCATE. Safe to re-run.
--
-- Note: migration 028 previously seeded a set of short supplier-company
-- "code names" (e.g. 'WILLOWOOD', 'DHARMAJ', 'JU', 'JU AGRI SCIENCES PVT LTD',
-- 'TRUUCHEM TECHNOLOGIES PVT LTD', 'WILLIWOOD CHEMICALS LTD' [sic]) used to
-- link the enquiry-comparison data from IAL Enquiry.xlsx. The full legal names
-- extracted here from the PO letterheads (e.g. 'WILLOWOOD CHEMICALS LIMITED',
-- 'DHARMAJ CROP GUARD LIMITED', 'JU AGRI SCIENCES PRIVATE LIMITED',
-- 'TRUUCHEM TECHNOLOGIES PRIVATE LIMITED') are different strings under the
-- company_name unique key, so this migration ADDS new rows alongside those
-- short-code rows rather than merging with them — reconciling the two is a
-- follow-up data-hygiene task, out of scope here (see report to the user).
--
-- Discrepancy note (see task report for detail): IRAVI AGRO LIFE LLP appears
-- with TWO different registered-office addresses/GSTINs across the PO corpus.
-- The majority of manually-drafted POs use "1st Floor, Plot No 6, Block No 40,
-- Auto Nagar, Hayath Nagar (M), Ranga Reddy (Dist), Hyderabad - 500070" with
-- GSTIN 36AALFI2946J1Z0. The three newest, computer-generated POs
-- (IAL/2627/1, /2, /3, dated 17-20 July 2026 — rendered by the procurement
-- app's own PO PDF generator) use "Flat No. 102, BVR Plaza, H.No. 5-3-112/2,
-- BJP Office Line, Shanthi Nagar, Kukatpally, Hyderabad, Telangana 500072"
-- with GSTIN 37AALFI2946J1ZY. This migration seeds the latter (the app's own
-- authoritative/most recent letterhead) as the address of record.
--
-- Apply AFTER 026/032 (schema + address columns already applied). Manual psql
-- over the SSM tunnel.

BEGIN;

INSERT INTO procurement.supplier_companies
  (company_name, address_line1, address_line2, address_line3, state, pin_code, gstin, is_active)
VALUES
  ('IRAVI AGRO LIFE LLP',
   'Flat No. 102, BVR Plaza, H.No. 5-3-112/2',
   'BJP Office Line, Shanthi Nagar, Kukatpally',
   'Hyderabad, Telangana 500072',
   'Telangana', '500072', '37AALFI2946J1ZY', TRUE),

  ('PRISTINE AGRO LIMITED',
   '6-80, Koyalagudem, D Nagaram',
   'N H, Devalamma Nagaram, Choutuppal',
   'Bhongir, Yadadri Bhuvanagiri Dist - 508252',
   'Telangana', '508252', '36AADCP2766L1Z1', TRUE),

  ('WILLOWOOD CHEMICALS LIMITED',
   'Unit I, Block 69/P, Manjusar',
   'Tal. Savli, Vadodara',
   'Gujarat - 391775',
   'Gujarat', '391775', '24AAECS0957K1Z7', TRUE),

  ('SUNITHA GRAPHICS',
   'H.No 5-35/263, Prashanti Nagar',
   'Shaktipuram, IE, Kukatpally',
   'Hyderabad, Telangana',
   'Telangana', NULL, '36AIPPK0887Q1ZA', TRUE),

  ('UNIQUE AGRICARE',
   '7/17, Sri Vani Nagar',
   'Near Coco Cola Godown, Ameenpur',
   'Miyapur, Hyderabad - 500090',
   'Telangana', '500090', '36ACZPN4124F1ZB', TRUE),

  ('TRUUCHEM TECHNOLOGIES PRIVATE LIMITED',
   'Embassy Tech Square, Kaverappa Layout',
   'Obeya Signet, Sarjapur Outer Ring Road',
   'Kadubisanahalli, Bengaluru - 560103',
   'Karnataka', '560103', '29AAKCT0893M1ZJ', TRUE),

  ('MERCO ENERGY SOLUTIONS (P) LTD.',
   'Plot No 230, Sy No.222,231',
   'IDA Pashamylaram, Patancheruvu',
   'Sangareddy - 502307',
   'Telangana', '502307', '36AAKCM2376E1ZE', TRUE),

  ('B B POLYMERS',
   'P No.9, Block No 29',
   'Beside Varun Motors, Auto Nagar',
   'Hyderabad, Telangana - 500070',
   'Telangana', '500070', '36DTOPR3757R1ZE', TRUE),

  ('DHANA CROP SCIENCES LIMITED',
   'Sy. No. 611 & 612',
   'Panthangi (V), Choutuppal (M)',
   'Yadadri Bhuvanagiri Dist, Telangana - 508252',
   'Telangana', '508252', '36AAECA1439J1ZR', TRUE),

  ('DHARMAJ CROP GUARD LIMITED',
   'Office No. 901 To 903 & 911',
   'B Square 2, Iscon-Ambli Road',
   'Ahmedabad (Gujarat) - 380058',
   'Gujarat', '380058', NULL, TRUE),

  ('JU AGRI SCIENCES PRIVATE LIMITED',
   '2302, Express Trade Tower 2, Tower II, 3rd Floor',
   'B-36, Sector-132',
   'Noida, (UP) - 201301',
   'Uttar Pradesh', '201301', '09AAACJ0096L1ZC', TRUE),

  ('SMR AGRO',
   '1-1-65,66 Mutyalapadu Bus Stand',
   'Chagalamarri V&M',
   'Nandyala Dist, Andhra Pradesh - 518553',
   'Andhra Pradesh', '518553', '37ABGCS0996R1ZB', TRUE),

  ('SREE SAI SINDHURA POLY PRODUCTS',
   'Shed No. B-11/2, IDA, Moula Ali',
   'Hyderabad',
   'Telangana - 500040',
   'Telangana', '500040', '36AAJFS6277Q1Z6', TRUE),

  ('SRI GAYATHRI PACKAGING INDUSTRIES',
   '7-198/3, Vinayak Nagar, Phase 1',
   'IDA Jeedimetla',
   'Telangana - 500055',
   'Telangana', '500055', '36ABDFS7639F1ZX', TRUE)

ON CONFLICT (company_name) DO UPDATE SET
  address_line1 = EXCLUDED.address_line1,
  address_line2 = EXCLUDED.address_line2,
  address_line3 = EXCLUDED.address_line3,
  state          = EXCLUDED.state,
  pin_code       = EXCLUDED.pin_code,
  gstin          = EXCLUDED.gstin;

COMMIT;
