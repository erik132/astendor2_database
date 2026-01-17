DROP TABLE IF EXISTS items;
DROP TABLE IF EXISTS blueprints;
DROP TABLE IF EXISTS blueprint_components;

CREATE TABLE items (
  id INT NOT NULL PRIMARY KEY,
  name VARCHAR(200) NOT NULL
);

CREATE TABLE blueprints(
  id INT NOT NULL PRIMARY KEY,
  name VARCHAR(200) NOT NULL,
  output_item_id INT NOT NULL
);

CREATE TABLE blueprint_components(
  item_id INT NOT NULL,
  blueprint_id INT NOT NULL,
  amount INT NOT NULL,
  PRIMARY KEY (item_id, blueprint_id)
);

INSERT INTO items(id, name) VALUES
  (1, 'Iron Ore'),
  (2, 'Coal'),
  (3, 'Wood'),
  (4, 'Horse'),
  (5, 'Sheep'),
  (6, 'Copper Ore'),
  (7, 'Tin Ore'),
  (8, 'Steel Ingot'),
  (9, 'Bronze Ingot'),
  (10, 'Camel'),
  (11, 'Wooden Shield'),
  (12, 'Short Bow'),
  (13, 'Iron Sword')
;

INSERT INTO blueprints(id, name, output_item_id) VALUES
  (1, 'Steel Ingot', 8),
  (2, 'Bronze Ingot', 9),
  (3, 'Wooden Shield', 11),
  (4, 'Short Bow', 12),
  (5, 'Iron Sword', 13)
;

INSERT INTO blueprint_components(item_id, blueprint_id, amount) VALUES
  (1, 1, 1),
  (2, 1, 1),
  (6, 2, 1),
  (7, 2, 1),
  (3, 3, 2),
  (3, 4, 2),
  (1, 5, 2)
;


