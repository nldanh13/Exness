//+------------------------------------------------------------------+
//| TrendBot/Panel.mqh: Bang thong tin tren bieu do
//+------------------------------------------------------------------+
//--- Bang thong tin ------------------------------------------------
int TradesToday()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   dt.hour = 0; dt.min = 0; dt.sec = 0;
   if(!HistorySelect(StructToTime(dt), TimeCurrent() + 60)) return 0;
   int n = 0;
   for(int i = HistoryDealsTotal() - 1; i >= 0; i--)
   {
      ulong d = HistoryDealGetTicket(i);
      if(d == 0) continue;
      if(HistoryDealGetString(d, DEAL_SYMBOL) == _Symbol &&
         HistoryDealGetInteger(d, DEAL_MAGIC) == (long)P_Magic &&
         HistoryDealGetInteger(d, DEAL_ENTRY) == DEAL_ENTRY_IN) n++;
   }
   return n;
}

//--- Nhac khi co lenh vao tay (Magic 0) tren cung tai khoan: gioi han lo ngay / sut giam cua bot khong tinh lenh do
void CheckManualTrades()
{
   if(MQLInfoInteger(MQL_TESTER)) return;
   static datetime last = 0;
   if(TimeCurrent() - last < 60) return;
   last = TimeCurrent();
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetTicket(i) == 0 || PositionGetInteger(POSITION_MAGIC) != 0) continue;
      if(ShouldNotify("manual", 6 * 3600))
         Notify(StringFormat("[%s] Co lenh vao tay (%s) tren tai khoan dang chay bot. Quy tac: khong giao dich tay song song voi bot; "
                             "gioi han lo cua bot khong tinh lenh nay.", _Symbol, PositionGetString(POSITION_SYMBOL)));
      break;
   }
}

void UpdatePanel()
{
   CheckManualTrades();
   if(!P_ShowPanel) return;
   if(MQLInfoInteger(MQL_TESTER) && !MQLInfoInteger(MQL_VISUAL_MODE)) return;
   if(TimeCurrent() - lastPanel < 2) return;
   lastPanel = TimeCurrent();

   double eq    = BotEquity();
   double peak  = GVGet("peak", eq);
   double dayPL = DayPL();
   double dd    = peak > 0 ? (1.0 - BotEquityForLimits() / peak) * 100.0 : 0;   // cung cach tinh voi gioi han
   string cur   = AccountInfoString(ACCOUNT_CURRENCY);

   Comment(StringFormat(
      "BTC bot v" + BOT_VERSION + " (%s)  |  %s\n"
      "Trang thai: %s\n"
      "Von cua bot: %.2f %s\n"
      "Lai/lo hom nay (xet gioi han): %.2f %s (%.2f%%)%s\n"
      "Da dong hom nay: %.2f %s\n"
      "Lenh hom nay: %d\n"
      "Sut giam tu dinh: %.2f%% / gioi han %.1f%%\n"
      "Spread: %d point%s",
      P_Strategy == STRAT_DONCHIAN ? "Donchian" : P_Strategy == STRAT_RSI_REVERT ? "RSI luot song" : P_Strategy == STRAT_ORB ? "ORB phien My" : P_Strategy == STRAT_EXHAUST ? "Dao chieu" : P_Strategy == STRAT_FVG ? "FVG" : P_Strategy == STRAT_SPRING ? "Spring/Upthrust" : P_Strategy == STRAT_MACD ? "MACD da khung" : P_Strategy == STRAT_IMOM ? "Quan tinh trong ngay" : "EMA pullback", _Symbol, IsHalted() ? "DUNG HAN (sut giam)" : g_status,
      eq, cur, dayPL, cur, dayStartEquity > 0 ? dayPL / dayStartEquity * 100.0 : 0,
      DailyLocked() ? "  [DA KHOA HOM NAY]" : "", g_closedToday, cur,
      TradesToday(), dd, P_MaxDrawdownPct,
      (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD),
      P_UseFunding ? "\nFunding: " + (g_fundState == "" ? "chua kiem tra" : g_fundState) : ""));
}

//+------------------------------------------------------------------+
