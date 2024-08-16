SET GLOBAL event_scheduler = ON;

DROP EVENT IF EXISTS UpdateBlackMarketEvent;

CREATE EVENT IF NOT EXISTS UpdateBlackMarketEvent
ON SCHEDULE EVERY 1 WEEK
DO
    CALL UpdateBlackMarketSets();