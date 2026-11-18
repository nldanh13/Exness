# -*- coding: utf-8 -*-
"""v5.47: khoi dong giua nen, du lieu 9 khung, Dow di qua xa, lich tin dem, vai tro bo loc (tinh, khong MetaEditor)."""
import unittest

from test_safety import function, source


class V547(unittest.TestCase):
    def test_restart_does_not_analyse_mid_bar_or_twice(self):
        main = source("BTC_EMA_Pullback_v2.mq5")
        a = main.index("if(g_firstBarCheck && !MQLInfoInteger(MQL_TESTER))")
        self.assertLess(main.index("SERIES_SYNCHRONIZED"), a)
        self.assertLess(a, main.index("TraceBegin();"))
        blk = main[a:main.index("EvReset();", a)]
        for frag in ('GVName("lastBarDone")', "TimeCurrent() - barTime > 60", "lastBarTime = barTime;", "return;"):
            self.assertIn(frag, blk)
        self.assertIn("g_firstBarCheck = true;", function("OnInit", "BTC_EMA_Pullback_v2.mq5"))
        self.assertIn("UninitializeReason()", function("OnInit", "BTC_EMA_Pullback_v2.mq5"))

    def test_nine_frames_wait_for_data_instead_of_partial_vote(self):
        sync = function("SyncDirectionStep", "TrendBot/DirectionSync.mqh")
        i = sync.index("if(g_tbMissing > 0)")
        self.assertLess(sync.index("g_tbMissing = 0;"), i)
        self.assertLess(i, sync.index("g_syncReady = true;"))
        self.assertIn("g_syncReady = false; g_syncDir = 0;", sync[i:i + 400])
        self.assertIn("BarsCalculated(g_tbE20[i])", function("TrendAtM15Close", "TrendBot/ManualEntry.mqh"))

    def test_dow_stretch_counts_as_late_stage(self):
        smart = function("SmartSignals", "TrendBot/Signals.mqh")
        self.assertIn("bool stretched = P_DowStretchATR > 0 && stretch >= P_DowStretchATR;", smart)
        self.assertIn("t.legs >= P_DowLateLegs) || stretched))", smart)
        self.assertIn('k == "InpDowStretchATR"', source("BTC_EMA_Pullback_v2.mq5"))

    def test_calendar_cached_and_filtered(self):
        cache = function("CalCache", "TrendBot/Filters.mqh")
        self.assertIn("now - g_calLoaded < 600", cache)
        self.assertIn("NewsIgnored(ev.name)", cache)
        for fn in ("MinutesToNews", "LastNewsTime"):
            self.assertIn("CalCache()", function(fn, "TrendBot/Filters.mqh"))

    def test_first_tick_timing_reported_separately(self):
        core = source("TrendBot/Core.mqh")
        self.assertIn("if(!g_tkFirstDone) { g_tkFirstDone = true; g_tkFirstUs = us; return; }", core)

    def test_observation_status_not_labelled_as_block(self):
        st = source("TrendBot/Status.mqh")
        self.assertNotIn("chan=4,8,16", st)
        self.assertIn("cham=4,8,16;vaitro=chi quan sat", st)


if __name__ == "__main__":
    unittest.main()
