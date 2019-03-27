/******************** Abnormal User Identification ********************/

--------------- 1. User's rating for each restaurant ---------------

-- No user has reviewed the same restaurant more than once!!
DROP TABLE IF EXISTS userRestaurantRating;
CREATE TABLE userRestaurantRating (
  userId VARCHAR(32),
  restaurantId VARCHAR(32),
  userRating NUMERIC(3, 2),
  PRIMARY KEY(userId, restaurantId)
);

INSERT INTO userRestaurantRating
  SELECT ur.userId, r.restaurantId,
         ROUND(AVG(ur.stars), 2) AS metric
  FROM userReview ur JOIN restaurant r ON ur.restaurantId = r.restaurantId
  GROUP BY ur.userId, r.restaurantId;

--------------- 2. User's rating vs. actual rating ---------------

-- Variance is set to 0 for users with only 1 review
DROP TABLE IF EXISTS userRatingDifference;
CREATE TABLE userRatingDifference (
  userId VARCHAR(32),
  avgDiff NUMERIC(3, 2),
  varDiff NUMERIC(3, 2),
  PRIMARY KEY(userId)
);

WITH tempDifference AS(
  SELECT ur.userId, ROUND(AVG(ABS(ur.userRating - r.stars)), 2) AS avgDiff,
         COALESCE(ROUND(VARIANCE(ABS(ur.userRating - r.stars)), 2), 0.00) AS varDiff
  FROM userRestaurantRating ur JOIN restaurant r ON ur.restaurantId = r.restaurantId
  GROUP BY ur.userId
)
INSERT INTO userRatingDifference
  SELECT userId, avgDiff, varDiff
  FROM tempDifference;

SELECT ROUND(AVG(avgDiff), 4) AS mean, ROUND(AVG(varDiff), 4) AS vairance
FROM userRatingDifference;
-- mean avgDiff is 0.7307 and mean varDiff is 0.2957

--------------- 3. Identify abnormal users ---------------

SELECT *
FROM userRatingDifference
WHERE avgDiff > 1.00;

--------------- 4. Ratio of abnormal users ---------------

SELECT (SELECT COUNT(urd.userId)
        FROM userRatingDifference urd
        WHERE urd.avgDiff > 1.00) AS abnormalUser, COUNT (*) AS totalUser
FROM userRatingDifference;
-- out of 707 sample users, 89 are marked as abnormal, around 12.59% fake rate.
-- which aligns fairly well with the general consensus of 20% fake review
-- http://people.hbs.edu/mluca/FakeItTillYouMakeIt.pdf
-- https://www.marketwatch.com/story/20-of-yelp-reviews-are-fake-2013-09-24


/******************** Gender-rating Relationship ********************/

--------------- 1. Assign gender to yelpUser ---------------

-- create nameGender table
DROP TABLE IF EXISTS nameGender;
CREATE TABLE nameGender(
  name VARCHAR(32),
  gender CHAR(1),
  PRIMARY KEY(name)
);

-- create nameGenderFreq temporary table
DROP TABLE IF EXISTS nameGenderFreq;
CREATE TEMPORARY TABLE nameGenderFreq(
  name VARCHAR(32),
  gender CHAR(1),
  frequency NUMERIC(5, 4),
  PRIMARY KEY(name, gender, frequency)
);

WITH nameGenderCount AS(
  SELECT name, gender, SUM(frequency) AS individualCount
  FROM nameGenderRaw
  GROUP BY name, gender
),
total AS(
  SELECT name, SUM(individualCount) AS totalCount
  FROM nameGenderCount
  GROUP BY name
)
INSERT INTO nameGenderFreq(name, gender, frequency)
  SELECT g.name, g.gender, ROUND(g.individualCount * 1.0 / t.totalCount, 4) AS ratio
  FROM nameGenderCount g, total t
  WHERE g.name = t.name
  ORDER BY g.name, g.gender;

-- use vote-for-majority policy to determine gender for each first name
CREATE OR REPLACE FUNCTION assignGenderToName() RETURNS VOID AS
$$
DECLARE
  cursor CURSOR FOR SELECT * FROM nameGenderFreq;
  currName VARCHAR(32);
  prevName VARCHAR(32) DEFAULT '-1';
  currGender CHAR(1);
  prevGender CHAR(1) DEFAULT 'X';
  currFreq NUMERIC(5, 4);
  prevFreq NUMERIC(5, 4) DEFAULT -1;
BEGIN
OPEN cursor;
LOOP
  FETCH cursor INTO currName, currGender, currFreq;
  EXIT WHEN NOT FOUND;

  IF currName = prevName THEN
    IF currFreq > prevFreq THEN
      UPDATE nameGender SET gender = currGender WHERE name = currName;
    END IF;
  ELSE
    INSERT INTO nameGender(name, gender) VALUES (prevName, prevGender);
  END IF;

  prevName = currName;
  prevGender = currGender;
  prevFreq = currFreq;
END LOOP;
-- don't forget the last name
INSERT INTO nameGender(name, gender) VALUES (prevName, prevGender);
CLOSE cursor;
-- remove the redundant first row
DELETE FROM nameGender WHERE name = '-1';
END;
$$
LANGUAGE plpgsql;

SELECT assignGenderToName();

-- add column gender to yelpUser
ALTER TABLE yelpUser ADD COLUMN gender CHAR(1);

WITH genderAssignement AS(
  SELECT y.name, n.gender
  FROM yelpUser y JOIN nameGender n ON y.name = n.name
)
UPDATE yelpUser
SET gender = g.gender
FROM genderAssignement g
WHERE yelpUser.name = g.name;

SELECT gender, COUNT(*)
FROM yelpUser
GROUP BY gender;

/**

  gender | count
 --------+-------
  (null) |    81
  M      |   621
  F      |    69

 */

--------------- 2. Get review count and average rating ---------------

SELECT y.gender, COUNT(u.stars) AS reviewNum, ROUND(AVG(u.stars), 2) as avgStar
FROM yelpUser y, userReview u
WHERE y.userId = u.userId AND
      gender IS NOT NULL
GROUP BY y.gender;

/**

 gender | reviewnum | avgstar
--------+-----------+---------
 M      |     23622 |    3.69
 F      |      4362 |    3.65

 */
