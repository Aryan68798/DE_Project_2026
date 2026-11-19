# Phase 4: Optimization report

**Team T0074 · Section E** · PostgreSQL 18.6 · MacBook Pro M4 (same laptop as the Phase 3 baseline)
· database `urban_company_db` (150,000 bookings) · run on 19 Nov 2026

**Files**
- Indexes: [`sql/05_indexes.sql`](../sql/05_indexes.sql) (20 indexes, each with a comment saying which queries it serves and why)
- Rewritten queries: [`sql/06_optimized_queries.sql`](../sql/06_optimized_queries.sql) (R04, R12, R13, R20 rewritten; the rest unchanged)
- Raw plans and summary: `benchmarks/results/baseline/` (before) and `benchmarks/results/optimized/` (after)
- Result-equality proof: [`benchmarks/compare_results.py`](../benchmarks/compare_results.py)

**Method:** exactly as in Phase 3. `EXPLAIN (ANALYZE, BUFFERS)`, write queries inside `BEGIN … ROLLBACK`.
```
psql -d urban_company_db -f sql/05_indexes.sql          # creates the indexes, then VACUUM ANALYZE
./benchmarks/run_benchmark.sh urban_company_db optimized 5 sql/06_optimized_queries.sql
```
"Before" is the 3-run average from `baseline/summary.csv`; "After" is the 5-run average from
`optimized/summary.csv`. Every number below is copied from those two files.

**Headline:** the 30 queries took **5,713.3 ms** in total before and **85.1 ms** after,
**98.5% less (67× faster)**. The two slowest queries, R19 (3.3 s) and R25 (2.1 s),
now take under 3 ms each.

## 1. Optimization table

Improvement % = (before − after) / before × 100

| Query | Before (ms) | Problem found in the plan | Optimization applied | After (ms) | Improvement | Same result? |
|---|--:|---|---|--:|---|---|
| R01 | 0.061 | Seq Scan on two tiny tables (60 + 10 rows) | None needed: tables fit in one page, Seq Scan is the best plan | 0.048 | 21.3% (1.3×) | ✅ |
| R02 | 6.858 | Seq Scan on professionals + Seq Scan on 150k bookings for the clash check | `ix_professionals_city_status`; clash check uses `ix_bookings_pro_start` (Index Only Scan) | 0.986 | 85.6% (7.0×) | ✅ |
| R03 | 5.625 | Seq Scan on 150k bookings to find one customer | `ix_bookings_customer_start` (customer_id, scheduled_start): lookup + already sorted | 0.056 | 99.0% (100.4×) | ✅ |
| R04 | 4.719 | Seq Scan + `DATE(scheduled_start)` hides the column from any index | Sargable range rewrite + `ix_bookings_pro_start` | 0.049 | 99.0% (96.3×) | ✅ |
| R05 | 7.550 | Seq Scan of 150k rows to find 84 REQUESTED rows, then Sort | Partial index `ix_bookings_requested_start` WHERE status='REQUESTED' (no sort) | 0.032 | 99.6% (235.9×) | ✅ |
| R06 | 1.298 | Seq Scan on 40k customers for one phone number | `ix_customers_phone` | 0.025 | 98.1% (51.9×) | ✅ |
| R07 | 5.117 | Seq Scan on bookings for one pro's week | Covering `ix_bookings_pro_completed` INCLUDE (price, discount, tip): Index Only Scan | 0.055 | 98.9% (93.0×) | ✅ |
| R08 | 1.478 | Seq Scan on 27k payouts | Partial `ix_payouts_pending_week` WHERE status='PENDING' | 0.529 | 64.2% (2.8×) | ✅ |
| R09 | 6.094 | Seq Scan on bookings for one month | Partial covering `ix_bookings_completed_start`: Index Only Scan of June only | 1.619 | 73.4% (3.8×) | ✅ |
| R10 | 17.741 | Seq Scan + aggregate over every booking | Not improved: must count all 150k bookings per pro (see below) | 16.861 | 5.0% (1.1×) | ✅ |
| R11 | 0.622 | Seq Scan on reschedules | `ix_reschedules_created` (Index Only Scan for June) | 0.450 | 27.7% (1.4×) | ✅ |
| R12 | 7.638 | Seq Scan + `EXTRACT(YEAR …)` is not sargable | Range rewrite + partial covering `ix_bookings_discount_booked` WHERE discount > 0 | 0.846 | 88.9% (9.0×) | ✅ |
| R13 | 7.992 | Seq Scan + `NOT IN` over a subquery that contains NULLs → **always 0 rows (wrong)** | `NOT EXISTS` rewrite (correct result) + partial `ix_bookings_cust_cancel_pro` | 0.555 | 93.1% (14.4×) | ⚠️ fixed (was wrong) |
| R14 | 20.757 | Seq Scan on all bookings for city 1 | Covering `ix_bookings_city_booked`: Index Only Scan of city 1 only; still reads 24k rows | 13.482 | 35.0% (1.5×) | ✅ |
| R15 | 12.721 | Seq Scan on reviews and bookings | `ix_reviews_created` for June reviews; bookings side still a hash join | 9.882 | 22.3% (1.3×) | ✅ |
| R16 | 4.849 | Seq Scan on bookings | Covering `ix_bookings_city_booked` (city_id, booked_at) INCLUDE (pincode) | 0.168 | 96.5% (28.9×) | ✅ |
| R17 | 15.021 | Seq Scan on bookings | Partial covering `ix_bookings_completed_booked`: Index Only Scan | 8.294 | 44.8% (1.8×) | ✅ |
| R18 | 15.924 | Seq Scan on 76k reviews + `ILIKE` on every row + Sort | `ix_reviews_created` read backwards; stops after 50 matches | 0.169 | 98.9% (94.2×) | ✅ |
| R19 | 3328.504 | **Correlated subqueries: 2 Seq Scans of 150k bookings for each of 357 pros** (1.8M buffer hits) | `ix_bookings_pro_start` + `ix_bookings_pro_completed` turn each subquery into an index lookup | 1.828 | 99.9% (1820.8×) | ✅ |
| R20 | 8.344 | Seq Scan + `scheduled_start::date` cast is not sargable | Range rewrite + `ix_bookings_completed_start` (Index Only Scan) | 1.147 | 86.3% (7.3×) | ✅ |
| R21 | 14.430 | Seq Scan + anti-join over all 127k completed jobs | Not improved: must check every completed job (see below) | 13.258 | 8.1% (1.1×) | ✅ |
| R22 | 32.400 | Seq Scan + external merge sort on disk (7.4 MB) for OFFSET 100000 | Covering `ix_bookings_booked_desc`: already sorted, no disk sort | 5.985 | 81.5% (5.4×) | ✅ |
| R23 | 0.050 | Already a primary-key lookup | None needed | 0.043 | 14.0% (1.2×) | ✅ |
| R24 | 9.516 | Seq Scan for 3.7k rows with a fee | Partial covering `ix_bookings_fee_start` WHERE cancellation_fee > 0 | 0.241 | 97.5% (39.5×) | ✅ |
| R25 | 2143.788 | **Correlated subquery: Seq Scan of bookings for each of 357 pros** + 5.3M-row nested loop | `ix_pro_availability_date`, `ix_professionals_city_status`, `ix_bookings_pro_start` | 2.778 | 99.9% (771.7×) | ✅ same rows (ties at LIMIT) |
| W01 | 0.552 | Plain INSERT | Slower: 14 more bookings indexes to update (write overhead) | 0.786 | -42.4% (slower) | ✅ (write, data rolled back) |
| W02 | 10.866 | `min(booking_id)` walked the PK through 148,818 non-REQUESTED rows | Partial `ix_bookings_requested_id`: first entry is the answer | 0.418 | 96.2% (26.0×) | ✅ (write, data rolled back) |
| W03 | 6.780 | Seq Scan to find pro 425's job | `ix_bookings_pro_start` | 0.216 | 96.8% (31.4×) | ✅ (write, data rolled back) |
| W04 | 8.876 | Seq Scan for one week of completed jobs | Partial covering `ix_bookings_completed_at`: Index Only Scan | 2.300 | 74.1% (3.9×) | ✅ (write, data rolled back) |
| W05 | 7.167 | Seq Scan for 359 ASSIGNED rows | Partial `ix_bookings_assigned_end` WHERE status='ASSIGNED' | 2.007 | 72.0% (3.6×) | ✅ (write, data rolled back) |
| **Total** | **5713.338** | | | **85.113** | **98.5% (67×)** | |

## 2. The wrong-result query: R13 (NOT IN with NULLs)

R13 asks for active professionals who have **never** had a booking cancelled by a customer. The original
query always returns **0 rows**.

```sql
AND p.pro_id NOT IN (SELECT b.pro_id FROM bookings b WHERE b.status = 'CANCELLED_BY_CUSTOMER')
```

**Why:** customers can cancel before a professional is assigned, so 6,058 of the 12,123
`CANCELLED_BY_CUSTOMER` bookings have `pro_id = NULL`. `x NOT IN (a, b, NULL)` means
`x <> a AND x <> b AND x <> NULL`. `x <> NULL` is UNKNOWN, never TRUE, so the whole condition is never
TRUE and every professional is filtered out.

**Fix:** `NOT EXISTS` only looks for a matching row and doesn't compare against NULLs:

```sql
AND NOT EXISTS (SELECT 1 FROM bookings b
                WHERE b.pro_id = p.pro_id AND b.status = 'CANCELLED_BY_CUSTOMER')
```

| | Rows returned |
|---|--:|
| Original (`NOT IN`) | 0 |
| Fixed (`NOT EXISTS`) | 377 |

`WHERE b.pro_id IS NOT NULL` inside the `NOT IN` subquery would also give the right 377 rows. `NOT EXISTS` was
chosen because it is also faster: an anti-join that uses the small partial index `ix_bookings_cust_cancel_pro`
(7.992 ms → 0.555 ms).

## 3. Proof that results are unchanged

`benchmarks/compare_results.py` runs every READ query twice: the original from `queries/workload_30.sql`
on a copy of the database **without** the new indexes, and the version from `sql/06_optimized_queries.sql`
on the database **with** them. It compares the row count and an MD5 checksum of the rows.

```
python3 benchmarks/compare_results.py <db_without_indexes> <db_with_indexes>
```

| Query | Rewritten? | Rows before | Rows after | Checksum before | Checksum after | Same result? |
|---|---|--:|--:|---|---|---|
| R01 | no | 5 | 5 | `2e47c32fbd9d` | `2e47c32fbd9d` | ✅ identical (same rows, same order) |
| R02 | no | 10 | 10 | `5d1e8eef5ce4` | `5d1e8eef5ce4` | ✅ identical (same rows, same order) |
| R03 | no | 1 | 1 | `769189b68f56` | `769189b68f56` | ✅ identical (same rows, same order) |
| R04 | yes | 1 | 1 | `5b5daf1290f5` | `5b5daf1290f5` | ✅ identical (same rows, same order) |
| R05 | no | 46 | 46 | `c6fdd1e13293` | `c6fdd1e13293` | ✅ identical (same rows, same order) |
| R06 | no | 1 | 1 | `bf6a8935d54c` | `bf6a8935d54c` | ✅ identical (same rows, same order) |
| R07 | no | 1 | 1 | `79601719f02b` | `79601719f02b` | ✅ identical (same rows, same order) |
| R08 | no | 1080 | 1080 | `d64ea21114cb` | `d64ea21114cb` | ✅ identical (same rows, same order) |
| R09 | no | 10 | 10 | `9efb772a8a9d` | `9efb772a8a9d` | ✅ identical (same rows, same order) |
| R10 | no | 20 | 20 | `ef639f411860` | `ef639f411860` | ✅ identical (same rows, same order) |
| R11 | no | 10 | 10 | `0be1d57a53cd` | `0be1d57a53cd` | ✅ identical (same rows, same order) |
| R12 | yes | 6 | 6 | `dc9964f101af` | `dc9964f101af` | ✅ identical (same rows, same order) |
| R13 | yes | 0 | 377 | `d41d8cd98f00` | `5dc0f4c94b82` | ❌ DIFFERENT |
| R14 | no | 840 | 840 | `6aeb3d06caf0` | `6aeb3d06caf0` | ✅ identical (same rows, same order) |
| R15 | no | 86 | 86 | `95d4cc852241` | `95d4cc852241` | ✅ identical (same rows, same order) |
| R16 | no | 10 | 10 | `e749ecdddfcc` | `e749ecdddfcc` | ✅ identical (same rows, same order) |
| R17 | no | 81 | 81 | `4cf14a0933d7` | `4cf14a0933d7` | ✅ identical (same rows, same order) |
| R18 | no | 50 | 50 | `619bcfba34ef` | `619bcfba34ef` | ✅ identical (same rows, same order) |
| R19 | no | 357 | 357 | `4223b933ac15` | `4223b933ac15` | ✅ identical (same rows, same order) |
| R20 | yes | 30 | 30 | `72baf2c767f1` | `72baf2c767f1` | ✅ identical (same rows, same order) |
| R21 | no | 1000 | 1000 | `0cfbc86faee4` | `0cfbc86faee4` | ✅ identical (same rows, same order) |
| R22 | no | 25 | 25 | `4786d9c95332` | `4786d9c95332` | ✅ identical (same rows, same order) |
| R23 | no | 1 | 1 | `520acc9aee4f` | `520acc9aee4f` | ✅ identical (same rows, same order) |
| R24 | no | 7 | 7 | `54f7258d5b09` | `54f7258d5b09` | ✅ identical (same rows, same order) |
| R25 | no | 30 | 30 | `0085d15821ae` | `0085d15821ae` | ✅ identical (same rows, same order) |


Notes on the three rows that are not "identical":
- **R05:** same 46 rows. Some jobs start at the same time, and `ORDER BY scheduled_start` doesn't say
  how to order ties, so the planner may return them in any order.
- **R13:** different on purpose; this is the bug fix in section 2.
- **R25:** the two results have the same 30 `booked_min` values. Four Bengaluru pros have exactly
  225 booked minutes and sit across the `LIMIT 30` cut-off (rows 29–32), so the query itself allows
  either pair of them. The original query has the same non-determinism; adding `a.pro_id` to the
  `ORDER BY` would make it deterministic.

WRITE queries (W01–W05) are not rewritten, so they change exactly the same rows. Indexes never change which
rows a WHERE clause matches, and the benchmark rolls every write back.

## 4. Before/after plans for the 5 biggest improvements

Excerpts of run 1 from `benchmarks/results/baseline/<id>.txt` and `benchmarks/results/optimized/<id>.txt`.

### R19: 3,328.504 ms → 1.828 ms (1,821×)
Before: both correlated subqueries run a full **Seq Scan of bookings for each of the 357 professionals**
(357 × 2 × 150,000 rows; 1,816,443 buffer hits).
```
Seq Scan on professionals p  (actual time=10.456..3304.846 rows=357 loops=1)
  SubPlan 1 -> Seq Scan on bookings b   (actual time=5.157..5.400 rows=3.41 loops=357)
                 Rows Removed by Filter: 149997
  SubPlan 2 -> Seq Scan on bookings b_1 (actual time=0.086..3.849 rows=64.12 loops=357)
                 Rows Removed by Filter: 149936
Execution Time: 3304.977 ms
```
After: each subquery is a few-entry index lookup with no heap access (`Heap Fetches: 0`).
```
Bitmap Index Scan on ix_professionals_city_status (rows=357)
  SubPlan 1 -> Index Only Scan using ix_bookings_pro_start on bookings b (actual time=0.003..0.003 loops=357)
  SubPlan 3 -> Index Only Scan Backward using ix_bookings_pro_completed on bookings b_1 (loops=357)
Execution Time: 2.572 ms
```

### R25: 2,143.788 ms → 2.778 ms (772×)
Before: a **Seq Scan of bookings per professional** in the subquery, plus a nested loop that compared
5.3 million (pro, availability) pairs.
```
GroupAggregate (actual time=9.721..2144.562 rows=357)
  -> Nested Loop  Rows Removed by Join Filter: 5325858
       -> Seq Scan on pro_availability a  Rows Removed by Filter: 57087
  SubPlan 1 -> Seq Scan on bookings b (actual time=5.336..5.382 loops=357)
```
After: availability rows for the week come from `ix_pro_availability_date`, the join is a hash join,
and the subquery is an Index Only Scan on `ix_bookings_pro_start`.
```
HashAggregate (actual time=1.959..2.698 rows=357)
  -> Hash Join
       -> Bitmap Index Scan on ix_pro_availability_date
       -> Bitmap Index Scan on ix_professionals_city_status
  SubPlan 1 -> Index Only Scan using ix_bookings_pro_start on bookings
```

### R22: 32.400 ms → 5.985 ms (5.4×)
Before: all 150,000 rows sorted, **spilling to disk** because the sort didn't fit in `work_mem`.
```
Sort  Sort Key: booked_at DESC  Sort Method: external merge  Disk: 7464kB
  -> Seq Scan on bookings (rows=150000)
Execution Time: 32.207 ms
```
After: the index is already in `booked_at DESC` order and covers every selected column, so PostgreSQL
just walks 100,025 index entries. No sort and no table access.
```
Limit -> Index Only Scan using ix_bookings_booked_desc on bookings (rows=100025)  Heap Fetches: 0
Execution Time: 6.526 ms
```
OFFSET still has to step over 100,000 entries. Keyset pagination
(`WHERE booked_at < <last booked_at on the previous page> ORDER BY booked_at DESC LIMIT 25`) would make
every page cost the same; it is left for Phase 5 because it changes how the app asks for a page.

### W02: 10.866 ms → 0.418 ms (26×)
Before: `min(booking_id) WHERE status='REQUESTED'` walked the primary key from the start and threw away
**148,818** rows before reaching the first REQUESTED booking.
```
Index Scan using bookings_pkey on bookings bookings_1
  Filter: ((status)::text = 'REQUESTED'::text)  Rows Removed by Filter: 148818
Execution Time: 10.763 ms
```
After: the partial index contains only the 84 REQUESTED bookings, so its first entry is the answer.
```
Index Only Scan using ix_bookings_requested_id on bookings bookings_1  (rows=1)  Heap Fetches: 0
Execution Time: 0.446 ms
```

### R05: 7.550 ms → 0.032 ms (236×)
Before: Seq Scan of 150,000 rows to keep 46, then a sort.
```
Sort -> Seq Scan on bookings  Rows Removed by Filter: 149954
Execution Time: 7.494 ms
```
After: one scan of the tiny partial index, already in `scheduled_start` order.
```
Index Scan using ix_bookings_requested_start on bookings  (rows=46)
Execution Time: 0.047 ms
```

## 5. Write overhead

Every new index on `bookings` must be updated on each INSERT and on each UPDATE that changes an indexed
column, so writes pay for faster reads.

| Query | Before (ms) | After (ms) | Change | Why |
|---|--:|--:|---|---|
| W01 INSERT one booking | 0.552 | 0.786 | **+0.234 ms (+42%) slower** | 14 extra indexes on `bookings` to update |
| W02 UPDATE one booking | 10.866 | 0.418 | 96% faster | finding the row got far cheaper than the extra index updates |
| W03 UPDATE one booking | 6.780 | 0.216 | 97% faster | same reason |
| W04 INSERT … SELECT payouts | 8.876 | 2.300 | 74% faster | reading the week's jobs became an Index Only Scan; `payouts` got only one small partial index |
| W05 UPDATE ASSIGNED → NO_SHOW | 7.167 | 2.007 | 72% faster | same reason |

**Is it acceptable?** Yes. Only W01 got slower, by about a quarter of a millisecond, and it still takes
under 1 ms, well inside the 5 ms target for app-facing queries. W02–W05 got faster because finding the
rows was their main cost. To keep write overhead low, the rare-status indexes are partial (REQUESTED,
ASSIGNED, CANCELLED_BY_CUSTOMER, fee > 0, discount > 0), so most INSERTs and UPDATEs don't touch them.

## 6. Index storage

Size from `pg_relation_size` after `VACUUM ANALYZE`.

| Index | Table | Index size | Table size |
|---|---|--:|--:|
| ix_bookings_pro_completed | bookings | 9,576 kB | 20 MB |
| ix_bookings_booked_desc | bookings | 8,800 kB | 20 MB |
| ix_bookings_city_booked | bookings | 8,752 kB | 20 MB |
| ix_bookings_pro_start | bookings | 8,736 kB | 20 MB |
| ix_bookings_completed_start | bookings | 6,376 kB | 20 MB |
| ix_bookings_completed_at | bookings | 6,200 kB | 20 MB |
| ix_bookings_customer_start | bookings | 4,640 kB | 20 MB |
| ix_bookings_completed_booked | bookings | 3,952 kB | 20 MB |
| ix_bookings_discount_booked (partial) | bookings | 648 kB | 20 MB |
| ix_bookings_cust_cancel_pro (partial) | bookings | 144 kB | 20 MB |
| ix_bookings_fee_start (partial) | bookings | 136 kB | 20 MB |
| ix_bookings_requested_start (partial) | bookings | 16 kB | 20 MB |
| ix_bookings_requested_id (partial) | bookings | 16 kB | 20 MB |
| ix_bookings_assigned_end (partial) | bookings | 16 kB | 20 MB |
| ix_pro_availability_date | pro_availability | 2,808 kB | 3,592 kB |
| ix_reviews_created | reviews | 2,384 kB | 4,888 kB |
| ix_customers_phone | customers | 1,248 kB | 3,536 kB |
| ix_reschedules_created | reschedules | 264 kB | 504 kB |
| ix_payouts_pending_week (partial) | payouts | 48 kB | 2,376 kB |
| ix_professionals_city_status | professionals | 40 kB | 216 kB |
| **Total new indexes** | | **63 MB** | |

The 14 new indexes on `bookings` (about 57 MB) are almost **3× the size of the table** (20 MB). Most of that
comes from the covering indexes, which copy columns via `INCLUDE` to get Index Only Scans. On 150k rows
this is cheap. For Phase 5 (20× data) the first candidates to drop or merge are
`ix_bookings_booked_desc` (it only serves R22, which keyset pagination could serve with a smaller index)
and `ix_bookings_completed_booked`, which overlaps with other COMPLETED indexes. The six partial
indexes together take under 1 MB.

## 7. Queries we could not speed up much, and why

| Query | Before → After (ms) | Why it stays slow |
|---|---|---|
| R10 | 17.741 → 16.861 | It counts **every** booking per professional (`GROUP BY pro_id` over all 150k rows, with `HAVING count(*) >= 20`). Any correct plan must read every row, and a Seq Scan is the cheapest way to do that. Only a summary table or materialized view of jobs per pro would help. |
| R21 | 14.430 → 13.258 | It checks **all 127,692 completed jobs** against `pro_skills`. There is no selective filter to index; the plan is already a hash anti-join over two Seq Scans, which is the right shape. |
| R14 | 20.757 → 13.482 | It reads all 23,919 Bengaluru bookings (16% of the table) and groups them. The covering index avoids the table but still has to read and group those rows. |
| R15 | 12.721 → 9.882 | June reviews now come from `ix_reviews_created`, but the join to `bookings` (to get `pro_id`) is a hash join that still scans bookings: the planner estimates one scan is cheaper than thousands of primary-key lookups. |
| R17 | 15.021 → 8.294 | Reads every completed booking booked since 1 Jan 2026 (the Index Only Scan avoids the table, but it is still a large share of the rows), then groups by customer and category. |
| R01, R23 | ~0.05 | Already fast: tiny tables or a primary-key lookup. Nothing to gain. |
