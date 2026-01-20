DROP PROCEDURE IF EXISTS process_world_harvests;

DROP VIEW IF EXISTS tile_training_queue_info;
DROP VIEW IF EXISTS tile_crafting_queue_info;

DROP TABLE IF EXISTS unit_templates;
DROP TABLE IF EXISTS tile_units;
DROP TABLE IF EXISTS warlord_units;
DROP TABLE IF EXISTS unit_equipment;
DROP TABLE IF EXISTS tile_inventories;
DROP TABLE IF EXISTS warlord_inventories;
DROP TABLE IF EXISTS tile_training_queue;

--Base values for all units.
CREATE TABLE unit_templates(
	id INT PRIMARY KEY,
	speed INT NOT NULL,
	combat INT NOT NULL,
	name VARCHAR(255) NOT NULL
);

--Units attached to a tile.
CREATE TABLE tile_units(
	world_id INT NOT NULL,
	tile_id INT NOT NULL,
	template_id INT NOT NULL,
	amount INT NOT NULL,
	PRIMARY KEY (world_id, tile_id, template_id)
);

--Units attached to a warlord.
CREATE TABLE warlord_units(
	world_id INT NOT NULL,
	warlord_id INT NOT NULL,
	template_id INT NOT NULL,
	amount INT NOT NULL,
	PRIMARY KEY(world_id, warlord_id, template_id)
);

--Items required to train 1 unit.
CREATE TABLE unit_equipment(
	template_id INT NOT NULL,
	item_id INT NOT NULL,
	amount INT NOT NULL,
	PRIMARY KEY(template_id, item_id)
);

--Items attached to a tile.
CREATE TABLE tile_inventories(
	world_id INT NOT NULL,
	tile_id INT NOT NULL,
	item_id INT NOT NULL,
	amount INT NOT NULL,
	PRIMARY KEY (world_id, tile_id, item_id)
);

--Items attached to a warlord.
CREATE TABLE warlord_inventories(
	world_id INT NOT NULL,
	warlord_id INT NOT NULL,
	item_id INT NOT NULL,
	amount INT NOT NULL,
	PRIMARY KEY (world_id, warlord_id, item_id)
);

--Tile training queues
CREATE TABLE tile_training_queue(
	id SERIAL,
	world_id INT NOT NULL,
	tile_id INT NOT NULL,
	template_id INT NOT NULL,
	amount INT NOT NULL
);

CREATE VIEW tile_training_queue_info AS
SELECT
	ttq.id,
	world_id,
	tile_id,
	amount,
	name
FROM tile_training_queue ttq LEFT JOIN unit_templates ut ON ttq.template_id=ut.id;

CREATE VIEW tile_crafting_queue_info AS
SELECT
  tcq.id AS id,
  world_id,
  tile_id,
  amount,
  name
FROM tile_crafting_queue tcq LEFT JOIN blueprints b ON tcq.blueprint_id=b.id;

CREATE PROCEDURE process_world_harvests(arg_world_id INT)
LANGUAGE SQL
AS $$
  UPDATE world_harvests SET harvest_meter = subq.harvest_progress FROM
  (SELECT 
    wh.tile_id, 
    wh.item_id, 
    wh.amount/100.0+wh.harvest_meter AS harvest_progress 
    FROM world_tiles wt JOIN world_harvests wh ON wt.id=wh.tile_id WHERE wt.world_id=arg_world_id) subq
  WHERE subq.tile_id=world_harvests.tile_id AND subq.item_id=world_harvests.item_id;

  INSERT INTO tile_inventories(world_id, tile_id, item_id, amount)
  (SELECT 
    wt.world_id, 
    wh.tile_id, 
    wh.item_id, 
    1
  FROM world_tiles wt JOIN world_harvests wh ON wt.id=wh.tile_id WHERE wt.world_id=arg_world_id AND wh.harvest_meter >= 1.0)
  ON CONFLICT(world_id, tile_id, item_id) DO UPDATE SET amount = tile_inventories.amount + 1;

  UPDATE world_harvests SET harvest_meter = world_harvests.harvest_meter - 1.0 FROM
  (SELECT wh.tile_id, wh.item_id FROM world_tiles wt JOIN world_harvests wh ON wt.id=wh.tile_id WHERE wt.world_id=arg_world_id AND wh.harvest_meter >= 1.0) subq
  WHERE world_harvests.tile_id = subq.tile_id AND world_harvests.item_id=subq.item_id;
$$;