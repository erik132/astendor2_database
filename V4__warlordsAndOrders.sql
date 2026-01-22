DROP PROCEDURE IF EXISTS move_warlord;

DROP TABLE IF EXISTS warlords;
DROP TABLE IF EXISTS warlord_orders;

CREATE TABLE warlords(
  id SERIAL PRIMARY KEY,
  world_id INT NOT NULL,
  user_id INT NOT NULL,
  race_id INT NOT NULL,
  x INT NOT NULL,
  y INT NOT NULL,
  is_warlord_busy BOOLEAN NOT NULL DEFAULT false,
  UNIQUE(world_id, user_id)
);

CREATE TABLE warlord_orders(
  warlord_id INT PRIMARY KEY,
  order_text TEXT NOT NULL
);

INSERT INTO warlords(world_id, user_id, race_id, x, y) VALUES(1, 1, 1, 1, 1);

INSERT INTO warlord_orders(warlord_id, order_text) VALUES (1, 'move east move west move north take 5 grunt take 5 iron sword');

CREATE PROCEDURE move_warlord(arg_warlord_id INT, arg_x INT, arg_y INT)
LANGUAGE SQL
AS $$
  UPDATE warlords SET x = x + arg_x, y= y + arg_y FROM
  (SELECT id, x_ok + y_ok AS movement_ok FROM
  (SELECT id, CASE WHEN new_x < 0 OR new_x >= xdim THEN 0 ELSE 1 END AS x_ok, CASE WHEN new_y < 0 OR new_y >= ydim THEN 0 ELSE 1 END AS y_ok FROM
  (SELECT 
    warlords.id, 
    x + arg_x AS new_x, 
    y + arg_y AS new_y, 
    maps.xdim, 
    maps.ydim 
  FROM warlords JOIN worlds ON warlords.world_id=worlds.id JOIN maps ON worlds.map_id=maps.id WHERE warlords.id=arg_warlord_id))) subq
  WHERE warlords.id=arg_warlord_id AND subq.movement_ok = 2;
$$;