# -*- coding: utf-8 -*-
"""v5.50: nhat ky can thiep BAN <-> BOT (TrendBot_cantiep.csv), kiem tra tinh."""
import unittest

from test_safety import function, source


class V550(unittest.TestCase):
    def test_module_included_after_journal(self):
        main = source("BTC_EMA_Pullback_v2.mq5")
        self.assertLess(main.index('#include "TrendBot/Journal.mqh"'), main.index('#include "TrendBot/Intervene.mqh"'))

    def test_every_bot_trade_result_is_logged(self):
        done = function("TradeDone", "TrendBot/Core.mqh")
        self.assertIn('IvBotDone(true, kind, detail, "")', done)
        self.assertIn("IvBotDone(false, kind, detail, msg)", done)
        core = source("TrendBot/Core.mqh")
        self.assertLess(core.index("void IvBotDone("), core.index("bool TradeDone("))

    def test_snapshot_taken_before_guard_acts(self):
        step = function("SafetyStep", "BTC_EMA_Pullback_v2.mq5")
        self.assertLess(step.index("IvScan();"), step.index("GuardManual();"))

    def test_transactions_hooked_before_state_gate(self):
        tx = function("OnTradeTransaction", "BTC_EMA_Pullback_v2.mq5")
        self.assertLess(tx.index("IvOnTx(trans);"), tx.index("g_stateReady"))
        self.assertIn("IvRelease(reason);", function("OnDeinit", "BTC_EMA_Pullback_v2.mq5"))

    def test_who_comes_from_mt5_reason_and_bot_marks(self):
        iv = source("TrendBot/Intervene.mqh")
        for r in ("DEAL_REASON_WEB", "DEAL_REASON_MOBILE", "DEAL_REASON_CLIENT", "DEAL_REASON_EXPERT", "DEAL_REASON_SL"):
            self.assertIn(r, iv)
        seen = function("IvSeen", "TrendBot/Intervene.mqh")
        self.assertIn("IvBotMark(k, price, sl, tp)", seen)
        self.assertIn("IV_GRACE_MS", seen)
        # Ban sua roi bot sua lai ngay: phan cua ban van duoc ghi
        self.assertIn("IvFlushWait(k);", function("IvBotDone", "TrendBot/Intervene.mqh"))

    def test_stale_request_not_logged_and_tester_skipped(self):
        bd = function("IvBotDone", "TrendBot/Intervene.mqh")
        self.assertLess(bd.index('g_ivWhy = "";'), bd.index("if(!IvOn()) return;"))
        self.assertIn("rc == 0", bd)
        self.assertIn("!MQLInfoInteger(MQL_TESTER)", function("IvOn", "TrendBot/Intervene.mqh"))

    def test_guard_gives_reasons_and_locks_are_noted(self):
        g = source("TrendBot/Guard.mqh")
        self.assertIn('g_ivWhy = StringFormat("lenh tay chua co SL', g)
        self.assertIn("g_ivWhy = StringFormat(\"lenh dang lai %.1fR: \"", g)
        self.assertEqual(g.count('IvNote("BOT"'), 4)

    def test_report_script_sends_new_file(self):
        self.assertIn('"TrendBot_cantiep"', source("GuiNhatKy.ps1"))


if __name__ == "__main__":
    unittest.main()
