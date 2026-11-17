# -*- coding: utf-8 -*-
"""Direction-shadow invariant and pure-Python metric tests (not MetaEditor)."""
import csv
import importlib.util
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def load_evaluator():
    path = ROOT / "cong-cu" / "danh_gia_huong.py"
    spec = importlib.util.spec_from_file_location("danh_gia_huong", path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def src(path):
    return (ROOT / path).read_text(encoding="utf-8-sig")


class DirectionShadowTests(unittest.TestCase):
    def test_no_shadow_vote_reaches_order_paths(self):
        main = src("BTC_EMA_Pullback_v2.mq5")
        direc = src("TrendBot/Direction.mqh")
        risk = src("TrendBot/Risk.mqh")
        signals = src("TrendBot/Signals.mqh")
        self.assertIn('#include "TrendBot/Direction.mqh"', main)
        self.assertIn("DirectionStep();", main)
        self.assertIn("if(P_Strategy != STRAT_SMART) return;", direc)
        for forbidden in ("trade.Buy(", "trade.Sell(", "CalcLots(",
                          "SendEntry(", "P_RiskPercent =", "g_sigRiskMult ="):
            self.assertNotIn(forbidden, direc)
        for shadow_name in ("DirectionStep", "DirConsensus", "g_dirLastVote",
                            "g_dirLastAgree"):
            self.assertNotIn(shadow_name, risk)
            self.assertNotIn(shadow_name, signals)
        self.assertIn("CHI QUAN SAT", direc)

    def test_closed_only_lookahead_safe_horizons_and_persistence(self):
        code = src("TrendBot/Direction.mqh")
        self.assertIn("iTime(_Symbol, PERIOD_M15, 1)", code)
        self.assertIn("iClose(_Symbol, PERIOD_M15, 1)", code)
        self.assertIn("const int horizons[3] = {4, 8, 16}", code)
        self.assertIn("iBarShift(_Symbol, PERIOD_M15, r.t, true)", code)
        self.assertIn("shift <= horizons[j]", code)
        self.assertIn("iClose(_Symbol, PERIOD_M15, shift - horizons[j])", code)
        self.assertIn('StringFormat("LAST,%I64d', code)
        self.assertIn("g_dirLastBar = (datetime)StringToInteger(p[1])", code)
        self.assertIn("DirSavePending();", src("BTC_EMA_Pullback_v2.mq5"))
        self.assertIn("DirRelease();", src("BTC_EMA_Pullback_v2.mq5"))
        self.assertIn("MathMax(2.0 * r.spread, 0.10 * r.atr)", code)
        self.assertIn("if(up >= 3 && down == 0) return 1;", code)
        self.assertIn("if(down >= 3 && up == 0) return -1;", code)

    def test_offline_scores_without_trading_pnl(self):
        mod = load_evaluator()
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "shadow.csv"
            fields = ["event", "t_m15_server_epoch", "horizon", "entry",
                      "close", "delta_price", "atr_m15", "spread",
                      "ensemble", "dow", "ema", "macd", "structure", "label"]
            def row(event, t, h, price, delta, votes, label):
                return [event, t, h, 100, price, delta, 10, 1, *votes, label]
            with path.open("w", newline="", encoding="utf-8") as h:
                writer = csv.writer(h)
                writer.writerow(fields)
                writer.writerow(row("F", 10000, 0, 0, 0, [1, 1, 1, 1, 0], "PENDING"))
                writer.writerow(row("R", 10000, 4, 105, 5, [1, 1, 1, 1, 0], "UP"))
                writer.writerow(row("R", 10000, 8, 95, -5, [1, 1, 1, 1, 0], "DOWN"))
                writer.writerow(row("R", 10000, 16, 101, 1, [1, 1, 1, 1, 0], "FLAT"))
                writer.writerow(row("F", 11000, 0, 0, 0, [0, -1, 1, -1, -1], "PENDING"))
                writer.writerow(row("R", 11000, 4, 97, -3, [0, -1, 1, -1, -1], "DOWN"))
            result = mod.assess(path)
            self.assertEqual(result["forecasts"], 2)
            h4 = result["horizons"][4]
            self.assertEqual(h4["resolved"], 2)
            self.assertEqual(h4["sources"]["ensemble"]["predictions"], 1)
            self.assertEqual(h4["sources"]["ensemble"]["correct"], 1)
            self.assertEqual(h4["sources"]["ensemble"]["abstentions"], 1)
            self.assertEqual(h4["sources"]["dow"]["correct"], 2)
            self.assertEqual(h4["sources"]["ema"]["incorrect"], 1)
            self.assertEqual(result["horizons"][8]["sources"]["ensemble"]["incorrect"], 1)
            self.assertEqual(result["horizons"][16]["sources"]["ensemble"]["flat"], 1)
            self.assertEqual(result["horizons"][16]["unresolved_or_missing"], 1)

    def test_inconsistent_record_is_rejected(self):
        mod = load_evaluator()
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "shadow.csv"
            path.write_text(
                "event,t_m15_server_epoch,horizon,entry,close,delta_price,atr_m15,spread,ensemble,dow,ema,macd,structure,label\n"
                "F,10000,0,100,0,0,10,1,1,1,1,1,0,PENDING\n"
                "R,10000,4,100,105,5,10,1,-1,1,1,1,0,UP\n",
                encoding="utf-8"
            )
            with self.assertRaisesRegex(ValueError, "Thay doi phieu"):
                mod.assess(path)


if __name__ == "__main__":
    unittest.main()
