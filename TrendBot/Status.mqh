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
      case STRAT_FIBVP:      return "Fibonacci + Volume Profile";
      case STRAT_DIVCVD:     return "Phan ky RSI + CVD";
      case STRAT_BIGTRADE:   return "Big Trades";
      case STRAT_DISTRIB:    return "Hop phan phoi / tich luy";
      case STRAT_GRID:       return "Danh luoi";
      case STRAT_KNIFE:      return "Dao roi: nho - lon - giu";
      case STRAT_OB:         return "Order block: phan ung tai vung";
      case STRAT_DOW:        return "Dow: thuy trieu + con song";
      case STRAT_VWAP:       return "VWAP trong ngay + 3 cap dai";
      case STRAT_KEYVOL:     return "Vung Key Volume";
      case STRAT_SIMPLE:     return "3 cau hoi: mua - cho ca - phao";
      case STRAT_NEWS:       return "Tin lon: cho cu quet xong";
      case STRAT_PD:         return "Premium / discount 2 khung";
      case STRAT_CHAIN:      return "Chuoi phan tich: thuy trieu - vi tri - setup";
      case STRAT_AUTO:       return "Tu dong theo bang xep hang";
      case STRAT_SMART:      return "Theo tinh huong";
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

// Nhat ky quyet dinh (v5.32): giao dien hien khung "Quyet dinh cua bot" va "Nhat ky qua trinh".
// Common\Files\TrendBot_quyetdinh_<chart>.txt, moi dong: gio may|loai|noi dung (giu 200 dong gan nhat, ghi lai moi 10 giay).
// Loai: phan-tich (bot doi quyet dinh / ly do cho), vao-lenh, thoat, quan-ly (sua SL, chot phan...), khoa-lenh, loi.
string   g_dlog[];
bool     g_dlogDirty = false, g_dlogLoaded = false;
string   g_dlogLastStatus = "", g_lastEntryWhy = "";
datetime g_lastEntryAt = 0;
string DecisionFile() { return "TrendBot_quyetdinh_" + IntegerToString(ChartID()) + ".txt"; }
void DecisionLoad()
{
   if(g_dlogLoaded) return;
   g_dlogLoaded = true;
   int h = FileOpen(DecisionFile(), FILE_READ | FILE_TXT | FILE_ANSI | FILE_COMMON | FILE_SHARE_READ | FILE_SHARE_WRITE);
   if(h == INVALID_HANDLE) return;
   while(!FileIsEnding(h))
   {
      string l = FileReadString(h);
      if(l == "") continue;
      int n = ArraySize(g_dlog);
      ArrayResize(g_dlog, n + 1); g_dlog[n] = l;
   }
   FileClose(h);
   int n = ArraySize(g_dlog);
   if(n > 200) ArrayRemove(g_dlog, 0, n - 200);
}
void DecisionLog(const string kind, const string text)
{
   if(MQLInfoInteger(MQL_TESTER) || text == "") return;
   DecisionLoad();
   string t = text;
   StringReplace(t, "\r", " "); StringReplace(t, "\n", " ");   // giu dau "|": giao dien noi lai phan sau truong thu 2
   int n = ArraySize(g_dlog);
   if(n >= 200) { ArrayRemove(g_dlog, 0, n - 199); n = ArraySize(g_dlog); }
   ArrayResize(g_dlog, n + 1);
   g_dlog[n] = TimeToString(TimeLocal(), TIME_DATE | TIME_SECONDS) + "|" + kind + "|" + t;
   g_dlogDirty = true;
}
void DecisionWrite()
{
   if(!g_dlogDirty) return;
   int h = FileOpen(DecisionFile(), FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_COMMON | FILE_SHARE_READ);
   if(h == INVALID_HANDLE) return;
   for(int i = 0; i < ArraySize(g_dlog); i++) FileWriteString(h, g_dlog[i] + "\r\n");
   FileClose(h);
   g_dlogDirty = false;
}

// Qua trinh phan tich (v5.42): TrendBot_phantich_<chart>.txt (Unicode UTF-16 de giu dau tieng Viet), moi dong 1 lan phan tich nen vua dong:
//   gio nen (server)<TAB>luc phan tich (gio may)<TAB>khung (phut)<TAB>ket luan<TAB>cac buoc (nhom`trang thai`noi dung, noi bang ``)
// Giu 96 lan gan nhat (1 ngay M15). Ghi o lan WriteStatus ngay sau nen (cung tick phan tich da chay xong).
string g_trLog[];
bool   g_trLoaded = false;
string TraceFile() { return "TrendBot_phantich_" + IntegerToString(ChartID()) + ".txt"; }
void TraceFlush()
{
   g_trPending = false;
   if(MQLInfoInteger(MQL_TESTER)) return;
   if(!g_trLoaded)
   {
      g_trLoaded = true;
      int hr = FileOpen(TraceFile(), FILE_READ | FILE_TXT | FILE_UNICODE | FILE_COMMON | FILE_SHARE_READ | FILE_SHARE_WRITE);
      if(hr != INVALID_HANDLE)
      {
         while(!FileIsEnding(hr)) { string l = FileReadString(hr); if(l == "") continue; int k = ArraySize(g_trLog); ArrayResize(g_trLog, k + 1); g_trLog[k] = l; }
         FileClose(hr);
      }
   }
   string steps = g_tr;
   // Phan sau phan tich: bo loc chung, kiem tra rui ro / tinh lot, gui lenh (bang chung ghi sau khi chien luoc tra ket qua)
   string tail = g_trEvFrom > 0 ? StringSubstr(g_ev, g_trEvFrom) : (steps == "" ? g_ev : "");
   StringReplace(tail, "`", "'");
   StringTrimLeft(tail); StringTrimRight(tail);
   if(StringFind(tail, "; ") == 0) tail = StringSubstr(tail, 2);
   if(tail != "")
   {
      StringReplace(tail, " ; ", "``Ket luan`2`");             // cac muc bang chung noi bang " ; "
      steps += (steps == "" ? "" : "``") + "Ket luan`2`" + tail;
   }
   string st = IsHalted() ? "DUNG HAN (sut giam)" : g_status;
   StringReplace(st, "`", "'"); StringReplace(st, "\t", " ");
   steps += (steps == "" ? "" : "``") + "Ket luan`3`" + st;
   int n = ArraySize(g_trLog);
   if(n >= 96) { ArrayRemove(g_trLog, 0, n - 95); n = ArraySize(g_trLog); }
   ArrayResize(g_trLog, n + 1);
   g_trLog[n] = TimeToString(g_trBar, TIME_DATE | TIME_MINUTES) + "\t" + TimeToString(g_trAt, TIME_DATE | TIME_SECONDS) + "\t" +
                IntegerToString(PeriodSeconds((ENUM_TIMEFRAMES)P_TF) / 60) + "\t" + st + "\t" + steps;
   int h = FileOpen(TraceFile(), FILE_WRITE | FILE_TXT | FILE_UNICODE | FILE_COMMON | FILE_SHARE_READ);
   if(h == INVALID_HANDLE) return;
   for(int i = 0; i < ArraySize(g_trLog); i++) FileWriteString(h, g_trLog[i] + "\r\n");
   FileClose(h);
}

void WriteStatus()
{
   if(MQLInfoInteger(MQL_TESTER)) return;
   if(g_trPending) TraceFlush();     // ngay ca khi chua toi 10 giay: tick phan tich da xong
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
   FileWriteString(h, "chienluoc=" + (g_autoMode ? "Tu dong -> " + g_autoName + ": " : "") + StrategyName() + " " + EnumToString((ENUM_TIMEFRAMES)P_TF) + "\r\n");
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
   string st = IsHalted() ? "DUNG HAN (sut giam)" : g_status;
   if(GuardHalted()) st = "DUNG HAN: von tai khoan sut qua gioi han (bao ve lenh tay)";
   else if(InpGuardManual && GuardDayLocked()) st += " | Khoa lenh tay + tu vao toi het ngay";
   FileWriteString(h, "trangthai=" + st + "\r\n");
   // Quyet dinh hien tai (giao dien hien tung buoc khi noi dung co dang "B1 ... | B2 ... | ...") va ly do lenh gan nhat
   FileWriteString(h, "quyetdinh=" + st + "\r\n");
   FileWriteString(h, "lydovao=" + g_lastEntryWhy + "\r\n");
   FileWriteString(h, "bangchung=" + g_ev + "\r\n");
   if(P_Strategy == STRAT_SMART) FileWriteString(h, "hoc=" + LearnSummary() + "\r\n");
   // Dang theo doi (v5.40): nhung gi bot canh o nen vua phan tich + lenh giay dang chay (giao dien tinh R tam tinh theo gia hien tai)
   if(P_Strategy == STRAT_SMART && g_wTime > 0)
   {
      string tf = EnumToString((ENUM_TIMEFRAMES)P_TF);
      StringReplace(tf, "PERIOD_", "");
      long left = (long)(iTime(_Symbol, P_TF, 0) + PeriodSeconds((ENUM_TIMEFRAMES)P_TF) - TimeCurrent());
      int dg = _Digits;
      FileWriteString(h, "theodoi=luc:" + TimeToString(g_wTime, TIME_MINUTES) +
                      ";gia:" + DoubleToString(SymbolInfoDouble(_Symbol, SYMBOL_BID), dg) + ";ask:" + DoubleToString(SymbolInfoDouble(_Symbol, SYMBOL_ASK), dg) +
                      ";hi:" + DoubleToString(g_wHi, dg) + ";lo:" + DoubleToString(g_wLo, dg) + ";atr:" + DoubleToString(g_wAtr, dg) +
                      StringFormat(";adx:%.1f;sit:%d;tide:%d;dir:%d;nen:%d;con:%I64d;tf:%s;adxT:%.0f;adxR:%.0f;boxR:%.2f;b3:%.2f;lmax:%d",
                                   g_wAdx, g_smartSit, g_wTide, g_wDir, g_wBars, left < 0 ? (long)0 : left, tf, P_SmartTrendADX, P_SmartRangeADX,
                                   P_SmartRangeATR, P_VwapBand3, P_LearnMaxBars) +
                      ";vw:" + DoubleToString(g_wVw, dg) + ";vsd:" + DoubleToString(g_wVsd, dg) + ";tv:" + g_wMem + ";kv:" + g_wKV + "\r\n");
      string gs = "";
      if(P_Learn)
         for(int i = 0; i < ArraySize(g_lvt) && i < 40; i++)
            gs += (gs == "" ? "" : ",") + TimeToString(g_lvt[i].t, TIME_DATE | TIME_MINUTES) + StringFormat("~%d~%d~%d~", g_lvt[i].sit, g_lvt[i].strat, g_lvt[i].dir) +
                  DoubleToString(g_lvt[i].entry, dg) + "~" + DoubleToString(g_lvt[i].sl, dg) + "~" + DoubleToString(g_lvt[i].tp, dg) + "~" +
                  DoubleToString(g_lvt[i].risk, dg) + StringFormat("~%d~%.2f~%.2f~", g_lvt[i].bars, g_lvt[i].mfe, g_lvt[i].mae) + DoubleToString(g_lvt[i].cost, dg);
      FileWriteString(h, "giay=" + gs + "\r\n");
   }
   FileWriteString(h, "lydovaoluc=" + (g_lastEntryAt > 0 ?TimeToString(g_lastEntryAt, TIME_DATE | TIME_MINUTES) : "") + "\r\n");
   if(st != g_dlogLastStatus) { DecisionLog("phan-tich", st + (g_ev != "" ? " || " + g_ev : "")); g_dlogLastStatus = st; }
   FileWriteString(h, "xuly=" + TickTimeText() + "\r\n");
   FileWriteString(h, "choGD=" + (TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) && MQLInfoInteger(MQL_TRADE_ALLOWED) ? "1" : "0") + "\r\n");
   FileClose(h);
   DecisionWrite();
}

void StatusRelease() { FileDelete(StatusFile(), FILE_COMMON); }
