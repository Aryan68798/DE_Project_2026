-- CP1: Database Integrity Validation
SET search_path TO uc;

-- CHECK 1: Verify booking foreign-key relationships
SELECT 'Booking customer references' AS check_name,
       COUNT(*) AS failures
FROM bookings b
LEFT JOIN customers c ON b.customer_id = c.customer_id
WHERE c.customer_id IS NULL

UNION ALL

SELECT 'Booking service references',
       COUNT(*)
FROM bookings b
LEFT JOIN services s ON b.service_id = s.service_id
WHERE s.service_id IS NULL

UNION ALL

SELECT 'Booking professional references',
       COUNT(*)
FROM bookings b
LEFT JOIN professionals p ON b.pro_id = p.pro_id
WHERE b.pro_id IS NOT NULL AND p.pro_id IS NULL;

-- CHECK 2: Verify composite-key uniqueness
SELECT 'Duplicate professional availability' AS check_name,
       COUNT(*) AS failures
FROM (
    SELECT pro_id, work_date
    FROM pro_availability
    GROUP BY pro_id, work_date
    HAVING COUNT(*) > 1
) duplicates

UNION ALL

SELECT 'Duplicate professional weekly payouts',
       COUNT(*)
FROM (
    SELECT pro_id, week_start
    FROM payouts
    GROUP BY pro_id, week_start
    HAVING COUNT(*) > 1
) duplicates;

-- CHECK 3: Verify payout arithmetic
SELECT 'Incorrect net payout calculations' AS check_name,
       COUNT(*) AS failures
FROM payouts
WHERE net_payout <> gross_earnings - commission;
