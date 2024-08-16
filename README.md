# Black-Market-Vendor

Adds a Vendor who sells 1 Armor Set per class and rotates them out weekly.

The SQL table's (`black_market_armor_sets` `black_market_current_set`) is created in your "World" folder. The Lua script for the NPC handles randomly getting the Armor sets and allows players to purchase them for 100 Araxia Tokens (Item ID: 910001).


One table for all the armor sets and one table for the current sets (resets weekly).
<br>
<br>
### Step 1: Create `black_market_armor_sets` Table and populate it
(A. Create `black_market_armor_sets` first and populate it, you can use the SQL provided in this repo.)

```sql
CREATE TABLE IF NOT EXISTS `black_market_armor_sets` (
    `class` INT NOT NULL,
    `item_id` INT NOT NULL,
    `name` VARCHAR(255) NOT NULL,
    `item_set_id` INT NOT NULL,
    `set_name` VARCHAR(255) NOT NULL,
    PRIMARY KEY (`item_id`)
);
```
<br>
<br>

### Step 2: Populate `black_market_armor_sets` Table

EXAMPLE:

```sql
INSERT INTO `black_market_armor_sets` (`class`, `item_id`, `name`, `item_set_id`, `set_name`) VALUES
    (11, 23294, 'Knight-Captain''s Dragonhide Chestpiece', 551, 'Lieutenant Commander''s Refuge'),
    (11, 23295, 'Knight-Captain''s Dragonhide Leggings', 551, 'Lieutenant Commander''s Refuge'),
    (11, 23280, 'Knight-Lieutenant''s Dragonhide Grips', 551, 'Lieutenant Commander''s Refuge'),
    (11, 23281, 'Knight-Lieutenant''s Dragonhide Treads', 551, 'Lieutenant Commander''s Refuge'),
    (11, 23308, 'Lieutenant Commander''s Dragonhide Headguard', 551, 'Lieutenant Commander''s Refuge'),
    (11, 23309, 'Lieutenant Commander''s Dragonhide Shoulders', 551, 'Lieutenant Commander''s Refuge'),
    (3, 16425, 'Knight-Captain''s Chain Hauberk', 550, 'Lieutenant Commander''s Pursuance'),
    (3, 16426, 'Knight-Captain''s Chain Leggings', 550, 'Lieutenant Commander''s Pursuance'),
    (3, 23279, 'Knight-Lieutenant''s Chain Vices', 550, 'Lieutenant Commander''s Pursuance'),
    (3, 16401, 'Knight-Lieutenant''s Chain Boots', 550, 'Lieutenant Commander''s Pursuance'),
    (3, 23306, 'Lieutenant Commander''s Chain Helm', 550, 'Lieutenant Commander''s Pursuance'),
    (3, 23307, 'Lieutenant Commander''s Chain Shoulders', 550, 'Lieutenant Commander''s Pursuance');
```

## Step 3: Create `black_market_current_set` Table
This table will hold the current week's selected armor sets for each class.

```sql
CREATE TABLE IF NOT EXISTS `black_market_current_set` (
    `class` INT NOT NULL,
    `item_set_id` INT NOT NULL,
    `set_name` VARCHAR(255) NOT NULL,
    PRIMARY KEY (`class`)
);
```

## Step 4: Create the Stored Procedure
The stored procedure will update the `black_market_current_set` table with random sets each week.

```sql
CREATE PROCEDURE UpdateBlackMarketSets()
BEGIN
    -- Clear the current sets table
    DELETE FROM black_market_current_set;

    -- Insert new random sets for each class
    INSERT INTO black_market_current_set (class, item_set_id, set_name)
    SELECT class, item_set_id, set_name
    FROM (
        SELECT class, item_set_id, set_name,
               ROW_NUMBER() OVER (PARTITION BY class ORDER BY RAND()) AS rn
        FROM black_market_armor_sets
    ) AS temp
    WHERE temp.rn = 1;
END;
```

## Step 5: Create the Event Scheduler
Set up the event scheduler to call the stored procedure every week.

```sql
SET GLOBAL event_scheduler = ON;

DROP EVENT IF EXISTS UpdateBlackMarketEvent;

CREATE EVENT IF NOT EXISTS UpdateBlackMarketEvent
ON SCHEDULE EVERY 1 WEEK
DO
    CALL UpdateBlackMarketSets();
```


## Step 6: Test the Stored Procedure Manually
Manually call the stored procedure to ensure it works as expected.

```sql
CALL UpdateBlackMarketSets();
```

<br>

## Lua Script for the NPC
Here’s the Lua script that interacts with the above SQL tables. Make sure this script is correctly placed in your server’s Lua scripts directory.

```lua
local BLACK_MARKET_NPC_ID = 101111 -- Replace with your NPC's ID
local ARAXIA_TOKEN_ID = 910001 -- ID Tokens or Currency
local SET_COST = 100 -- Cost of each armor set in Araxia Tokens
local UPDATE_INTERVAL = 604800 -- 1 week in seconds

local CLASS_NAMES_AND_ICONS = {
    [11] = {name = "Druid", icon = "Interface\\icons\\classicon_druid"},
    [3] = {name = "Hunter", icon = "Interface\\icons\\classicon_hunter"},
    [8] = {name = "Mage", icon = "Interface\\icons\\classicon_mage"},
    [2] = {name = "Paladin", icon = "Interface\\icons\\classicon_paladin"},
    [5] = {name = "Priest", icon = "Interface\\icons\\classicon_priest"},
    [4] = {name = "Rogue", icon = "Interface\\icons\\classicon_rogue"},
    [7] = {name = "Shaman", icon = "Interface\\icons\\classicon_shaman"},
    [9] = {name = "Warlock", icon = "Interface\\icons\\classicon_warlock"},
    [1] = {name = "Warrior", icon = "Interface\\icons\\classicon_warrior"},
    [6] = {name = "Death Knight", icon = "Interface\\icons\\spell_deathknight_classicon"}
}

local selectedSets = {}

local function UpdateBlackMarketSets()
    selectedSets = {}
    local query = WorldDBQuery("SELECT class, item_set_id, set_name FROM black_market_current_set")
    if query then
        repeat
            local class = query:GetInt32(0)
            local item_set_id = query:GetInt32(1)
            local set_name = query:GetString(2)
            selectedSets[class] = { item_set_id = item_set_id, set_name = set_name }
        until not query:NextRow()
    end
end

UpdateBlackMarketSets()

local function BlackMarket_OnGossipHello(event, player, creature)
    player:GossipClearMenu()
    for classId, classData in pairs(CLASS_NAMES_AND_ICONS) do
        local icon = "|T" .. classData.icon .. ":25|t"
        player:GossipMenuAddItem(0, icon .. " View " .. classData.name .. " armor set", 0, classId)
    end
    player:GossipSendMenu(1, creature)
end

local function ShowAvailableSets(player, creature, classId)
    local selectedSet = selectedSets[classId]
    if selectedSet then
        local set_name = selectedSet.set_name
        local item_set_id = selectedSet.item_set_id
        
        player:GossipClearMenu()
        player:GossipMenuAddItem(0, set_name .. " (100 Araxia Tokens)", 0, 1000 + item_set_id)
        player:GossipMenuAddItem(0, "Back", 0, 999) -- Add an option to go back to the class menu
        player:GossipSendMenu(1, creature)
    else
        player:SendNotification("No set available for this class.")
        BlackMarket_OnGossipHello(event, player, creature)
    end
end

local function BlackMarket_OnGossipSelectOption(event, player, creature, sender, item_set_id, code)
    local token_count = player:GetItemCount(ARAXIA_TOKEN_ID)
    if token_count >= SET_COST then
        local items_query = WorldDBQuery("SELECT item_id FROM black_market_armor_sets WHERE item_set_id = " .. item_set_id)
        if items_query then
            repeat
                local item_id = items_query:GetInt32(0)
                player:AddItem(item_id, 1)
            until not items_query:NextRow()
        end
        player:RemoveItem(ARAXIA_TOKEN_ID, SET_COST)
        player:SendNotification("You have purchased the armor set for " .. SET_COST .. " Araxia Tokens.")
    else
        player:SendNotification("You do not have enough Araxia Tokens.")
    end
    player:GossipComplete()
end

local function BlackMarket_OnGossipSelect(event, player, creature, sender, intid, code)
    if intid == 999 then
        BlackMarket_OnGossipHello(event, player, creature) -- Go back to the class menu
    elseif intid >= 1000 then
        BlackMarket_OnGossipSelectOption(event, player, creature, sender, intid - 1000, code) -- Handle item purchase
    elseif CLASS_NAMES_AND_ICONS[intid] then
        ShowAvailableSets(player, creature, intid) -- Show armor sets for the selected class
    end
end

RegisterCreatureGossipEvent(BLACK_MARKET_NPC_ID, 1, BlackMarket_OnGossipHello) -- GOSSIP_HELLO
RegisterCreatureGossipEvent(BLACK_MARKET_NPC_ID, 2, BlackMarket_OnGossipSelect) -- GOSSIP_SELECT
```



### Summary of Setup

1. **Tables:**
    - `black_market_armor_sets`: Contains all possible armor sets and items.
    - `black_market_current_set`: Contains the current week's selected armor sets.

2. **Stored Procedure:**
    - `UpdateBlackMarketSets`: Updates the current sets table with one random armor set per class each week.

3. **Event Scheduler:**
    - `UpdateBlackMarketEvent`: Calls the stored procedure weekly to refresh the available sets.

4. **Lua Script:**
    - Manages the NPC interactions, displays the current sets, and handles purchases.

By following these steps, you ensure that the Black Market NPC is correctly set up to provide players with a weekly rotating selection of armor sets.
