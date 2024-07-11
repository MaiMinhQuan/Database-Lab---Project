-- Tao bang
CREATE TABLE "accounts" (
  "phone" varchar PRIMARY KEY,
  "name" varchar,
  "type" varchar,
  "discount_point" float,
  "visit_count" int
);




CREATE TABLE "bills" (
  "bill_id" serial PRIMARY KEY,
  "time_check_in" timestamp,
  "time_check_out" timestamp,
  "point" int,
  "comment" text,
  "bill_status" int,
  "time_booking" timestamp,
  "total_price" float,
  "phone" varchar,
  "reduce" float,
  "number_of_guest" int


);


CREATE TABLE "orders" (
  "order_id" serial PRIMARY KEY,
  "bill_id" int,
  "item_id" varchar ,
  "table_id" int,
  "quantity" int
);




CREATE TABLE "tables" (
  "table_id" int PRIMARY KEY,
  "capacity" int,
  "status" int,
  "area_id" int
);




CREATE TABLE "areas" (
  "area_id" int PRIMARY KEY,
  "area_name" varchar
);




CREATE TABLE "items" (
  "item_id" varchar PRIMARY KEY,
  "food_id" varchar,
  "combo_id" varchar
);




CREATE TABLE "foods" (
  "food_id" varchar PRIMARY KEY,
  "name" varchar,
  "price" int,
  "food_status" varchar,
  "description" varchar
);




CREATE TABLE "combos" (
  "combo_id" varchar PRIMARY KEY,
  "combo_name" varchar,
  "combo_status" varchar,
  "price" int
);




CREATE TABLE "join_food_combos" (
  "food_id" varchar,
  "combo_id" varchar
);

-- Tao khoa 
ALTER TABLE "bills" ADD FOREIGN KEY ("phone") REFERENCES "accounts" ("phone");


ALTER TABLE "orders" ADD FOREIGN KEY ("bill_id") REFERENCES "bills" ("bill_id");


ALTER TABLE "orders" ADD FOREIGN KEY ("table_id") REFERENCES "tables" ("table_id");


ALTER TABLE "tables" ADD FOREIGN KEY ("area_id") REFERENCES "areas" ("area_id");


ALTER TABLE "join_food_combos" ADD FOREIGN KEY ("food_id") REFERENCES "foods" ("food_id");


ALTER TABLE "join_food_combos" ADD FOREIGN KEY ("combo_id") REFERENCES "combos" ("combo_id");


ALTER TABLE "orders" ADD FOREIGN KEY ("item_id") REFERENCES "items" ("item_id") ;


ALTER TABLE "items" ADD FOREIGN KEY ("food_id") REFERENCES "foods" ("food_id") ;


ALTER TABLE "items" ADD FOREIGN KEY ("combo_id") REFERENCES "combos" ("combo_id") ;