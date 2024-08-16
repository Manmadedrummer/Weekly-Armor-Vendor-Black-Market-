CREATE TABLE IF NOT EXISTS `black_market_armor_sets` (
    `class` INT NOT NULL,
    `item_id` INT NOT NULL,
    `name` VARCHAR(255) NOT NULL,
    `item_set_id` INT NOT NULL,
    `set_name` VARCHAR(255) NOT NULL,
    PRIMARY KEY (`item_id`)
);