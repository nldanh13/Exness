//+------------------------------------------------------------------+
//| TrendBot/Core.mqh: Bien chung, ten bien toan cuc, tien ich gui lenh, vi the cua bot
//+------------------------------------------------------------------+
CTrade   trade;
int      hFast = INVALID_HANDLE, hTrend = INVALID_HANDLE, hATR = INVALID_HANDLE;
int      hATRSL = INVALID_HANDLE;          // ATR cho SL / buoc nhoi / trailing (InpSLTFmin); = hATR khi dung khung chinh
int      g_reEntries = 0;                  // So lan vao lai sau khi bi cat lo (da khop)
ENUM_TIMEFRAMES TFFromMin(const int m)
{
   switch(m)
   {
      case 1: return PERIOD_M1;   case 2: return PERIOD_M2;   case 3: return PERIOD_M3;   case 4: return PERIOD_M4;
      case 5: return PERIOD_M5;   case 6: return PERIOD_M6;   case 10: return PERIOD_M10; case 12: return PERIOD_M12;
      case 15: return PERIOD_M15; case 20: return PERIOD_M20; case 30: return PERIOD_M30; case 60: return PERIOD_H1;
      case 120: return PERIOD_H2; case 240: return PERIOD_H4;
   }
   return PERIOD_CURRENT;
}
int      hHTF  = INVALID_HANDLE, hADX   = INVALID_HANDLE;
int      hMkt  = INVALID_HANDLE;
int      hRSI  = INVALID_HANDLE;
int      hATRD1 = INVALID_HANDLE, hBB = INVALID_HANDLE;
int      hMACD = INVALID_HANDLE, hMACDH = INVALID_HANDLE;
double   g_sigRiskMult = 1;              // he so rui ro lenh nay do chien luoc dat (vd. lenh thu nho o day dao roi)
double   g_sigPartialPx = 0;             // muc gia chot mot phan do chien luoc dat (0 = theo R)
datetime g_knifeProbeUsed = 0, g_knifeUsed = 0;
datetime g_obUsed = 0, g_obFlipUsed = 0;
datetime g_pdUsed = 0;                  // premium / discount: cu quet da vao lenh (moi cu 1 lan)
datetime g_newsUsedT = 0;               // tin da danh cu quet (chien luoc 20, moi tin 1 lan)
int      g_newsProtects = 0;             // so lan bao ve lenh truoc tin (InpNewsProtect)
int      g_fvgPat = 0;                    // mau nen xac nhan cua lenh FVG gan nhat (ZoneCandle), de ghi nhat ky          // order block da vao lenh / da danh khang cu (moi OB 1 lan)   // dao roi: day da vao lenh thu / lenh lon (moi day 1 lan)
double   g_sigSL = 0, g_sigTP = 0;
// Bang chung cua quyet dinh (v5.33): cac con so cu the dan toi quyet dinh o nen dang xet, noi bang " ; ".
// Xoa o dau moi nen moi, ghi vao file trang thai (bangchung=) va nhat ky quyet dinh (sau dau " || ").
string   g_ev = "";
// Che do Tu dong (chien luoc 23, v5.34): khai bao o day vi Status.mqh dung truoc phan code Tu dong trong file .mq5
bool     g_autoMode = false;
ulong    g_autoMagic = 0;
string   g_autoName = "", g_autoWant = "";
datetime g_autoRead = 0;
int      g_smartSit = 0;                 // tinh huong thi truong vua chan doan (chien luoc 24, Signals.mqh)
string   g_smartName = "";
int      g_smartPrev = 0, g_smartPrevDir = 0;   // tinh huong / chieu thuy trieu o nen truoc (vung dem)
bool     g_smartStateLoaded = false;          // v5.46: da nap tinh huong nen truoc / tin da dung tu Global Variables (giu qua khoi dong lai)
// Dang theo doi (v5.40): bot dang canh gi o nen vua phan tich (hop, VWAP, vung Key Volume, trang thai tung kien thuc).
// Status.mqh ghi ra dong "theodoi=" de giao dien ve khung "Dang theo doi"; chi dung cho che do Theo tinh huong.
datetime g_wTime = 0;
double   g_wHi = 0, g_wLo = 0, g_wAtr = 0, g_wAdx = 0, g_wVw = 0, g_wVsd = 0;
int      g_wTide = 0, g_wDir = 0, g_wBars = 0;
string   g_wMem = "", g_wKV = "";
double   g_pzA = 0, g_pzB = 0, g_pzC = 0, g_pzD = 0;   // so lieu tam do ham mau hinh tra ra (khong gian gia cua mau, co the doi dau)
void EvReset() { g_ev = ""; }
void EvAdd(const string s) { if(s == "" || StringLen(g_ev) > 1800) return; g_ev += (g_ev == "" ? "" : " ; ") + s; }
// Qua trinh phan tich (v5.42): moi lan phan tich nen vua dong ghi TUNG BUOC (du lieu lay gi, tinh ra so nao, so voi nguong nao,
// tung kien thuc ket luan gi, ket luan cuoi) - ke ca khi ket luan khong doi. Status.mqh ghi ra TrendBot_phantich_<chart>.txt
// (96 lan gan nhat = 1 ngay M15) cho khung "Qua trinh phan tich" tren giao dien. Moi buoc: nhom`trang thai`noi dung,
// cac buoc noi bang "``". Trang thai: 1 dat, 0 khong dat, 2 thong tin, 3 ket luan. Tat khi backtest.
string   g_tr = "";
bool     g_trOn = false, g_trPending = false;
datetime g_trBar = 0, g_trAt = 0;
int      g_trEvFrom = 0;                  // vi tri trong g_ev tu do la bang chung SAU phan tich (bo loc chung, tinh lot)
string   g_why = "";                      // ly do kien thuc thanh vien KHONG co setup o nen nay (dat trong BaseSignals)
void Why(const string s) { g_why = s; }
void TraceBegin()
{
   g_trOn = !MQLInfoInteger(MQL_TESTER);
   if(!g_trOn) return;
   g_tr = ""; g_trEvFrom = 0; g_trPending = true;
   g_trBar = iTime(_Symbol, P_TF, 1); g_trAt = TimeLocal();
}
void Tr(const string grp, const int ok, const string s)
{
   if(!g_trOn || s == "" || StringLen(g_tr) > 12000) return;
   string t = s;
   StringReplace(t, "`", "'"); StringReplace(t, "\t", " "); StringReplace(t, "\r", " "); StringReplace(t, "\n", " ");
   g_tr += (g_tr == "" ? "" : "``") + grp + "`" + IntegerToString(ok) + "`" + t;
}
string Px(const double v) { return DoubleToString(v, _Digits); }       // SL (khoang cach) / TP (gia) do chien luoc dat; 0 = dung mac dinh ATR / RR
datetime g_fvgUsed = 0;
datetime g_fibUsed = 0;                 // Fib + VP: thoi diem dinh/day cua con song da vao lenh (moi song chi vao 1 lan)
datetime g_divUsed = 0, g_absUsed = 0;  // RSI + CVD: dinh/day phan ky da vao lenh; lan hap thu gan nhat da vao lenh
datetime g_bigUsed = 0;                 // Big Trades: bong bong / chuoi bong bong da vao lenh (moi cai chi vao 1 lan)
datetime g_distUsed = 0;                // Phan phoi / tich luy: nen hung phan cua cau truc da vao lenh (moi cau truc 1 lan)
int      g_stallExits = 0;               // so lenh dong vi dung yen qua lau (InpStallBars)
int      g_sessPartials = 0;             // so lan chot mot nua khi het gio cao diem (InpSessPartialR)
double   g_reqPrice = 0;                 // gia luc gui lenh vao (de do truot gia that)
long     g_reqSpread = 0;                  // FVG da vao lenh (moi khoang trong chi vao 1 lan)
double   g_rsi = 50;
string   g_mktSym = "";
datetime lastBarTime    = 0;
datetime lastPanel      = 0;
double   dayStartEquity = 0;     // "Von cua bot" luc dau ngay
double   g_closedPL     = 0;     // Lai/lo da dong cua bot tu moc (epoch)
double   g_closedToday  = 0;     // Lai/lo da dong cua bot trong ngay
bool     g_plDirty      = true;  // Can tinh lai tu lich su
datetime g_lastPLCalc   = 0;
int      currentDay     = -1;
bool     dailyNotified  = false;
string   g_status         = "Khoi dong";
datetime lastLossTime   = 0;

//+------------------------------------------------------------------+
// Ten bien trang thai gan voi tai khoan + symbol + magic, tranh xung dot giua nhieu bieu do / tai khoan
string GVName(const string key)
{
   return "BTCEA_" + (string)AccountInfoInteger(ACCOUNT_LOGIN) + "_" + _Symbol + "_" + (string)P_Magic + "_" + key;
}

// Gioi han thong bao: moi loai (key) toi da 1 lan moi `seconds` giay
string   g_ntKeys[];
datetime g_ntTimes[];
bool ShouldNotify(const string key, const int seconds)
{
   int n = ArraySize(g_ntKeys);
   for(int i = 0; i < n; i++)
      if(g_ntKeys[i] == key)
      {
         if(TimeCurrent() - g_ntTimes[i] < seconds) return false;
         g_ntTimes[i] = TimeCurrent();
         return true;
      }
   ArrayResize(g_ntKeys, n + 1);
   ArrayResize(g_ntTimes, n + 1);
   g_ntKeys[n]  = key;
   g_ntTimes[n] = TimeCurrent();
   return true;
}

// Xac nhan server da thuc hien lenh (khong chi dua vao gia tri tra ve cua CTrade).
// `kind` la loai thao tac (khong kem so ticket) de gom thong bao trung.
// Xoa ma loi cu ngay truoc khi gui lenh, de GetLastError() trong TradeDone dung la loi cua lan nay.
// Dung: PrepSend() && trade.Xxx(...)  (&& dung ngay sau PrepSend nen khong anh huong ket qua)
bool PrepSend() { ResetLastError(); return true; }

bool TradeDone(const bool sent, const string kind, const string detail = "")
{
   uint rc = trade.ResultRetcode();
   // Chi DONE / DONE_PARTIAL moi la da khop; PLACED chi la da dat lenh, chua chac khop
   bool ok = sent && (rc == TRADE_RETCODE_DONE || rc == TRADE_RETCODE_DONE_PARTIAL);
   // DONE_PARTIAL: chi khop MOT PHAN. Lenh dong phai tu kiem tra vi the con hay khong (GuardPosLeft), khong coi la da dong het.
   if(ok && rc == TRADE_RETCODE_DONE_PARTIAL) Print(StringFormat("[%s] %s %s chi khop mot phan", _Symbol, kind, detail));
   if(ok) { if(kind != "Vao lenh") DecisionLog("quan-ly", kind + " " + detail); return true; }
   string msg;
   if(!sent && rc == 0)
      // Bi tu choi truoc khi gui len server: lay loi kiem tra cua lan nay, khong phai ma cu
      msg = StringFormat("[%s] %s %s chua gui duoc: kiem tra %u %s, loi %d", _Symbol, kind, detail,
                         trade.CheckResultRetcode(), trade.CheckResultRetcodeDescription(), GetLastError());
   else
      msg = StringFormat("[%s] %s %s that bai: %u %s", _Symbol, kind, detail, rc, trade.ResultRetcodeDescription());
   Print(msg);
   DecisionLog("loi", msg);
   // Sua SL chi ghi log; cac loai khac bao ve dien thoai toi da 1 lan / 5 phut moi loai
   if(kind != "Sua SL" && ShouldNotify(kind, 300) && !MQLInfoInteger(MQL_TESTER))
   {
      if(P_PushNotify) SendNotification(msg);
      if(P_Telegram)   SendTelegram(msg);
   }
   return false;
}

bool IsHedging()
{
   return (ENUM_ACCOUNT_MARGIN_MODE)AccountInfoInteger(ACCOUNT_MARGIN_MODE) == ACCOUNT_MARGIN_MODE_RETAIL_HEDGING;
}

// Vi the (theo POSITION_IDENTIFIER) con mo khong
bool PositionOpenById(const ulong id)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
      if(PositionGetTicket(i) != 0 && (ulong)PositionGetInteger(POSITION_IDENTIFIER) == id) return true;
   return false;
}

//--- Moi Magic + ma chi duoc 1 bot dung. Moi bot ghi 1 bien Temp mang so chart cua minh trong TEN bien
// (gia tri double khong chua du so chart). Bien Temp tu mat khi tat MT5, nen khong bi ket sau khi may sap.
string MagicPrefix() { return "BTCEA_" + IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)) + "_OWN_" + _Symbol + "_" + (string)P_Magic + "_"; }
bool ClaimMagic()
{
   string pre = MagicPrefix();
   for(int i = GlobalVariablesTotal() - 1; i >= 0; i--)
   {
      string n = GlobalVariableName(i);
      if(StringFind(n, pre) != 0) continue;
      long other = StringToInteger(StringSubstr(n, StringLen(pre)));
      if(other == ChartID()) continue;
      if(other != 0 && ChartSymbol(other) != "")          // chart kia van mo va van con bot
      {
         string msg = StringFormat("[%s] Da co bot khac dung Magic %I64u tren %s. Doi InpMagic hoac go bot kia.",
                                   _Symbol, P_Magic, _Symbol);
         Print(msg); Alert(msg);
         return false;
      }
      GlobalVariableDel(n);                                 // chart da dong: bien cu bo lai
   }
   GlobalVariableTemp(pre + IntegerToString(ChartID()));
   GlobalVariableSet(pre + IntegerToString(ChartID()), 1);
   return true;
}
void ReleaseMagic() { GlobalVariableDel(MagicPrefix() + IntegerToString(ChartID())); }

//--- Ghi gia yeu cau va gia khop that cua moi lenh vao (chi khi chay that / demo) de do truot gia,
// roi dua nguoc vao backtest. File Common\Files\TrendBot_truotgia.csv.
void LogSlippage(const bool isBuy, const double fill)
{
   if(g_reqPrice <= 0) return;
   LogSlippageAt(isBuy, g_reqPrice, g_reqSpread, fill, (long)P_Magic);
   g_reqPrice = 0;
}
// Ghi truot gia vao lenh cho moi loai lenh (v5.10.17): ca lenh tu vao / nhoi magic 0 cua bo 05 / 06
void LogSlippageAt(const bool isBuy, const double req, const long spread, const double fill, const long magic)
{
   if(MQLInfoInteger(MQL_TESTER) || req <= 0 || fill <= 0) return;
   string f = "TrendBot_truotgia.csv";
   bool isNew = !FileIsExist(f, FILE_COMMON);
   int h = FileOpen(f, FILE_READ | FILE_WRITE | FILE_CSV | FILE_ANSI | FILE_COMMON | FILE_SHARE_READ, ',');
   if(h == INVALID_HANDLE) return;
   if(isNew) FileWrite(h, "ThoiGian", "Ma", "Magic", "Chieu", "GiaYeuCau", "GiaKhop", "Truot_diem_batLoi", "Spread_diem_luocGui");
   FileSeek(h, 0, SEEK_END);
   double slip = (isBuy ? fill - req : req - fill) / _Point;   // duong = khop xau hon
   FileWrite(h, TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS), _Symbol, magic, isBuy ? "Buy" : "Sell",
             DoubleToString(req, _Digits), DoubleToString(fill, _Digits), DoubleToString(slip, 0), spread);
   FileClose(h);
}

// Truot gia luc cham SL / TP (v5.10.13): lenh dung khong bao dam khop dung gia dat khi thi truong chay manh.
// Ghi vao cung file TrendBot_truotgia.csv, cot Chieu = "SL Buy" / "TP Sell"... GiaYeuCau = muc SL / TP, GiaKhop = gia dong that.
void LogStopSlippage(const ulong deal)
{
   if(MQLInfoInteger(MQL_TESTER) || HistoryDealGetString(deal, DEAL_SYMBOL) != _Symbol) return;
   if(HistoryDealGetInteger(deal, DEAL_ENTRY) != DEAL_ENTRY_OUT) return;
   long reason = HistoryDealGetInteger(deal, DEAL_REASON);
   if(reason != DEAL_REASON_SL && reason != DEAL_REASON_TP) return;
   double lvl = HistoryDealGetDouble(deal, reason == DEAL_REASON_SL ? DEAL_SL : DEAL_TP);
   double px  = HistoryDealGetDouble(deal, DEAL_PRICE);
   if(lvl <= 0 || px <= 0) return;
   bool closeBySell = HistoryDealGetInteger(deal, DEAL_TYPE) == DEAL_TYPE_SELL;   // dong lenh Buy = deal Sell
   double slip = (closeBySell ? lvl - px : px - lvl) / _Point;                   // duong = khop xau hon muc dat
   string f = "TrendBot_truotgia.csv";
   bool isNew = !FileIsExist(f, FILE_COMMON);
   int h = FileOpen(f, FILE_READ | FILE_WRITE | FILE_CSV | FILE_ANSI | FILE_COMMON | FILE_SHARE_READ, ',');
   if(h == INVALID_HANDLE) return;
   if(isNew) FileWrite(h, "ThoiGian", "Ma", "Magic", "Chieu", "GiaYeuCau", "GiaKhop", "Truot_diem_batLoi", "Spread_diem_luocGui");
   FileSeek(h, 0, SEEK_END);
   FileWrite(h, TimeToString((datetime)HistoryDealGetInteger(deal, DEAL_TIME), TIME_DATE | TIME_SECONDS), _Symbol,
             HistoryDealGetInteger(deal, DEAL_MAGIC), (reason == DEAL_REASON_SL ? "SL " : "TP ") + (closeBySell ? "Buy" : "Sell"),
             DoubleToString(lvl, _Digits), DoubleToString(px, _Digits), DoubleToString(slip, 0), (long)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD));
   FileClose(h);
}

// Thoi gian xu ly moi lan OnTick / OnTimer (v5.10.13), de xem bot co xu ly cham lam lo tick khong
ulong  g_tkMaxUs = 0, g_tkSumUs = 0;
long   g_tkCount = 0, g_tkSlow = 0;      // so lan > 100 ms
void TickTimeRecord(const ulong us)
{
   if(MQLInfoInteger(MQL_TESTER)) return;
   g_tkCount++; g_tkSumUs += us;
   if(us > g_tkMaxUs) g_tkMaxUs = us;
   if(us > 100000) g_tkSlow++;
}
string TickTimeText()
{
   if(g_tkCount <= 0) return "chua do";
   return StringFormat("TB %.1f ms, lon nhat %.0f ms, %I64d lan > 100 ms / %I64d", g_tkSumUs / 1000.0 / g_tkCount, g_tkMaxUs / 1000.0, g_tkSlow, g_tkCount);
}

bool IsOwnSelected()
{
   return PositionGetString(POSITION_SYMBOL) == _Symbol &&
          PositionGetInteger(POSITION_MAGIC) == (long)P_Magic;
}

bool GetValue(const int handle, const int buffer, const int shift, double &value)
{
   double buf[];
   if(CopyBuffer(handle, buffer, shift, 1, buf) != 1) return false;
   value = buf[0];
   return true;
}
// ATR dung cho SL / buoc nhoi / trailing: khung InpSLTFmin neu co, khong thi giu ATR khung chinh (fallback)
double SLAtr(const double fallback)
{
   if(hATRSL == INVALID_HANDLE || hATRSL == hATR) return fallback;
   double v;
   return GetValue(hATRSL, 0, 1, v) && v > 0 ? v : fallback;
}

double NormalizeVolume(double lots)
{
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(step <= 0) step = 0.01;
   lots = MathFloor(lots / step + 1e-9) * step;
   int digits = (int)MathMax(0, MathCeil(-MathLog10(step)));
   return NormalizeDouble(lots, digits);
}

// Account-money preflight for EVERY new market order, including manual button,
// pyramiding and Guard magic0. Conservative defaults: each new order may consume
// <=35% of currently free margin; projected margin level >=300%, cash free >=10%
// equity. Server dynamic HMR is checked with OrderCheck immediately before send.
// Not a guarantee against gap, stop-out, changed quote or slippage.
bool EntryMarginOk(const bool buy, const double lots, const double price,
                   const double sl, const double tp)
{
   if(lots <= 0 || price <= 0 || sl <= 0) return false;
   double accounting = 0;
   if(!LedgerDayPL(2, accounting)) return false; // khong du history de kiem soat tong rui ro
   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   double free = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   double used = AccountInfoDouble(ACCOUNT_MARGIN);
   double newMargin = 0;
   if(eq <= 0 || free <= 0 ||
      !OrderCalcMargin(buy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL,
                       _Symbol, lots, price, newMargin) || newMargin <= 0)
      return false;
   if(newMargin > free * 0.35 || free - newMargin < eq * 0.10 ||
      eq / (used + newMargin) * 100.0 < 300.0)
   {
      if(ShouldNotify("marginBlock", 3600))
         PrintFormat("[%s] BO VAO: du tru ky quy khong du (margin %.2f / free %.2f %s).",
                     _Symbol, newMargin, free, AccountInfoString(ACCOUNT_CURRENCY));
      return false;
   }
   MqlTradeRequest request; MqlTradeCheckResult result;
   ZeroMemory(request); ZeroMemory(result);
   request.action = TRADE_ACTION_DEAL;
   request.magic = P_Magic;
   request.symbol = _Symbol;
   request.volume = lots;
   request.type = buy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   request.price = price;
   request.sl = NormalizeDouble(sl, _Digits);
   request.tp = tp > 0 ? NormalizeDouble(tp, _Digits) : 0;
   request.deviation = 100;
   long fills = SymbolInfoInteger(_Symbol, SYMBOL_FILLING_MODE);
   if((fills & SYMBOL_FILLING_IOC) == SYMBOL_FILLING_IOC)
      request.type_filling = ORDER_FILLING_IOC;
   else if((fills & SYMBOL_FILLING_FOK) == SYMBOL_FILLING_FOK)
      request.type_filling = ORDER_FILLING_FOK;
   else request.type_filling = ORDER_FILLING_RETURN;
   if(!OrderCheck(request, result) ||
      (result.retcode != 0 && result.retcode != TRADE_RETCODE_DONE && result.retcode != TRADE_RETCODE_PLACED))
   {
      if(ShouldNotify("orderCheck", 3600))
         PrintFormat("[%s] BO VAO: OrderCheck loi retcode=%u (%s).",
                     _Symbol, result.retcode, result.comment);
      return false;
   }
   if(result.margin_free < eq * 0.10 ||
      (result.margin_level > 0 && result.margin_level < 300.0))
   {
      if(ShouldNotify("marginFuture", 3600))
         PrintFormat("[%s] BO VAO: margin sau OrderCheck (free %.2f, level %.1f%%).",
                     _Symbol, result.margin_free, result.margin_level);
      return false;
   }
   return true;
}

//--- Vi the ----------------------------------------------------------
bool HasOwnPosition()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetTicket(i) == 0) continue;
      if(IsOwnSelected()) return true;
   }
   return false;
}

void CloseAll()
{
   // Dong dong bo va KIEM TRA retcode. Async khong dong atom gi o server; CloseBy chi dung khi co vi the nguoc chieu hedging.
   // Khi dung khan cap, timer phai duoc thu lai ngay ca khi TimeCurrent dung yen vi khong co tick.
   static ulong lastTryMs = 0;
   ulong nowMs = GetTickCount64();
   ulong intervalMs = (IsHalted() || GuardHalted()) ? 2000 : 10000;
   if(lastTryMs > 0 && nowMs - lastTryMs < intervalMs) return;
   lastTryMs = nowMs;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !IsOwnSelected()) continue;
      TradeDone(PrepSend() && trade.PositionClose(ticket), "Dong lenh", "#" + (string)ticket);
   }
}
