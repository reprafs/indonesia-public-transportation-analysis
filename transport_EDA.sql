

-- Menampilakn 20 Baris Data
SELECT TOP 20 * FROM transport;

-- Salin data dan struktur kolom
SELECT *
INTO dbo.transport_analyse
FROM dbo.transport;

SELECT TOP 20 * FROM transport_analyse;

-- 2. Drop kolom yang tidak dipakai
ALTER TABLE transport_analyse
DROP COLUMN payment_method,
            carbon_emission_savings_kg,
            arrival_time,
            cot_transit_logistics_rationale,
            confidence_score;

-- 3. Melakukan data standarditation mengenai range score dan index
UPDATE transport_analyse
SET passenger_load_factor_pct      = passenger_load_factor_pct / 10.0,
    transit_efficiency_index       = transit_efficiency_index / 100.0,
    crowding_discomfort_score      = crowding_discomfort_score / 100.0,
    fare_to_speed_ratio            = fare_to_speed_ratio / 10.0,
    first_last_mile_friction_index = first_last_mile_friction_index / 10.0;

-- Q1 Seberapa andal layanan kita? Berapa % perjalanan terlambat dan rata-rata delay_minutes-nya?

-- Buat tabel dummy untuk delay
ALTER TABLE transport_analyse
ADD is_delayed TINYINT,
    is_late_significant TINYINT,
    delay_category VARCHAR(15);

-- insert dummy dan category
UPDATE transport_analyse
SET is_delayed = CASE WHEN delay_minutes > 0 THEN 1 ELSE 0 END,
    is_late_significant = CASE WHEN delay_minutes > 5 THEN 1 ELSE 0 END,
    delay_category = CASE
        WHEN delay_minutes = 0   THEN 'On-time'
        WHEN delay_minutes <= 5  THEN '1-5 min'
        WHEN delay_minutes <= 10 THEN '6-10 min'
        WHEN delay_minutes <= 15 THEN '11-15 min'
        ELSE                          '16-30 min'
    END;

-- Q1Ringkasan keterlambatan
SELECT
    COUNT(*) AS total_trip,
    ROUND(100.0 * SUM(is_delayed) / COUNT(*), 1) AS pct_delayed,
    ROUND(AVG(delay_minutes * 1.0), 2) AS avg_delay_all,
    ROUND(AVG(CASE WHEN is_delayed = 1
        THEN delay_minutes * 1.0 END), 2) AS avg_delay_when_delayed
FROM transport_analyse;

-- jumlah trip yg terlambat berdasarkan kategori delay
SELECT delay_category,
       COUNT(*) AS jumlah,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct
FROM transport_analyse
GROUP BY delay_category
ORDER BY delay_category;


-- Q2: Rute dengan persentase keterlambatan tertinggi
SELECT
    transit_mode,
    origin_station,
    destination_station,
    COUNT(*) AS total_trip,
    ROUND(100.0 * SUM(is_delayed) / COUNT(*), 1) AS pct_delayed,
    ROUND(AVG(CASE WHEN is_delayed = 1
     THEN delay_minutes * 1.0 END), 1) AS avg_delay
FROM transport_analyse
GROUP BY transit_mode, origin_station, destination_station
HAVING COUNT(*) >= 10
ORDER BY pct_delayed DESC;


--  Keterlambatan berdasarkan jam sibuk 
SELECT 
    peak_hour_category, 
    COUNT(*) AS total_trip, 
    CAST(100.0 * SUM(is_delayed) / COUNT(*) AS DECIMAL(5,1)) AS pct_delayed, 
    CAST(AVG(CASE WHEN is_delayed = 1 THEN delay_minutes * 1.0 END) AS DECIMAL(5,1)) AS avg_delay 
FROM transport_analyse 
GROUP BY peak_hour_category 
ORDER BY pct_delayed DESC;
 

-- Delay dan crowding vs kepuasan
SELECT
    CASE
        WHEN passenger_load_factor_pct < 60 THEN 'Low'
        WHEN passenger_load_factor_pct < 90 THEN 'Medium'
        ELSE 'High'
    END AS crowding_level,
    transit_satisfaction_class,
    COUNT(*) AS total_trip
FROM transport_analyse
GROUP BY
    CASE
        WHEN passenger_load_factor_pct < 60 THEN 'Low'
        WHEN passenger_load_factor_pct < 90 THEN 'Medium'
        ELSE 'High'
    END,
    transit_satisfaction_class
ORDER BY crowding_level, transit_satisfaction_class;

-- Q5 Keterlambatan dan kepadatan berdasarkan periode waktu
SELECT
    peak_hour_category,
    COUNT(*) AS total_trip,
    CAST(AVG(delay_minutes * 1.0) AS DECIMAL(5,1)) AS avg_delay,
    CAST(100.0 * SUM(is_delayed) / COUNT(*) AS DECIMAL(5,1)) AS pct_delayed,
    CAST(AVG(passenger_load_factor_pct * 1.0) AS DECIMAL(5,1)) AS avg_passenger_load,
    CAST(AVG(crowding_discomfort_score * 1.0) AS DECIMAL(5,2)) AS avg_crowding
FROM transport_analyse
GROUP BY peak_hour_category
ORDER BY pct_delayed DESC;

