-- SQL — User Behavioral Analytics
-- Mô tả: Toàn bộ truy vấn chạy trên SQL Server 2022, 
--        nguồn dữ liệu gốc là bảng bang_hanh_vi (cấp độ 1 dòng = 1 event trong phiên truy cập)
--============================================================
-- thứ tự chạy tổng quát:
-- 01_data_cleaning_validation.sql
-- Mục đích: Kiểm tra tổng quan bảng gốc trước khi phân tích — 	Kiểm tra phạm vi dữ liệu, giá trị bất thường, missing value trên bảng gốc
-- Output: Không tạo bảng — chỉ để xác nhận dữ liệu sạch trước khi đi tiếp vào phân tích

--02_session_table_view.sql
-- Mục đích: Gộp dữ liệu về cấp session, gắn nhãn price_tier, speed_tier, phan_khuc_KH
-- Output: View session_table — nguồn chính cho toàn bộ measure DAX trong Power BI

--03_gate_ztest_inputs.sql
-- Mục đích: Tính n (cỡ mẫu)/x (số sự kiện)/rate (tỷ lệ) theo Gate 1 (thêm giỏ hàng) và Gate 2 (chốt đơn) 
--           cho 4 biến: device_type, traffic_source, channel, price_tier
--Output: Kết quả n/x/rate — đưa sang Excel (file Z-test_inputs.xlsx) để tính z-score và p-value

-- Lưu ý: z-score và p-value của two-proportion z-test không được tính trong SQL
--        bước tính z/p-value được thực hiện trên Excel,
--        sau đó kết quả tổng hợp (bao gồm cả spread và kết luận Sig./Not Sig.) 
--        được nhập vào Power BI làm bảng Bang_Ztest
--=============================================================

-- Chi tiết trình bày cụ thể dưới đây:
-- ============================================================
-- 01_data_cleaning_validation.sql
-- Mục đích: Kiểm tra tổng quan bảng gốc trước khi phân tích 
--           Kiểm tra phạm vi dữ liệu, giá trị bất thường, missing value trên bảng gốc
-- Bảng nguồn: bang_hanh_vi (cấp độ 1 dòng = 1 event)
-- ============================================================

-- 1. Phạm vi dữ liệu: mỗi cột có bao nhiêu giá trị khác nhau
SELECT 
    COUNT(*)                           AS tong_dong,
    COUNT(DISTINCT session_id)         AS session_id,
    COUNT(DISTINCT user_id)            AS user_id,
    COUNT(DISTINCT timestamp_utc)      AS timestamp_utc,
    COUNT(DISTINCT event_index)        AS event_index,
    COUNT(DISTINCT user_action)        AS user_action,
    COUNT(DISTINCT product_id)         AS product_id,
    COUNT(DISTINCT category)           AS category,
    COUNT(DISTINCT brand)              AS brand,
    COUNT(DISTINCT price)              AS price,
    COUNT(DISTINCT channel)            AS channel,
    COUNT(DISTINCT device_type)        AS device_type,
    COUNT(DISTINCT region)             AS region,
    COUNT(DISTINCT traffic_source)     AS traffic_source,
    COUNT(DISTINCT time_spent_sec)     AS time_spent_sec,
    COUNT(DISTINCT session_length)     AS session_length,
    COUNT(DISTINCT interaction_count)  AS interaction_count,
    COUNT(DISTINCT is_conversion)      AS is_conversion,
    COUNT(DISTINCT drop_off_flag)      AS drop_off_flag
FROM bang_hanh_vi;

-- 2. Kiểm định phạm vi giá trị số — phát hiện giá trị âm/bằng 0 bất thường
SELECT 
    MIN(price)      AS min_price,
    MAX(price)      AS max_price,
    AVG(price)      AS avg_price,
    SUM(CASE WHEN price <= 0 THEN 1 ELSE 0 END)          AS gia_tri_loi,
    MIN(time_spent_sec) AS min_time,
    MAX(time_spent_sec) AS max_time,
    AVG(time_spent_sec) AS avg_time,
    SUM(CASE WHEN time_spent_sec <= 0 THEN 1 ELSE 0 END) AS time_loi,
    MIN(session_length) AS min_length,
    MAX(session_length) AS max_length
FROM bang_hanh_vi;

-- 3. Kiểm tra missing value — tách 3 nhóm cột (định danh / hành vi số / ngữ cảnh)
--    để mỗi kết quả trả về gọn, dễ đọc thay vì 1 bảng quá nhiều cột
SELECT 
    SUM(CASE WHEN session_id   IS NULL THEN 1 ELSE 0 END) AS null_session,
    SUM(CASE WHEN user_id      IS NULL THEN 1 ELSE 0 END) AS null_user_id,
    SUM(CASE WHEN timestamp_utc IS NULL THEN 1 ELSE 0 END) AS null_timestamp_utc,
    SUM(CASE WHEN event_index  IS NULL THEN 1 ELSE 0 END) AS null_event_index,
    SUM(CASE WHEN user_action  IS NULL THEN 1 ELSE 0 END) AS null_user_action
FROM bang_hanh_vi;

SELECT 
    SUM(CASE WHEN time_spent_sec    IS NULL THEN 1 ELSE 0 END) AS null_time_spent_sec,
    SUM(CASE WHEN session_length    IS NULL THEN 1 ELSE 0 END) AS null_session_length,
    SUM(CASE WHEN interaction_count IS NULL THEN 1 ELSE 0 END) AS null_interaction_count
FROM bang_hanh_vi;

SELECT 
    SUM(CASE WHEN price           IS NULL THEN 1 ELSE 0 END) AS null_price,
    SUM(CASE WHEN channel         IS NULL THEN 1 ELSE 0 END) AS null_channel,
    SUM(CASE WHEN traffic_source  IS NULL THEN 1 ELSE 0 END) AS null_traffic_source,
    SUM(CASE WHEN device_type     IS NULL THEN 1 ELSE 0 END) AS null_device_type,
    SUM(CASE WHEN region          IS NULL THEN 1 ELSE 0 END) AS null_region,
    SUM(CASE WHEN drop_off_flag   IS NULL THEN 1 ELSE 0 END) AS null_drop_off_flag,
    SUM(CASE WHEN is_conversion   IS NULL THEN 1 ELSE 0 END) AS null_is_conversion
FROM bang_hanh_vi;

-- ============================================================
-- 02_session_table_view.sql
-- Mục đích: Chuyển dữ liệu từ cấp độ "1 dòng = 1 event" sang "1 dòng = 1 session", đồng thời gắn nhãn price_tier,
--           speed_tier, phan_khuc_KH ngay trong cùng 1 view.
-- Vì sao gộp chung 1 view thay vì tách ra bước riêng?
--   Việc tính price_tier/speed_tier cần percentile (phân vị) tính trên chính bảng đã gộp theo session (behavior_table) 
--   - tách thành 2 file sẽ phải viết lại behavior_table 2 lần. 
--   Gộp vào 1 view giúp Power BI chỉ cần đọc 1 nguồn duy nhất.
--
-- Output: view "session_table" — nguồn chính cho toàn bộ
--         measure DAX trong Power BI (GateValue, Pct_convert...)
-- ============================================================

CREATE VIEW session_table AS
WITH behavior_table AS (
    SELECT 
        session_id,
        MAX(device_type)    AS device_type,
        MAX(channel)         AS channel,
        MAX(traffic_source)  AS traffic_source,
        MAX(category)        AS category,
        MAX(price)           AS price,
        MAX(CAST(is_conversion AS INT))  AS is_conversion,
        MAX(CAST(drop_off_flag AS INT))  AS drop_off_flag,
        MAX(CASE WHEN user_action = 'add_to_cart' THEN 1 ELSE 0 END) AS co_atc,
        SUM(time_spent_sec)      AS total_time_spent_sec,
        MAX(interaction_count)   AS total_interaction_count,
        ROUND(
            CAST(SUM(time_spent_sec) AS FLOAT) / NULLIF(MAX(interaction_count), 0),
        2) AS muc_do_tuong_tac
    FROM bang_hanh_vi
    GROUP BY session_id
),
percentile_table AS (
    SELECT DISTINCT 
        PERCENTILE_CONT(0.33) WITHIN GROUP (ORDER BY price) OVER()               AS p33_price,
        PERCENTILE_CONT(0.67) WITHIN GROUP (ORDER BY price) OVER()               AS p67_price,
        PERCENTILE_CONT(0.5)  WITHIN GROUP (ORDER BY total_interaction_count) OVER() AS median_interaction,
        PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY muc_do_tuong_tac) OVER()    AS p25_toc_do,
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY muc_do_tuong_tac) OVER()    AS p75_toc_do
    FROM behavior_table 
)
SELECT 
    B.*,
    CASE 
        WHEN B.price >= P.p67_price THEN 'gia_cao' 
        WHEN B.price <  P.p33_price THEN 'gia_thap'
        ELSE 'gia_trung'
    END AS price_tier,
    CASE 
        WHEN B.muc_do_tuong_tac <= P.p25_toc_do THEN 'Fast'
        WHEN B.muc_do_tuong_tac <= P.p75_toc_do THEN 'Medium'
        ELSE 'Slow'
    END AS speed_tier,
    CASE
        WHEN B.is_conversion = 1 AND total_interaction_count >= P.median_interaction THEN 'khach_tien_nang'
        WHEN B.is_conversion = 1 AND total_interaction_count <  P.median_interaction THEN 'khach_mua_nhanh'
        WHEN B.is_conversion = 0 AND total_interaction_count >= P.median_interaction THEN 'khach_check_hang'
        ELSE 'khach_tim_kiem_thuong'
    END AS phan_khuc_KH
FROM behavior_table B
CROSS JOIN (SELECT TOP 1 * FROM percentile_table) P;

-- ============================================================
-- 03_gate_ztest_inputs.sql
-- Mục đích: Tính n (cỡ mẫu), x (số sự kiện), rate (tỷ lệ) cho
--           từng nhóm của 4 biến (device_type, traffic_source,
--           channel, price_tier), tách riêng theo Gate 1
--           (tỷ lệ thêm giỏ hàng) và Gate 2 (tỷ lệ chốt đơn trong số đã thêm giỏ hàng).
--
-- Lưu ý: z-score và p-value không tính trong SQL —
--   3 cột n/x/rate mỗi khối dưới đây được đưa sang Excel để
--   tính two-proportion z-test (xem file Z-test_inputs.xlsx trong Excel)
--   File này chỉ cung cấp nguyên liệu đầu vào, không phải kết
--   quả kiểm định cuối cùng.
-- ============================================================

-- ===================== DEVICE_TYPE =====================

-- Gate 1: tỷ lệ thêm giỏ hàng theo device_type
WITH session_level AS (
    SELECT 
        session_id,
        MAX(device_type) AS device_type,
        MAX(CASE WHEN user_action = 'add_to_cart' THEN 1 ELSE 0 END) AS has_atc,
        MAX(CAST(is_conversion AS INT)) AS is_conversion
    FROM bang_hanh_vi
    GROUP BY session_id
)
SELECT 
    device_type,
    COUNT(*)                                AS n,
    SUM(has_atc)                            AS x_atc,
    CAST(SUM(has_atc) AS FLOAT) / COUNT(*)  AS atc_rate
FROM session_level
GROUP BY device_type
ORDER BY atc_rate DESC;

-- Gate 2: tỷ lệ chốt đơn trong số đã thêm giỏ hàng, theo device_type
WITH session_level AS (
    SELECT 
        session_id,
        MAX(device_type) AS device_type,
        MAX(CASE WHEN user_action = 'add_to_cart' THEN 1 ELSE 0 END) AS has_atc,
        MAX(CAST(is_conversion AS INT)) AS is_conversion
    FROM bang_hanh_vi
    GROUP BY session_id
)
SELECT 
    device_type,
    COUNT(*)                                       AS n,
    SUM(is_conversion)                             AS x_convert,
    CAST(SUM(is_conversion) AS FLOAT) / COUNT(*)   AS convert_rate
FROM session_level
WHERE has_atc = 1
GROUP BY device_type
ORDER BY convert_rate DESC;


-- ===================== TRAFFIC_SOURCE =====================

-- Gate 1
WITH session_level AS (
    SELECT 
        session_id,
        MAX(traffic_source) AS traffic_source,
        MAX(CASE WHEN user_action = 'add_to_cart' THEN 1 ELSE 0 END) AS has_atc,
        MAX(CAST(is_conversion AS INT)) AS is_conversion
    FROM bang_hanh_vi
    GROUP BY session_id
)
SELECT 
    traffic_source,
    COUNT(*)                                AS n,
    SUM(has_atc)                            AS x_atc,
    CAST(SUM(has_atc) AS FLOAT) / COUNT(*)  AS atc_rate
FROM session_level
GROUP BY traffic_source
ORDER BY atc_rate DESC;

-- Gate 2
WITH session_level AS (
    SELECT 
        session_id,
        MAX(traffic_source) AS traffic_source,
        MAX(CASE WHEN user_action = 'add_to_cart' THEN 1 ELSE 0 END) AS has_atc,
        MAX(CAST(is_conversion AS INT)) AS is_conversion
    FROM bang_hanh_vi
    GROUP BY session_id
)
SELECT 
    traffic_source,
    COUNT(*)                                       AS n,
    SUM(is_conversion)                             AS x_convert,
    CAST(SUM(is_conversion) AS FLOAT) / COUNT(*)   AS convert_rate
FROM session_level
WHERE has_atc = 1
GROUP BY traffic_source
ORDER BY convert_rate DESC;


-- ===================== CHANNEL =====================

-- Gate 1
WITH session_level AS (
    SELECT 
        session_id,
        MAX(channel) AS channel,
        MAX(CASE WHEN user_action = 'add_to_cart' THEN 1 ELSE 0 END) AS has_atc,
        MAX(CAST(is_conversion AS INT)) AS is_conversion
    FROM bang_hanh_vi
    GROUP BY session_id
)
SELECT 
    channel,
    COUNT(*)                                AS n,
    SUM(has_atc)                            AS x_atc,
    CAST(SUM(has_atc) AS FLOAT) / COUNT(*)  AS atc_rate
FROM session_level
GROUP BY channel
ORDER BY atc_rate DESC;

-- Gate 2
WITH session_level AS (
    SELECT 
        session_id,
        MAX(channel) AS channel,
        MAX(CASE WHEN user_action = 'add_to_cart' THEN 1 ELSE 0 END) AS has_atc,
        MAX(CAST(is_conversion AS INT)) AS is_conversion
    FROM bang_hanh_vi
    GROUP BY session_id
)
SELECT 
    channel,
    COUNT(*)                                       AS n,
    SUM(is_conversion)                             AS x_convert,
    CAST(SUM(is_conversion) AS FLOAT) / COUNT(*)   AS convert_rate
FROM session_level
WHERE has_atc = 1
GROUP BY channel
ORDER BY convert_rate DESC;


-- ===================== PRICE_TIER =====================
-- Riêng price cần thêm bước tính ngưỡng percentile (p33/p67)
-- để chia thành 3 nhóm gia_thap/gia_trung/gia_cao trước khi đếm.

-- Gate 1
WITH bang_tam AS (
    SELECT 
        session_id,
        MAX(price) AS price,
        MAX(CASE WHEN user_action = 'add_to_cart' THEN 1 ELSE 0 END) AS has_atc,
        MAX(CAST(is_conversion AS INT)) AS is_conversion
    FROM bang_hanh_vi
    GROUP BY session_id
),
gia_threshold AS (
    SELECT DISTINCT
        PERCENTILE_CONT(0.33) WITHIN GROUP (ORDER BY price) OVER() AS p33,
        PERCENTILE_CONT(0.67) WITHIN GROUP (ORDER BY price) OVER() AS p67
    FROM bang_tam
),
session_level AS (
    SELECT 
        b.session_id,
        b.has_atc,
        b.is_conversion,
        CASE 
            WHEN b.price <= T.p33 THEN 'gia_thap'
            WHEN b.price <= T.p67 THEN 'gia_trung'
            ELSE 'gia_cao'
        END AS nhom_gia
    FROM bang_tam b
    CROSS JOIN (SELECT TOP 1 * FROM gia_threshold) T
)
SELECT 
    nhom_gia,
    COUNT(*)                                AS n,
    SUM(has_atc)                            AS x_atc,
    CAST(SUM(has_atc) AS FLOAT) / COUNT(*)  AS atc_rate
FROM session_level
GROUP BY nhom_gia
ORDER BY atc_rate DESC;

-- Gate 2
WITH bang_tam AS (
    SELECT 
        session_id,
        MAX(price) AS price,
        MAX(CASE WHEN user_action = 'add_to_cart' THEN 1 ELSE 0 END) AS has_atc,
        MAX(CAST(is_conversion AS INT)) AS is_conversion
    FROM bang_hanh_vi
    GROUP BY session_id
),
gia_threshold AS (
    SELECT DISTINCT
        PERCENTILE_CONT(0.33) WITHIN GROUP (ORDER BY price) OVER() AS p33,
        PERCENTILE_CONT(0.67) WITHIN GROUP (ORDER BY price) OVER() AS p67
    FROM bang_tam
),
session_level AS (
    SELECT 
        b.session_id,
        b.has_atc,
        b.is_conversion,
        CASE 
            WHEN b.price <= T.p33 THEN 'gia_thap'
            WHEN b.price <= T.p67 THEN 'gia_trung'
            ELSE 'gia_cao'
        END AS nhom_gia
    FROM bang_tam b
    CROSS JOIN (SELECT TOP 1 * FROM gia_threshold) T
)
SELECT 
    nhom_gia,
    COUNT(*)                                       AS n,
    SUM(is_conversion)                             AS x_convert,
    CAST(SUM(is_conversion) AS FLOAT) / COUNT(*)   AS convert_rate
FROM session_level
WHERE has_atc = 1
GROUP BY nhom_gia
ORDER BY convert_rate DESC;

