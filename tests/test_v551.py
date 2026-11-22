# -*- coding: utf-8 -*-
"""v5.51: spread khong lam khoa ngay lenh tay, chi phi bot giam lot khong tinh, file nhat ky theo tai khoan, phat hien gian doan."""
import unittest

from test_safety import function, source


class V551(unittest.TestCase):
    def test_open_spread_measured_only_on_success(self):
        led = function("LedgerDayPL", "TrendBot/Ledger.mqh")
        self.assertLess(led.index("g_ledgerOpenSpread = 0;"), led.index("HistorySelect("))
        self.assertIn("OrderCalcProfit(ORDER_TYPE_BUY, sm, PositionGetDouble(POSITION_VOLUME), ask, bid, sc)", led)
        self.assertLess(led.index("g_ledgerHealthy = true;"), led.index("g_ledgerOpenSpread = sprd;"))

    def test_day_locks_ignore_entry_spread_and_bot_lot_cut(self):
        g = function("GuardManual", "TrendBot/Guard.mqh")
        self.assertIn("pl += g_ledgerOpenSpread - GuardCutPL();", g)
        self.assertIn("hp += g_ledgerOpenSpread - GuardCutPL();", g)
        self.assertIn("ap += g_ledgerOpenSpread;", g)
        # dieu chinh dat SAU khi tinh von dau ngay (base / hb), TRUOC khi so voi gioi han
        self.assertLess(g.index("double hb = eq - hp;"), g.index("hp += g_ledgerOpenSpread"))
        self.assertLess(g.index("hp += g_ledgerOpenSpread"), g.index("hp <= -hb * P_GuardHumanDayPct"))
        self.assertIn("GuardAddCutPL(cut);", g)
        self.assertIn("if(human && OrderCalcProfit(", g)

    def test_journal_files_per_account_and_replay_is_quiet(self):
        self.assertIn('AcctFile("TrendBot_nhatky")', source("TrendBot/Journal.mqh"))
        self.assertIn('AcctFile("TrendBot_cantiep")', source("TrendBot/Intervene.mqh"))
        self.assertEqual(source("TrendBot/Core.mqh").count('AcctFile("TrendBot_truotgia")'), 2)
        js = function("JournalScan", "TrendBot/Journal.mqh")
        self.assertIn("bool replay = !first && !FileIsExist(JR_FILE, FILE_COMMON);", js)
        self.assertIn("bool warn = !quiet", js)
        self.assertIn("if(!replay) JPushLot(x.vol);", js)
        ps = source("GuiNhatKy.ps1")
        self.assertIn("_tk{1}.csv", ps)

    def test_interruptions_logged(self):
        tick = function("OnTick", "BTC_EMA_Pullback_v2.mq5")
        self.assertLess(tick.index("IvHeartbeat();"), tick.index("OnTickBody();"))
        self.assertIn("IvSlowTick(w0, us, g_pf);", tick)
        self.assertIn("IvHeartbeat();", function("OnTimer", "BTC_EMA_Pullback_v2.mq5"))
        self.assertIn("g_ivBeat = 0;", function("IvRelease", "TrendBot/Intervene.mqh"))


if __name__ == "__main__":
    unittest.main()
