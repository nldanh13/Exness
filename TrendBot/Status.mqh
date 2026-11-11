//+------------------------------------------------------------------+
//| TrendBot/Status.mqh: Ghi trang thai cho giao dien tren trinh duyet (GiaoDien.ps1)
//| - Moi 10 giay ghi Common\Files\TrendBot_trangthai_<chart>.txt: tai khoan that hay demo,
//|   so lenh bot dang giu (ca lenh tu vao magic 0 cua bo 05/06), so lenh tay, so lenh mo cua ca tai khoan, trang thai bot.
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

// Dem vi the tren ma nay theo nguon (v5.10.12):
//  - bot   : magic = P_Magic (bot tu giao dich theo chien luoc)
//  - tuvao : magic 0 nhung do bot mo o che do bao ve lenh tay (ghi chu "TB tu vao" / "TB nhoi tay", xem GuardBotMade)
//  - tay   : magic 0 con lai (lenh ban tu vao)
// Truoc v5.10.12 chi dem magic = P_Magic nen bo 05 / 06 (tu vao, magic 0) luon bao 0 lenh bot du dang giu vi the.
// Luu y: mot so may chu co the cat / doi ghi chu lenh; khi do lenh tu vao se bi dem vao "tay" (tong van dung).
void OwnPositionCounts(int &bot, int &tuvao, int &tay)
{
   bot = 0; tuvao = 0; tay = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetTicket(i) == 0 || PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      long mg = PositionGetInteger(POSITION_MAGIC);
      if(mg == (long)P_Magic && P_Magic != 0) bot++;
      else if(mg == 0) { if(GuardBotMade()) tuvao++; else tay++; }
   }
}

// So lenh bot dang giu tren ma nay = lenh theo magic + lenh tu vao / tu nhoi (magic 0).
int OwnPositionCount()
{
   int b, a, t;
   OwnPositionCounts(b, a, t);
   return b + a;
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
   int nBot, nTuVao, nTay;
   OwnPositionCounts(nBot, nTuVao, nTay);
   FileWriteString(h, "lenhbot=" + IntegerToString(nBot + nTuVao) + "\r\n");   // tong lenh do bot mo (magic + tu vao)
   FileWriteString(h, "lenhmagic=" + IntegerToString(nBot) + "\r\n");
   FileWriteString(h, "lenhtuvao=" + IntegerToString(nTuVao) + "\r\n");
   FileWriteString(h, "lenhtay=" + IntegerToString(nTay) + "\r\n");
   FileWriteString(h, "lenhtaikhoan=" + IntegerToString(PositionsTotal()) + "\r\n");
   FileWriteString(h, "von=" + DoubleToString(BotEquity(), 2) + "\r\n");
   FileWriteString(h, "tien=" + AccountInfoString(ACCOUNT_CURRENCY) + "\r\n");
   FileWriteString(h, "laihomnay=" + DoubleToString(DayPL(), 2) + "\r\n");
   FileWriteString(h, "trangthai=" + (IsHalted() ? "DUNG HAN (sut giam)" : g_status) + "\r\n");
   FileWriteString(h, "choGD=" + (TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) && MQLInfoInteger(MQL_TRADE_ALLOWED) ? "1" : "0") + "\r\n");
   FileClose(h);
}

void StatusRelease() { FileDelete(StatusFile(), FILE_COMMON); }
