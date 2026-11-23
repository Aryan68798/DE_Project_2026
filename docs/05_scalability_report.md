# Phase 5: Scalability report

**Team T0074 · Section E** · PostgreSQL 18.6 · MacBook Pro M4, 16 GB (same laptop as Phases 3 and 4)
· database `urban_company_large` (3,000,000 bookings) · run on 22 Nov 2026

**Files**
- Raw plans and summary on the large data: `benchmarks/results/large/` (3 runs per query)
- Seed results we compare against: `benchmarks/results/optimized/summary.csv` (Phase 4)
- Indexes: [`sql/05_indexes.sql`](../sql/05_indexes.sql) (one index added in this phase, see §3)
- Partitioning design: [`sql/08_partitioning.sql`](../sql/08_partitioning.sql)

**Method**
```
createdb urban_company_large
psql -d urban_company_large -f sql/01_schema.sql
psql -d urban_company_large -f sql/02_load_data.sql      # folder name changed to large_data/ only
psql -d urban_company_large -f sql/05_indexes.sql        # ends with VACUUM ANALYZE
./benchmarks/run_benchmark.sh urban_company_large large 3 sql/06_optimized_queries.sql
```
Only the **optimized** queries were run on the large data, never the original 30.
Loading the 7.5 million rows took 45 s and building the indexes 13 s.

| Table | Seed rows | Large rows | Growth |
|-------|----------:|-----------:|-------:|
| bookings | 150,000 | 3,000,000 | 20× |
| reviews | 76,539 | 1,535,227 | 20× |
| pro_availability | 70,407 | 1,397,530 | 20× |
| customers | 40,000 | 800,000 | 20× |
| payouts | 27,015 | 536,303 | 20× |
| reschedules | 5,391 | 106,306 | 20× |
| pro_skills | 5,000 | 100,001 | 20× |
| professionals | 2,500 | 50,000 | 20× |

**Headline:** all 30 queries meet their target on the large data. Together they take
**1,125.6 ms** on 3,000,000 bookings against **85.1 ms** on 150,000, i.e. **13× more time for
20× more data**. One query (R02) missed its 5 ms target at first; one new index fixed it (§3).

## 1. Results table

| Query | Optimized on seed (ms) | Optimized on large (ms) | Growth (large ÷ seed) | Target | Meets target? | If not, what you changed |
|-------|------------------------:|------------------------:|----------------------:|-------:|:-------------:|--------------------------|
| R01 | 0.048 | 0.062 | 1.3× | < 5 ms | ✅ |  |
| R02 | 0.986 | 0.190 | 0.2× | < 5 ms | ✅ | Was 6.28 ms; added `ix_professionals_city_status_rating` (§3) |
| R03 | 0.056 | 0.045 | 0.8× | < 5 ms | ✅ |  |
| R04 | 0.049 | 0.042 | 0.9× | < 5 ms | ✅ |  |
| R05 | 0.032 | 0.463 | 14.5× | < 5 ms | ✅ |  |
| R06 | 0.025 | 0.026 | 1.0× | < 5 ms | ✅ |  |
| R07 | 0.055 | 0.051 | 0.9× | < 5 ms | ✅ |  |
| R08 | 0.529 | 11.134 | 21.0× | < 250 ms | ✅ |  |
| R09 | 1.619 | 15.192 | 9.4× | < 5,000 ms | ✅ |  |
| R10 | 16.861 | 167.410 | 9.9× | < 5,000 ms | ✅ |  |
| R11 | 0.450 | 7.583 | 16.9× | < 250 ms | ✅ |  |
| R12 | 0.846 | 19.500 | 23.0× | < 5,000 ms | ✅ |  |
| R13 | 0.555 | 21.362 | 38.5× | < 250 ms | ✅ |  |
| R14 | 13.482 | 149.857 | 11.1× | < 5,000 ms | ✅ |  |
| R15 | 9.882 | 89.560 | 9.1× | < 5,000 ms | ✅ |  |
| R16 | 0.168 | 2.704 | 16.1× | < 250 ms | ✅ |  |
| R17 | 8.294 | 245.935 | 29.7× | < 5,000 ms | ✅ |  |
| R18 | 0.169 | 0.299 | 1.8× | < 250 ms | ✅ |  |
| R19 | 1.828 | 40.970 | 22.4× | < 5,000 ms | ✅ |  |
| R20 | 1.147 | 22.840 | 19.9× | < 5,000 ms | ✅ |  |
| R21 | 13.258 | 180.732 | 13.6× | < 5,000 ms | ✅ |  |
| R22 | 5.985 | 6.556 | 1.1× | < 250 ms | ✅ |  |
| R23 | 0.043 | 0.045 | 1.0× | < 5 ms | ✅ |  |
| R24 | 0.241 | 3.446 | 14.3× | < 5,000 ms | ✅ |  |
| R25 | 2.778 | 44.662 | 16.1× | < 5,000 ms | ✅ |  |
| W01 | 0.786 | 0.836 | 1.1× | < 5 ms | ✅ |  |
| W02 | 0.418 | 0.460 | 1.1× | < 5 ms | ✅ |  |
| W03 | 0.216 | 0.046 | 0.2× | < 5 ms | ✅ |  |
| W04 | 2.300 | 50.342 | 21.9× | < 1,000 ms | ✅ |  |
| W05 | 2.007 | 43.271 | 21.6× | < 250 ms | ✅ |  |

Targets: real-time / app-facing < 5 ms · interactive tools < 250 ms · reports < 5,000 ms ·
batch W04 < 1,000 ms. Closest to its limit is **R17 at 246 ms against 5,000 ms** (5% of the budget),
so every group has a large safety margin.

## 2. Growth analysis (data grew 20×)

### 2.1 Stayed about the same (under 2×): R01, R02, R03, R04, R06, R07, R18, R22, R23, W01, W02, W03
These are **index lookups that return a fixed number of rows**. A B-tree's depth grows with
log n: going from 150,000 to 3,000,000 bookings adds at most one level to the tree, i.e. one more
page read. Examples:
- **R03, R04, R07, W03** go straight to one customer's or one professional's rows through
  `ix_bookings_customer_start` / `ix_bookings_pro_start` / `ix_bookings_pro_completed`. Each
  customer and professional still has about the same number of bookings, so the work is the same.
- **R06** (customer by phone) and **R23** (booking by id) are single-row index lookups.
- **R22** (support console, page 4,001) uses the index `ix_bookings_booked_desc` and reads the
  first 100,025 index entries. That count depends on the page number, not on the table size, so
  it stays at ~6 ms. (With keyset pagination it would be ~0.05 ms; see §5.3.)
- **R01** and **W01/W02** touch tiny tables (`services`, `service_categories`) or a handful of rows.
- **R02** became *faster* (0.99 → 0.19 ms) because of the new index from §3.

### 2.2 Grew roughly in proportion (9× – 23×): R05, R08–R12, R14–R16, R19–R21, R24, R25, W04, W05
These queries **read a fixed share of a table**: "all jobs in June 2026", "all REQUESTED
bookings", "every pro in Bengaluru". When the table grows 20×, that share holds 20× more rows,
so the time grows close to 20×. Most of them still use Index Only Scans, so they read only the
rows they need, but they need 20× more of them.
- **R09, R10, R14, R15, R21** grew 9–14×, a bit less than 20×, because part of the time on the
  seed data was fixed overhead (planning, hash setup) and because the large plans use 2 parallel
  workers that the planner did not bother with on the seed data.
- **R08, R12, R19, R20, W04, W05** grew 20–23×: pure "read 20× the rows" behaviour.
- **R10 and R21** use a `Seq Scan on bookings` because they aggregate *all* assigned or completed
  jobs; an index would not help. At 167 ms and 181 ms they are far below the 5 s report target.

### 2.3 Grew more than 20×: R13 (38×), R17 (30×)
- **R17** (customers who booked one category 3+ times in 2026) groups 842,638 bookings by
  (customer, category) into ~800,000 groups. With the default `work_mem = 4MB` the hash table no
  longer fits in memory: the plan shows `Batches: 17  Disk Usage: 30992kB`, so it spills to a temp
  file. On the seed data it fit in one batch. Spilling is what makes the growth super-linear.
  Running it with `SET work_mem = '64MB'` (only in the reporting session) keeps it in memory
  (`Batches: 1`) and brings it from 269 ms to 218 ms. It meets the target either way (246 ms vs
  5,000 ms), so we did not change the server setting.
- **R13** (active pros never cancelled by a customer) is a hash anti-join between 44,064 active
  professionals and 238,918 customer-cancelled bookings (from the partial index
  `ix_bookings_cust_cancel_pro`). Both inputs grew 20×. On the seed data the whole hash fit in the
  CPU cache and the query took only 0.555 ms, so the fixed overhead was a big share; the ratio
  looks large because the base was so small. 21 ms against a 250 ms target is fine.

## 3. What broke at scale and how we fixed it

**R02 (slot picker), target < 5 ms: first run on the large data 6.50 ms.**

Before (plan from `benchmarks/results/large/`, first run, 6.28 ms):
```
Limit (actual time=5.681..6.242 rows=10)
  -> Nested Loop Anti Join
     -> Nested Loop
        -> Gather Merge                     -- 2 parallel workers
           -> Sort  Sort Key: p.rating DESC NULLS LAST
              -> Nested Loop  Join Filter: (ps.category_id = c.category_id)
                                Rows Removed by Join Filter: 3941
                 -> Merge Join  Merge Cond: (ps.pro_id = p.pro_id)
                    -> Parallel Index Only Scan using pro_skills_pkey on pro_skills   rows=33329 x3
                    -> Sort -> Bitmap Heap Scan on professionals p                    rows=7073
                               -> Bitmap Index Scan on ix_professionals_city_status
Execution Time: 6.280 ms
```
**Why it broke:** on the seed data Bengaluru had ~350 active pros; on the large data it has 7,073.
The plan fetched **all** of them, joined them with **all 100,000** `pro_skills` rows, threw most
away, and **sorted** the survivors by rating just to return the top 10. Every step scaled with the
city size even though the answer is always 10 rows.

**Fix:** put the sort column into the index (added to `sql/05_indexes.sql`):
```sql
CREATE INDEX IF NOT EXISTS ix_professionals_city_status_rating
    ON professionals (city_id, status, rating DESC NULLS LAST) INCLUDE (full_name);
```
After (0.074 ms on its own, 0.19 ms average in the benchmark including the first cold run):
```
Limit (actual time=0.021..0.066 rows=10)
  -> Nested Loop Anti Join
     -> Nested Loop
        -> Nested Loop
           -> Index Scan using ix_professionals_city_status_rating on professionals p   rows=20
           -> Index Only Scan using pro_skills_pkey on pro_skills ps                   loops=20
        -> Index Scan using pro_availability_pkey on pro_availability a                loops=10
     -> Index Only Scan using ix_bookings_pro_start on bookings b                       loops=10
Execution Time: 0.074 ms
```
The index already returns the pros best-rated first, so there is no Sort, and thanks to
`LIMIT 10` PostgreSQL stops after reading **20** professionals instead of 7,073: **85× faster**.
We also tried an index on `pro_skills (category_id, pro_id)`; the planner did not use it, so we
dropped it. The new index is 2.5 MB.

No other query missed its target, so no other change was needed.

## 4. Storage

| | Seed (150k bookings) | Large (3M bookings) | Growth |
|---|---:|---:|---:|
| Tables (heap + TOAST) | 35 MB | 696 MB | 20× |
| Indexes | 72 MB | 1,436 MB | 20× |
| **Total** | **108 MB** | **2,132 MB** | 20× |
| `bookings` table | 20 MB | 398 MB | 20× |
| `bookings` indexes (15 incl. PK) | 60 MB | 1,192 MB | 20× |
| `reviews` table / indexes | 4.9 MB / 4.1 MB | 96 MB / 79 MB | 20× |
| `pro_availability` table / indexes | 3.6 MB / 4.3 MB | 70 MB / 83 MB | 20× |

Storage grows linearly. The indexes take **2× the space of the tables**, and on `bookings` 3× the
table: that is the price of the Index Only Scans that make the reads fast (Phase 4 §6 measured
the write overhead). At 100× (15 M bookings) we expect about 2 GB of bookings heap and 6 GB of
bookings indexes, which is the main reason for partitioning below.

## 5. Architecture for 100× (15,000,000 bookings)

### 5.1 Partitioning
**Table:** `bookings`. **Method:** `RANGE` on `scheduled_start`, **one partition per month**.
DDL, data copy and pruning demo: [`sql/08_partitioning.sql`](../sql/08_partitioning.sql)
(built as `uc.bookings_part` next to the original; 3,000,000 rows copied in ~40 s).

Why this column and method:
- 23 of our 30 queries filter on a date column (`scheduled_start`, `booked_at`, `completed_at`, …) (a day, a week,
  June 2026, the year 2026). RANGE by month lets PostgreSQL skip every other month.
- The data spreads evenly: every month holds 154,000–171,000 bookings (see the row count in the
  script output), so no partition becomes a hotspot.
- Old months never change again. They can be archived with `DETACH PARTITION` in milliseconds,
  instead of a huge `DELETE` followed by a long VACUUM.
- LIST by city would not help the national reports, and HASH by `booking_id` only prunes on
  exact id lookups (R23), which are already fast.

**Partition pruning (measured on the 3M rows):**
```
-- one professional, one day
Index Scan using bookings_p2026_06_pro_id_scheduled_start_... on bookings_p2026_06
  Index Cond: ((pro_id = 101) AND (scheduled_start >= '2026-06-15') AND (scheduled_start < '2026-06-16'))
Execution Time: 0.011 ms

-- June city revenue report: only the June partition (164,772 rows) is scanned, not 3,000,000
Parallel Seq Scan on bookings_p2026_06
Execution Time: 16.8 ms

-- no date filter: every one of the 25 partitions is scanned (no pruning)
Append -> Index Only Scan on bookings_p2025_01 ... bookings_p2026_07, bookings_p_default
```
So the rule for the app is: **every query on bookings must carry a date window**. R13 and
R23 (all-time per professional, lookup by id) do not, and would have to visit every partition's index; for
them we would keep the date in the URL/session or add it to the WHERE clause.

**Primary-key rule:** on a partitioned table every PRIMARY KEY / UNIQUE constraint must contain
the partition key. So the key becomes `PRIMARY KEY (booking_id, scheduled_start)`.
Consequence: `reviews.booking_id` and `reschedules.booking_id` can no longer reference
`bookings(booking_id)` alone. Either they store `scheduled_start` too (composite foreign key),
or the check moves to a trigger / the application.

### 5.2 Sharding
We would shard by **city** (`city_id`). Every booking, its professional, its availability and its
customer address belong to one city, so the real-time path (R02, R03, R04, R05, R06, W01–W03)
stays on one shard. Sharding by professional or customer would split one city's dispatch (R05,
W02) across all shards.

Queries that become **cross-shard**: the national reports R09, R10, R12, R13, R15, R17, R21, R24
and finance W04 (payouts per pro, but a pro could move city). We would handle them by
(a) running them on every shard in parallel and merging the partial results (counts and sums
merge easily; R10's rate = sum(no-shows) / sum(jobs)), or (b) better, sending a nightly copy of
every shard into one **analytics warehouse** and running the reports there. Customers who book
in two cities (R17, R06 phone lookup) need a small global `customers` directory.

### 5.3 Read replicas and caching
- **Must hit the primary** (they write, or must see a write that just happened): W01–W05, R02
  (slot picker must see the booking made a second ago, or we double-book), R04 (partner's job
  list), R05 (dispatch queue), R23 (booking detail right after booking).
- **Replica** (a few seconds of lag is fine): R03, R06, R07, R08, R11, R16, R18, R19, R22, R25.
- **Replica + cache / summary table** (heavy reports, data changes slowly): R09, R10, R12, R13,
  R14, R15, R17, R20, R21, R24. These are the queries that grew ~20× (§2.2–2.3); precomputing them
  into a daily summary table refreshed at night makes them constant-time. R01 (service menu) is
  cached in the app: it changes only when the catalogue changes.
- **R22** should move to keyset pagination (`WHERE booked_at < :last_seen ORDER BY booked_at DESC
  LIMIT 25`, where `:last_seen` is the `booked_at` of the last row on the previous page) so deep
  pages stay at ~0.05 ms instead of growing with the page number.

### 5.4 Maintenance
- `bookings` is update-heavy (status changes in W02, W03, W05). Default autovacuum waits for 20%
  of the table to change, which at 15 M rows means 3 M dead rows. We would set
  ```sql
  ALTER TABLE uc.bookings SET (autovacuum_vacuum_scale_factor = 0.01,
                               autovacuum_analyze_scale_factor = 0.005);
  ```
  so it runs after ~1% changes. With monthly partitions this matters less: only the current and
  next month's partitions are updated, old ones are frozen once and never vacuumed again.
- Index Only Scans (most of our plans) depend on an up-to-date visibility map, which is another
  reason to vacuum `bookings` often.
- **Archiving:** keep 18 months online; `DETACH PARTITION` older months and move them to cheap
  storage. Reports on history run in the warehouse.
- **Summary tables:** refresh the daily/monthly report tables (§5.3) every night after the
  payout job W04, with `REFRESH MATERIALIZED VIEW CONCURRENTLY` so reads are not blocked.
- `work_mem` 32–64 MB for the reporting role only, so big GROUP BYs like R17 do not spill (§2.3).

## 6. Conclusion
**Yes, the database is ready for next year's 20× growth.** On 3,000,000 bookings every one of the
30 queries meets its target, most of them by a wide margin, after one extra index (R02). The
real-time queries stay flat because they are index lookups; the reports grow linearly but are
still 20–30× under their limit; storage grows linearly to 2.1 GB.

Remaining risks:
1. **Reports grow linearly.** At 100× R17 would reach ~1.2 s and R10/R21 ~0.9 s: still under 5 s,
   but they need summary tables (§5.3) before the data grows much further.
2. **Index size.** `bookings` indexes are 3× the table; every new booking updates 15 indexes. Monthly
   partitions keep each index small and the write path bounded.
3. **Queries without a date window** (R13, R23) lose the benefit of partitioning.
4. **R22's OFFSET pagination** gets slower for deeper pages; keyset pagination fixes it.
5. These numbers are from one laptop with all data in RAM (shared_buffers 128 MB plus OS cache).
   On a server where the 2 GB no longer fits in memory, the first run of each query would be slower.
