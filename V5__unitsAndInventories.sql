DROP PROCEDURE IF EXISTS process_world_training_queue;
DROP PROCEDURE IF EXISTS process_world_crafting_queue;
DROP PROCEDURE IF EXISTS process_world_harvests;

DROP VIEW IF EXISTS tile_training_queue_info;
DROP VIEW IF EXISTS tile_crafting_queue_info;

DROP TABLE IF EXISTS world_crafting_queue_status;
DROP TABLE IF EXISTS world_training_queue_status;
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

CREATE TABLE tile_crafting_queue(
  id SERIAL,
  world_id INT NOT NULL,
  tile_id INT NOT NULL,
  blueprint_id INT NOT NULL,
  amount INT NOT NULL
);

CREATE TABLE world_crafting_queue_status(
	world_id INT NOT NULL,
	queue_id INT NOT NULL,
	blueprint_id INT NOT NULL,
	tile_id INT NOT NULL,
	item_id INT NOT NULL,
	required_amount INT NOT NULL,
	available_amount INT,
	is_present INT NOT NULL,
	go_no_go INT
);

CREATE TABLE world_training_queue_status(
	world_id INT NOT NULL,
	queue_id INT NOT NULL,
	template_id INT NOT NULL,
	tile_id INT NOT NULL,
	item_id INT NOT NULL,
	required_amount INT NOT NULL,
	available_amount INT,
	is_present INT NOT NULL,
	go_no_go INT
);

INSERT INTO unit_templates(id, speed, combat, name) VALUES
(1, 20, 10, 'Grunt'),
(2, 20, 8, 'Archer'),
(3, 15, 8, 'Spearman'),
(4, 50, 8, 'Horseman')
;

INSERT INTO unit_equipment(template_id, item_id, amount) VALUES
(1, 13, 1),
(1, 11, 1),
(2, 12, 1),
(3, 14, 1),
(4, 13, 1),
(4, 4, 1)
;


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


CREATE PROCEDURE process_world_crafting_queue(arg_world_id INT)
LANGUAGE SQL
AS $$
	--Inserting first blueprint in every tile crafting queue into the temporary table along with required and available materials.
	INSERT INTO world_crafting_queue_status(world_id, queue_id, blueprint_id, tile_id, item_id, required_amount, available_amount, is_present)
	SELECT 
		arg_world_id,
		required_items.queue_id, 
		required_items.blueprint_id, 
		required_items.tile_id, 
		required_items.item_id, 
		required_items.amount AS required_amount, 
		tile_inventories.amount AS available_amount,
		CASE WHEN tile_inventories.amount IS NULL THEN 0 WHEN tile_inventories.amount < required_items.amount THEN 0 ELSE 1 END AS verdict
	FROM
	(SELECT required_bps.queue_id, required_bps.blueprint_id, required_bps.tile_id, bp_components.item_id, bp_components.amount FROM
	(select id AS queue_id, tile_id, blueprint_id, amount from (
	select id, tile_id, blueprint_id, amount, ROW_NUMBER() OVER (PARTITION BY tile_id ORDER BY id ASC) AS rn FROM tile_crafting_queue WHERE world_id=arg_world_id) where rn=1) required_bps
	 JOIN 
	(SELECT bc.blueprint_id, bc.item_id, bc.amount FROM blueprints b JOIN blueprint_components bc ON b.id=bc.blueprint_id) bp_components 
	ON required_bps.blueprint_id = bp_components.blueprint_id) required_items 
	LEFT JOIN
	tile_inventories ON required_items.tile_id=tile_inventories.tile_id AND required_items.item_id=tile_inventories.item_id;

	--Checking which blueprints have enough materials to be crafted.
	UPDATE world_crafting_queue_status SET go_no_go=decision.verdict FROM
	(SELECT subq.queue_id, CASE WHEN expected=actual THEN 1 ELSE 0 END AS verdict FROM
	(SELECT 
		queue_id, 
		SUM(is_present) AS expected, 
		count(is_present) AS actual
	FROM world_crafting_queue_status WHERE world_id=arg_world_id GROUP BY queue_id) subq) decision
	WHERE world_crafting_queue_status.queue_id=decision.queue_id;

	--Removing crafting materials by amount
	UPDATE tile_inventories SET amount= tile_inventories.amount - subq.required_amount FROM
		(SELECT 
			ti.tile_id, 
			ti.item_id, 
			wcqs.required_amount
		FROM world_crafting_queue_status wcqs LEFT JOIN tile_inventories ti ON wcqs.tile_id=ti.tile_id AND wcqs.item_id=ti.item_id
		WHERE wcqs.go_no_go=1 AND wcqs.world_id=arg_world_id) subq
	WHERE tile_inventories.tile_id=subq.tile_id AND tile_inventories.item_id=subq.item_id;

	--Adding crafted items to inventories
	INSERT INTO tile_inventories(world_id, tile_id, item_id, amount)
	(SELECT arg_world_id, required_bps.tile_id, b.output_item_id, 1 AS amount FROM
		(SELECT 
			blueprint_id, 
			tile_id 
		FROM world_crafting_queue_status WHERE go_no_go=1 AND world_id=arg_world_id GROUP BY blueprint_id, tile_id) required_bps LEFT JOIN blueprints b ON required_bps.blueprint_id=b.id)
	ON CONFLICT(world_id, tile_id, item_id) DO UPDATE SET amount = tile_inventories.amount + 1;

	--Removing crafting queue blueprints by amount
	UPDATE tile_crafting_queue SET amount = tile_crafting_queue.amount - 1 FROM
	(SELECT queue_id FROM world_crafting_queue_status WHERE go_no_go=1 AND world_id=arg_world_id GROUP BY queue_id) subq
	WHERE tile_crafting_queue.id = subq.queue_id;

	DELETE FROM tile_crafting_queue WHERE amount < 1;
	DELETE FROM tile_inventories WHERE amount < 1;
	DELETE FROM world_crafting_queue_status WHERE world_id=arg_world_id;
$$;


CREATE PROCEDURE process_world_training_queue(arg_world_id INT)
LANGUAGE SQL
AS $$
	--Inserting first template in every tile crafting queue into the temporary table along with required and available materials.
	INSERT INTO world_training_queue_status(world_id, queue_id, template_id, tile_id, item_id, required_amount, available_amount, is_present)
	SELECT 
		arg_world_id,
		required_items.queue_id, 
		required_items.template_id, 
		required_items.tile_id, 
		required_items.item_id, 
		required_items.amount AS required_amount, 
		tile_inventories.amount AS available_amount,
		CASE WHEN tile_inventories.amount IS NULL THEN 0 WHEN tile_inventories.amount < required_items.amount THEN 0 ELSE 1 END AS verdict
	FROM
	(SELECT required_templates.queue_id, required_templates.template_id, required_templates.tile_id, template_components.item_id, template_components.amount FROM
	(select id AS queue_id, tile_id, template_id, amount from (
		select id, tile_id, template_id, amount, ROW_NUMBER() OVER (PARTITION BY tile_id ORDER BY id ASC) AS rn FROM tile_training_queue WHERE world_id=arg_world_id) where rn=1) required_templates
	JOIN 
	(SELECT ue.template_id, ue.item_id, ue.amount FROM unit_templates ut JOIN unit_equipment ue ON ut.id=ue.template_id) template_components
	ON required_templates.template_id = template_components.template_id) required_items 
	LEFT JOIN
	tile_inventories ON required_items.tile_id=tile_inventories.tile_id AND required_items.item_id=tile_inventories.item_id;

	--Checking which templates have enough materials to be crafted.
	UPDATE world_training_queue_status SET go_no_go=decision.verdict FROM
	(SELECT subq.queue_id, CASE WHEN expected=actual THEN 1 ELSE 0 END AS verdict FROM
	(SELECT 
		queue_id, 
		SUM(is_present) AS expected, 
		count(is_present) AS actual
	FROM world_training_queue_status WHERE world_id=arg_world_id GROUP BY queue_id) subq) decision
	WHERE world_training_queue_status.queue_id=decision.queue_id;

	--Removing crafting materials by amount
	UPDATE tile_inventories SET amount= tile_inventories.amount - subq.required_amount FROM
		(SELECT 
			ti.tile_id, 
			ti.item_id, 
			wtqs.required_amount
		FROM world_training_queue_status wtqs LEFT JOIN tile_inventories ti ON wtqs.tile_id=ti.tile_id AND wtqs.item_id=ti.item_id
		WHERE wtqs.go_no_go=1 AND wtqs.world_id=arg_world_id) subq
	WHERE tile_inventories.tile_id=subq.tile_id AND tile_inventories.item_id=subq.item_id;

	--Adding trained units to tiles
	INSERT INTO tile_units(world_id, tile_id, template_id, amount)
	(SELECT arg_world_id, required_templates.tile_id, ut.id, 1 AS amount FROM
		(SELECT 
			template_id, 
			tile_id 
		FROM world_training_queue_status WHERE go_no_go=1 AND world_id=arg_world_id GROUP BY template_id, tile_id) required_templates LEFT JOIN unit_templates ut ON required_templates.template_id=ut.id)
	ON CONFLICT(world_id, tile_id, template_id) DO UPDATE SET amount = tile_units.amount + 1;

	--Removing crafting queue blueprints by amount
	UPDATE tile_training_queue SET amount = tile_training_queue.amount - 1 FROM
	(SELECT queue_id FROM world_training_queue_status WHERE go_no_go=1 AND world_id=arg_world_id GROUP BY queue_id) subq
	WHERE tile_training_queue.id = subq.queue_id;

	DELETE FROM tile_training_queue WHERE amount < 1;
	DELETE FROM tile_inventories WHERE amount < 1;
	DELETE FROM world_training_queue_status WHERE world_id=arg_world_id;
$$;