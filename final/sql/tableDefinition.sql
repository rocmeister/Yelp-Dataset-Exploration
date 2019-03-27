
DROP TABLE IF EXISTS business;
DROP TABLE IF EXISTS person;
DROP TABLE IF EXISTS review;
DROP TABLE IF EXISTS restaurant;
DROP TABLE IF EXISTS userReview;
DROP TABLE IF EXISTS friend;
DROP TABLE IF EXISTS yelpUser;
DROP TABLE IF EXISTS nameGenderRaw;

CREATE TABLE business(
  state VARCHAR(4),
  "attributes.NoiseLevel" VARCHAR(16),
  "hours.Monday" VARCHAR(16),
  "attributes.Caters" BOOLEAN,
  "attributes.BYOBCorkage" VARCHAR(16),
  "attributes.WiFi" VARCHAR(16),
  "attributes.RestaurantsPriceRange2" INTEGER,
  "attributes.RestaurantsGoodForGroups" BOOLEAN,
  "attributes.Ambience" VARCHAR(256),
  "attributes.Smoking" VARCHAR(16),
  "attributes.AcceptsInsurance" BOOLEAN,
  "attributes.Alcohol" VARCHAR(16),
  "attributes.DogsAllowed" BOOLEAN,
  "attributes.BestNights" VARCHAR(256),
  "attributes.RestaurantsReservations" BOOLEAN,
  "attributes.Corkage" BOOLEAN,
  name VARCHAR(256),
  address VARCHAR(256),
  "attributes.RestaurantsTableService" BOOLEAN,
  "attributes.HappyHour" BOOLEAN,
  "attributes.AgesAllowed" VARCHAR(16),
  "attributes.HasTV" BOOLEAN,
  "attributes.DriveThru" BOOLEAN,
  "attributes.RestaurantsTakeOut" BOOLEAN,
  "hours.Saturday" VARCHAR(16),
  neighborhood VARCHAR(256),
  reviewCount INTEGER,
  "hours.Tuesday" VARCHAR(16),
  "attributes.WheelchairAccessible" BOOLEAN,
  "attributes.BikeParking" BOOLEAN,
  categories VARCHAR(64),
  "hours.Friday" VARCHAR(16),
  postalCode VARCHAR(16),
  businessId VARCHAR(32),
  stars NUMERIC(2, 1),
  "hours.Thursday" VARCHAR(16),
  "attributes.BusinessAcceptsCreditCards" BOOLEAN,
  "attributes.Music" VARCHAR(256),
  "attributes.BYOB" BOOLEAN,
  "attributes.BusinessParking" VARCHAR(256),
  "attributes.GoodForDancing" BOOLEAN,
  "attributes.RestaurantsAttire" VARCHAR(256),
  attributes TEXT,
  "attributes.HairSpecializesIn" VARCHAR(256),
  "attributes.DietaryRestrictions" VARCHAR(256),
  "attributes.BusinessAcceptsBitcoin" BOOLEAN,
  "attributes.RestaurantsCounterService" BOOLEAN,
  city VARCHAR(64),
  isOpen INTEGER,
  "hours.Wednesday" VARCHAR(16),
  longitude NUMERIC,
  "hours.Sunday" VARCHAR(16),
  "attributes.GoodForKids" BOOLEAN,
  hours VARCHAR(512),
  "attributes.ByAppointmentOnly" BOOLEAN,
  "attributes.RestaurantsDelivery" BOOLEAN,
  "attributes.CoatCheck" BOOLEAN,
  "attributes.Open24Hours" BOOLEAN,
  "attributes.OutdoorSeating" BOOLEAN,
  "attributes.GoodForMeal" VARCHAR(256),
  latitude NUMERIC
);

CREATE TABLE person(
  cool INTEGER,
  useful INTEGER,
  complimentProfile INTEGER,
  reviewCount INTEGER,
  complimentList INTEGER,
  userId VARCHAR(32),
  funny INTEGER,
  complimentCute INTEGER,
  complimentPhotos INTEGER,
  name VARCHAR(32),
  complimentCool INTEGER,
  complimentFunny INTEGER,
  elite VARCHAR(256),
  friends TEXT,
  complimentMore INTEGER,
  complimentWriter INTEGER,
  complimentPlain INTEGER,
  complimentNote INTEGER,
  complimentHot INTEGER,
  yelpingSince DATE,
  averageStars NUMERIC(3, 2),
  fans INTEGER
);

CREATE TABLE review(
  stars INTEGER,
  reviewDate DATE,
  restaurantId VARCHAR(32),
  reviewContent TEXT,
  cool INTEGER,
  funny INTEGER,
  reviewId VARCHAR(32),
  userId VARCHAR(32),
  useful INTEGER
);

CREATE TABLE restaurant(
  restaurantId VARCHAR(32),
  city VARCHAR(64),
  state VARCHAR(4),
  category VARCHAR(64),
  stars NUMERIC(2, 1),
  PRIMARY KEY(restaurantId)
);

CREATE TABLE yelpUser(
  userId VARCHAR(32),
  name VARCHAR(32),
  friends TEXT,
  compliment INTEGER,
  PRIMARY KEY(userId)
);

CREATE TABLE friend(
  userId VARCHAR(32) REFERENCES yelpUser(userId),
  friendId VARCHAR(32),
  PRIMARY KEY (userId, friendId)
);

CREATE TABLE userReview(
  reviewId VARCHAR(32),
  userId VARCHAR(32) REFERENCES yelpUser(userId),
  restaurantId VARCHAR(32) REFERENCES restaurant(restaurantId),
  stars INTEGER,
  PRIMARY KEY(reviewId)
);

CREATE TABLE nameGenderRaw(
  name VARCHAR(16),
  gender CHAR(1),
  frequency INTEGER
);

-- execute in terminal
\copy business FROM '/path/to/file/yelp_academic_dataset_business.csv' WITH CSV HEADER DELIMITER AS ',';
\copy person   FROM '/path/to/file/yelp_academic_dataset_user.csv' WITH CSV HEADER DELIMITER AS ',';
\copy review   FROM '/path/to/file/yelp_academic_dataset_review.csv' WITH CSV HEADER DELIMITER AS ',';
\copy nameGenderRaw FROM '/path/to/file/nameGender.csv' DELIMITER AS ',';

INSERT INTO yelpUser(userId, name, friends, compliment)
  SELECT userId, name, friends,
         complimentHot + complimentMore + complimentProfile + complimentCute +
         complimentList + complimentNote + complimentPlain + complimentCool +
         complimentFunny + complimentWriter + complimentPhotos
  FROM person
  WHERE friends != 'None' AND
        (complimentHot + complimentMore + complimentProfile + complimentCute +
         complimentList + complimentNote + complimentPlain + complimentCool +
         complimentFunny + complimentWriter + complimentPhotos) >= 5000;

INSERT INTO friend(userId, friendId)
  SELECT u.userId, temp.friendId
  FROM yelpUser u,
       unnest(string_to_array(u.friends, ',')) AS temp(friendId);

INSERT INTO userReview(reviewId, userId, restaurantId, stars)
  SELECT reviewId, userId, restaurantId, stars
  FROM review
  WHERE userId IN (SELECT u.userId FROM yelpUser u) AND
        restaurantId IN (SELECT r.restaurantId FROM restaurant r);

INSERT INTO restaurant(restaurantId, city, state, category, stars)
  SELECT businessId, city, state, categories, stars
  FROM business;

