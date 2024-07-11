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