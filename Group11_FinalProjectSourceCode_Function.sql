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