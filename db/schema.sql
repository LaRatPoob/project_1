-- Warehouse Stock Tracker (MVP)

BEGIN;

CREATE TABLE IF NOT EXISTS products (
  id           BIGSERIAL PRIMARY KEY,
  sku          TEXT NOT NULL UNIQUE,
  name         TEXT NOT NULL,
  unit         TEXT NOT NULL DEFAULT 'each',
  reorder_point INTEGER NOT NULL DEFAULT 0 CHECK (reorder_point >= 0),
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS locations (
  id        BIGSERIAL PRIMARY KEY,
  code      TEXT NOT NULL UNIQUE,
  name      TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

DO $$ BEGIN
  CREATE TYPE txn_type AS ENUM ('RECEIVE', 'SHIP', 'MOVE', 'ADJUST');
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

CREATE TABLE IF NOT EXISTS stock_transactions (
  id          BIGSERIAL PRIMARY KEY,
  type        txn_type NOT NULL,
  reference   TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS stock_transaction_lines (
  id               BIGSERIAL PRIMARY KEY,
  transaction_id   BIGINT NOT NULL REFERENCES stock_transactions(id) ON DELETE CASCADE,
  product_id       BIGINT NOT NULL REFERENCES products(id),
  from_location_id BIGINT REFERENCES locations(id),
  to_location_id   BIGINT REFERENCES locations(id),
  quantity         NUMERIC(18,3) NOT NULL CHECK (quantity > 0),

  -- Enforce valid shapes per movement type at the line level
  CHECK (
    (from_location_id IS NOT NULL) OR (to_location_id IS NOT NULL)
  ),
  CHECK (
    NOT (from_location_id IS NOT NULL AND to_location_id IS NOT NULL AND from_location_id = to_location_id)
  )
);

-- Stock on hand view (computed, not stored)
CREATE OR REPLACE VIEW v_stock_on_hand AS
SELECT
  p.sku,
  p.name,
  l.code AS location_code,
  l.name AS location_name,
  COALESCE(SUM(
    CASE
      WHEN stl.to_location_id = l.id THEN stl.quantity
      WHEN stl.from_location_id = l.id THEN -stl.quantity
      ELSE 0
    END
  ), 0) AS on_hand
FROM products p
CROSS JOIN locations l
LEFT JOIN stock_transaction_lines stl
  ON stl.product_id = p.id
 AND (stl.from_location_id = l.id OR stl.to_location_id = l.id)
GROUP BY p.sku, p.name, l.code, l.name
ORDER BY p.sku, l.code;

COMMIT;

