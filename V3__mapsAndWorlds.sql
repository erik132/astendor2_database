DROP VIEW IF EXISTS world_description;
DROP VIEW IF EXISTS world_tiles_info;
DROP VIEW IF EXISTS world_tile_harvest_info;

DROP TABLE IF EXISTS maps;
DROP TABLE IF EXISTS map_tiles;
DROP TABLE IF EXISTS terrains;
DROP TABLE IF EXISTS races;
DROP TABLE IF EXISTS worlds;
DROP TABLE IF EXISTS world_tiles;
DROP TABLE IF EXISTS map_harvests;
DROP TABLE IF EXISTS world_harvests;

--map is a template, world is the implementation of that template
CREATE TABLE maps (
  id SERIAL PRIMARY KEY,
  xdim INT NOT NULL,
  ydim INT NOT NULL,
  name VARCHAR(30) NOT NULL,
  description TEXT NOT NULL,
  map_file VARCHAR(255) NOT NULL
);

CREATE TABLE map_tiles(
  id INT PRIMARY KEY,
  map_id INT NOT NULL,
  x INT NOT NULL,
  y INT NOT NULL,
  name VARCHAR(255) NOT NULL,
  terrain_id INT NOT NULL,
  race_id INT NOT NULL
);

--amount shows how many units per 100 turns
CREATE TABLE map_harvests(
  tile_id INT NOT NULL,
  item_id INT NOT NULL,
  amount INT NOT NULL,
  PRIMARY KEY (tile_id, item_id)
);

CREATE TABLE worlds(
  id SERIAL PRIMARY KEY,
  name VARCHAR(30) NOT NULL,
  map_id INT NOT NULL,
  harvest_multiplier FLOAT NOT NULL DEFAULT 1.0,
  turn_nr INT NOT NULL DEFAULT 0
);

CREATE TABLE world_tiles(
  id SERIAL PRIMARY KEY,
  map_tile_id INT NOT NULL,
  world_id INT NOT NULL,
  x INT NOT NULL,
  y INT NOT NULL,
  name VARCHAR(255) NOT NULL,
  terrain_id INT NOT NULL,
  race_id INT NOT NULL,
  owner_warlord INT DEFAULT NULL
);

CREATE TABLE world_harvests(
  tile_id INT NOT NULL,
  item_id INT NOT NULL,
  amount INT NOT NULL,
  harvest_meter FLOAT NOT NULL DEFAULT 0.0,
  PRIMARY KEY (tile_id, item_id)
);

CREATE TABLE terrains(
  id INT PRIMARY KEY,
  name VARCHAR(50),
  description TEXT
);

CREATE TABLE races(
  id INT PRIMARY KEY,
  name VARCHAR(50),
  description TEXT
);

CREATE VIEW world_description AS 
SELECT worlds.id AS world_id, 
  worlds.name AS world_name, 
  harvest_multiplier, 
  turn_nr, 
  xdim, 
  ydim, 
  maps.name AS map_name, 
  description AS map_description 
FROM worlds LEFT JOIN maps ON worlds.map_id=maps.id;

CREATE VIEW world_tiles_info AS
SELECT 
  world_tiles.id AS tile_id,
  world_id, 
  x, 
  y, 
  world_tiles.name AS tile_name, 
  terrains.name AS terrain_name, 
  races.name AS race_name 
FROM world_tiles LEFT JOIN terrains ON world_tiles.terrain_id=terrains.id 
LEFT JOIN races ON world_tiles.race_id=races.id;

CREATE VIEW world_tile_harvest_info AS
SELECT 
  tile_id, 
  item_id, 
  amount,
  items.name AS item_name 
FROM world_harvests JOIN items ON world_harvests.item_id=items.id;

CREATE VIEW world_tiles_harvest_info AS
SELECT 
  wt.world_id,
  wh.tile_id, 
  wh.item_id, 
  wh.harvest_meter
  FROM world_tiles wt JOIN world_harvests wh ON wt.id=wh.tile_id WHERE wt.world_id=1;

INSERT INTO races (id, name, description) VALUES
  (1, 'Orcs', 'A warrior race usually living on tough environments like mountains, hills or swamps'),
  (2, 'Dwarves', 'Short and strong miners usually prefering mountains'),
  (3, 'High elves', 'Magical beings that usually live in forests or grasslands'),
  (4, 'Halflings', 'Little peaceful creatures who prefer plains. They make good farmers'),
  (5, 'Nomads', 'Demon like race, who prefers deserts and plains. Excellent herd keepers');

INSERT INTO terrains (id, name, description) VALUES
  (1,'Plains', 'Flat land, good for herding'),
  (2,'Mountains', 'Rocky area, rich in minerals'),
  (3,'Forest', 'Trees everywhere'),
  (4,'Desert', 'Sand everywhere'),
  (5,'Grassland', 'Animals love it, plants love it even more'),
  (6,'Wetlands', 'random resources and wierd stuff in general'),
  (7,'Hills', 'Elevated ground with some minerals');

INSERT INTO maps (xdim, ydim, name, description, map_file) VALUES
  (3,3,'Moria', 'Initial 3x3 test map', 'moria.jpg'),
  (3,3,'Montreal', 'Second 3x3 test map', 'montreal.jpg');

INSERT INTO map_tiles(id, map_id, x, y, name, terrain_id, race_id) VALUES
  (1,1,0,0, 'Chaos mountain 1', 2,1),
  (2,1,1,0, 'chaos mountain 2', 2,2),
  (3,1,2,0, 'Mount Doom', 2, 1),
  (4,1,0,1, 'Plains 1', 1, 4),
  (5,1,1,1, 'chaos mountains 3', 2, 2),
  (6,1,2,1, 'Forest 1', 3, 3),
  (7,1,0,2, 'Kharakum Desert', 4, 5),
  (8,1,1,2, 'Plains 2', 1, 4),
  (9,1,2,2, 'Elvin Forest', 3, 3);

INSERT INTO map_tiles(id, map_id, x, y, name, terrain_id, race_id) VALUES
  (10,2,0,0, 'Great plains', 1, 5),
  (11,2,1,0, 'Northern crossing', 1, 4),
  (12,2,2,0, 'The delta', 6, 1),
  (13,2,0,1, 'Western plains', 1, 5),
  (14,2,1,1, 'Royal mountains', 2, 2),
  (15,2,2,1, 'Eastern hills', 7, 2),
  (16,2,0,2, 'Lazarus Wetlands', 6, 1),
  (17,2,1,2, 'Guay ruins', 7, 3),
  (18,2,2,2, 'Evergrowth', 5, 3);

INSERT INTO map_harvests (tile_id, item_id, amount) VALUES
  (1, 1, 12),
  (2, 1, 12),
  (2, 2, 25),
  (3, 1, 25),
  (4, 5, 12),
  (5, 2, 12),
  (6, 3, 25),
  (7, 10, 20),
  (8, 4, 18),
  (9, 3, 40);

INSERT INTO map_harvests(tile_id, item_id, amount) VALUES
  (10, 4, 20),
  (10, 5, 20),
  (11, 5, 15),
  (12, 4, 10),
  (12, 5, 10),
  (12, 1, 8),
  (13, 2, 8),
  (13, 5, 20),
  (14, 1, 35),
  (14, 2, 35),
  (15, 1, 20),
  (15, 2, 20),
  (16, 1, 15),
  (17, 2, 10),
  (17, 3, 10),
  (18, 3, 35);

INSERT INTO worlds (name, map_id) VALUES
  ('Pernau', 2);

INSERT INTO world_tiles(world_id, map_tile_id, x, y, name, terrain_id, race_id) SELECT 1, id, x, y, name, terrain_id, race_id FROM map_tiles where map_id=2;

INSERT INTO world_harvests(tile_id, item_id, amount)
SELECT world_tiles.id, map_harvests.item_id, map_harvests.amount FROM world_tiles JOIN map_harvests ON world_tiles.map_tile_id=map_harvests.tile_id WHERE world_tiles.world_id=1;