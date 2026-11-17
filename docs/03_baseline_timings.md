# Phase 3: Baseline Timings

**Team:** T0074 · **Section:** E · **Checkpoint:** CP2

## Setup and method

| Item | Value |
|------|-------|
| Machine | MacBook Pro M4 (same laptop will be used for Phase 4) |
| PostgreSQL | 18.6 (Postgres.app), default server settings (`work_mem` = 4MB, `shared_buffers` = 128MB, `max_parallel_workers_per_gather` = 2) |
| Database | `urban_company_db`, schema `uc` |
| Data | `seed_data.zip`: 150,000 bookings, all 11 tables loaded with the expected row counts |
| Indexes | Only the ones PostgreSQL creates for PRIMARY KEY / UNIQUE: `bookings_pkey`, `cities_pkey`, `customers_pkey`, `payouts_pkey`, `payouts_pro_id_week_start_key`, `pro_availability_pkey`, `pro_skills_pkey`, `professionals_pkey`, `reschedules_pkey`, `reviews_pkey`, `service_categories_pkey`, `services_pkey`. No tuning indexes. |
| Statistics | `VACUUM ANALYZE` run once right after loading |
| Command | `./benchmarks/run_benchmark.sh urban_company_db baseline 3` |

Steps to reproduce:

```bash
createdb urban_company_db
psql -d urban_company_db -f sql/01_schema.sql
psql -d urban_company_db -f sql/02_load_data.sql
psql -d urban_company_db -c "VACUUM ANALYZE;"
./benchmarks/run_benchmark.sh urban_company_db baseline 3
```

Every query was run 3 times with `EXPLAIN (ANALYZE, BUFFERS)`; the number recorded is the `Execution Time`
line of each run. Write queries (`W01`–`W05`) ran inside `BEGIN; … ROLLBACK;`, so the data was not changed.
The raw plans of all 3 runs are in [`benchmarks/results/baseline/`](../benchmarks/results/baseline/) (`R01.txt` … `W05.txt`)
and the averages are in [`summary.csv`](../benchmarks/results/baseline/summary.csv).

### Schema fix needed before W01 could run

On the first benchmark attempt `W01` failed:

```
ERROR:  null value in column "discount" of relation "bookings" violates not-null constraint
```

`W01` inserts a new booking without listing `discount` or `cancellation_fee`. Both columns are `NOT NULL`
(every seed row has a value), but they had no default. Following the rule "fix the schema, not the query",
`sql/01_schema.sql` now declares `discount ... NOT NULL DEFAULT 0` and `cancellation_fee ... NOT NULL DEFAULT 0`.
This is also the correct business rule: a newly requested booking has no discount applied and no
cancellation fee. The database was rebuilt from scratch with the fixed schema and all 30 queries were
benchmarked again; the numbers below are from that clean run.

## Timing table (all 30 queries)

| SQL Query | Type | Run 1 (ms) | Run 2 (ms) | Run 3 (ms) | Average (ms) |
|---|---|---:|---:|---:|---:|
| R01: Service menu: active AC Repair services, cheapest first | READ | 0.085 | 0.046 | 0.052 | 0.061 |
| R02: Slot picker: Bengaluru salon professionals free on 3 July 2026 from 11:00 to 12:30 | READ | 6.845 | 6.865 | 6.865 | 6.858 |
| R03: "My bookings": customer 226's upcoming bookings | READ | 5.588 | 5.609 | 5.677 | 5.625 |
| R04: Partner app: professional 425's jobs on 2 July 2026 | READ | 4.937 | 4.583 | 4.638 | 4.719 |
| R05: Dispatch: requested jobs with no professional that start before noon on 2 July 2026 | READ | 7.494 | 7.571 | 7.584 | 7.550 |
| R06: Customer support: look up a customer by mobile number | READ | 1.305 | 1.319 | 1.271 | 1.298 |
| R07: Partner app: professional 425's earnings in the week of 22 June 2026 | READ | 5.132 | 5.124 | 5.095 | 5.117 |
| R08: Finance: payouts still pending for the week starting 22 June 2026 | READ | 1.462 | 1.454 | 1.517 | 1.478 |
| R09: Quality: share of June 2026 jobs that started more than 15 minutes late, per category | READ | 6.114 | 6.073 | 6.095 | 6.094 |
| R10: Quality: no-show rate of professionals with at least 20 assigned jobs | READ | 17.736 | 17.621 | 17.866 | 17.741 |
| R11: Operations: services rescheduled most often in June 2026 | READ | 0.615 | 0.621 | 0.631 | 0.622 |
| R12: UC Plus: total discount given to Plus members per month in 2026 | READ | 7.730 | 7.617 | 7.568 | 7.638 |
| R13: Partner rewards: active professionals who have never had a booking cancelled by a customer | READ | 8.003 | 7.971 | 8.002 | 7.992 |
| R14: Demand planning: Bengaluru bookings by category, weekday and hour of the scheduled slot | READ | 20.673 | 20.875 | 20.724 | 20.757 |
| R15: Quality: professionals whose average rating in June 2026 is below 4.0 (at least 5 reviews) | READ | 12.728 | 12.663 | 12.772 | 12.721 |
| R16: Expansion: top 10 Mumbai pincodes by bookings in June 2026 | READ | 4.836 | 4.939 | 4.773 | 4.849 |
| R17: Retention: customers who booked the same category 3 or more times in 2026 | READ | 15.147 | 14.894 | 15.021 | 15.021 |
| R18: Quality: newest reviews complaining about lateness | READ | 15.636 | 15.985 | 16.150 | 15.924 |
| R19: City report: June 2026 completed jobs and last job date of every active Bengaluru professional | READ | 3304.977 | 3345.317 | 3335.218 | 3328.504 |
| R20: Finance: daily GMV and running total for June 2026 | READ | 8.308 | 8.398 | 8.327 | 8.344 |
| R21: Compliance: completed jobs done by a professional who is not skilled in that service's category | READ | 14.314 | 14.454 | 14.522 | 14.430 |
| R22: Support console: all bookings, newest first, page 4,001 (25 per page) | READ | 32.207 | 32.735 | 32.259 | 32.400 |
| R23: Booking detail page | READ | 0.050 | 0.046 | 0.054 | 0.050 |
| R24: Finance: cancellation fees collected per month in 2026 | READ | 9.467 | 9.381 | 9.699 | 9.516 |
| R25: Capacity: utilisation (booked minutes ÷ available minutes) of Bengaluru professionals, 22–28 June 2026 | READ | 2144.745 | 2141.612 | 2145.006 | 2143.788 |
| W01: Customer app: book an AC service for 3 July 2026, 11:00 | WRITE | 0.575 | 0.553 | 0.529 | 0.552 |
| W02: Dispatch: give the oldest REQUESTED booking to professional 425 | WRITE | 10.763 | 10.988 | 10.846 | 10.866 |
| W03: Partner app: professional 425 finishes their job on 2 July 2026 and gets a ₹50 tip | WRITE | 6.679 | 6.913 | 6.747 | 6.780 |
| W04: Finance: create payouts for the week starting 29 June 2026 from completed jobs | WRITE | 8.958 | 8.852 | 8.819 | 8.876 |
| W05: Operations: assigned jobs whose slot ended before 2 July 2026 without starting become NO_SHOW | WRITE | 7.206 | 7.191 | 7.104 | 7.167 |
| **Total (sum of all 30)** | | **5690.315** | **5728.270** | **5721.431** | **5713.339** |

**Headline:** two queries, **R19 (3,328.5 ms)** and **R25 (2,143.8 ms)**, take **96 %** of the total
workload time. Both run a correlated subquery that seq-scans the 150,000-row `bookings` table once per
professional. All other 28 queries finish in under 33 ms on the seed data, but most of them already read
the whole `bookings` table, so they will grow linearly with the 20× data in Phase 5.

## Scan type and reason, per query

Scan types are taken from the third run's plan (`scan_nodes` column of `summary.csv`). "Rows removed" numbers
are copied from the `Rows Removed by Filter` lines in the raw plans.

| Query | Scan type(s) | Why it is slow or fast |
|-------|--------------|------------------------|
| R01 | Seq Scan on `services`, Seq Scan on `service_categories` | Fast (0.06 ms): both tables are tiny (60 and 10 rows, one page each), so a seq scan + hash join is the cheapest plan; an index would not help. |
| R02 | Seq Scan on `pro_skills`, `professionals`, `service_categories`, `bookings` (parallel); Index Scan `pro_availability_pkey` | The availability lookup uses the composite PK `(pro_id, work_date)` well, but the `NOT EXISTS` clash check has no index on `bookings(pro_id, status, scheduled_start)`, so a parallel seq scan of all 150k bookings is done to find the 15 clashing jobs. |
| R03 | Seq Scan on `bookings`; Seq Scan `services`; Index Scan `professionals_pkey` | No index on `bookings.customer_id`: the plan reads all 150,000 bookings and discards 149,999 to return one row for customer 226. |
| R04 | Parallel Seq Scan on `bookings`; Seq Scan `services` | No index on `pro_id`, and `DATE(scheduled_start) = …` wraps the column in a function so even a future index on `scheduled_start` could not be used (not sargable). 150k rows read to return 1. |
| R05 | Seq Scan on `bookings` | No index on `status`/`scheduled_start`; REQUESTED is a rare status (46 rows match), but all 149,954 other rows still have to be read and filtered. |
| R06 | Seq Scan on `customers` | `customers.phone` has no UNIQUE constraint/index, so a phone lookup reads all 40,000 customers (39,999 removed). Fast in absolute terms only because the table is small. |
| R07 | Parallel Seq Scan on `bookings` | No index on `(pro_id, completed_at)`; 2 matching rows found by scanning all 150k bookings with 1 parallel worker. |
| R08 | Seq Scan on `payouts`, Seq Scan on `professionals` | The UNIQUE `(pro_id, week_start)` index starts with `pro_id`, so it can't be used for a `week_start` filter; all 27,015 payouts are scanned (25,935 removed). Fast because the table is small. |
| R09 | Parallel Seq Scan on `bookings`; Seq Scan `services`, `service_categories` | Reads all bookings to keep ~7,100 June completed jobs (no index on `scheduled_start`), then a cheap hash join + aggregate over 10 categories. |
| R10 | Seq Scan on `bookings` | Aggregates over almost the whole table (143,858 rows with a pro), so a seq scan is the correct access path; time goes into the HashAggregate over 2,220 professionals. One of the slower simple queries (17.7 ms) because it truly reads everything. |
| R11 | Seq Scan on `reschedules`; Index Scan `bookings_pkey`, `services_pkey` | Fast (0.6 ms): `reschedules` is small (5,391 rows) and each of the 269 June reschedules is joined to its booking through the primary-key index. |
| R12 | Parallel Seq Scan on `bookings` | `EXTRACT(YEAR FROM booked_at) = 2026` is a function on the column (not sargable), and there is no index on `discount`; the whole table is read to find 4,543 discounted 2026 bookings. |
| R13 | Seq Scan on `professionals`, Seq Scan on `bookings` (hashed SubPlan) | Seq scan of bookings to build the hashed `NOT IN` list (12,123 rows). **It returns 0 rows**: 6,058 `CANCELLED_BY_CUSTOMER` bookings have `pro_id IS NULL`, and `x NOT IN (…, NULL)` is never TRUE. This is the NULL-related wrong result to fix in Phase 4 (use `NOT EXISTS`). |
| R14 | Seq Scan on `bookings`; Seq Scan `services` | Reads all bookings to keep the 23,919 Bengaluru ones (no index on `city_id`), then sorts them (1.5 MB quicksort) for a GroupAggregate into 840 groups. Large intermediate result makes it the slowest seq-scan report (20.8 ms). |
| R15 | Seq Scan on `reviews`, Seq Scan on `bookings` | Seq scan of reviews for June (4,265 kept, 72,274 removed; no index on `created_at`), and the planner chose a hash join that seq-scans all 150,000 bookings instead of 4,265 PK lookups. |
| R16 | Parallel Seq Scan on `bookings` | No index on `(city_id, booked_at)`; 1,360 Mumbai June bookings found by reading all 150k rows. |
| R17 | Seq Scan on `bookings`; Seq Scan `services` | Reads all bookings to keep 42,145 completed 2026 bookings and hash-aggregates ~40,000 (customer, category) groups, of which only 81 survive `HAVING count(*) >= 3`. Large hash table = 15 ms. |
| R18 | Seq Scan on `reviews` | `ILIKE '%late%'` has a leading wildcard, so a B-tree index can never be used; every one of the 76,539 comments is pattern-matched (68,767 removed), then a top-N sort by `created_at`. Needs a trigram (GIN) index. |
| R19 | Seq Scan on `professionals`; Seq Scan on `bookings` **× 714** | **Slowest query (3.3 s).** Two correlated scalar subqueries run once per active Bengaluru pro (357 loops each). Each loop seq-scans all 150,000 bookings because there is no index on `bookings.pro_id`: 714 full scans ≈ 107 million rows read. |
| R20 | Parallel Seq Scan on `bookings` | `scheduled_start::date BETWEEN …` casts the column (not sargable) and there is no index, so the whole table is read to find 7,111 June completed jobs; the window function on 30 rows is cheap. |
| R21 | Parallel Seq Scan on `bookings`; Seq Scan `services`, `pro_skills` | Must check every completed booking (127,692 rows) against `pro_skills`; the planner correctly uses a Hash Anti Join. Reading most of the table is unavoidable here. |
| R22 | Seq Scan on `bookings` | `ORDER BY booked_at DESC OFFSET 100000` must sort all 150k rows and throw away the first 100,000. The sort doesn't fit in `work_mem` (external merge, 7.4 MB on disk). Needs an index on `booked_at` and keyset pagination. |
| R23 | Index Scan `bookings_pkey`; Seq Scan `services` | Fast (0.05 ms): lookup by primary key, joined to the 60-row services table. |
| R24 | Seq Scan on `bookings` | No index on `cancellation_fee` or `scheduled_start`; 1,228 rows with a fee in 2026 are found by reading all 150k rows. |
| R25 | Index Scan `professionals_pkey`; Seq Scan on `pro_availability`; Seq Scan on `bookings` **× 357** | **Second slowest (2.1 s).** (1) The planner nested-loops 400 Bengaluru pros against 13,320 materialised availability rows, removing 5.3 million rows by join filter. (2) The correlated subquery for booked minutes seq-scans all 150k bookings once per pro (357 loops). No index on `bookings.pro_id` or `pro_availability.work_date`. |
| W01 | (no scan) — Insert | Fast (0.55 ms): a single-row insert; most of the time is the 4 foreign-key checks, each done through a primary-key index. |
| W02 | Index Scan `bookings_pkey` (×2) | `min(booking_id) WHERE status='REQUESTED'` walks the PK index from the start and filters 148,818 rows before it finds the first REQUESTED booking (10.5 ms). The UPDATE itself is a fast PK lookup. A partial index on REQUESTED bookings would make this instant. |
| W03 | Seq Scan on `bookings` | No index on `(pro_id, status, scheduled_start)`; the whole table is read to update 1 row. |
| W04 | Seq Scan on `bookings` | No index on `completed_at`; whole table read to find 462 completed jobs in the week, then 401 payout rows inserted (FK check per row: 0.9 ms). |
| W05 | Seq Scan on `bookings` | No index on `status`/`scheduled_end`; whole table read to update the 154 matching ASSIGNED rows. |

## Summary of what the baseline shows

- **Almost every query does a Seq Scan on `bookings`.** The only index on `bookings` is the primary key,
  so any filter on `pro_id`, `customer_id`, `status`, `city_id` or a date column reads all 150,000 rows.
  On the seed data that costs ~4–8 ms per scan; at 20× data it will cost ~20× more.
- **Correlated subqueries multiply the seq scans:** R19 (714 scans) and R25 (357 scans) together take
  5.47 s of the 5.71 s total. An index on `bookings(pro_id, …)` or a rewrite to a join/GROUP BY is the
  biggest win available in Phase 4.
- **Non-sargable predicates** (R04 `DATE(...)`, R12 `EXTRACT(YEAR ...)`, R20 `::date`) will block indexes
  even after we create them, so these queries also need rewriting to plain range conditions.
- **Leading-wildcard `ILIKE`** (R18) needs a `pg_trgm` GIN index; **deep `OFFSET`** (R22) needs an index on
  `booked_at` plus keyset pagination.
- **Wrong result:** R13 returns an empty list because of `NOT IN` with NULL `pro_id` values; it will be
  rewritten with `NOT EXISTS` in Phase 4.
- Queries on small tables (R01, R06, R08, R11, R23, W01) are already fast; R10 and R21 must read most of
  `bookings` by design and are unlikely to gain much from an index.
