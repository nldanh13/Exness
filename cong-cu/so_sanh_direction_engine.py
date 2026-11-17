# -*- coding: utf-8 -*-
"""Compare shadow DirectionEngine v5.45 with the LIVE gate v5.44 at +4/8/16 M15.

Inputs are IMMUTABLE forecasts (F) and subsequent resolved labels (R) from
MT5 Common/Files/TrendBot_direction_engine_..._M15.csv.
Both algorithms share the same timestamps/prices. No actual trade P&L, no fees,
no claims of independent samples or calibrated confidence probabilities.
"""
from __future__ import annotations

import argparse
import csv
import math
from collections import defaultdict
from pathlib import Path

HORIZONS = (4, 8, 16)
REQUIRED = {
    "event", "t_m15_server_epoch", "horizon", "entry", "close",
    "delta_price", "atr_m15", "spread", "engine", "legacy",
    "structure", "ema", "momentum", "up_score", "down_score", "adx", "label",
}
PREDICTORS = ("engine", "legacy", "always_up", "always_down")


def read_ledger(path: str | Path):
    forecasts, outcomes = {}, {}
    duplicates = 0
    with Path(path).open(encoding="utf-8-sig", newline="") as file:
        reader = csv.DictReader(file)
        if reader.fieldnames is None or not REQUIRED.issubset(reader.fieldnames):
            raise ValueError("Sai schema CSV v5.45: can file TrendBot_direction_engine_*_M15.csv")
        for row in reader:
            if not row["event"]:
                continue
            time = int(row["t_m15_server_epoch"])
            horizon = int(row["horizon"])
            if time <= 0:
                raise ValueError("Thoi gian phai >0")
            if row["event"] == "F":
                if horizon != 0:
                    raise ValueError("Forecast khong duoc co horizon >0")
                if time in forecasts:
                    duplicates += 1
                else:
                    for source in ("engine", "legacy", "structure", "ema", "momentum"):
                        if int(row[source]) not in (-1, 0, 1):
                            raise ValueError("Huong du doan ngoai -1/0/+1")
                    up, down = int(row["up_score"]), int(row["down_score"])
                    if not (0 <= up <= 100 and 0 <= down <= 100 and up + down <= 100):
                        raise ValueError("Tong diem khong hop le")
                    if int(row["engine"]) != score(int(row["structure"]), int(row["ema"]), int(row["momentum"])):
                        raise ValueError("Du doan Engine khong khop voi nhom nguon")
                    if up != (40 if int(row["structure"]) > 0 else 0) + (35 if int(row["ema"]) > 0 else 0) + (25 if int(row["momentum"]) > 0 else 0):
                        raise ValueError("Diem mua khong nhat quan")
                    if down != (40 if int(row["structure"]) < 0 else 0) + (35 if int(row["ema"]) < 0 else 0) + (25 if int(row["momentum"]) < 0 else 0):
                        raise ValueError("Diem ban khong nhat quan")
                    forecasts[time] = row
            elif row["event"] == "R":
                if horizon not in HORIZONS:
                    raise ValueError("Horizon chi la 4,8,16")
                if (time, horizon) in outcomes:
                    duplicates += 1
                else:
                    outcomes[(time, horizon)] = row
            else:
                raise ValueError("Event phai F hoac R")
    if not forecasts:
        raise ValueError("Khong co forecast F de danh gia")
    return forecasts, outcomes, duplicates


def score(structure, ema, momentum):
    up = (40 if structure > 0 else 0) + (35 if ema > 0 else 0) + (25 if momentum > 0 else 0)
    down = (40 if structure < 0 else 0) + (35 if ema < 0 else 0) + (25 if momentum < 0 else 0)
    return 1 if up >= 70 and up > down else -1 if down >= 70 and down > up else 0


def realized(row):
    delta = float(row["delta_price"])
    noise = max(2.0 * max(float(row["spread"]), 0.0), 0.1 * max(float(row["atr_m15"]), 0.0))
    return 0 if abs(delta) <= noise else 1 if delta > 0 else -1


def wilson(k, n):
    if not n:
        return (None, None)
    z = 1.96
    p = k/n
    d = 1+z*z/n
    mid = (p+z*z/(2*n))/d
    pad = z*math.sqrt((p*(1-p)+z*z/(4*n))/n)/d
    return (round(max(0, mid-pad), 4), round(min(1, mid+pad), 4))


def compare(path: str | Path):
    forecasts, outcomes, duplicates = read_ledger(path)
    result = {"forecasts": len(forecasts), "duplicates": duplicates,
              "unmatched_outcomes": 0, "horizons": {}}
    for h in HORIZONS:
        stats = {p: defaultdict(int) for p in PREDICTORS}
        market = defaultdict(int)
        for (t, horizon), r in outcomes.items():
            if horizon != h:
                continue
            f = forecasts.get(t)
            if f is None:
                result["unmatched_outcomes"] += 1
                continue
            for key in ("engine", "legacy", "structure", "ema", "momentum", "up_score", "down_score"):
                if int(r[key]) != int(f[key]):
                    raise ValueError(f"Phieu ghi {key} bi thay doi sau forecast t={t}, h={h}")
            for key in ("entry", "atr_m15", "spread"):
                if abs(float(r[key])-float(f[key])) > 1e-5:
                    raise ValueError(f"Du lieu dau vao {key} bi thay doi t={t}, h={h}")
            if abs(float(r["entry"])+float(r["delta_price"])-float(r["close"])) > 1e-5:
                raise ValueError(f"Gia/duong di khong nhat quan t={t}, h={h}")
            actual = realized(r)
            expected = "UP" if actual > 0 else "DOWN" if actual < 0 else "FLAT"
            if r["label"] != expected:
                raise ValueError(f"Nhãn R khong nhat quan t={t}, h={h}")
            market["resolved"] += 1
            market["up" if actual > 0 else "down" if actual < 0 else "flat"] += 1
            if int(f["engine"]) != int(f["legacy"]):
                market["disagree"] += 1
            for model in PREDICTORS:
                vote = (1 if model == "always_up" else -1 if model == "always_down" else int(f[model]))
                row = stats[model]
                row["total"] += 1
                if vote == 0:
                    row["abstain"] += 1
                elif actual == 0:
                    row["flat"] += 1
                elif vote == actual:
                    row["correct"] += 1
                else:
                    row["incorrect"] += 1
        comparisons = {}
        for model, item in stats.items():
            correct, incorrect = item["correct"], item["incorrect"]
            nonflat = correct + incorrect
            comparisons[model] = {
                "predictions": item["total"] - item["abstain"],
                "abstained": item["abstain"],
                "correct": correct, "incorrect": incorrect, "flat": item["flat"],
                "accuracy_nonflat": round(correct/nonflat, 4) if nonflat else None,
                "wilson95_nonflat": wilson(correct, nonflat),
            }
        result["horizons"][h] = {
            "resolved": market["resolved"],
            "unresolved_or_missing": len(forecasts)-market["resolved"],
            "realized": {k: market[k] for k in ("up", "down", "flat")},
            "engine_vs_legacy_disagree": market["disagree"],
            "models": comparisons,
        }
    return result


def format_report(report):
    parts = [
        "DirectionEngine v5.45 / Sync v5.44 - chung nến M15, CHỈ QUAN SÁT",
        f"F={report['forecasts']} | F/R lặp={report['duplicates']} "
        f"| R không có F={report['unmatched_outcomes']}",
    ]
    for h, item in report["horizons"].items():
        actual = item["realized"]
        parts.append(
            f"\nH+{h} M15: có nhãn {item['resolved']}/{report['forecasts']} "
            f"| tăng/giảm/đi ngang={actual['up']}/{actual['down']}/{actual['flat']} "
            f"| Engine khác v5.44={item['engine_vs_legacy_disagree']}"
        )
        for model, row in item["models"].items():
            acc = "-" if row["accuracy_nonflat"] is None else f"{row['accuracy_nonflat']:.1%}"
            low, high = row["wilson95_nonflat"]
            band = "-" if low is None else f"{low:.1%}..{high:.1%}"
            parts.append(
                f"  {model:12} tín hiệu={row['predictions']:5} bỏ phiếu={row['abstained']:5} "
                f"đúng={row['correct']:5} sai={row['incorrect']:5} ngang={row['flat']:5} "
                f"đúng/không ngang={acc:>6} Wilson95={band}"
            )
    parts.append(
        "\nCẢNH BÁO: 4/8/16 và tín hiệu từng nến CHỒNG LẤN; Wilson95 chưa hiệu chỉnh phụ thuộc theo thời gian. "
        "Thang điểm 0-100 KHÔNG phải xác suất. Không tính P&L, spread khớp lệnh, slippage, "
        "margin, drawdown hay lợi nhuận. Cần walk-forward, các khối không chồng lấn và "
        "MT5 Strategy Tester/demo trước bất kỳ thay đổi nào lên giao dịch thật."
    )
    return "\n".join(parts)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("csv", help="Common/Files/TrendBot_direction_engine_..._M15.csv")
    args = parser.parse_args()
    print(format_report(compare(args.csv)))


if __name__ == "__main__":
    main()
