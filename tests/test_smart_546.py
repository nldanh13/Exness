# -*- coding: utf-8 -*-
"""v5.46: hoi quy tinh cho 5 loi tu log v5.45.0 (khong bien dich MetaEditor)."""
import re
import unittest

from test_safety import function, source


class Smart546(unittest.TestCase):
    def test_news_situation_falls_through_when_used_or_expired(self):
        smart = function("SmartSignals", "TrendBot/Signals.mqh")
        self.assertIn("bool newsUsedB = lastNewsB > 0 && lastNewsB == g_newsUsedT;", smart)
        self.assertIn("P_SmartNewsHoldMin <= 0 || minsB <= P_SmartNewsHoldMin", smart)
        self.assertIn("else if(newsHold)", smart)
        self.assertNotIn("else if(lastNewsB > 0)", smart)

    def test_energy_news_ignored_in_every_live_calendar_lookup(self):
        filt = source("TrendBot/Filters.mqh")
        for fn in ("USNewsNear", "MinutesToNews", "LastNewsTime"):
            self.assertIn("!NewsIgnored(ev.name)", function(fn, "TrendBot/Filters.mqh"), fn)
        body = function("NewsIgnored", "TrendBot/Filters.mqh")
        for k in ('"crude"', '"oil"', '"natural gas"'):
            self.assertIn(k, body)
        self.assertLess(filt.index("bool NewsIgnored("), filt.index("bool USNewsNear("))

    def test_situation_and_used_news_survive_restart(self):
        smart = function("SmartSignals", "TrendBot/Signals.mqh")
        self.assertTrue(smart.lstrip("{ \n").startswith("SmartStateLoad();"))
        self.assertIn("SmartStateSave();", smart)
        load = function("SmartStateLoad", "TrendBot/Signals.mqh")
        self.assertIn("MQL_TESTER", load)
        self.assertIn("2 * PeriodSeconds(P_TF)", load)
        self.assertIn('GVName("smNewsUsed")', source("TrendBot/Signals.mqh").split("bool SmartSignals(")[1])
        self.assertIn("g_smartStateLoaded = false;", function("ResetRuntimeState", "BTC_EMA_Pullback_v2.mq5"))

    def test_paper_trade_not_duplicated_and_uses_live_price(self):
        reg = function("LearnRegister", "TrendBot/Learn.mqh")
        self.assertIn("if(g_lvt[i].sit == sit && g_lvt[i].strat == st && g_lvt[i].dir == dir) return;", reg)
        self.assertIn("SymbolInfoDouble(_Symbol, SYMBOL_BID)", reg)
        self.assertIn("g_lvt[n].entry = px;", reg)

    def test_direction_blocked_paper_trades_tagged_and_not_counted(self):
        main = source("BTC_EMA_Pullback_v2.mq5")
        i = main.index("!SyncEntryAllowed(buySignal))")
        self.assertIn('LearnTagBar(g_smartSit, buySignal ? 1 : -1, "dbh=0");', main[i:i + 400])
        self.assertIn("if(LearnCounts(g_lvt[i].feat)) LearnStat(", function("LearnUpdate", "TrendBot/Learn.mqh"))
        self.assertIn("LearnCounts(p[10])", function("LearnLoad", "TrendBot/Learn.mqh"))

    def test_no_signal_on_unsynchronized_history(self):
        main = source("BTC_EMA_Pullback_v2.mq5")
        g = main.index("SERIES_SYNCHRONIZED")
        self.assertLess(g, main.index("   lastBarTime = barTime;"))

    def test_chase_filter_only_blocks_breakout_and_dow_in_strong_trend(self):
        smart = function("SmartSignals", "TrendBot/Signals.mqh")
        self.assertIn("bool chase = g_smartSit == 4 && (m == 1 || m == 16) &&", smart)
        # lenh giay van duoc ghi truoc khi bo setup
        self.assertLess(smart.index("LearnRegister(g_smartSit, m, dm"), smart.index("if(chase && ruleOk)"))

    def test_new_inputs_wired_into_set_loader(self):
        main = source("BTC_EMA_Pullback_v2.mq5")
        for k in ("InpSmartNewsHoldMin", "InpNewsSkipEnergy", "InpSmartChaseADX", "InpSmartChaseSLATR"):
            self.assertRegex(main, r"(?m)^input\s+\w+\s+" + k + r"\s*=")
            self.assertIn('k == "%s"' % k, main)

    def test_micro_lot_off_by_default_and_bounded(self):
        main = source("BTC_EMA_Pullback_v2.mq5")
        self.assertRegex(main, r"(?m)^input\s+bool\s+InpMicroLot\s*=\s*false;")
        calc = function("CalcLots", "TrendBot/Risk.mqh")
        i = calc.index("P_MicroLot")
        blk = calc[i:calc.index("if(lots < minL && P_MaxRiskRoundUp > 0", i)]
        for frag in ("P_Strategy != STRAT_SMART", "HasOwnPosition()", "GroupOpenRisk(stdRisk) > 0",
                     "P_MicroMaxSLATR * atrM", "MathMin(riskBase * P_MicroMaxLossPct / 100.0, allowed)",
                     "riskBase * P_MaxDrawdownPct / 100.0", "lots = minL;"):
            self.assertIn(frag, blk)
        # chi lot toi thieu, khong bao gio lon hon
        self.assertNotIn("lots = minL *", blk)
        for k in ("InpMicroLot", "InpMicroMaxLossPct", "InpMicroMaxSLATR"):
            self.assertIn('k == "%s"' % k, main)


if __name__ == "__main__":
    unittest.main()
