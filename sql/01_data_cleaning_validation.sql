-- ============================================================
-- 01_data_cleaning_validation.sql
-- Mục đích: Kiểm tra tổng quan bảng gốc trước khi phân tích —	Kiểm tra phạm vi dữ liệu, giá trị bất thường, missing value trên bảng gốc
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
