# -*- coding: utf-8 -*-
"""v5.49: giai doan cuoi + ADX manh, do thoi gian tung cum, Spring vao som, gop lenh giay trung (tinh)."""
import unittest

from test_safety import function, source


class V549(unittest.TestCase):
    def test_late_stage_with_strong_adx_keeps_pullback_tools_at_reduced_risk(self):
        smart = function("SmartSignals", "TrendBot/Signals.mqh")
        i = smart.index('list = "5,15,21"; sitRisk')
        self.assertLess(i, smart.index('list = "12,6"'))
        self.assertIn("adx >= P_SmartTrendADX", smart[i - 400:i])
        self.assertIn("if(sitRisk > 0 && sitRisk < 1) mult *= sitRisk;", smart)

    def test_spring_early_only_inside_smart_loop_and_restored(self):
        smart = function("SmartSignals", "TrendBot/Signals.mqh")
        self.assertIn("if(m == 6 && P_SmartSpringEarly) P_SpringFull = false;", smart)
        self.assertLess(smart.index("P_SpringFull = false;"), smart.index("P_SpringFull = kSpr;"))

    def test_slowest_tick_has_section_breakdown(self):
        main = source("BTC_EMA_Pullback_v2.mq5")
        body = function("OnTickBody", "BTC_EMA_Pullback_v2.mq5")
        for n in ("dong bo 9 khung", "ghi trang thai", "phan tich setup", "quan ly lenh"):
            self.assertIn('Prof("%s");' % n, body)
        self.assertIn("ProfBegin();", function("OnTick", "BTC_EMA_Pullback_v2.mq5"))
        self.assertIn("g_tkMaxDetail = g_pf;", source("TrendBot/Core.mqh"))

    def test_duplicate_open_paper_trades_merged_on_load(self):
        load = function("LearnLoadOpen", "TrendBot/Learn.mqh")
        self.assertIn("g_lvt[j].t < g_lvt[i].t", load)
        self.assertIn("if(removed > 0) LearnSaveOpen();", load)


if __name__ == "__main__":
    unittest.main()
