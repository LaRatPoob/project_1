BEGIN;

INSERT INTO products (sku, name, unit, reorder_point)
VALUES ('SKU-001', 'Widget', 'each', 10)
ON CONFLICT (sku) DO NOTHING;

INSERT INTO locations (code, name)
VALUES ('A1', 'Bin A1'), ('B1', 'Bin B1')
ON CONFLICT (code) DO NOTHING;

-- RECEIVE 25 into A1
INSERT INTO stock_transactions (type, reference) VALUES ('RECEIVE', 'PO-1001') RETURNING id;
-- In psql scripts we can’t easily capture RETURNING without \gset, so do it in one statement:
WITH t AS (
  INSERT INTO stock_transactions (type, reference)
  VALUES ('RECEIVE', 'PO-1001')
  RETURNING id
)
INSERT INTO stock_transaction_lines (transaction_id, product_id, to_location_id, quantity)
SELECT t.id, p.id, l.id, 25
FROM t
JOIN products p ON p.sku = 'SKU-001'
JOIN locations l ON l.code = 'A1';

-- MOVE 5 from A1 -> B1
WITH t AS (
  INSERT INTO stock_transactions (type, reference)
  VALUES ('MOVE', 'MV-2001')
  RETURNING id
)
INSERT INTO stock_transaction_lines (transaction_id, product_id, from_location_id, to_location_id, quantity)
SELECT t.id, p.id, lf.id, lt.id, 5
FROM t
JOIN products p ON p.sku = 'SKU-001'
JOIN locations lf ON lf.code = 'A1'
JOIN locations lt ON lt.code = 'B1';

COMMIT;
