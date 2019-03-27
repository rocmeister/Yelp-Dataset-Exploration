/******************** Preference Prediction ********************/

--------------- 1. Set U ---------------

DROP TABLE IF EXISTS userCategory;
CREATE TABLE userCategory (
    userId VARCHAR(32),
    category VARCHAR(32),
    PRIMARY KEY(userId, category)
);

WITH userCategoryMetric AS(
  SELECT ur.userId, r.category,
         ROUND(0.5 * COUNT(ur.stars) + 0.5 * AVG(ur.stars), 2) AS metric
  FROM userReview ur JOIN restaurant r ON ur.restaurantId = r.restaurantId
  GROUP BY ur.userId, r.category
)
INSERT INTO userCategory
SELECT temp.userId, temp.category
FROM (SELECT userId, category,
             ROW_NUMBER() OVER (PARTITION BY userId
                                ORDER BY metric DESC) AS rowNum
      FROM userCategoryMetric) AS temp
WHERE temp.rowNum <= 20
ORDER BY temp.userId;

--------------- 2. Recommend by city ---------------

-- (a) Identify user's city
DROP TABLE IF EXISTS userCity;
CREATE TABLE userCity (
    userId VARCHAR(32),
    city VARCHAR(64),
    state VARCHAR(4)
);

WITH userCityTotal AS(
  SELECT ur.userId, r.state, r.city, COUNT(ur.reviewId) as numReview
  FROM userReview ur JOIN restaurant r ON ur.restaurantId = r.restaurantId
  GROUP BY ur.userId, r.state, r.city
)
INSERT INTO userCity
SELECT temp.userId, temp.city, temp.state
FROM (SELECT *, ROW_NUMBER() OVER (PARTITION BY userId
                                   ORDER BY numReview DESC) AS rowNum
      FROM userCityTotal) AS temp
WHERE temp.rowNum <= 1
ORDER BY temp.userId;

--(b) Set C
DROP TABLE IF EXISTS highRatedCategoryPerCity;
CREATE TABLE highRatedCategoryPerCity (
 state VARCHAR(4),
 city VARCHAR(64),
 category VARCHAR(64),
 PRIMARY KEY(state, city, category)
);

WITH restaurantCategory AS(
  SELECT state, city, category,
         ROUND(AVG(stars), 2) AS avgStar, COUNT(*) AS count
  FROM restaurant r
  WHERE city IS NOT NULL AND state IS NOT NULL
  GROUP BY (state, city, category)
),
topCategories AS(
  SELECT state, city, category, avgStar
  FROM (SELECT *, ROW_NUMBER() over (PARTITION BY (state, city)
                                     ORDER BY avgStar DESC) AS rowId
        FROM restaurantCategory) AS s
  WHERE rowId <= 20
)
INSERT INTO highRatedCategoryPerCity
  SELECT state, city, category
  FROM topCategories;


DROP TABLE IF EXISTS cityRecommendation;
CREATE TABLE cityRecommendation(
  userId VARCHAR(32),
  cityCategory VARCHAR(32),
  PRIMARY KEY(userId, cityCategory)
);

INSERT INTO cityRecommendation
SELECT uc.userId, hr.category
FROM userCity uc, highRatedCategoryPerCity hr
WHERE uc.state = hr.state AND uc.city = hr.city;

--(c) Calculate the Jaccard index between U and C
DROP TABLE IF EXISTS cityRecommendationJaccardIndex;
CREATE TABLE cityRecommendationJaccardIndex(
  userId VARCHAR(32),
  index NUMERIC(4, 3),
  PRIMARY KEY(userId)
);

CREATE OR REPLACE FUNCTION getCityRecommendationJaccardIndex(id VARCHAR(32))
RETURNS VOID AS
$$
DECLARE
  intersectionSize INTEGER;
  unionSize INTEGER;
BEGIN
  intersectionSize = (SELECT COUNT(*)
                      FROM (SELECT u.category
                            FROM userCategory u
                            WHERE u.userId = id
                            INTERSECT
                            SELECT c.cityCategory
                            FROM cityRecommendation c
                            WHERE c.userId = id) AS temp);
  unionSize = (SELECT COUNT(*)
               FROM (SELECT u.category
                     FROM userCategory u
                     WHERE u.userId = id
                     UNION
                     SELECT c.cityCategory
                     FROM cityRecommendation c
                     WHERE c.userId = id) AS temp);

  INSERT INTO cityRecommendationJaccardIndex
  VALUES(id, ROUND(intersectionSize * 1.0 / unionSize));
END;
$$
LANGUAGE plpgsql;

SELECT getCityRecommendationJaccardIndex(userId)
FROM (SELECT DISTINCT u.userId
      FROM userReview u) AS temp;

--(d) Get the average of Jaccard Indices
SELECT ROUND(AVG(index), 4)
FROM cityRecommendationJaccardIndex;
-- 0.0014


--------------- 3. Recommend by friend ---------------

-- (a) Find friend cycles
-- use index to make it run faster
CREATE INDEX yelpUserId ON yelpUser(userId);
CREATE INDEX friendUserId ON friend(userId);
CREATE INDEX friendFriendId ON friend(friendId);

-- table to hold unvisited users
DROP TABLE IF EXISTS unVisited;
CREATE TEMPORARY TABLE unVisited(
  userId VARCHAR(32),
  PRIMARY KEY(userId)
);

-- table to hold users of one block
DROP TABLE IF EXISTS block;
CREATE TEMPORARY TABLE block(
  userId VARCHAR(32),
  PRIMARY KEY(userId)
);

-- getFriendCycles() function
CREATE OR REPLACE FUNCTION getFriendCycles()
RETURNS TABLE(friendCycleId INTEGER, userId VARCHAR(32)) AS
$$
DECLARE
  unVisitedNum INTEGER;
  blockSizeBefore INTEGER;
  blockSizeAfter INTEGER;
  blockId INTEGER DEFAULT 1;
BEGIN
  -- mark all users as unvisited
  INSERT INTO unVisited SELECT u.userId FROM yelpUser u;
  unVisitedNum = (SELECT COUNT(*) FROM unVisited);

  WHILE unVisitedNum > 0
  LOOP
    -- insert a user into the block table
    INSERT INTO block SELECT u.userId FROM unVisited u LIMIT 1;

    -- loop until all friended users are inserted into the block table
    blockSizeBefore = -1;
    blockSizeAfter = 0;
    WHILE blockSizeBefore != blockSizeAfter
    LOOP
      -- update blockSizeBefore
      blockSizeBefore = (SELECT COUNT(*) FROM block);

      INSERT INTO block
        SELECT DISTINCT u.userId
        FROM unVisited u
        WHERE (u.userId IN (SELECT f.friendId
                            FROM friend f, block b
                            WHERE f.userId = b.userId) OR
               u.userId IN (SELECT f.userId
                            FROM friend f, block b
                            WHERE f.friendId = b.userId))
              AND u.userId NOT IN (SELECT b.userId FROM block b);

      -- remove inserted users
      DELETE FROM unVisited u
      WHERE u.userId IN (SELECT b.userId FROM block b);

      -- update blockSizeAfter
      blockSizeAfter = (SELECT COUNT(*) FROM block);
    END LOOP;

    -- we are only interested in friend cycle with more than 1 person
    IF blockSizeAfter > 1 THEN
      RAISE NOTICE 'Friend Cycle %', blockId;
      RETURN QUERY
        SELECT blockId, u.userId
        FROM yelpUser u, block b
        WHERE u.userId = b.userId
        ORDER BY blockId;
      blockId = blockId + 1;
    END IF;

    -- clear block table
    TRUNCATE TABLE block;

    -- update unVisitedNum
    unVisitedNum = (SELECT COUNT(*) FROM unVisited);
  END LOOP;
END;
$$
LANGUAGE plpgsql;

DROP TABLE IF EXISTS friendCycle;
CREATE TABLE friendCycle(
  friendCycleId INTEGER,
  userId VARCHAR(32),
  PRIMARY KEY(friendCycleId, userId)
);

INSERT INTO friendCycle
  SELECT * FROM getFriendCycles();

-- (b) Set F
DROP TABLE IF EXISTS friendRecommendation;
CREATE TABLE friendRecommendation(
  userId VARCHAR(32),
  friendCategory VARCHAR(32),
  PRIMARY KEY(userId, friendCategory)
);

-- id is an input userId
CREATE OR REPLACE FUNCTION getFriendRecommendation(id VARCHAR(32))
RETURNS VOID AS
$$
DECLARE
BEGIN
  WITH friendCategory AS(
    SELECT uc.category
    FROM friendCycle f, userCategory uc
    WHERE f.userId = uc.userId AND
          uc.userId != id AND
          f.friendCycleId = (SELECT f.friendCycleId
                             FROM friendCycle f
                             WHERE id = f.userId)
  ),
  categoryCount AS(
    SELECT category, COUNT(category) AS COUNT
    FROM friendCategory
    GROUP BY category
    ORDER BY COUNT(category) DESC
  )
  INSERT INTO friendRecommendation(userId, friendCategory)
    SELECT id, c.category
    FROM categoryCount c
    LIMIT 20;
END;
$$
LANGUAGE plpgsql;

SELECT getFriendRecommendation(userId)
FROM friendCycle;

-- (c) Calculate the Jaccard index between U and F
DROP TABLE IF EXISTS friendRecommendationJaccardIndex;
CREATE TABLE friendRecommendationJaccardIndex(
  userId VARCHAR(32),
  index NUMERIC(4, 3),
  PRIMARY KEY(userId)
);

CREATE OR REPLACE FUNCTION getFriendRecommendationJaccardIndex(id VARCHAR(32))
RETURNS VOID AS
$$
DECLARE
  intersectionSize INTEGER;
  unionSize INTEGER;
BEGIN
  intersectionSize = (SELECT COUNT(*)
                      FROM (SELECT u.category
                            FROM userCategory u
                            WHERE u.userId = id
                            INTERSECT
                            SELECT f.friendCategory
                            FROM friendRecommendation f
                            WHERE f.userId = id) AS temp);
  unionSize = (SELECT COUNT(*)
               FROM (SELECT u.category
                     FROM userCategory u
                     WHERE u.userId = id
                     UNION
                     SELECT f.friendCategory
                     FROM friendRecommendation f
                     WHERE f.userId = id) AS temp);

  INSERT INTO friendRecommendationJaccardIndex
  VALUES(id, ROUND(intersectionSize * 1.0 / unionSize, 2));
END;
$$
LANGUAGE plpgsql;

SELECT getFriendRecommendationJaccardIndex(userId)
FROM friendCycle;

-- (d) Get the average of Jaccard Indices
SELECT ROUND(AVG(index), 4) AS index
FROM friendRecommendationJaccardIndex;
-- 0.1328
