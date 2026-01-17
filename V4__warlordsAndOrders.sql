DROP TABLE IF EXISTS warlords;
DROP TABLE IF EXISTS warlord_orders;

CREATE TABLE warlords(
  id SERIAL PRIMARY KEY,
  world_id INT NOT NULL,
  user_id INT NOT NULL,
  race_id INT NOT NULL,
  x INT NOT NULL,
  y INT NOT NULL,
  UNIQUE(world_id, user_id)
);

CREATE TABLE warlord_orders(
  warlord_id INT PRIMARY KEY,
  order_text TEXT NOT NULL
);

INSERT INTO warlords(world_id, user_id, race_id, x, y) VALUES(1, 1, 1, 1, 1);

INSERT INTO warlord_orders(warlord_id, order_text) VALUES (1, 'move east move west move north take 5 grunt take 5 iron sword');