# -*- coding: utf-8 -*-
"""DirectionEngine v5.45 shadow-only invariants and matched-horizon metrics."""
from __future__ import annotations

import csv
import importlib.util
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
COLUMNS = [
    "event", "t_m15_server_epoch", "horizon", "entry", "close", "delta_price",
    "atr_m15", "spread", "engine", "legacy", "structure", "ema", "momentum",
    "up_score", "down_score", "adx", "label",
]


def source(path):
    return (ROOT / path).read_text(encoding="utf-8-sig")


def load_evaluator():
    path = ROOT / "cong-cu" / "so_sanh_direction_engine.py"
    spec = importlib.util.spec_from_file_location("so_sanh_direction_engine", path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def score(structure, ema, momentum):
    up = (40 if structure > 0 else 0) + (35 if ema > 0 else 0) + (25 if momentum > 0 else 0)
    down = (40 if structure < 0 else 0) + (35 if ema < 0 else 0) + (25 if momentum < 0 else 0)
    return (1 if up >= 70 and up > down else -1 if down >= 70 and down > up else 0)


def make_row(event, t, horizon, close, structural, ema, macd, legacy, label):
    engine = score(structural, ema, macd)
    up = 40 * (structural > 0) + 35 * (ema > 0) + 25 * (macd > 0)
    down = 40 * (structural < 0) + 35 * (ema < 0) + 25 * (macd < 0)
    return [
        event, t, horizon, 100, close,
        0 if event == "F" else close - 100,
        10, 1, engine, legacy, structural, ema, macd, up, down, 26.5, label,
    ]


class DirectionEngineTests(unittest.TestCase):
    def test_mathematical_model_and_27_category_combinations(self):
        mod = load_evaluator()
        for structural in (-1, 0, 1):
            for ema in (-1, 0, 1):
                for momentum in (-1, 0, 1):
                    self.assertEqual(mod.score(structural, ema, momentum),
                                     score(structural, ema, momentum))
        self.assertEqual(score(1, 1, -1), 1)  #75 points; MACD opposition recorded
        self.assertEqual(score(-1, -1, 1), -1)
        self.assertEqual(score(1, -1, 1), 0)  # 65 vs35 insufficient
        self.assertEqual(score(0, 1, 1), 0)   # EMA+MACD only 60
        self.assertEqual(score(1, 1, 1), 1)

    def test_dow_and_ema_are_never_counted_twice(self):
        code = source("TrendBot/DirectionEngine.mqh")
        self.assertIn("EngineStructureGroup(g_dirLastDow, g_dirLastStructure)", code)
        self.assertIn("EngineEMAGroup(g_syncNineUp, g_syncNineDn,", code)
        self.assertIn("g_tbSnapshotVotes[7], g_tbSnapshotVotes[8], g_dirLastEma", code)
        self.assertIn("r.momentum = g_dirLastMacd;", code)
        self.assertIn("if(dow == 0 || (h4structure != 0 && h4structure != dow)) return 0;", code)
        self.assertIn("if(nine != 0 && ema50 != 0 && nine != ema50) return 0;", code)
        self.assertIn("return dow;", code)
        self.assertNotIn("r.engine = g_dirLastVote", code)
        self.assertNotIn("g_syncDir = ", code)
        self.assertNotIn("g_sigRiskMult =", code)
        self.assertNotIn("P_RiskPercent =", code)
        for prohibited in ("trade.Buy(", "trade.Sell(", "OrderSend(", "SendEntry(", "SyncEntryAllowed("):
            self.assertNotIn(prohibited, code)

    def test_closed_m15_order_and_safe_persistent_outcomes(self):
        code = source("TrendBot/DirectionEngine.mqh")
        main = source("BTC_EMA_Pullback_v2.mq5")
        self.assertIn('if(P_Strategy != STRAT_SMART) return;', code)
        self.assertIn('datetime bar = iTime(_Symbol, PERIOD_M15, 1);', code)
        self.assertIn("g_dirLastBar != bar || !g_syncReady", code)
        self.assertIn("g_syncBar != bar || !g_tbSnapshotReady || g_tbSnapshotBar != bar", code)
        self.assertIn("if(bar == g_engineBar) return;", code)
        self.assertIn("iBarShift(_Symbol, PERIOD_M15, r.t, true)", code)
        self.assertIn("shift <= horizons[j]", code)
        self.assertIn("iClose(_Symbol, PERIOD_M15, shift - horizons[j])", code)
        self.assertIn("const int horizons[3] = {4, 8, 16}", code)
        self.assertIn('StringFormat("LAST,%I64d', code)
        self.assertIn("if(r.t == g_engineBar) EngineApply(r);", code)
        self.assertIn("EngineSavePending();", main)
        self.assertIn("ArrayResize(g_enginePending, 0);", main)
        self.assertIn("if(!EngineAppend(EngineCsvRow(\"R\"", code)
        self.assertIn("if(!EngineAppend(EngineCsvRow(\"F\"", code)
        self.assertIn("r.done |= mask; g_engineOutcomeCount++;", code)
        self.assertIn("return written > 0;", code)
        self.assertLess(main.index("DirectionStep();"), main.index("SyncDirectionStep();"))
        self.assertLess(main.index("SyncDirectionStep();"), main.index("DirectionEngineStep();"))
        self.assertLess(main.index("DirectionEngineStep();"), main.index("JournalScan();"))
        self.assertIn('#include "TrendBot/DirectionEngine.mqh"', main)
        # The real trading gate is still the v5.44 SyncEntryAllowed, never the challenger.
        self.assertIn("!P_ManualEntry && !SyncEntryAllowed(buySignal)", main)
        self.assertNotIn("g_engineDir == (buy", main)

    def test_immutable_matched_outcomes_and_baselines(self):
        mod = load_evaluator()
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "engine.csv"
            with path.open("w", newline="", encoding="utf-8") as f:
                w = csv.writer(f)
                w.writerow(COLUMNS)
                w.writerow(make_row("F", 10000, 0, 0, 1, 1, -1, 0, "PENDING"))
                w.writerow(make_row("R", 10000, 4, 105, 1, 1, -1, 0, "UP"))
                w.writerow(make_row("R", 10000, 8, 95, 1, 1, -1, 0, "DOWN"))
                w.writerow(make_row("R", 10000, 16, 101, 1, 1, -1, 0, "FLAT"))
                w.writerow(make_row("F", 11000, 0, 0, -1, -1, 1, -1, "PENDING"))
                w.writerow(make_row("R", 11000, 4, 97, -1, -1, 1, -1, "DOWN"))
                w.writerow(make_row("R", 11000, 4, 97, -1, -1, 1, -1, "DOWN"))
            report = mod.compare(path)
            self.assertEqual(report["forecasts"], 2)
            self.assertEqual(report["duplicates"], 1)
            h4 = report["horizons"][4]
            self.assertEqual(h4["resolved"], 2)
            self.assertEqual(h4["engine_vs_legacy_disagree"], 1)
            self.assertEqual(h4["models"]["engine"]["correct"], 2)
            self.assertEqual(h4["models"]["legacy"]["abstained"], 1)
            self.assertEqual(h4["models"]["legacy"]["correct"], 1)
            self.assertEqual(h4["models"]["always_up"]["incorrect"], 1)
            self.assertEqual(report["horizons"][8]["models"]["engine"]["incorrect"], 1)
            self.assertEqual(report["horizons"][16]["models"]["engine"]["flat"], 1)
            self.assertEqual(report["horizons"][16]["unresolved_or_missing"], 1)

    def test_mutating_historical_prediction_is_rejected(self):
        mod = load_evaluator()
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "engine.csv"
            original = make_row("F", 10000, 0, 0, 1, 1, 1, 1, "PENDING")
            changed = make_row("R", 10000, 4, 105, -1, -1, -1, 1, "UP")
            with path.open("w", newline="", encoding="utf-8") as f:
                w = csv.writer(f)
                w.writerow(COLUMNS)
                w.writerow(original)
                w.writerow(changed)
            with self.assertRaisesRegex(ValueError, "bi thay doi"):
                mod.compare(path)


if __name__ == "__main__":
    unittest.main()
