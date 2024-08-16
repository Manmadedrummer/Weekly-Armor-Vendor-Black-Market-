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