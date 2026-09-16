-- The same order book, written the way it would be for PostgreSQL alone.
--
-- `schema.sql` beside this one is the portable version, and is what the
-- example program applies so that a single file describes both backends. This
-- file is what a reader should copy when the target is Postgres and nothing
-- else: it uses the types and constraints a Postgres schema would actually be
-- given, which the portable one has to do without.
--
--   createdb orders
--   psql -d orders -f examples/db/postgres.sql
--   PUDU_DB_URL='postgresql://user:password@localhost:5432/orders' \
--     pudu run examples/db/Orders.pudu
--
-- The program applies `schema.sql` itself when the tables are absent, so this
-- file is for the case where the schema is owned by the database rather than
-- by the program.

DROP TABLE IF EXISTS order_lines, orders, products, customers, categories, regions;

CREATE TABLE regions (
  id    INTEGER     PRIMARY KEY,
  name  TEXT        NOT NULL
);

CREATE TABLE customers (
  id         INTEGER  PRIMARY KEY,
  region_id  INTEGER  NOT NULL REFERENCES regions (id),
  name       TEXT     NOT NULL,
  -- Nullable on purpose: a customer who gave no address is what separates a
  -- driver that carries absence from one that reports empty text.
  email      TEXT
);

CREATE TABLE categories (
  id    INTEGER  PRIMARY KEY,
  name  TEXT     NOT NULL
);

CREATE TABLE products (
  id           INTEGER        PRIMARY KEY,
  category_id  INTEGER        NOT NULL REFERENCES categories (id),
  sku          TEXT           NOT NULL UNIQUE,
  -- NUMERIC rather than a float. A float cannot hold 0.10, and a total that is
  -- out by a hundredth is the failure this column exists to prevent.
  unit_price   NUMERIC(12, 2) NOT NULL CHECK (unit_price >= 0)
);

CREATE TABLE orders (
  id           INTEGER  PRIMARY KEY,
  customer_id  INTEGER  NOT NULL REFERENCES customers (id),
  placed_on    DATE     NOT NULL,
  status       TEXT     NOT NULL CHECK (status IN ('pending', 'shipped', 'cancelled'))
);

CREATE TABLE order_lines (
  id          INTEGER  PRIMARY KEY,
  order_id    INTEGER  NOT NULL REFERENCES orders (id) ON DELETE CASCADE,
  product_id  INTEGER  NOT NULL REFERENCES products (id),
  quantity    INTEGER  NOT NULL CHECK (quantity > 0)
);

-- The joins the example runs read orders by customer and lines by order, so
-- these are the indexes those joins want.
CREATE INDEX orders_by_customer ON orders (customer_id);
CREATE INDEX order_lines_by_order ON order_lines (order_id);

INSERT INTO regions (id, name) VALUES (1, 'North'), (2, 'South');

INSERT INTO categories (id, name) VALUES (1, 'Tools'), (2, 'Books');

INSERT INTO customers (id, region_id, name, email) VALUES
  (1, 1, 'Ada',   'ada@example.test'),
  (2, 1, 'Alan',  NULL),
  (3, 2, 'Grace', 'grace@example.test'),
  (4, 2, 'Zoe',   NULL);

INSERT INTO products (id, category_id, sku, unit_price) VALUES
  (1, 1, 'HAMMER-01', 12.50),
  (2, 1, 'WRENCH-02', 7.25),
  (3, 2, 'BOOK-03',   30.00);

INSERT INTO orders (id, customer_id, placed_on, status) VALUES
  (1, 1, DATE '2026-01-05', 'shipped'),
  (2, 1, DATE '2026-02-11', 'shipped'),
  (3, 2, DATE '2026-02-14', 'pending'),
  (4, 3, DATE '2026-03-02', 'cancelled');

INSERT INTO order_lines (id, order_id, product_id, quantity) VALUES
  (1, 1, 1, 2),
  (2, 1, 2, 4),
  (3, 2, 3, 1),
  (4, 3, 1, 1),
  (5, 4, 3, 10);
