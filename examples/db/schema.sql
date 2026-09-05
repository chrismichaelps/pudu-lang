-- An order book, in the shape a real one has: customers in regions, products
-- in categories, orders that belong to a customer, and the lines that belong
-- to an order. The queries below join across all four, which is where a
-- database layer is actually tested — a driver that only ever runs
-- `select 1` proves nothing about how it carries a NULL, a decimal, or a
-- column whose name only appears in a join.
--
-- Written to the intersection of SQLite and PostgreSQL so one file describes
-- both: no SERIAL, no AUTOINCREMENT, no backend-specific types. Identifiers
-- are supplied rather than generated for the same reason, and because a test
-- that knows its own keys can assert on exact rows.

CREATE TABLE regions (
  id       INTEGER NOT NULL PRIMARY KEY,
  name     VARCHAR(64) NOT NULL
);

CREATE TABLE customers (
  id         INTEGER NOT NULL PRIMARY KEY,
  region_id  INTEGER NOT NULL,
  name       VARCHAR(128) NOT NULL,
  -- Deliberately nullable: a customer who never gave one is the case that
  -- separates a driver carrying absence from one turning it into empty text.
  email      VARCHAR(128),
  FOREIGN KEY (region_id) REFERENCES regions (id)
);

CREATE TABLE categories (
  id    INTEGER NOT NULL PRIMARY KEY,
  name  VARCHAR(64) NOT NULL
);

CREATE TABLE products (
  id           INTEGER NOT NULL PRIMARY KEY,
  category_id  INTEGER NOT NULL,
  sku          VARCHAR(32) NOT NULL,
  -- Money. Not a float, because a float cannot hold 0.10 and a total that is
  -- out by a hundredth is the bug this column exists to avoid.
  unit_price   DECIMAL(12, 2) NOT NULL,
  FOREIGN KEY (category_id) REFERENCES categories (id)
);

CREATE TABLE orders (
  id           INTEGER NOT NULL PRIMARY KEY,
  customer_id  INTEGER NOT NULL,
  placed_on    DATE NOT NULL,
  status       VARCHAR(16) NOT NULL,
  FOREIGN KEY (customer_id) REFERENCES customers (id)
);

CREATE TABLE order_lines (
  id         INTEGER NOT NULL PRIMARY KEY,
  order_id   INTEGER NOT NULL,
  product_id INTEGER NOT NULL,
  quantity   INTEGER NOT NULL,
  FOREIGN KEY (order_id) REFERENCES orders (id),
  FOREIGN KEY (product_id) REFERENCES products (id)
);

INSERT INTO regions (id, name) VALUES (1, 'North'), (2, 'South');

INSERT INTO categories (id, name) VALUES (1, 'Tools'), (2, 'Books');

-- One customer with no email, one region with no customers of its own beyond
-- the pair below, so an outer join has something to be outer about.
INSERT INTO customers (id, region_id, name, email) VALUES
  (1, 1, 'Ada',  'ada@example.test'),
  (2, 1, 'Alan', NULL),
  (3, 2, 'Grace','grace@example.test'),
  (4, 2, 'Zoe',   NULL);

INSERT INTO products (id, category_id, sku, unit_price) VALUES
  (1, 1, 'HAMMER-01', 12.50),
  (2, 1, 'WRENCH-02', 7.25),
  (3, 2, 'BOOK-03',   30.00);

INSERT INTO orders (id, customer_id, placed_on, status) VALUES
  (1, 1, '2026-01-05', 'shipped'),
  (2, 1, '2026-02-11', 'shipped'),
  (3, 2, '2026-02-14', 'pending'),
  (4, 3, '2026-03-02', 'cancelled');

-- Grace's order is cancelled and Alan's is pending, so a query that filters on
-- status has something to exclude rather than passing by accident.
INSERT INTO order_lines (id, order_id, product_id, quantity) VALUES
  (1, 1, 1, 2),
  (2, 1, 2, 4),
  (3, 2, 3, 1),
  (4, 3, 1, 1),
  (5, 4, 3, 10);
