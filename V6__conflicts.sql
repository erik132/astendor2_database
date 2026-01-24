DROP PROCEDURE IF EXISTS resolve_conflicts;
DROP FUNCTION IF EXISTS escape_warlord;

DROP TABLE IF EXISTS conflict_warlords;
DROP TABLE IF EXISTS conflict_tiles;
DROP TABLE IF EXISTS conflicted_units;
DROP TABLE IF EXISTS conflict_sides;
DROP TABLE IF EXISTS units_in_transit;
DROP TABLE IF EXISTS items_in_transit;

--Warlords who are directly in the battle.
CREATE TABLE conflict_warlords(
	world_id INT NOT NULL,
	warlord_id INT NOT NULL,
	tile_id INT NOT NULL
);

CREATE TABLE conflict_tiles(
	world_id INT NOT NULL,
	tile_id INT NOT NULL,
	xcoord INT NOT NULL,
	ycoord INT NOT NULL
);

--If warlord_id IS NULL, the unit is attached to the tile, otherwise it is attached to the warlord who is located on this tile.
CREATE TABLE conflicted_units(
	world_id INT NOT NULL,
	tile_id INT NOT NULL,
	warlord_id INT,
	template_id INT NOT NULL,
	amount INT NOT NULL,
	owner_warlord_id INT NOT NULL,
	side_id INT DEFAULT NULL,
	new_amount INT 
);

--warlord_id as side owner id.
CREATE TABLE conflict_sides(
	world_id INT NOT NULL,
	side_id INT NOT NULL,
	tile_id INT NOT NULL,
	full_combat_power INT NOT NULL,
	reduced_combat_power INT,
	attack_power INT,
	distributed_attack_power INT,
	won_fight INT DEFAULT 0
);

--Units that are moving from tile to tile.
CREATE TABLE units_in_transit(
	target_tile_id INT NOT NULL,
	template_id INT NOT NULL,
	amount INT NOT NULL,
	source_target_id INT NOT NULL,
	turns_left INT NOT NULL
);

--Items that are moving from tile to tile.
CREATE TABLE items_in_transit(
	target_tile_id INT NOT NULL,
	item_id INT NOT NULL,
	amount INT NOT NULL,
	source_target_id INT NOT NULL,
	turns_left INT NOT NULL
);

--Chooses a random direction and moves the warlord there. Minds the map borders.
CREATE FUNCTION escape_warlord(arg_warlord_id INT) RETURNS INT
AS $$
	DECLARE 
		x_max INT;
		y_max INT;
		x_move INT := 0;
		y_move INT := 0;
		direction1 INT;
		direction2 INT;
		x_current INT;
		y_current INT;
	BEGIN
	SELECT INTO x_max, y_max 
		maps.xdim - 1, maps.ydim - 1 
	FROM worlds JOIN maps ON worlds.map_id=maps.id AND worlds.id=arg_warlord_id;

	SELECT INTO direction1, direction2 ROUND(RANDOM() + 1), ROUND(RANDOM() + 1);
	SELECT INTO x_current, y_current x, y FROM warlords WHERE id=arg_warlord_id;

	IF direction1=1 THEN
		IF direction2 = 1 THEN
			x_move = 1;
			IF x_current=x_max THEN
				x_move = -1;
			END IF;
		ELSE
			x_move = -1;
			IF x_current=0 THEN
				x_move = 1;
			END IF;
		END IF;
	ELSE
		IF direction2 = 1 THEN
			y_move = 1;
			IF y_current=y_max THEN
				y_move = -1;
			END IF;
		ELSE
			y_move = -1;
			IF y_current=0 THEN
				y_move = 1;
			END IF;
		END IF;
	END IF;

	UPDATE warlords SET x=x+x_move, y=y+y_move WHERE id=arg_warlord_id;
	RETURN 0;
	END;
$$ LANGUAGE PLPGSQL;

CREATE PROCEDURE resolve_conflicts(arg_world_id INT)
LANGUAGE SQL
AS $$
	--Which tiles are having an ongoing battle
	INSERT INTO conflict_tiles(world_id, tile_id, xcoord, ycoord)
	SELECT 
		arg_world_id AS world_id,
		wt.id AS defending_tile_id,
		wt.x,
		wt.y 
	FROM warlords w LEFT JOIN world_tiles wt ON w.x=wt.x AND w.y=wt.y WHERE wt.owner_warlord IS NOT NULL AND wt.owner_warlord != w.id AND wt.world_id=arg_world_id;

	--List all warlords who are part of an ongoing battle.
	INSERT INTO conflict_warlords(world_id, warlord_id, tile_id)
	SELECT 
		arg_world_id AS world_id, 
		w.id AS warlord_id, 
		ct.tile_id 
	FROM conflict_tiles ct JOIN warlords w ON ct.xcoord=w.x AND ct.ycoord=w.y AND ct.world_id=arg_world_id;


	--Add all warlord carried units into conflict
	INSERT INTO conflicted_units(world_id, tile_id, warlord_id, template_id, amount, owner_warlord_id)
	SELECT 
		arg_world_id AS world_id, 
		cw.tile_id, 
		cw.warlord_id, 
		wu.template_id, 
		wu.amount, 
		cw.warlord_id 
	FROM conflict_warlords cw JOIN warlord_units wu ON cw.warlord_id=wu.warlord_id WHERE cw.world_id=arg_world_id;

	--Add all tile units into conflict
	INSERT INTO conflicted_units(world_id, tile_id, warlord_id, template_id, amount, owner_warlord_id)
	SELECT
		arg_world_id AS world_id,
		ct.tile_id,
		NULL,
		tu.template_id,
		tu.amount,
		wt.owner_warlord
	FROM conflict_tiles ct JOIN world_tiles wt ON ct.tile_id=wt.id JOIN tile_units tu ON ct.tile_id=tu.tile_id;

	--Setting the side for each unit group.
	UPDATE conflicted_units SET side_id = subq.rn FROM
	(SELECT owner_warlord_id, tile_id, ROW_NUMBER() OVER (PARTITION BY tile_id ORDER BY owner_warlord_id ASC) AS rn FROM 
	(SELECT owner_warlord_id, tile_id FROM conflicted_units WHERE world_id=arg_world_id GROUP BY owner_warlord_id, tile_id)) subq
	WHERE conflicted_units.owner_warlord_id = subq.owner_warlord_id;

	--calculating total combat power for all sides.
	INSERT INTO conflict_sides(world_id, side_id, tile_id, full_combat_power)
	SELECT 
		arg_world_id AS world_id, 
		cu.side_id, 
		cu.tile_id, 
		SUM(cu.amount * ut.combat) AS total_combat 
	FROM conflicted_units cu JOIN unit_templates ut ON cu.template_id=ut.id WHERE cu.world_id=arg_world_id GROUP BY cu.side_id, cu.tile_id;

	--Combat power is HP. Attack is 1/3 of combat power. 
	--Calculate attack power and distributed attack power for each side.
	UPDATE conflict_sides SET attack_power = subq.attack_power, distributed_attack_power = subq.distributed_attack_power FROM
	(SELECT attack_power / (amount_of_sides - 1) AS distributed_attack_power, attacks.attack_power, attacks.amount_of_sides, attacks.side_id, attacks.tile_id FROM
	(SELECT full_combat_power / 3 AS attack_power, amount_of_sides, cs.side_id, side_count.tile_id FROM
	(SELECT count(side_id) AS amount_of_sides, tile_id FROM conflict_sides WHERE world_id=arg_world_id GROUP BY tile_id) side_count JOIN conflict_sides cs ON side_count.tile_id=cs.tile_id) attacks) subq
	WHERE conflict_sides.world_id=arg_world_id AND conflict_sides.tile_id=subq.tile_id AND conflict_sides.side_id=subq.side_id;

	--Distrubute attack power between sides and reduce their combat power by that amount.
	UPDATE conflict_sides SET reduced_combat_power = conflict_sides.full_combat_power - subq.into_hp FROM
	(SELECT attack_sum.total_attack_power, attack_sum.total_attack_power - cs.distributed_attack_power AS into_hp, attack_sum.tile_id, cs.side_id FROM
	(SELECT 
		SUM(distributed_attack_power) AS total_attack_power, 
		tile_id 
	FROM conflict_sides WHERE world_id=arg_world_id GROUP BY tile_id) attack_sum JOIN conflict_sides cs ON attack_sum.tile_id=cs.tile_id) subq
	WHERE conflict_sides.tile_id=subq.tile_id AND conflict_sides.side_id=subq.side_id;

	--calculate winning side
	UPDATE conflict_sides SET won_fight = arg_world_id FROM
	(SELECT MIN(full_combat_power - reduced_combat_power) AS min_lost, tile_id FROM conflict_sides WHERE world_id=arg_world_id GROUP BY tile_id) subq
	WHERE subq.min_lost = conflict_sides.full_combat_power - conflict_sides.reduced_combat_power AND conflict_sides.tile_id=subq.tile_id;

	--If we have multiple winners, then everyone loses.
	UPDATE conflict_sides cs SET won_fight=0 FROM
	(SELECT 
		SUM(won_fight) AS draw_check, 
		tile_id 
	FROM conflict_sides WHERE world_id=arg_world_id GROUP BY tile_id) sum_fight 
	WHERE cs.tile_id=sum_fight.tile_id AND sum_fight.draw_check > arg_world_id;

	--Corrections
	UPDATE conflict_sides SET reduced_combat_power = 0 WHERE reduced_combat_power < 0 AND world_id=arg_world_id;

	--Calulate missing combat power for each unit type and set new amounts based on that.
	UPDATE conflicted_units SET new_amount=conflicted_units.amount - (missing_combat_power / subq.combat)::INT FROM
	(SELECT 
		(unit_info.amount * unit_info.combat)::FLOAT / reduced_power.full_combat_power::FLOAT * reduced_power.decayed_combat_power::FLOAT AS missing_combat_power, 
		reduced_power.tile_id, 
		unit_info.amount, 
		unit_info.combat, 
		unit_info.side_id,
		unit_info.template_id
	FROM
	(SELECT cu.amount, ut.combat, cu.tile_id, cu.side_id, cu.template_id FROM conflicted_units cu JOIN unit_templates ut ON cu.template_id=ut.id WHERE cu.world_id=arg_world_id) unit_info
	JOIN 
	(SELECT 
		full_combat_power - reduced_combat_power AS decayed_combat_power, 
		full_combat_power,
		tile_id,
		side_id
	FROM conflict_sides WHERE world_id=arg_world_id) reduced_power 
	ON reduced_power.tile_id=unit_info.tile_id AND reduced_power.side_id=unit_info.side_id) subq
	WHERE conflicted_units.tile_id=subq.tile_id AND conflicted_units.template_id=subq.template_id;


	--If the units on the defending tile lost, their amounts are turned to 0.
	UPDATE conflicted_units cu SET amount = 0 FROM
	(SELECT 
		cu.template_id, 
		cu.warlord_id, 
		cs.tile_id, 
		cs.side_id,
		cu.amount,
		cs.won_fight 
	FROM conflicted_units cu JOIN conflict_sides cs ON cu.world_id=arg_world_id AND cu.tile_id=cs.tile_id AND cu.side_id=cs.side_id AND cu.warlord_id IS NULL) subq
	WHERE cu.tile_id=subq.tile_id AND cu.template_id=subq.template_id AND cu.warlord_id IS NULL AND subq.won_fight=0;

	--Float is not precise. Stuff like this happens
	UPDATE conflicted_units SET amount = 0 WHERE world_id=arg_world_id AND amount < 0;

	--Set new amounts to warlord units
	UPDATE warlord_units SET amount=subq.new_amount FROM
	(SELECT 
		cu.warlord_id, 
		cu.tile_id, 
		cu.new_amount,
		cu.template_id 
	FROM conflicted_units cu JOIN warlord_units wu ON cu.warlord_id=wu.warlord_id AND cu.template_id=wu.template_id WHERE cu.world_id=arg_world_id) subq
	WHERE warlord_units.world_id=arg_world_id AND warlord_units.warlord_id=subq.warlord_id AND warlord_units.template_id=subq.template_id;

	--Set new amounts to tile units
	UPDATE tile_units SET amount=subq.new_amount FROM
	(SELECT 
		cu.tile_id, 
		cu.new_amount, 
		cu.template_id 
	FROM conflicted_units cu JOIN tile_units tu ON cu.tile_id=tu.tile_id AND cu.template_id=tu.template_id WHERE cu.world_id=arg_world_id AND cu.warlord_id IS NULL) subq
	WHERE tile_units.tile_id=subq.tile_id AND tile_units.template_id=subq.template_id;

	--Make the losing warlords move somewhere else
	SELECT warlord_id, CASE WHEN won_fight=0 THEN escape_warlord(warlord_id) ELSE 0 END AS warlord_move FROM
	(SELECT warlord_id, tile_id, side_id FROM conflicted_units WHERE world_id=arg_world_id AND warlord_id IS NOT NULL GROUP BY warlord_id, tile_id, side_id) participating_warlords
	JOIN 
	conflict_sides cs ON participating_warlords.tile_id=cs.tile_id AND participating_warlords.side_id=cs.side_id AND cs.won_fight=0;

	--Change owenership if the winning side is not the owner.
	UPDATE world_tiles wt SET owner_warlord=subq.owner_warlord_id FROM
	(SELECT 
		cs.tile_id,
		cu.owner_warlord_id,
		cs.side_id, 
		cs.won_fight
	FROM conflict_sides cs JOIN conflicted_units cu ON cs.tile_id=cu.tile_id AND cs.side_id=cu.side_id AND cs.world_id=arg_world_id 
	GROUP BY cs.tile_id, cu.owner_warlord_id, cs.side_id, cs.won_fight) subq
	WHERE wt.id=subq.tile_id AND subq.won_fight=arg_world_id;

	DELETE FROM conflict_warlords WHERE world_id=arg_world_id;
	DELETE FROM conflict_tiles WHERE world_id=arg_world_id;
	DELETE FROM conflicted_units WHERE world_id=arg_world_id;
	DELETE FROM conflict_sides WHERE world_id=arg_world_id;

	DELETE FROM warlord_units WHERE amount=0;
	DELETE FROM tile_units WHERE amount=0;
$$;

