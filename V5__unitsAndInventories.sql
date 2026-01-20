DROP VIEW IF EXISTS tile_training_queue_info;

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