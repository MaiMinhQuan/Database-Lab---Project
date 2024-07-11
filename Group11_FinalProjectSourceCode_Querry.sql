-- Querry

--Đưa ra tên 5 khách hàng đến quán nhiều lần nhất
select name from accounts
order by visit_count desc
limit 5

-- Đưa ra số điện thoại của các khách hàng có số lần đến quán > 6
select phone from accounts
where visit_count > 6

-- Đưa ra tên 5 khách hàng có điểm tích lũy cao nhất hiện tại
select name from accounts
order by discount_point desc
limit 5

-- Đưa ra sđt của các khách hàng  đến quán trong tháng 2024/05/01/ - 2024/05/10
SELECT a.phone, time_check_in
FROM accounts a
LEFT JOIN bills b ON a.phone = b.phone
WHERE b.time_check_in >= '2024-05-01'
	AND b.time_check_in < '2024-05-10'
	
-- Đưa ra 5 khách hàng đã trả nhiều tiền nhất
SELECT a.name
FROM accounts a
INNER JOIN bills b ON a.phone = b.phone
group by a.phone
order by SUM(b.total_price - b.reduce) DESC
limit 5

-- Đưa ra số khách hàng đến quán trong ngày “29-05-2024”
select COUNT(DISTINCT phone) from bills
where DATE(time_check_in) = '2024-05-29'

-- Đưa ra số lượng hóa đơn đã đặt hàng trước và không đến quán trong ngày “29-05-2024”
select COUNT(bill_id) 
from bills
where DATE(time_check_in) != '2024-05-29'  OR time_check_in IS NULL
	AND DATE(time_booking) < '2024-05-29';

-- Đưa ra số lượng hóa đơn có giá trị >50$ trong ngày “29-05-2024”
select count(bill_id)
from bills
where total_price > 50
and DATE(time_check_in) = '2024-05-29'

-- Đưa ra đầy đủ thông tin các món ăn trong combo có giá từ 50$ – 70$
select f.food_id, f.name, f.price, f.food_status, f.description, c.combo_id
from foods f
inner join join_food_combos jfc on jfc.food_id = f.food_id
inner join combos c on jfc.combo_id = c.combo_id
where c.price between 50 and 70
group by c.combo_id, f.food_id;

-- Đưa ra thông tin các món ăn, combo có status là “hết hàng” 
SELECT f.food_id, f.name, f.price, f.food_status,  'Food' AS item_type
FROM foods f
WHERE f.food_status = 'unavailable'
UNION
SELECT c.combo_id, c.combo_name, c.price, c.combo_status, 'Combo' AS item_type
FROM combos c
WHERE c.combo_status = 'unavailable'

-- Đưa ra top 5 các món ăn được gọi nhiều nhất theo từng ngày từ 20/05 – 26/05
SELECT 
    DATE(time_check_in) AS ngay,
    f.name AS mon_an,
    SUM(o.quantity) AS so_luong
FROM bills b
INNER JOIN orders o ON b.bill_id = o.bill_id
INNER JOIN items i ON o.item_id = i.item_id
INNER JOIN foods f ON i.food_id = f.food_id
WHERE 
    DATE(time_check_in) = '2024-05-25'
	AND f.name != 'null'
GROUP BY 
    DATE(time_check_in), f.food_id
ORDER BY 
    ngay, so_luong DESC
LIMIT 5;