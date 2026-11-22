-- =====================================================================
-- Urban Company DBMS Project · Team T0074 · Section E
-- Phase 4: indexes (sql/05_indexes.sql)
--
-- Run after 01_schema.sql and 02_load_data.sql:
--     psql -d urban_company_db -f sql/05_indexes.sql
--
-- Rules used for every index below
--   * Equality columns first, then the range / sort column.
--   * INCLUDE (...) adds the columns the query reads, so PostgreSQL can
--     answer from the index alone (Index Only Scan) without visiting the table.
--   * A partial index (WHERE ...) stores only the rows a query asks for.
--     That keeps it small when the filter matches a rare status or value
--     (REQUESTED = 84 rows, ASSIGNED = 359, cancellation_fee > 0 = 3,696).
--   * Indexes that already exist from Phase 2 (primary keys and UNIQUE) are
--     not repeated: bookings_pkey, reviews_pkey, pro_skills_pkey,
--     pro_availability_pkey (pro_id, work_date), payouts (pro_id, week_start), …
--
-- IF NOT EXISTS makes the file safe to run twice.
-- =====================================================================

SET search_path TO uc;

-- ---------------------------------------------------------------------
-- bookings: per professional
-- ---------------------------------------------------------------------

-- Serves R02 (clash check), R04 (one pro's jobs on a day), R19 (June jobs
-- per pro), R25 (booked minutes per pro in a week), W03 (pro finishes a job)
-- and R10 (jobs per pro).
-- pro_id is always an equality filter, scheduled_start is the range, so
-- (pro_id, scheduled_start). status and scheduled_end are INCLUDEd because
-- R02, R19 and R25 filter on status and R02/R25 read scheduled_end, which
-- lets those lookups be Index Only Scans.
CREATE INDEX IF NOT EXISTS ix_bookings_pro_start
    ON bookings (pro_id, scheduled_start) INCLUDE (status, scheduled_end);

-- Serves R07 (a pro's earnings in a week, filtered on completed_at) and
-- R19 (last job = max(completed_at) per pro).
-- (pro_id, completed_at): equality then range; for max() PostgreSQL reads
-- the last entry of the pro's slice backwards. price, discount and tip are
-- INCLUDEd so R07 never touches the table.
CREATE INDEX IF NOT EXISTS ix_bookings_pro_completed
    ON bookings (pro_id, completed_at) INCLUDE (status, price, discount, tip);

-- Serves R13 after the NOT EXISTS fix: "does this pro have a booking
-- cancelled by a customer?". Partial, so it holds only those 12,123 rows.
CREATE INDEX IF NOT EXISTS ix_bookings_cust_cancel_pro
    ON bookings (pro_id) WHERE status = 'CANCELLED_BY_CUSTOMER';

-- ---------------------------------------------------------------------
-- bookings: per customer
-- ---------------------------------------------------------------------

-- Serves R03 ("My bookings": one customer, upcoming, sorted by slot).
-- customer_id equality, then scheduled_start for both the >= filter and the
-- ORDER BY, so no sort step is needed.
CREATE INDEX IF NOT EXISTS ix_bookings_customer_start
    ON bookings (customer_id, scheduled_start);

-- ---------------------------------------------------------------------
-- bookings: rare statuses (partial indexes)
-- ---------------------------------------------------------------------

-- Serves R05 (dispatch: REQUESTED jobs starting before a time, sorted).
-- Only 84 REQUESTED rows, so a partial index on scheduled_start is tiny and
-- returns them already sorted.
CREATE INDEX IF NOT EXISTS ix_bookings_requested_start
    ON bookings (scheduled_start) INCLUDE (service_id, city_id)
    WHERE status = 'REQUESTED';

-- Serves W02 (min(booking_id) among REQUESTED bookings): the first entry
-- of this partial index is the answer.
CREATE INDEX IF NOT EXISTS ix_bookings_requested_id
    ON bookings (booking_id) WHERE status = 'REQUESTED';

-- Serves W05 (ASSIGNED jobs whose slot already ended). 359 rows only.
CREATE INDEX IF NOT EXISTS ix_bookings_assigned_end
    ON bookings (scheduled_end) WHERE status = 'ASSIGNED';

-- Serves R24 (cancellation fees per month): only 3,696 rows have a fee.
CREATE INDEX IF NOT EXISTS ix_bookings_fee_start
    ON bookings (scheduled_start) INCLUDE (cancellation_fee)
    WHERE cancellation_fee > 0;

-- Serves R12 after the sargable rewrite (Plus discounts per month in 2026):
-- 20,400 discounted rows, range on booked_at.
CREATE INDEX IF NOT EXISTS ix_bookings_discount_booked
    ON bookings (booked_at) INCLUDE (discount)
    WHERE discount > 0;

-- ---------------------------------------------------------------------
-- bookings: COMPLETED jobs by time (85% of rows are COMPLETED, but each
-- report only reads one month or one week of them)
-- ---------------------------------------------------------------------

-- Serves R09 (late starts in June per category) and R20 (daily GMV in
-- June, after the sargable rewrite). Range on scheduled_start; the columns
-- both reports read are INCLUDEd.
CREATE INDEX IF NOT EXISTS ix_bookings_completed_start
    ON bookings (scheduled_start) INCLUDE (service_id, started_at, price, discount)
    WHERE status = 'COMPLETED';

-- Serves W04 (payouts for a week, filtered on completed_at).
CREATE INDEX IF NOT EXISTS ix_bookings_completed_at
    ON bookings (completed_at) INCLUDE (pro_id, price, discount, tip)
    WHERE status = 'COMPLETED';

-- Serves R17 (repeat customers per category since 1 Jan 2026).
CREATE INDEX IF NOT EXISTS ix_bookings_completed_booked
    ON bookings (booked_at) INCLUDE (customer_id, service_id)
    WHERE status = 'COMPLETED';

-- ---------------------------------------------------------------------
-- bookings: per city and support console
-- ---------------------------------------------------------------------

-- Serves R16 (Mumbai pincodes in June: city_id = 2 and a booked_at range)
-- and R14 (all Bengaluru bookings by category / weekday / hour).
-- city_id equality first, booked_at range second. pincode, service_id and
-- scheduled_start are INCLUDEd so both run as Index Only Scans.
CREATE INDEX IF NOT EXISTS ix_bookings_city_booked
    ON bookings (city_id, booked_at) INCLUDE (pincode, service_id, scheduled_start);

-- Serves R22 (support console: newest bookings first, OFFSET 100000).
-- DESC matches the ORDER BY. The listed columns are INCLUDEd so the
-- 100,025 entries are read from the index, not the table.
CREATE INDEX IF NOT EXISTS ix_bookings_booked_desc
    ON bookings (booked_at DESC) INCLUDE (booking_id, customer_id, service_id, status);

-- ---------------------------------------------------------------------
-- other tables
-- ---------------------------------------------------------------------

-- Serves R06 (support looks up a customer by phone). Phone numbers are
-- unique in the data; a plain B-tree turns a 40,000-row Seq Scan into one
-- index lookup.
CREATE INDEX IF NOT EXISTS ix_customers_phone
    ON customers (phone);

-- Serves R08 (PENDING payouts of one week). Partial on the PENDING status;
-- week_start is the equality filter.
CREATE INDEX IF NOT EXISTS ix_payouts_pending_week
    ON payouts (week_start) WHERE status = 'PENDING';

-- Serves R11 (reschedules created in June).
CREATE INDEX IF NOT EXISTS ix_reschedules_created
    ON reschedules (created_at) INCLUDE (booking_id, requested_by);

-- Serves R15 (reviews created in June, range on created_at) and R18
-- (newest reviews mentioning "late": ORDER BY created_at DESC LIMIT 50).
-- About 10% of comments contain "late", so walking this index backwards
-- finds 50 matches after roughly 500 entries. That beats a pg_trgm GIN
-- index here, which would find all 7,772 matches and then sort them.
CREATE INDEX IF NOT EXISTS ix_reviews_created
    ON reviews (created_at) INCLUDE (rating_for_pro);

-- Serves R25 (availability rows of 22-28 June for every pro). The primary
-- key starts with pro_id, so it can't be used for a date range alone.
CREATE INDEX IF NOT EXISTS ix_pro_availability_date
    ON pro_availability (work_date) INCLUDE (start_time, end_time);

-- Serves R02, R19 and R25 (active professionals of one city).
CREATE INDEX IF NOT EXISTS ix_professionals_city_status
    ON professionals (city_id, status);

-- Phase 5 fix for R02 (slot picker, target under 5 ms). On the large data
-- (50,000 pros) ix_professionals_city_status returned all 7,073 active
-- Bengaluru pros, which were merge-joined with all of pro_skills and then
-- sorted by rating just to keep 10: 6.3 ms. With rating in the index the
-- planner walks the city's active pros best-rated first and stops after
-- 10 matches (LIMIT 10): 0.07 ms. INCLUDE (full_name) covers the SELECT.
CREATE INDEX IF NOT EXISTS ix_professionals_city_status_rating
    ON professionals (city_id, status, rating DESC NULLS LAST) INCLUDE (full_name);

-- Fresh statistics so the planner knows about the new indexes, and an up to
-- date visibility map so Index Only Scans don't fall back to the table.
VACUUM ANALYZE;
