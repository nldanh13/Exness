//+------------------------------------------------------------------+
//| TrendBot/Status.mqh: Ghi trang thai cho giao dien tren trinh duyet (GiaoDien.ps1)
//| - Moi 10 giay ghi Common\Files\TrendBot_trangthai_<chart>.txt: tai khoan that hay demo,
//|   so lenh bot dang giu, so lenh mo cua ca tai khoan, trang thai bot.
//| - Chi ghi khi chay that / demo, khong ghi khi backtest. Xoa file khi go bot khoi chart.
//| - Khong ghi so tai khoan hay mat khau.
//+------------------------------------------------------------------+
string StatusFile() { return "TrendBot_trangthai_" + IntegerToString(ChartID()) + ".txt"; }

string StrategyName()
{
   switch(P_Strategy)
   {
      case STRAT_DONCHIAN:   return "Donchian";
      case STRAT_RSI_REVERT: return "RSI luot song";
      case STRAT_ORB:        return "ORB phien My";
      case STRAT_EXHAUST:    return "Dao chieu";
      case STRAT_FVG:        return "FVG";
      case STRAT_SPRING:     return "Spring/Upthrust";
      case STRAT_MACD:       return "MACD da khung";
      case STRAT_IMOM:       return "Quan tinh trong ngay";
   }
   return "EMA pullback";
}

int OwnPositionCount()
{
   int n = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetTicket(i) == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) == _Symbol && PositionGetInteger(POSITION_MAGIC) == (long)P_Magic) n++;
   }
   return n;
}

void WriteStatus()
{
   if(MQLInfoInteger(MQL_TESTER)) return;
   static datetime last = 0;
   if(TimeLocal() - last < 10) return;
   last = TimeLocal();
   long mode = AccountInfoInteger(ACCOUNT_TRADE_MODE);   // 0 demo, 1 contest, 2 that
   string loai = mode == ACCOUNT_TRADE_MODE_REAL ? "that" : mode == ACCOUNT_TRADE_MODE_DEMO ? "demo" : "thi-dau";
   int h = FileOpen(StatusFile(), FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_COMMON | FILE_SHARE_READ);
   if(h == INVALID_HANDLE) return;
   FileWriteString(h, "phienban=" + BOT_VERSION + "\r\n");
   FileWriteString(h, "taikhoan=" + loai + "\r\n");
   FileWriteString(h, "may=" + AccountInfoString(ACCOUNT_SERVER) + "\r\n");
   FileWriteString(h, "ma=" + _Symbol + "\r\n");
   FileWriteString(h, "chienluoc=" + StrategyName() + " " + EnumToString((ENUM_TIMEFRAMES)P_TF) + "\r\n");
   FileWriteString(h, "lenhbot=" + IntegerToString(OwnPositionCount()) + "\r\n");
   FileWriteString(h, "lenhtaikhoan=" + IntegerToString(PositionsTotal()) + "\r\n");
   FileWriteString(h, "von=" + DoubleToString(BotEquity(), 2) + "\r\n");
   FileWriteString(h, "tien=" + AccountInfoString(ACCOUNT_CURRENCY) + "\r\n");
   FileWriteString(h, "laihomnay=" + DoubleToString(DayPL(), 2) + "\r\n");
   FileWriteString(h, "trangthai=" + (IsHalted() ? "DUNG HAN (sut giam)" : g_status) + "\r\n");
   FileWriteString(h, "xuly=" + TickTimeText() + "\r\n");
   FileWriteString(h, "choGD=" + (TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) && MQLInfoInteger(MQL_TRADE_ALLOWED) ? "1" : "0") + "\r\n");
   FileClose(h);
}

void StatusRelease() { FileDelete(StatusFile(), FILE_COMMON); }
