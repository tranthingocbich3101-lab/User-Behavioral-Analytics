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
