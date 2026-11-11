# -*- coding: utf-8 -*-
"""Static MQL5 safety regressions. These tests DO NOT compile MetaEditor code."""
import pathlib
import re
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]


def source(name):
    return (ROOT / name).read_text(encoding="utf-8-sig")


def without_literals(text):
    """Remove comments/strings while preserving punctuation and newline positions."""
    out, i, mode = [], 0, "code"
    while i < len(text):
        c = text[i]
        d = text[i:i + 2]
        if mode == "code":
            if d == "//":
                mode = "line"
                out.extend("  ")
                i += 2
                continue
            if d == "/*":
                mode = "block"
                out.extend("  ")
                i += 2
                continue
            if c in ('"', "'"):
                mode = c
                out.append(" ")
            else:
                out.append(c)
        elif mode == "line":
            out.append("\n" if c == "\n" else " ")
            if c == "\n":
                mode = "code"
        elif mode == "block":
            if d == "*/":
                out.extend("  ")
                mode = "code"
                i += 2
                continue
            out.append("\n" if c == "\n" else " ")
        else:
            if c == "\\" and i + 1 < len(text):
                out.extend("  ")
                i += 2
                continue
            if c == mode:
                mode = "code"
            out.append("\n" if c == "\n" else " ")
        i += 1
    if mode not in ("code", "line"):
        raise AssertionError("Unterminated MQL literal/comment: " + mode)
    return "".join(out)


def function(name, fname):
    code = source(fname)
    m = re.search(r"(?m)^\s*(?:void|bool|double|int|long|ulong|string|datetime)\s+" +
                  re.escape(name) + r"\s*\([^;{}]*?\)\s*\{", code)
    if not m:
        raise AssertionError(f"Missing function {name} in {fname}")
    start = m.end() - 1
    sanitized = without_literals(code)
    level = 0
    for pos in range(start, len(sanitized)):
        if sanitized[pos] == "{":
            level += 1
        elif sanitized[pos] == "}":
            level -= 1
            if level == 0:
                return code[start:pos + 1]
    raise AssertionError("Unclosed function " + name)


class MqlSafetyRegression(unittest.TestCase):
    def test_all_mql_parentheses_and_braces_balanced(self):
        paths = [ROOT / "BTC_EMA_Pullback_v2.mq5", *(ROOT / "TrendBot").glob("*.mqh")]
        for path in paths:
            with self.subTest(file=path.name):
                clean = without_literals(path.read_text(encoding="utf-8-sig"))
                stack = []
                pairs = {"}": "{", ")": "(", "]": "["}
                for i, c in enumerate(clean):
                    if c in "{([":
                        stack.append((c, i))
                    elif c in "})]":
                        self.assertTrue(stack, f"{path}: unmatched {c} at {i}")
                        self.assertEqual(stack.pop()[0], pairs[c], f"{path}: mismatch at {i}")
                self.assertFalse(stack, f"{path}: missing closing bracket(s) {stack[-5:]}")

    def test_live_r_uses_identifier_and_excludes_open_partial_fills(self):
        src = source("TrendBot/LiveR.mqh")
        self.assertIn("POSITION_IDENTIFIER", src)
        self.assertIn("PositionOpenById(pid)", src)
        self.assertIn("LRStillOpen(ids[j])", src)
        self.assertNotIn("PositionSelectByTicket(ids[j])", src)
        self.assertIn("DEAL_POSITION_ID", src)
        self.assertIn("DEAL_ENTRY_IN", src)
        self.assertIn("DEAL_SL", src)
        self.assertIn("DEAL_FEE", src)
        self.assertIn("OrderCalcProfit(", src)
        self.assertIn("g_lrAutoN = nAuto", src)
        self.assertIn("g_lrN = nMain", src)
        self.assertIn("if(kind[j] == 0 || risk[j] <= 0 || LRStillOpen(ids[j])) continue;", src)
        self.assertIn('GuardDealAuto(deal)', src)

    def test_non_hedging_accounts_refused_both_early_and_after_login(self):
        main = source("BTC_EMA_Pullback_v2.mq5")
        self.assertIn('KHONG KHOI DONG TrendBot: tai khoan NETTING/EXCHANGE', main)
        self.assertIn('ExpertRemove();', function("TryInitState", "BTC_EMA_Pullback_v2.mq5"))
        self.assertIn('return INIT_FAILED;', function("OnInit", "BTC_EMA_Pullback_v2.mq5"))

    def test_magic_zero_is_in_group_limit_under_same_lock(self):
        risk = source("TrendBot/Risk.mqh")
        me = source("TrendBot/ManualEntry.mqh")
        self.assertIn("GroupGuardRiskAllowed", risk)
        self.assertIn("GroupOpenRisk(unknownSLRisk) + OwnOpenRisk(unknownSLRisk)", risk)
        self.assertIn("GlobalVariableSetOnCondition", function("GroupLock", "TrendBot/Risk.mqh"))
        self.assertIn("GroupGuardReserveTag()", risk)
        for fn in ["GuardPyramid", "GuardAutoEntry"]:
            body = function(fn, "TrendBot/ManualEntry.mqh")
            for fragment in ["GroupLock()", "GroupGuardRiskAllowed(newRisk)",
                             "GroupReserveGuard(newRisk)", "GroupUnlock()", "GroupClearGuard()"]:
                self.assertIn(fragment, body, (fn, fragment))
            self.assertLess(body.index("GroupLock()"), body.index("GroupGuardRiskAllowed(newRisk)"))
            self.assertLess(body.index("GroupReserveGuard(newRisk)"), body.index("trade.SetExpertMagicNumber(0)"))
            if fn == "GuardAutoEntry":
                self.assertLess(body.index("GroupUnlock()"), body.index("GuardMarkAuto("))
            else:
                self.assertLess(body.index("GroupUnlock()"), body.index("GuardMarkBotMade("))

    def test_human_and_algo_buckets_independent_for_auto_pyramid(self):
        body = function("GuardPyramid", "TrendBot/ManualEntry.mqh")
        start = body.split("g_gpLast = TimeCurrent();", 1)[0]
        self.assertIn("GuardBucketLocked(2)", start)
        self.assertNotIn("|| GuardBucketLocked(1) ||", start)
        self.assertIn("GuardBucketLocked(1) && !GuardPositionAuto()", body)
        self.assertIn("GuardAlgoBudgetRemaining()", body)

    def test_account_cash_flow_tracking_is_mutexed_and_persistent(self):
        guard = source("TrendBot/Guard.mqh")
        self.assertIn("DEAL_TYPE_BALANCE", guard)
        self.assertIn("cashMutex", guard)
        self.assertIn('GlobalVariableSetOnCondition(mutex, mine, old)', guard)
        self.assertIn('GlobalVariableSetOnCondition(mutex, 0, mine)', guard)
        self.assertIn('cashScan', guard)
        self.assertIn('cashTicket', guard)
        self.assertIn("GuardRiskSave(true)", guard)
        self.assertIn("GuardCashAdjust()", function("GuardCheckAcctDD", "TrendBot/Guard.mqh"))

    def test_missing_external_data_does_not_silently_pass(self):
        main = source("BTC_EMA_Pullback_v2.mq5")
        f = source("TrendBot/Filters.mqh")
        self.assertIn("if(f == EMPTY_VALUE)", function("FundingOk", "BTC_EMA_Pullback_v2.mq5"))
        for label in ["Fear & Greed bat nhung thieu", "Wikipedia bat nhung thieu",
                      "Nasdaq khong du du lieu", "khong truy cap duoc lich tin My"]:
            self.assertIn(label, f)
        self.assertIn("g_newsDataOk = n >= 0", f)
        self.assertIn("!g_newsDataOk", function("GuardPyramid", "TrendBot/ManualEntry.mqh"))

    def test_min_lot_is_refused_at_small_equity(self):
        equity = 40.0
        volume_min = 0.01
        # 1 BTC/lot contract example: 100 USD price change -> 1 USD loss.
        for stop_usd in [100, 500, 3000]:
            expected_loss = volume_min * stop_usd
            self.assertGreater(expected_loss, 0.02 * equity)
            required_equity = expected_loss / 0.02
            self.assertGreater(required_equity, equity)
        self.assertIn("if(lots < minL)", source("TrendBot/Risk.mqh"))


    def test_origin_ledger_attributes_exits_by_opening_position(self):
        ledger = source("TrendBot/Ledger.mqh")
        self.assertIn("DEAL_POSITION_ID", ledger)
        self.assertIn("DEAL_ENTRY_IN", function("LedgerOrigin", "TrendBot/Ledger.mqh"))
        self.assertIn("DEAL_MAGIC", function("LedgerOrigin", "TrendBot/Ledger.mqh"))
        self.assertIn("HistorySelectByPosition(pid)", ledger)
        self.assertIn("DEAL_COMMISSION", ledger)
        self.assertIn("DEAL_FEE", ledger)
        self.assertIn("net -= oldPL", ledger)
        self.assertIn("LedgerMainClosedPL", source("TrendBot/Protection.mqh"))
        guard = source("TrendBot/Guard.mqh")
        self.assertIn("LedgerDayPL(bucket, pl)", guard)
        self.assertNotIn("GuardManualDayPL(DayStart(), 2) + DayPL()", guard)
        self.assertIn("LedgerDayPL(2, dailyPL)", guard)

    def test_account_wide_bucket_keys(self):
        guard = source("TrendBot/Guard.mqh")
        self.assertIn('GAcctKey(bucket == 1 ? "humanLock" : "algoLock")', guard)
        self.assertIn("LedgerDayPL(2, dailyPL)", guard)

    def test_first_order_group_cap_and_missing_stop_fail_closed(self):
        risk = source("TrendBot/Risk.mqh")
        lots = function("CalcLots", "TrendBot/Risk.mqh")
        self.assertIn("if(P_MaxGroupRiskPct > 0 && InGroup())", lots)
        self.assertNotIn('if(P_MaxGroupRiskPct > 0 && corr != "")', lots)
        self.assertIn("return DBL_MAX;", function("GroupOpenRisk", "TrendBot/Risk.mqh"))
        self.assertIn("return DBL_MAX;", function("OwnOpenRisk", "TrendBot/Risk.mqh"))
        self.assertIn("MathMin(BotEquity(), AccountInfoDouble(ACCOUNT_EQUITY))", risk)

    def test_margin_preflight_covers_every_entry_path(self):
        core = source("TrendBot/Core.mqh")
        checker = function("EntryMarginOk", "TrendBot/Core.mqh")
        for frag in ("OrderCalcMargin(", "OrderCheck(", "result.margin_free",
                     "result.margin_level", "free * 0.35"):
            self.assertIn(frag, checker)
        main = source("BTC_EMA_Pullback_v2.mq5")
        manage = source("TrendBot/Manage.mqh")
        me = source("TrendBot/ManualEntry.mqh")
        self.assertIn("EntryMarginOk(true, lots", main)
        self.assertIn("EntryMarginOk(false, lots", main)
        self.assertIn("EntryMarginOk(buy, lots", manage)
        self.assertIn("EntryMarginOk(buy, newLot", me)
        self.assertIn("EntryMarginOk(buy, lot", me)

    def test_cent_symbol_mapping_and_usc_are_not_hardcoded_into_pnl(self):
        main = source("BTC_EMA_Pullback_v2.mq5")
        self.assertIn('_Symbol == "BTCUSDc"', main)
        self.assertIn('P_CorrSymbols = "BTCUSDc,ETHUSDc"', main)
        self.assertIn('P_CorrSymbols == "BTCUSDm,ETHUSDm"', main)
        self.assertIn("OrderCalcProfit", source("TrendBot/Ledger.mqh"))

    def test_mtm_drawdown_has_separate_peak_and_is_not_forced_halt(self):
        protect = source("TrendBot/Protection.mqh")
        self.assertIn('GVGet("mtmPeak"', protect)
        self.assertIn('GVName("mtmPeak")', protect)
        self.assertIn("BotMtmDrawdownPct()", protect)
        self.assertIn("DD mark-to-market", source("TrendBot/Panel.mqh"))

    def test_tester_news_calendar_has_coverage_guard(self):
        filters = source("TrendBot/Filters.mqh")
        self.assertIn("g_newsT[ArraySize(g_newsT)-1] + 7*86400", filters)
        self.assertIn("nearest > 40.0 * 24.0", filters)
        self.assertIn("!g_newsDataOk", filters)


if __name__ == "__main__":
    unittest.main()
