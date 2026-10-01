CREATE DATABASE IF NOT EXISTS workshop;
USE workshop;

CREATE TABLE IF NOT EXISTS orders (
  id         INT PRIMARY KEY AUTO_INCREMENT,
  customer   VARCHAR(64)  NOT NULL,
  item       VARCHAR(64)  NOT NULL,
  qty        INT          NOT NULL,
  created_at DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO orders (customer, item, qty) VALUES
  ('acme',     'widget',  12),
  ('globex',   'gear',     3),
  ('initech',  'stapler',  1),
  ('umbrella', 'sensor',  40),
  ('hooli',    'server',   2);

CREATE USER IF NOT EXISTS 'shop'@'%' IDENTIFIED BY 'shop-pass';
GRANT SELECT ON workshop.* TO 'shop'@'%';
