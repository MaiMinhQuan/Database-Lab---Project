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


-- Function

--Hàm tạo account

CREATE OR REPLACE FUNCTION F_Create_Account(p_phone VARCHAR, p_name VARCHAR)
RETURNS VARCHAR AS $$
DECLARE
	v_username VARCHAR;
BEGIN
	SELECT name INTO v_username
	FROM accounts WHERE phone = p_phone;
	
	IF v_username IS NULL THEN
		BEGIN
			INSERT INTO accounts (phone, name, type, discount_point, visit_count)
			VALUES (p_phone, p_name, 'customer' , 0, 0);
			RETURN 'tao tai khoan thanh cong';
		EXCEPTION WHEN OTHERS THEN
			RETURN 'co loi xay ra khi tao tai khoan';
		END;
	ELSE
		RETURN 'tai khoan voi sdt nay da ton tai';
	END IF;
END;
$$ LANGUAGE plpgsql;

--Hàm booking

CREATE OR REPLACE FUNCTION F_Create_Booking(
    p_phone VARCHAR, 
    p_time_booking timestamp,
    p_number_of_guest	 int
)
RETURNS VARCHAR AS $$
BEGIN
    -- kiểm tra sdt hợp lệ
    IF NOT EXISTS(SELECT 1 FROM accounts WHERE phone = p_phone) THEN
        RETURN 'sdt ko ton tai';
    END IF;
    
    INSERT INTO bills(phone, time_booking, bill_status, number_of_guest)
    VALUES (p_phone, p_time_booking, 0, p_number_of_guest);
    
    RETURN 'tao booking thanh cong';
END;
$$ LANGUAGE plpgsql;

--Hàm cập nhật time_check_in cho KH đã book trước
CREATE OR REPLACE FUNCTION F_Update_Time_Check_In(p_phone varchar, p_bill_id INT)
RETURNS VARCHAR AS $$
DECLARE 
BEGIN
	UPDATE bills
	SET time_check_in = date_trunc('second',CURRENT_TIMESTAMP)
	WHERE phone = p_phone 
AND time_booking IS NOT NULL 
AND time_check_in IS NULL
AND p_bill_id = bill_id;
	RETURN 'da cap nhat time_check_in THANH CONG!';
END;
$$ LANGUAGE plpgsql;

--Hàm tạo bill (giành cho khách chưa đặt trước) 
cập nhật thêm check sdt

CREATE OR REPLACE FUNCTION F_Create_Bill(
p_phone VARCHAR, 
p_number_of_guest INT)
RETURNS VARCHAR AS $$
BEGIN
    -- kiểm tra số điện thoại hợp lệ
    IF NOT EXISTS(SELECT 1 FROM accounts WHERE phone = p_phone) THEN
        RETURN 'sdt ko ton tai';
    END IF;

    -- Thêm một bản ghi mới vào bảng bills với thời gian hiện tại đã loại bỏ phần mili giây
    INSERT INTO bills (phone, time_check_in, bill_status, number_of_guest)
    VALUES (p_phone, date_trunc('second', clock_timestamp()), 0, p_number_of_guest);

    RETURN 'tao bill thanh cong';
END;
$$ LANGUAGE plpgsql;


--Check đến đúng giờ

CREATE OR REPLACE FUNCTION F_On_Time(p_bill_id INT)
RETURNS INT AS $$
DECLARE
    v_time_booking TIMESTAMP;
    v_time_check_in TIMESTAMP;
BEGIN
    SELECT time_booking, time_check_in 
    INTO v_time_booking, v_time_check_in 
    FROM bills
    WHERE bill_id = p_bill_id;
    
    IF v_time_booking IS NULL THEN
        RETURN 0;
    ELSIF ABS (EXTRACT(EPOCH FROM (v_time_check_in - v_time_booking)) / 60) <= 15 THEN
        RETURN 1;
    ELSE
        RETURN 0;
    END IF;
END;
$$ LANGUAGE plpgsql;

--Hàm order food

CREATE OR REPLACE FUNCTION F_InsertOrder (
    IN p_bill_id INT,
    IN p_item_id VARCHAR,
    IN p_table_id INT,
    IN p_quantity INT
) 
RETURNS VOID AS $$
DECLARE
    v_order_id INT;
    v_item_count INT;
    v_new_count INT;
BEGIN
    -- Initialize variables
    v_order_id := 0;
    v_item_count := 0;
    v_new_count := 0;

    -- Check if the order already exists in BillInfo
    SELECT order_id, quantity
    INTO v_order_id, v_item_count
    FROM orders
    WHERE bill_id = p_bill_id AND item_id = p_item_id;

    -- If order exists, update quantity
    IF v_order_id > 0 THEN
        v_new_count := v_item_count + p_quantity;
        IF v_new_count > 0 THEN
            -- Update the existing order
            UPDATE orders
            SET quantity = v_new_count
            WHERE order_id = v_order_id;
        END IF;
    ELSE
        -- Otherwise, insert a new order
        INSERT INTO orders (bill_id, item_id, table_id, quantity)
        VALUES (p_bill_id, p_item_id, p_table_id, p_quantity);
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION F_On_Time(p_bill_id INT)
RETURNS INT AS $$
DECLARE
    v_time_booking TIMESTAMP;
    v_time_check_in TIMESTAMP;
BEGIN
    SELECT time_booking, time_check_in 
    INTO v_time_booking, v_time_check_in 
    FROM bills
    WHERE bill_id = p_bill_id;
    
    IF v_time_booking IS NULL THEN
        RETURN 0;
    ELSIF ABS (EXTRACT(EPOCH FROM (v_time_check_in - v_time_booking)) / 60) <= 15 THEN
        RETURN 1;
    ELSE
        RETURN 0;
    END IF;
END;
$$ LANGUAGE plpgsql;


--Hàm tính hóa đơn gốc

CREATE OR REPLACE FUNCTION F_BillSum(p_bill_id INT)
RETURNS VOID AS $$
DECLARE
    v_total_sum_food INT := 0;
    v_total_sum_combo INT := 0;
BEGIN
    -- Tính tổng giá trị các món ăn
    SELECT COALESCE(SUM(f.price * o.quantity), 0)
    INTO v_total_sum_food
    FROM orders AS o
    JOIN foods AS f ON f.food_id = o.item_id
    WHERE o.bill_id = p_bill_id;


    -- Tính tổng giá trị các combo
    SELECT COALESCE(SUM(c.price * o.quantity), 0)
    INTO v_total_sum_combo
    FROM orders AS o
    JOIN combos AS c ON c.combo_id = o.item_id
    WHERE o.bill_id = p_bill_id;


    -- Trả về tổng giá trị
    update bills set total_price = v_total_sum_food + v_total_sum_combo
    where bill_id = p_bill_id ;


END;
$$ LANGUAGE plpgsql;

--Hàm  trừ discount_point
CREATE OR REPLACE FUNCTION F_UsingDiscountpoint(
    IN p_bill_id INT,
    IN p_reduce INT
)
RETURNS VOID AS $$
DECLARE
    v_user_point INT;
	v_total_price INT;
	v_phone VARCHAR;
BEGIN
    -- Lấy điểm giảm giá hiện tại của khách hàng
	SELECT phone INTO v_phone
	FROM bills WHERE bill_id = p_bill_id;
	
    SELECT discount_point INTO v_user_point
    FROM accounts
    WHERE phone = v_phone;
	
	SELECT total_price INTO v_total_price
	FROM bills
	WHERE bill_id = p_bill_id;
    -- Kiểm tra điều kiện để sử dụng điểm giảm giá
    IF p_reduce > 0 AND p_reduce % 5 = 0 AND p_reduce <= v_user_point AND v_total_price >= p_reduce THEN
        -- Thực hiện thêm dòng vào bảng Pays
		UPDATE bills SET reduce = p_reduce WHERE bill_id = p_bill_id;

        -- Cập nhật điểm giảm giá của khách hàng
        UPDATE accounts
        SET discount_point = v_user_point - p_reduce
        WHERE phone = v_phone;
		
		UPDATE bills
		SET total_price = v_total_price - p_reduce
		WHERE bill_id = p_bill_id;
    END IF;
END;
$$ LANGUAGE plpgsql;

--Hàm gửi đánh giá, điểm số của khách hàng

CREATE OR REPLACE FUNCTION submit_review(
	p_bill_id INT,
	p_point INT,
	p_comment varchar
)
RETURNS VOID AS $$
BEGIN
	IF p_point < 1 OR p_point > 5 THEN
		RAISE EXCEPTION 'diem danh gia phai tu 1 den 5';
	END IF;
	
	UPDATE bills
	SET point = p_point, comment = p_comment
	WHERE bill_id = p_bill_id;
END;
$$ LANGUAGE plpgsql;

--Hàm thanh toán (chuyển bill_status từ 0 sang 1)

CREATE OR REPLACE FUNCTION F_Purchase(p_bill_id INT)
RETURNS VOID AS $$
BEGIN
	UPDATE bills SET bill_status = 1 WHERE bill_id = p_bill_id;
END;
$$ LANGUAGE plpgsql;

VD: SELECT F_Purchase(bill_id);


--Trigger

--trigger insert id_food vào item

CREATE OR REPLACE FUNCTION add_food_to_item()
RETURNS TRIGGER AS $$
BEGIN	
	IF NEW.food_stauts = 'available' THEN
  INSERT INTO items (item_id, food_id, combo_id) VALUES (NEW.food_id, new.food_id, 'NC');
  RETURN NEW;
  END IF;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER after_food_insert
AFTER INSERT ON foods
FOR EACH ROW
EXECUTE FUNCTION add_food_to_item();

 --trigger delete food_id vao item

CREATE OR REPLACE FUNCTION remove_food_from_item()
RETURNS TRIGGER AS $$
BEGIN
	DELETE FROM items WHERE item_id = OLD.food_id;
	RETURN OLD;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER after_food_delete
AFTER DELETE ON foods
FOR EACH ROW
EXECUTE FUNCTION remove_food_from_item();

--trigger insert combo_id vao item

CREATE OR REPLACE FUNCTION add_combo_to_item()
RETURNS TRIGGER AS $$
BEGIN
	IF NEW.combo_status = 'available' THEN
  INSERT INTO items (item_id, food_id, combo_id) VALUES (NEW.combo_id, 'NF', NEW.combo_id);
  RETURN NEW;
  END IF;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER after_combo_insert
AFTER INSERT ON combos
FOR EACH ROW
EXECUTE FUNCTION add_combo_to_item();

--trigger delete combo_id vao item

CREATE OR REPLACE FUNCTION remove_combo_from_item()
RETURNS TRIGGER AS $$
BEGIN
	DELETE FROM items WHERE item_id = OLD.combo_id;
	RETURN OLD;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER after_combo_delete
AFTER DELETE ON combos
FOR EACH ROW
EXECUTE FUNCTION remove_combo_from_item();

--trigger update food_status to item

CREATE OR REPLACE FUNCTION update_food_status_to_item()
RETURNS TRIGGER AS $$
BEGIN
    IF OLD.food_status = 'available' AND NEW.food_status = 'unavailable' THEN
        DELETE FROM items WHERE item_id = NEW.food_id;
	ELSEIF OLD.food_status = 'unavailable' AND NEW.food_status = 'available' THEN
        INSERT INTO items(item_id, food_id, combo_id) 
				VALUES(NEW.food_id, NEW.food_id, 'NC') ;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER after_food_status_to_item
AFTER UPDATE OF food_status ON foods
FOR EACH ROW
WHEN (OLD.food_status IS DISTINCT FROM NEW.food_status)
EXECUTE FUNCTION update_food_status_to_item();

--trigger update combo_status to item

CREATE OR REPLACE FUNCTION update_combo_status_to_item()
RETURNS TRIGGER AS $$
BEGIN
    IF OLD.combo_status = 'available' AND NEW.combo_status = 'unavailable' THEN
        DELETE FROM items WHERE item_id = NEW.combo_id;
	ELSEIF OLD.combo_status = 'unavailable' AND NEW.combo_status = 'available' THEN
        INSERT INTO items(item_id, food_id, combo_id) 
				VALUES(NEW.combo_id, 'NF', NEW.combo_id) ;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER after_combo_status_to_item
AFTER UPDATE OF combo_status ON combos
FOR EACH ROW
WHEN (OLD.combo_status IS DISTINCT FROM NEW.combo_status)
EXECUTE FUNCTION update_combo_status_to_item();

--trigger bàn khi order

CREATE OR REPLACE FUNCTION UpdateTableStatusWhenOrder()
RETURNS TRIGGER AS $$
DECLARE
    v_table_id INT;
    v_table_status INT;
BEGIN
    -- Get table_id from the inserted or updated row
    v_table_id := NEW.table_id;

    -- Check if table_id is not null
    IF v_table_id IS NOT NULL THEN
        -- Get current status of the table
        SELECT status INTO v_table_status
        FROM tables
        WHERE table_id = v_table_id;

        -- Check if table status is 0 and update if necessary
        IF v_table_status = 0 THEN
            UPDATE tables
            SET status = 1
            WHERE table_id = v_table_id;
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_table_status_when_order_trigger
AFTER INSERT OR UPDATE ON orders
FOR EACH ROW
EXECUTE FUNCTION UpdateTableStatusWhenOrder();

--Trigger khi thanh toán Bill
CREATE OR REPLACE FUNCTION UpdateBillWhenPaid()
RETURNS TRIGGER AS $$
DECLARE 
	v_on_time INT;
	v_having_visit INT;
	v_phone VARCHAR;
	v_having_point FLOAT;
	v_total_present FLOAT;
BEGIN
  	-- Update bàn thành trống sau khi thanh toán
      UPDATE tables
      SET status = 0
      WHERE table_id IN (
         SELECT table_id
         FROM orders
         WHERE bill_id = NEW.bill_id
      );
	  
	  -- Giảm 1% nếu đặt trước và đến đúng giờ
	SELECT f_on_Time(NEW.bill_id) INTO v_on_time;
	IF v_on_time = 1 THEN
	  UPDATE bills SET total_price = NEW.total_price * 0.99
	  WHERE bill_id = NEW.bill_id;
	END IF;
	
	-- Tăng visit_count
	SELECT phone INTO v_phone
	FROM bills WHERE bill_id = NEW.bill_id;
	
	SELECT visit_count INTO v_having_visit
    FROM accounts
    WHERE phone = v_phone;
	
	UPDATE accounts SET visit_count = v_having_visit + 1
	WHERE phone = v_phone;
	
	-- Cộng 2% gtri hóa đơn vào discount_point của KH
	SELECT discount_point INTO v_having_point
	FROM accounts WHERE phone = v_phone;
	-- Lấy total_price đã giảm 1%
	SELECT total_price INTO v_total_present
	FROM bills WHERE bill_id = NEW.bill_id;
	-- Update lại discount_point
	UPDATE accounts SET discount_point = v_having_point + ((v_total_present)* 0.2);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER utg_updatebillwhenpaid_trigger
AFTER UPDATE OF bill_status ON bills
FOR EACH ROW
WHEN (OLD.bill_status IS DISTINCT FROM NEW.bill_status)
EXECUTE FUNCTION UpdateBillWhenPaid();

--trigger tinh diem dua vao visit_count

CREATE OR REPLACE FUNCTION update_discount_points()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.visit_count = 5 THEN
    UPDATE accounts SET discount_point = NEW.discount_point + 4 WHERE phone = NEW.phone;
  ELSIF NEW.visit_count > 5 AND NEW.visit_count % 5 = 0 THEN
    UPDATE accounts SET discount_point = NEW.discount_point + ((NEW.visit_count / 5) - 1) * 10 WHERE phone = NEW.phone;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_discount_points
AFTER UPDATE OF visit_count ON accounts
FOR EACH ROW
WHEN (OLD.visit_count IS DISTINCT FROM NEW.visit_count)
EXECUTE FUNCTION update_discount_points();












