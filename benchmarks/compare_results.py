#!/usr/bin/env python3
"""Prove the optimized queries return the same rows as the originals.

Runs every READ query of queries/workload_30.sql on the BEFORE database
(no Phase 4 indexes) and of sql/06_optimized_queries.sql on the AFTER
database (with sql/05_indexes.sql), then compares row count and an MD5
checksum of the output.

  * ordered  : same rows in the same order (checked when the query has
               ORDER BY and the order is fully determined).
  * same set : same rows; only the order of rows that tie on the ORDER BY
               columns differs, which SQL allows.

Usage:
  python3 benchmarks/compare_results.py <before_db> <after_db>
Writes a Markdown table to stdout. Needs psql on PATH (or set PSQL=...).
"""
import hashlib
import os
import re
import subprocess
import sys

PSQL = os.environ.get("PSQL", "psql")
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def split(path):
    """Return {id: sql} using the same '-- @R01' markers as run_benchmark.sh."""
    out, cur = {}, None
    for line in open(path, encoding="utf-8"):
        m = re.match(r"^-- @([RW]\d+)\s*$", line)
        if line.startswith("-- @"):
            cur = m.group(1) if m else None
            if cur:
                out[cur] = ""
            continue
        if cur and not line.startswith("--"):
            out[cur] += line
    return out


def run(db, sql):
    res = subprocess.run(
        [PSQL, "-d", db, "-X", "-q", "-A", "-t", "-v", "ON_ERROR_STOP=1"],
        input="SET search_path TO uc;\n" + sql,
        capture_output=True, text=True, check=True,
    )
    return [l for l in res.stdout.splitlines() if l != ""]


def md5(lines):
    return hashlib.md5("\n".join(lines).encode()).hexdigest()[:12]


def main():
    before_db, after_db = sys.argv[1], sys.argv[2]
    orig = split(os.path.join(ROOT, "queries/workload_30.sql"))
    opt = split(os.path.join(ROOT, "sql/06_optimized_queries.sql"))
    print("| Query | Rewritten? | Rows before | Rows after | Checksum before | Checksum after | Same result? |")
    print("|---|---|--:|--:|---|---|---|")
    for qid in sorted(orig, key=lambda k: (k[0] != "R", int(k[1:]))):
        if not qid.startswith("R"):
            continue
        a, b = run(before_db, orig[qid]), run(after_db, opt[qid])
        rewritten = "yes" if orig[qid].strip() != opt[qid].strip() else "no"
        if a == b:
            verdict = "✅ identical (same rows, same order)"
        elif sorted(a) == sorted(b):
            verdict = "✅ same rows (ties in ORDER BY in a different order)"
        else:
            verdict = "❌ DIFFERENT"
        print(f"| {qid} | {rewritten} | {len(a)} | {len(b)} | `{md5(sorted(a))}` | `{md5(sorted(b))}` | {verdict} |")


if __name__ == "__main__":
    main()
