# -*- coding: utf-8 -*-
"""Offline validator for curated US macro calendar used by MT5 Strategy Tester.

Source schedules:
https://www.bls.gov/schedule/news_release/cpi.htm
https://www.bls.gov/schedule/2026/ (releases 08:30 Eastern).
This dataset intentionally covers CPI/FOMC ONLY; NFP requires a complete
historical series before it may be enabled as a comparable backtest filter.
"""
from datetime import datetime, timezone
from pathlib import Path
import csv

FILE = Path(__file__).resolve().parents[1] / "du-lieu" / "tin_my.csv"
CPI_2026 = [
    "2026-01-13 13:30", "2026-02-13 13:30", "2026-03-11 12:30",
    "2026-04-10 12:30", "2026-05-12 12:30", "2026-06-10 12:30",
    "2026-07-14 12:30", "2026-08-12 12:30", "2026-09-11 12:30",
    "2026-10-14 12:30", "2026-11-10 13:30", "2026-12-10 13:30",
]


def parse(path=FILE):
    rows = []
    with Path(path).open(encoding="utf-8-sig", newline="") as file:
        for raw in csv.reader(file):
            if not raw or raw[0].startswith("#") or raw[0] == "time":
                continue
            if len(raw) < 3:
                raise ValueError("Invalid calendar row: %r" % raw)
            ts, kind, stamp = raw[:3]
            if kind not in ("FOMC", "CPI"):
                raise ValueError("Unexpected macro type %r; history MUST be curated uniformly" % kind)
            when = datetime.strptime(stamp, "%Y-%m-%d %H:%M").replace(tzinfo=timezone.utc)
            if int(when.timestamp()) != int(ts):
                raise ValueError("UTC mismatch: " + repr(raw))
            rows.append((int(ts), kind, stamp))
    if rows != sorted(rows):
        raise ValueError("Macro releases must be ordered UTC")
    if len(set((x[0], x[1]) for x in rows)) != len(rows):
        raise ValueError("Duplicate events")
    if not rows:
        raise ValueError("Empty US calendar")
    return rows


def validate(path=FILE):
    rows = parse(path)
    present = {(kind, stamp) for _, kind, stamp in rows}
    missing = [date for date in CPI_2026 if ("CPI", date) not in present]
    if missing:
        raise ValueError("Missing official CPI 2026 release(s): %r" % missing)
    if ("FOMC", "2026-12-09 19:00") not in present:
        raise ValueError("Missing Dec 9, 2026 FOMC")
    if rows[-1][0] < int(datetime(2026, 12, 10, 13, 30, tzinfo=timezone.utc).timestamp()):
        raise ValueError("Calendar does not cover 2026-12-10")
    print("OK: %d verified, ordered CPI/FOMC events; 12/12 scheduled CPI 2026" % len(rows))
    return rows


if __name__ == "__main__":
    validate()
