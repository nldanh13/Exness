# -*- coding: utf-8 -*-
"""Regression for one synchronized direction gate in SMART mode.

These are static/pure tests; native MetaEditor compilation and demo tester
remain mandatory before the EX5 is used with a real account.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]

def source(path):
    return (ROOT / path).read_text(encoding="utf-8-sig")

def decision(nine, four, dow):
    """Mirror of SyncCombine: no mismatch/unknown can authorize an entry."""
    if nine == 0 or four == 0 or dow == 0:
        return 0
    return nine if nine == four == dow else 0

class UnifiedDirectionTests(unittest.TestCase):
    def test_full_vote_matrix_blocks_every_conflict_and_unknown(self):
        for nine in (-1, 0, 1):
            for four in (-1, 0, 1):
                for dow in (-1, 0, 1):
                    final = decision(nine, four, dow)
                    expected = nine if nine != 0 and nine == four == dow else 0
                    self.assertEqual(final, expected)
        self.assertEqual(decision(-1, 0, -1), 0)  # reported screenshot: 9TF down, 4-source undecided
        self.assertEqual(decision(1, -1, 1), 0)
        self.assertEqual(decision(-1, -1, -1), -1)
        self.assertEqual(decision(1, 1, 1), 1)

    def test_gate_is_strict_same_closed_m15_and_same_three_sources(self):
        d = source("TrendBot/DirectionSync.mqh")
        self.assertIn("if(nine == 0 || four == 0 || dow == 0) return 0;", d)
        self.assertIn("nine == four && four == dow", d)
        self.assertIn("up >= 6 && votes[6] == 1 && votes[7] == 1 && votes[8] == 1", d)
        self.assertIn("dn >= 6 && votes[6] == -1 && votes[7] == -1 && votes[8] == -1", d)
        self.assertIn("if(g_syncReady && g_syncBar == lastClosed) return;", d)
        self.assertIn("iTime(_Symbol, PERIOD_M15, 1)", d)
        self.assertIn("currentClosed == g_syncBar", d)
        self.assertIn("currentClosed == g_dirLastBar", d)
        self.assertIn("g_syncDir == (buy ? 1 : -1)", d)
        self.assertIn("TrendAtM15Close(i, at)", d)
        self.assertNotIn("trade.Buy(", d)
        self.assertNotIn("trade.Sell(", d)

    def test_nine_display_uses_same_snapshot_as_gate(self):
        d = source("TrendBot/DirectionSync.mqh")
        me = source("TrendBot/ManualEntry.mqh")
        self.assertIn("g_tbSnapshotVotes[i] = votes[i];", d)
        self.assertIn("g_tbSnapshotBar = lastClosed; g_tbSnapshotReady = true;", d)
        self.assertIn("g_tbSnapshotBar == iTime(_Symbol, PERIOD_M15, 1)", me)
        self.assertIn("fresh ? g_tbSnapshotVotes[i] : 0", me)
        self.assertIn("opened + seconds > closeAt", me)
        self.assertIn("shift++; // unfinished HTF bar", me)
        self.assertIn("GetValue(g_tbE20[i], 0, shift, e20)", me)
        self.assertIn("GetValue(g_tbE50[i], 0, shift, e50)", me)
        self.assertIn("KET LUAN: CHO DONG THUAN", d)

    def test_forecasts_resume_without_lookahead_or_duplicate(self):
        d = source("TrendBot/Direction.mqh")
        self.assertIn("if(r.t == g_dirLastBar) DirApplySnapshot(r);", d)
        self.assertIn("DirApplySnapshot(rec);", d)
        self.assertIn("if(bar == g_dirLastBar) return;", d)
        self.assertIn("const int horizons[3] = {4, 8, 16}", d)

    def test_every_auto_entry_path_is_guarded_but_exit_remains(self):
        main = source("BTC_EMA_Pullback_v2.mq5")
        me = source("TrendBot/ManualEntry.mqh")
        manage = source("TrendBot/Manage.mqh")
        self.assertIn('#include "TrendBot/DirectionSync.mqh"', main)
        self.assertLess(main.index("DirectionStep();"), main.index("SyncDirectionStep();"))
        self.assertLess(main.index("SyncDirectionStep();"), main.index("GuardAutoEntry();"))
        self.assertIn("!P_ManualEntry && !SyncEntryAllowed(buySignal)", main)
        self.assertIn("!SyncEntryAllowed(buySignal)", main)
        self.assertIn("!SyncEntryAllowed(buy)", main)
        self.assertIn("g_pendDir = 0; g_pendBlocked++;", main)
        self.assertIn("g_reDir = 0;", main)
        self.assertIn("!SyncEntryAllowed(dir > 0)", me)
        self.assertIn("!SyncEntryAllowed(buy)", me)
        self.assertIn("!SyncEntryAllowed(buy)", manage)
        pyramid = manage.split("void PyramidStep(", 1)[1]
        self.assertLess(pyramid.index("P_ExitOnEMA"), pyramid.index("!SyncEntryAllowed(buy)"))
        self.assertNotIn("P_RiskPercent =", source("TrendBot/DirectionSync.mqh"))
        self.assertNotIn("g_sigRiskMult =", source("TrendBot/DirectionSync.mqh"))

    def test_status_has_one_final_direction_plus_raw_evidence(self):
        p = source("TrendBot/Panel.mqh")
        st = source("TrendBot/Status.mqh")
        self.assertIn("HƯỚNG LỆNH THỐNG NHẤT (M15)", p)
        self.assertIn('huongdongbo=', st)
        self.assertIn('huonglenh=', st)
        self.assertIn('huong=', st)

if __name__ == "__main__":
    unittest.main()
