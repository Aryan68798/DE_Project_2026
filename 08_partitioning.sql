-- =====================================================================
-- Urban Company DBMS Project · Team T0074 · Section E
-- Phase 5: partitioning design for bookings (sql/08_partitioning.sql)
--
-- Run after 01_schema.sql, 02_load_data.sql and 05_indexes.sql:
--     psql -d urban_company_large -f sql/08_partitioning.sql
--
-- Why bookings, and why RANGE on scheduled_start
--   * bookings is the biggest table (3,000,000 rows on the large data, and
--     it grows every day). Every other big table (reviews, reschedules,
--     payouts) hangs off it.
--   * Almost every query asks for a time window on scheduled_start:
--     one pro's jobs on a day (R04), a customer's upcoming bookings (R03),
--     June jobs per pro (R19), bookings in a week (R25), the daily batch
--     job (W04). With RANGE partitions per month, PostgreSQL skips every
--     month outside the window ("partition pruning").
--   * Old months become read-only. A whole month can be archived or
--     dropped with DETACH PARTITION instead of a slow DELETE + VACUUM.
--   * LIST (by city) or HASH (by booking_id) would not help: city reports
--     still read every month, and HASH prunes only on exact booking_id.
--
-- Primary-key rule for partitioned tables
--   A PRIMARY KEY or UNIQUE constraint on a partitioned table must include
--   every partition-key column. So the key becomes
--   (booking_id, scheduled_start), not booking_id alone.
--   Consequence: reviews.booking_id and reschedules.booking_id can no
--   longer have a FOREIGN KEY to bookings(booking_id) alone. Either they
--   also store scheduled_start (composite FK), or the app/trigger checks it.
--
-- This file builds the partitioned table next to the original as
-- uc.bookings_part, copies the data, and shows pruning with EXPLAIN.
-- The original uc.bookings and all other scripts are left unchanged.
-- =====================================================================

SET search_path TO uc;

DROP TABLE IF EXISTS bookings_part;

-- 1. Parent table: same columns and CHECKs as bookings, partitioned by month
CREATE TABLE bookings_part (
    booking_id       BIGINT       NOT NULL,
    customer_id      INTEGER      NOT NULL REFERENCES customers(customer_id),
    service_id       INTEGER      NOT NULL REFERENCES services(service_id),
    pro_id           INTEGER      REFERENCES professionals(pro_id),
    city_id          INTEGER      NOT NULL REFERENCES cities(city_id),
    pincode          VARCHAR(10)  NOT NULL,
    booked_at        TIMESTAMPTZ  NOT NULL,
    scheduled_start  TIMESTAMPTZ  NOT NULL,
    scheduled_end    TIMESTAMPTZ  NOT NULL,
    started_at       TIMESTAMPTZ,
    completed_at     TIMESTAMPTZ,
    status           VARCHAR(30)  NOT NULL CHECK (status IN (
                         'COMPLETED', 'NO_SHOW', 'CANCELLED_BY_PRO',
                         'CANCELLED_BY_CUSTOMER', 'ASSIGNED', 'REQUESTED',
                         'IN_PROGRESS')),
    price            NUMERIC(10,2) NOT NULL CHECK (price >= 0),
    discount         NUMERIC(10,2) NOT NULL DEFAULT 0 CHECK (discount >= 0),
    cancellation_fee NUMERIC(10,2) NOT NULL DEFAULT 0 CHECK (cancellation_fee >= 0),
    tip              NUMERIC(10,2) CHECK (tip IS NULL OR tip >= 0),
    payment_method   VARCHAR(20)  NOT NULL
                         CHECK (payment_method IN ('UPI', 'CASH', 'CARD', 'WALLET')),
    CHECK (scheduled_end > scheduled_start),
    CHECK (discount <= price),
    -- the partition key must be part of the primary key
    PRIMARY KEY (booking_id, scheduled_start)
) PARTITION BY RANGE (scheduled_start);

-- 2. One partition per month for 2025 and 2026, plus a DEFAULT partition
--    that catches anything outside those months (so an INSERT never fails).
DO $$
DECLARE
    m DATE := DATE '2025-01-01';
BEGIN
    WHILE m < DATE '2027-01-01' LOOP
        EXECUTE format(
            'CREATE TABLE bookings_p%s PARTITION OF bookings_part
                 FOR VALUES FROM (%L) TO (%L)',
            to_char(m, 'YYYY_MM'), m, (m + INTERVAL '1 month')::date);
        m := (m + INTERVAL '1 month')::date;
    END LOOP;
END $$;

CREATE TABLE bookings_p_default PARTITION OF bookings_part DEFAULT;

-- 3. Indexes on the parent are created on every partition automatically.
--    Same idea as 05_indexes.sql, but each index is now one small index
--    per month instead of one big index.
CREATE INDEX ON bookings_part (pro_id, scheduled_start) INCLUDE (status, scheduled_end);
CREATE INDEX ON bookings_part (customer_id, scheduled_start);
CREATE INDEX ON bookings_part (city_id, scheduled_start);

-- 4. Copy the data
INSERT INTO bookings_part SELECT * FROM bookings;
ANALYZE bookings_part;

-- 5. Rows per partition (should be spread evenly across the months)
SELECT tableoid::regclass AS partition, COUNT(*) AS rows
FROM bookings_part
GROUP BY 1
ORDER BY 1;

-- 6. Partition pruning: a one-day window touches ONE partition only.
--    The plan lists only bookings_p2026_06 (compare with the same query
--    on bookings_part without a date filter, which lists every partition).
EXPLAIN (ANALYZE, BUFFERS)
SELECT booking_id, scheduled_start, status
FROM bookings_part
WHERE pro_id = 101
  AND scheduled_start >= TIMESTAMPTZ '2026-06-15 00:00:00+05:30'
  AND scheduled_start <  TIMESTAMPTZ '2026-06-16 00:00:00+05:30'
ORDER BY scheduled_start;

-- 7. A month-long report scans only that month's partition
EXPLAIN (ANALYZE, BUFFERS)
SELECT city_id, COUNT(*) AS jobs, SUM(price - discount) AS revenue
FROM bookings_part
WHERE status = 'COMPLETED'
  AND scheduled_start >= TIMESTAMPTZ '2026-06-01 00:00:00+05:30'
  AND scheduled_start <  TIMESTAMPTZ '2026-07-01 00:00:00+05:30'
GROUP BY city_id;

-- 8. Without a filter on scheduled_start there is no pruning: every
--    partition is scanned. Queries must always carry a date window.
EXPLAIN
SELECT COUNT(*) FROM bookings_part WHERE customer_id = 12345;

-- 9. Archiving: an old month is removed in milliseconds, without DELETE.
--    (Shown, not run, so the data stays complete.)
-- ALTER TABLE bookings_part DETACH PARTITION bookings_p2025_01;
-- ALTER TABLE bookings_p2025_01 SET SCHEMA archive;   -- or pg_dump it and DROP
