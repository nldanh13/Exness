//+------------------------------------------------------------------+
//| BTC_EMA_Pullback_v2.mq5                                          |
//| EA theo xu huong: loc EMA200 (H1 + H4), ADX, vao khi hoi EMA20   |
//| SL theo ATR, TP theo RR, chot mot phan, hoa von, trailing ATR    |
//| Bo loc gio, gioi han lo ngay, gioi han sut giam tu dinh          |
//| Thong bao push MT5 / Telegram, bang thong tin tren bieu do       |
//| CHI DUNG DE THU NGHIEM - BACKTEST VA CHAY DEMO TRUOC             |
//+------------------------------------------------------------------+
#define  BOT_VERSION "3.8"
#property version   "3.80"
#property description "Donchian breakout (mac dinh) hoac EMA pullback, ATR stop, trailing, bo loc, canh bao"

#include <Trade\Trade.mqh>

enum ENUM_STRATEGY
{
   STRAT_EMA_PULLBACK = 0,   // Hoi ve EMA20 theo xu huong
   STRAT_DONCHIAN     = 1    // Pha vo kenh Donchian (breakout)
};

input group "=== Tin hieu ==="
input ENUM_STRATEGY   InpStrategy        = STRAT_DONCHIAN;     // Chien luoc vao lenh
input int             InpDonchianPeriod  = 20;        // So nen cua kenh Donchian (breakout)
input double          InpBreakMinATR     = 0.0;       // Donchian: gia dong cua phai vuot kenh it nhat x ATR (0 = tat)
input double          InpBreakMinBody    = 0.0;       // Donchian: than nen pha vo >= % bien do nen, cung chieu (0 = tat)
input bool            InpBreakConfirm    = false;     // Donchian: cho them 1 nen, gia van giu ngoai kenh moi vao
input double          InpBreakMaxATR     = 0.0;       // Donchian: bo qua nen pha vo dai hon x ATR (nen thanh ly day chuyen, 0 = tat)
input ENUM_TIMEFRAMES InpTF              = PERIOD_H4; // Khung tin hieu
input int             InpFastEMA         = 20;        // EMA nhanh (vung hoi)
input int             InpTrendEMA        = 200;       // EMA xu huong
input int             InpATRPeriod       = 14;        // Chu ky ATR

input group "=== Bo loc thi truong ==="
input bool            InpUseFunding      = false;     // Loc funding rate Binance Futures (dam dong dung don bay qua lech)
input double          InpFundingMax      = 0.03;      // Bo Buy khi funding > X% / 8 gio, bo Sell khi funding < -X%
input bool            InpUseFearGreed    = false;     // Loc Fear & Greed Index (tam ly dam dong, alternative.me)
input int             InpFngGreedMax     = 76;        // Bo Buy khi chi so hom qua >= muc nay (tham lam cuc do)
input int             InpFngFearMin      = 24;        // Bo Sell khi chi so hom qua <= muc nay (so hai cuc do)
input bool            InpUseAttention    = false;     // Chi vao lenh khi luot xem Wikipedia TB 7 ngay > TB 30 ngay (su chu y tang)
input bool            InpUseMarketFilter = false;     // Chi Buy khi Nasdaq tren EMA200 D1, chi Sell khi duoi
input string          InpMarketSymbol    = "USTEC";   // Ma Nasdaq tren san (tu thu them duoi "m" neu khong co)
input bool            InpAvoidUSNews     = false;     // Khong vao lenh gan tin My quan trong (lich kinh te MT5, chi khi chay that)
input int             InpNewsHours       = 2;         // So gio truoc/sau tin
input bool            InpUseHTF          = true;      // Xac nhan xu huong khung lon
input ENUM_TIMEFRAMES InpHTF             = PERIOD_D1; // Khung lon
input int             InpHTFEMA          = 200;       // EMA khung lon
input bool            InpUseADX          = true;      // Loc thi truong di ngang bang ADX
input int             InpADXPeriod       = 14;        // Chu ky ADX
input double          InpADXMin          = 20.0;      // ADX toi thieu de vao lenh
input bool            InpUseCandle       = false;     // Bat buoc mau nen (pin bar / engulfing)

input group "=== SL / TP / Khoi luong ==="
input double          InpATRMult         = 2.5;       // SL = ATR x he so
input double          InpRR              = 0.0;       // TP = SL x RR (0 = khong dat TP, de trailing thoat)
input double          InpRiskPercent     = 1.0;       // % von rui ro moi lenh
input double          InpMaxRiskRoundUp  = 1.5;       // Lot tinh ra < lot toi thieu: van vao lot toi thieu neu rui ro that <= X% (0 = bo qua lenh)
input string          InpCorrSymbols     = "BTCUSDm,ETHUSDm"; // Cac ma di cung nhau (BTC/ETH): dang co lenh ma khac thi giam rui ro
input double          InpCorrRiskScale   = 0.5;       // He so rui ro khi ma cung nhom dang co lenh (1 = tat)

input group "=== Quan ly lenh ==="
input bool            InpUsePartial      = false;     // Chot loi mot phan
input double          InpPartialR        = 1.0;       // Chot khi lai dat (R)
input double          InpPartialPct      = 50.0;      // % khoi luong chot
input bool            InpUseBreakeven    = false;     // Doi SL ve hoa von
input double          InpBreakevenR      = 1.0;       // Khi lai dat (R)
input double          InpBEBufferR       = 0.05;      // Cong them vao muc hoa von (tinh theo R), ngoai phi + swap
input bool            InpUseTrailing     = true;      // Trailing stop theo ATR
input double          InpTrailStartR     = 0.0;       // Bat dau trailing khi lai dat (R)
input double          InpTrailATRMult    = 3.0;       // Khoang trailing = ATR x he so

input group "=== Bo loc thoi gian (gio server) ==="
input bool            InpSkipWeekend     = false;     // Khong vao lenh moi Thu 7, Chu nhat
input int             InpBlock1Start     = -1;        // Khung nghi 1: tu gio (-1 = tat)
input int             InpBlock1End       = 14;        // Khung nghi 1: den gio
input int             InpBlock2Start     = -1;        // Khung nghi 2: tu gio (-1 = tat)
input int             InpBlock2End       = 20;        // Khung nghi 2: den gio
input int             InpMaxSpreadPoints = 0;         // Spread toi da (point, 0 = tat)

input group "=== Gioi han vao lenh ==="
input bool            InpAllowBuy        = true;      // Cho phep Buy
input bool            InpAllowSell       = true;      // Cho phep Sell
input int             InpMaxTradesPerDay = 0;         // So lenh toi da moi ngay (0 = khong gioi han)
input int             InpCooldownBars    = 0;         // Nghi bao nhieu nen sau 1 lenh thua (0 = tat)

input group "=== Bao ve tai khoan ==="
input double          InpMaxDailyLossPct = 3.0;       // Lo trong ngay toi da % (0 = tat), chi tinh lai/lo cua bot
input bool            InpCloseOnDailyLoss = true;     // Dong lenh dang mo khi cham lo ngay
input double          InpMaxDrawdownPct  = 15.0;      // Sut giam tu dinh toi da % (0 = tat), chi tinh lai/lo cua bot
input bool            InpCloseOnHalt     = true;      // Dong het lenh khi cham sut giam toi da
input bool            InpResetHalt       = false;     // Dat true 1 lan de mo khoa bot va dat lai moc von
input double          InpCapital         = 0;         // Von danh cho bot (0 = toan bo balance luc dat moc). Dung khi chia von cho nhieu EA

input group "=== Thong bao ==="
input bool            InpPushNotify      = true;      // Push ve app MT5 tren dien thoai
input bool            InpTelegram        = false;     // Gui Telegram
input string          InpTgToken         = "";        // Telegram bot token
input string          InpTgChatId        = "";        // Telegram chat id

input group "=== Khac ==="
input bool            InpShowPanel       = true;      // Hien bang thong tin
input ulong           InpMagic           = 20261105;  // Magic number
input string          InpTestLabel       = "";        // Ten lan chay backtest (ghi vao file ket qua)

CTrade   trade;
int      hFast = INVALID_HANDLE, hTrend = INVALID_HANDLE, hATR = INVALID_HANDLE;
int      hHTF  = INVALID_HANDLE, hADX   = INVALID_HANDLE;
int      hMkt  = INVALID_HANDLE;
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
   return "BTCEA_" + (string)AccountInfoInteger(ACCOUNT_LOGIN) + "_" + _Symbol + "_" + (string)InpMagic + "_" + key;
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
   if(ok) return true;
   string msg;
   if(!sent && rc == 0)
      // Bi tu choi truoc khi gui len server: lay loi kiem tra cua lan nay, khong phai ma cu
      msg = StringFormat("[%s] %s %s chua gui duoc: kiem tra %u %s, loi %d", _Symbol, kind, detail,
                         trade.CheckResultRetcode(), trade.CheckResultRetcodeDescription(), GetLastError());
   else
      msg = StringFormat("[%s] %s %s that bai: %u %s", _Symbol, kind, detail, rc, trade.ResultRetcodeDescription());
   Print(msg);
   // Sua SL chi ghi log; cac loai khac bao ve dien thoai toi da 1 lan / 5 phut moi loai
   if(kind != "Sua SL" && ShouldNotify(kind, 300) && !MQLInfoInteger(MQL_TESTER))
   {
      if(InpPushNotify) SendNotification(msg);
      if(InpTelegram)   SendTelegram(msg);
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

bool IsOwnSelected()
{
   return PositionGetString(POSITION_SYMBOL) == _Symbol &&
          PositionGetInteger(POSITION_MAGIC) == (long)InpMagic;
}

bool GetValue(const int handle, const int buffer, const int shift, double &value)
{
   double buf[];
   if(CopyBuffer(handle, buffer, shift, 1, buf) != 1) return false;
   value = buf[0];
   return true;
}

double NormalizeVolume(double lots)
{
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(step <= 0) step = 0.01;
   lots = MathFloor(lots / step + 1e-9) * step;
   int digits = (int)MathMax(0, MathCeil(-MathLog10(step)));
   return NormalizeDouble(lots, digits);
}

//--- Thong bao -----------------------------------------------------
string UrlEncode(const string s)
{
   uchar b[];
   int n = StringToCharArray(s, b, 0, WHOLE_ARRAY, CP_UTF8);
   string out = "";
   for(int i = 0; i < n - 1; i++)
   {
      uchar c = b[i];
      if((c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z') || (c >= '0' && c <= '9') ||
         c == '-' || c == '_' || c == '.' || c == '~')
         out += CharToString(c);
      else
         out += StringFormat("%%%02X", c);
   }
   return out;
}

void SendTelegram(const string msg)
{
   if(InpTgToken == "" || InpTgChatId == "") return;
   string url  = "https://api.telegram.org/bot" + InpTgToken + "/sendMessage";
   string body = "chat_id=" + UrlEncode(InpTgChatId) + "&text=" + UrlEncode(msg);
   char data[];
   int n = StringToCharArray(body, data, 0, WHOLE_ARRAY, CP_UTF8);
   if(n > 0) ArrayResize(data, n - 1);           // bo ky tu ket thuc chuoi
   char   result[];
   string resultHeaders;
   ResetLastError();
   int code = WebRequest("POST", url, "Content-Type: application/x-www-form-urlencoded\r\n",
                         5000, data, result, resultHeaders);
   if(code == -1)
      PrintFormat("Telegram loi %d. Them https://api.telegram.org vao Tools > Options > Expert Advisors > Allow WebRequest",
                  GetLastError());
   else if(code != 200)
      PrintFormat("Telegram tra ve HTTP %d: %s", code, CharArrayToString(result));
}

void Notify(const string msg)
{
   Print(msg);
   if(MQLInfoInteger(MQL_TESTER)) return;          // khong gui khi backtest
   if(InpPushNotify) SendNotification(msg);
   if(InpTelegram)   SendTelegram(msg);
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
   // Gioi han 1 lan moi 10 giay de khong spam lenh/thong bao khi server tu choi lien tuc
   static datetime lastTry = 0;
   if(TimeCurrent() - lastTry < 10) return;
   lastTry = TimeCurrent();
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !IsOwnSelected()) continue;
      TradeDone(PrepSend() && trade.PositionClose(ticket), "Dong lenh", "#" + (string)ticket);
   }
}

//--- Bao ve tai khoan ----------------------------------------------
// Cac moc lo ngay / sut giam chi tinh tren LAI/LO CUA CHINH BOT (theo magic + symbol):
//   Von cua bot = von moc (balance luc bat dau theo doi) + lai/lo da dong + lai/lo dang chay
// Nap/rut tien hay EA khac tren cung tai khoan khong lam lech cac moc nay.
double GVGet(const string key, const double def = 0)
{
   string k = GVName(key);
   return GlobalVariableCheck(k) ? GlobalVariableGet(k) : def;
}

datetime DayStart()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   dt.hour = 0; dt.min = 0; dt.sec = 0;
   return StructToTime(dt);
}

double DealNet(const ulong d)
{
   return HistoryDealGetDouble(d, DEAL_PROFIT) + HistoryDealGetDouble(d, DEAL_SWAP) +
          HistoryDealGetDouble(d, DEAL_COMMISSION) + HistoryDealGetDouble(d, DEAL_FEE);
}

// Tinh lai lai/lo da dong tu lich su giao dich (khi co giao dich moi, hoac moi 60 giay)
void RefreshClosedPL()
{
   if(!g_plDirty && TimeCurrent() - g_lastPLCalc < 60) return;
   datetime epoch = (datetime)GVGet("epoch", 0);
   datetime today = DayStart();
   if(!HistorySelect(epoch, TimeCurrent() + 60)) return;
   double all = 0, day = 0;
   for(int i = HistoryDealsTotal() - 1; i >= 0; i--)
   {
      ulong d = HistoryDealGetTicket(i);
      if(d == 0) continue;
      if(HistoryDealGetString(d, DEAL_SYMBOL) != _Symbol ||
         HistoryDealGetInteger(d, DEAL_MAGIC) != (long)InpMagic) continue;
      double net = DealNet(d);
      all += net;
      if((datetime)HistoryDealGetInteger(d, DEAL_TIME) >= today) day += net;
   }
   g_closedPL    = all;
   g_closedToday = day;
   g_plDirty     = false;
   g_lastPLCalc  = TimeCurrent();
}

double FloatingPL()
{
   double f = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetTicket(i) == 0 || !IsOwnSelected()) continue;
      f += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
   }
   return f;
}

double BaseCapital() { return InpCapital > 0 ? InpCapital : GVGet("base"); }
double BotEquity() { return BaseCapital() + g_closedPL + FloatingPL(); }

// Von dung de xet gioi han: chi tru phan lo dang chay (duoi gia vao), KHONG tinh lai dang chay.
// Nho vay, lenh dang lai ma tra bot lai lai khong bi coi la lo ngay / sut giam.
double BotEquityForLimits() { return BaseCapital() + g_closedPL + MathMin(0.0, FloatingPL()); }

// Dat moc von cua bot (lan dau chay, hoac khi InpResetHalt = true)
// unlock = true chi khi nguoi dung chu dong dat InpResetHalt. Doi InpCapital chi dat lai moc,
// KHONG go trang thai dung han / khoa lo ngay, de khong vo tinh mo khoa bot da cham gioi han rui ro.
void ResetBaseline(const bool unlock)
{
   GlobalVariableSet(GVName("epoch"), (double)TimeCurrent());
   GlobalVariableSet(GVName("base"),  AccountInfoDouble(ACCOUNT_BALANCE));
   if(unlock)
   {
      GlobalVariableDel(GVName("halt"));
      GlobalVariableDel(GVName("dayLock"));
   }
   GlobalVariableDel(GVName("dayId"));
   currentDay = -1;                                   // de UpdateDay chup lai moc dau ngay
   g_plDirty = true;
   RefreshClosedPL();
   GlobalVariableSet(GVName("peak"), BotEquityForLimits());
}

// Von cua bot luc dau ngay duoc luu vao Global Variable, nen khoi dong lai giua ngay khong reset
void UpdateDay()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   int dayId = dt.year * 1000 + dt.day_of_year;
   if(dayId != currentDay)
   {
      currentDay    = dayId;
      dailyNotified = false;
      g_plDirty     = true;
      RefreshClosedPL();
      if((int)GVGet("dayId", -1) == dayId && GlobalVariableCheck(GVName("dayEq")))
         dayStartEquity = GVGet("dayEq");
      else
      {
         dayStartEquity = BotEquityForLimits();
         GlobalVariableSet(GVName("dayId"), dayId);
         GlobalVariableSet(GVName("dayEq"), dayStartEquity);
      }
   }
}

// Lai/lo trong ngay = thay doi cua "von xet gioi han" so voi luc dau ngay
//   = lai/lo dong hom nay + (lo dang chay bay gio - lo dang chay luc 00:00)
// Lenh giu qua dem dang lo 70 luc 00:00 roi lo them 20 -> lo ngay = 20, khong phai 90.
double DayPL() { return BotEquityForLimits() - dayStartEquity; }

// Da cham lo ngay thi KHOA den het ngay, ke ca khi lo hoi phuc lai sau do
bool DailyLocked() { return (int)GVGet("dayLock", -1) == currentDay; }
bool DailyLossHit()
{
   if(InpMaxDailyLossPct <= 0 || dayStartEquity <= 0) return false;
   if(DailyLocked()) return true;
   return DayPL() <= -dayStartEquity * InpMaxDailyLossPct / 100.0;
}

// Kiem tra lo ngay moi tick: chan lenh moi va (tuy chon) dong lenh dang mo
void CheckDailyLoss()
{
   static int hits = 0;
   if(!DailyLossHit()) { hits = 0; return; }
   if(!DailyLocked() && ++hits < 2) return;
   GlobalVariableSet(GVName("dayLock"), currentDay);
   if(!dailyNotified)
   {
      Notify(StringFormat("[%s] Cham gioi han lo ngay %.1f%% (%.2f). Ngung vao lenh den mai%s.",
                          _Symbol, InpMaxDailyLossPct, DayPL(), InpCloseOnDailyLoss ? ", da dong lenh dang mo" : ""));
      dailyNotified = true;
   }
   if(InpCloseOnDailyLoss && HasOwnPosition()) CloseAll();
}

bool IsHalted() { return GVGet("halt") > 0; }

// Chong "lo gia": ngay sau khi so lenh mo thay doi, lich su giao dich co the chua cap nhat,
// nen bo qua kiem tra trong 2 tick va chi kich hoat khi dieu kien dung 2 lan lien tiep.
int  g_lastPosCount = -1;
int  g_skipTicks    = 0;
int  CountOwnPositions()
{
   int n = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
      if(PositionGetTicket(i) != 0 && IsOwnSelected()) n++;
   return n;
}
bool LimitsReady()
{
   int n = CountOwnPositions();
   if(n != g_lastPosCount) { g_lastPosCount = n; g_plDirty = true; g_skipTicks = 2; }
   if(g_skipTicks > 0) { g_skipTicks--; return false; }
   return true;
}

void CheckDrawdown()
{
   double eq   = BotEquityForLimits();
   double peak = GVGet("peak");
   if(eq > peak) { GlobalVariableSet(GVName("peak"), eq); peak = eq; }
   static int hits = 0;
   if(InpMaxDrawdownPct <= 0 || IsHalted() || peak <= 0) return;
   if(eq > peak * (1.0 - InpMaxDrawdownPct / 100.0)) { hits = 0; return; }
   if(++hits >= 2)
   {
      GlobalVariableSet(GVName("halt"), 1);
      Notify(StringFormat("[%s] BOT DUNG HAN: von cua bot sut %.1f%% tu dinh %.2f. Dat InpResetHalt=true de chay lai.",
                          _Symbol, (1.0 - eq / peak) * 100.0, peak));
      if(InpCloseOnHalt) CloseAll();
   }
}

//--- Bo loc thoi gian ----------------------------------------------
bool InWindow(const int hour, const int s, const int e)
{
   if(s < 0 || e < 0 || s == e) return false;
   if(s < e) return hour >= s && hour < e;
   return hour >= s || hour < e;                  // khung qua nua dem
}

bool TimeAllowed(string &why)
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   if(InpSkipWeekend && (dt.day_of_week == 0 || dt.day_of_week == 6)) { why = "cuoi tuan"; return false; }
   if(InWindow(dt.hour, InpBlock1Start, InpBlock1End) ||
      InWindow(dt.hour, InpBlock2Start, InpBlock2End)) { why = "khung gio tin tuc"; return false; }
   return true;
}

//--- Mau nen -------------------------------------------------------
bool BullCandle()
{
   double o1 = iOpen(_Symbol, InpTF, 1), c1 = iClose(_Symbol, InpTF, 1);
   double h1 = iHigh(_Symbol, InpTF, 1), l1 = iLow(_Symbol, InpTF, 1);
   double o2 = iOpen(_Symbol, InpTF, 2), c2 = iClose(_Symbol, InpTF, 2);
   double range = h1 - l1;
   if(range <= 0) return false;
   double body      = MathAbs(c1 - o1);
   double lowerWick = MathMin(o1, c1) - l1;
   bool pin       = lowerWick >= 0.5 * range && body <= 0.35 * range && c1 >= l1 + 0.5 * range;
   bool engulfing = c1 > o1 && c2 < o2 && c1 >= o2 && o1 <= c2;
   return pin || engulfing;
}

bool BearCandle()
{
   double o1 = iOpen(_Symbol, InpTF, 1), c1 = iClose(_Symbol, InpTF, 1);
   double h1 = iHigh(_Symbol, InpTF, 1), l1 = iLow(_Symbol, InpTF, 1);
   double o2 = iOpen(_Symbol, InpTF, 2), c2 = iClose(_Symbol, InpTF, 2);
   double range = h1 - l1;
   if(range <= 0) return false;
   double body      = MathAbs(c1 - o1);
   double upperWick = h1 - MathMax(o1, c1);
   bool pin       = upperWick >= 0.5 * range && body <= 0.35 * range && c1 <= h1 - 0.5 * range;
   bool engulfing = c1 < o1 && c2 > o2 && c1 <= o2 && o1 >= c2;
   return pin || engulfing;
}

//--- Khoi luong ----------------------------------------------------
//--- Funding rate (Binance USDT-M Futures) ----------------------------
// Backtest: doc file funding_<CAP>.csv trong thu muc Common\Files (script ChayThuNghiem tai ve).
// Chay that: hoi Binance moi gio qua WebRequest (them https://fapi.binance.com vao danh sach cho phep),
// loi thi dung gia tri moi nhat trong file.
datetime g_fT[];
double   g_fR[];
double   g_liveFunding = EMPTY_VALUE;
datetime g_liveFundingAt = 0;
int      g_fundBlocked = 0;     // so tin hieu bi bo vi funding (ghi vao ket qua backtest)
string FundingPair()
{
   if(StringFind(_Symbol, "BTC") >= 0) return "BTCUSDT";
   if(StringFind(_Symbol, "ETH") >= 0) return "ETHUSDT";
   return "";
}
void LoadFunding()
{
   ArrayResize(g_fT, 0); ArrayResize(g_fR, 0);
   string pair = FundingPair();
   if(pair == "") return;
   int h = FileOpen("funding_" + pair + ".csv", FILE_READ | FILE_CSV | FILE_ANSI | FILE_COMMON, ',');
   if(h == INVALID_HANDLE) { Print("Chua co file funding_", pair, ".csv: bo loc funding se khong chan lenh nao."); return; }
   while(!FileIsEnding(h))
   {
      string ms = FileReadString(h);
      string rt = FileReadString(h);
      long   t  = StringToInteger(ms);
      if(t <= 0) continue;                              // dong tieu de / dong trong
      int n = ArraySize(g_fT);
      ArrayResize(g_fT, n + 1); ArrayResize(g_fR, n + 1);
      g_fT[n] = (datetime)(t / 1000);
      g_fR[n] = StringToDouble(rt) * 100.0;             // doi sang %
   }
   FileClose(h);
   PrintFormat("Da nap %d moc funding %s.", ArraySize(g_fT), pair);
}
// Funding (%) da biet tai thoi diem t: moc gan nhat <= t. EMPTY_VALUE neu khong co du lieu.
double FundingAt(const datetime t)
{
   int n = ArraySize(g_fT);
   if(n == 0 || t < g_fT[0]) return EMPTY_VALUE;
   if(t - g_fT[n - 1] > 2 * 86400) return EMPTY_VALUE;  // du lieu cu qua 2 ngay: coi nhu khong co
   int lo = 0, hi = n - 1;
   while(lo < hi) { int mid = (lo + hi + 1) / 2; if(g_fT[mid] <= t) lo = mid; else hi = mid - 1; }
   return g_fR[lo];
}
string g_fundState = "";   // hien tren bang thong tin
datetime g_liveFundingOk = 0;
bool LiveFundingFresh() { return g_liveFunding != EMPTY_VALUE && TimeCurrent() - g_liveFundingOk <= 2 * 86400; }
double FundingNow()
{
   if(!MQLInfoInteger(MQL_TESTER) && FundingPair() != "" && TimeCurrent() - g_liveFundingAt >= 3600)
   {
      g_liveFundingAt = TimeCurrent();
      char req[], res[]; string hdr;
      int code = WebRequest("GET", "https://fapi.binance.com/fapi/v1/premiumIndex?symbol=" + FundingPair(),
                            "", 5000, req, res, hdr);
      if(code == 200)
      {
         string js = CharArrayToString(res);
         int k = StringFind(js, "\"lastFundingRate\":\"");
         if(k >= 0)
         {
            k += StringLen("\"lastFundingRate\":\"");
            g_liveFunding = StringToDouble(StringSubstr(js, k, StringFind(js, "\"", k) - k)) * 100.0;
            g_liveFundingOk = TimeCurrent();
         }
      }
      else if(ShouldNotify("funding", 86400))
         PrintFormat("Khong lay duoc funding (%d). Them https://fapi.binance.com vao Tools > Options > Expert Advisors > Allow WebRequest.", code);
   }
   if(!MQLInfoInteger(MQL_TESTER))
   {
      if(LiveFundingFresh()) { g_fundState = StringFormat("%.4f%% (Binance)", g_liveFunding); return g_liveFunding; }
      double f = FundingAt(TimeCurrent());
      g_fundState = f == EMPTY_VALUE ? "KHONG CO DU LIEU - bo loc dang tat" : StringFormat("%.4f%% (file cu)", f);
      return f;
   }
   return FundingAt(TimeCurrent());
}

//--- Chuoi so lieu theo ngay (Fear & Greed, luot xem Wikipedia) ------
// File trong Common\Files, moi dong "unix_giay,gia_tri" (script ChayThuNghiem tai ve).
// Chi dung so lieu cua NGAY HOM QUA tro ve truoc, tranh nhin truoc tuong lai trong backtest.
datetime g_fngT[];  double g_fngV[];
datetime g_wikT[];  double g_wikV[];
datetime g_fngLiveAt = 0, g_wikLiveAt = 0;
int      g_fngBlocked = 0, g_attBlocked = 0, g_mktBlocked = 0, g_newsBlocked = 0;
datetime DayOf(const datetime t) { return t - t % 86400; }
string WikiArticle()
{
   if(StringFind(_Symbol, "BTC") >= 0) return "Bitcoin";
   if(StringFind(_Symbol, "ETH") >= 0) return "Ethereum";
   return "";
}
// Them / cap nhat 1 ngay, giu mang tang dan theo thoi gian
void MergeDaily(datetime &t[], double &v[], const datetime day, const double val)
{
   int n = ArraySize(t);
   if(n > 0 && day == t[n - 1]) { v[n - 1] = val; return; }
   if(n > 0 && day < t[n - 1])
   {
      for(int i = n - 1; i >= 0 && t[i] >= day; i--) if(t[i] == day) { v[i] = val; return; }
      return;                                    // ngay cu khong co trong file: bo qua
   }
   ArrayResize(t, n + 1); ArrayResize(v, n + 1);
   t[n] = day; v[n] = val;
}
void LoadDaily(const string file, datetime &t[], double &v[])
{
   ArrayResize(t, 0); ArrayResize(v, 0);
   int h = FileOpen(file, FILE_READ | FILE_CSV | FILE_ANSI | FILE_COMMON, ',');
   if(h == INVALID_HANDLE) { Print("Chua co file ", file, ": bo loc dung file nay se khong chan lenh nao."); return; }
   while(!FileIsEnding(h))
   {
      long   ts = StringToInteger(FileReadString(h));
      double x  = StringToDouble(FileReadString(h));
      if(ts > 0) MergeDaily(t, v, DayOf((datetime)ts), x);
   }
   FileClose(h);
   PrintFormat("Da nap %d ngay tu %s.", ArraySize(t), file);
}
// Trung binh cac ngay trong [lastDay - days + 1, lastDay]. EMPTY_VALUE neu thieu qua 30% so ngay.
double DailyAvg(const datetime &t[], const double &v[], const datetime lastDay, const int days)
{
   int n = ArraySize(t);
   if(n == 0 || lastDay < t[0]) return EMPTY_VALUE;
   int lo = 0, hi = n - 1;
   while(lo < hi) { int mid = (lo + hi + 1) / 2; if(t[mid] <= lastDay) lo = mid; else hi = mid - 1; }
   double sum = 0; int cnt = 0;
   for(int i = lo; i >= 0 && t[i] > lastDay - days * 86400; i--) { sum += v[i]; cnt++; }
   if(cnt < days * 0.7) return EMPTY_VALUE;
   return sum / cnt;
}
string JsonValue(const string js, const string key, const int from, int &pos)
{
   string k = "\"" + key + "\":";
   pos = StringFind(js, k, from);
   if(pos < 0) return "";
   int a = pos + StringLen(k);
   while(a < StringLen(js) && (StringGetCharacter(js, a) == ' ' || StringGetCharacter(js, a) == '"')) a++;
   int b = a;
   while(b < StringLen(js)) { ushort c = StringGetCharacter(js, b); if(c == '"' || c == ',' || c == '}') break; b++; }
   return StringSubstr(js, a, b - a);
}
bool HttpGet(const string url, string &body)
{
   char req[], res[]; string hdr;
   int code = WebRequest("GET", url, "User-Agent: BTC-EA/1.0\r\n", 8000, req, res, hdr);
   body = CharArrayToString(res, 0, WHOLE_ARRAY, CP_UTF8);
   if(code != 200 && ShouldNotify("http" + StringSubstr(url, 0, 30), 86400))
   {
      int e = StringFind(url, "/", 8);
      PrintFormat("Khong tai duoc %s (%d). Them %s vao Tools > Options > Expert Advisors > Allow WebRequest.",
                  url, code, StringSubstr(url, 0, e));
   }
   return code == 200;
}
// Chay that: cap nhat so lieu moi qua mang (6 gio / lan)
void RefreshDailyLive()
{
   if(MQLInfoInteger(MQL_TESTER)) return;
   string js; int pos;
   if(InpUseFearGreed && TimeCurrent() - g_fngLiveAt >= 6 * 3600)
   {
      g_fngLiveAt = TimeCurrent();
      datetime td[]; double tv[];
      if(HttpGet("https://api.alternative.me/fng/?limit=10", js))
         for(int from = 0; ; )
         {
            string val = JsonValue(js, "value", from, pos);
            if(pos < 0) break;
            string ts  = JsonValue(js, "timestamp", pos, pos);
            if(pos < 0) break;
            from = pos + 1;
            int k = ArraySize(td);
            ArrayResize(td, k + 1); ArrayResize(tv, k + 1);
            td[k] = DayOf((datetime)StringToInteger(ts)); tv[k] = StringToDouble(val);
         }
      // API tra ngay moi nhat truoc: sap xep tang dan roi gop vao chuoi
      for(int i = 1; i < ArraySize(td); i++)
         for(int j = i; j > 0 && td[j] < td[j - 1]; j--)
         { datetime x = td[j]; td[j] = td[j - 1]; td[j - 1] = x; double y = tv[j]; tv[j] = tv[j - 1]; tv[j - 1] = y; }
      for(int i = 0; i < ArraySize(td); i++) MergeDaily(g_fngT, g_fngV, td[i], tv[i]);
   }
   if(InpUseAttention && WikiArticle() != "" && TimeCurrent() - g_wikLiveAt >= 6 * 3600)
   {
      g_wikLiveAt = TimeCurrent();
      string a = TimeToString(TimeGMT() - 45 * 86400, TIME_DATE), b = TimeToString(TimeGMT(), TIME_DATE);
      StringReplace(a, ".", ""); StringReplace(b, ".", "");
      if(HttpGet("https://wikimedia.org/api/rest_v1/metrics/pageviews/per-article/en.wikipedia/all-access/user/"
                 + WikiArticle() + "/daily/" + a + "/" + b, js))
         for(int from = 0; ; )
         {
            string ts = JsonValue(js, "timestamp", from, pos);     // dang 2026110500
            if(pos < 0) break;
            string vw = JsonValue(js, "views", pos, pos);
            if(pos < 0) break;
            from = pos + 1;
            MqlDateTime m; ZeroMemory(m);
            m.year = (int)StringToInteger(StringSubstr(ts, 0, 4));
            m.mon  = (int)StringToInteger(StringSubstr(ts, 4, 2));
            m.day  = (int)StringToInteger(StringSubstr(ts, 6, 2));
            MergeDaily(g_wikT, g_wikV, StructToTime(m), StringToDouble(vw));
         }
   }
}
// Tin vi mo My quan trong trong khoang +-InpNewsHours (chi chay that; lich kinh te khong co trong backtest)
bool USNewsNear(string &name)
{
   if(MQLInfoInteger(MQL_TESTER)) return false;
   MqlCalendarValue vals[];
   datetime now = TimeTradeServer();
   if(CalendarValueHistory(vals, now - InpNewsHours * 3600, now + InpNewsHours * 3600, "US") <= 0) return false;
   for(int i = 0; i < ArraySize(vals); i++)
   {
      MqlCalendarEvent ev;
      if(CalendarEventById(vals[i].event_id, ev) && ev.importance == CALENDAR_IMPORTANCE_HIGH)
      { name = ev.name; return true; }
   }
   return false;
}

// Ma khac trong InpCorrSymbols dang co lenh (cua bat ky bot nao) -> tra ten ma, khong co -> ""
string CorrOpen()
{
   string list = "," + InpCorrSymbols + ",";
   StringReplace(list, " ", "");
   if(StringFind(list, "," + _Symbol + ",") < 0) return "";
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      string sym = PositionGetSymbol(i);
      if(sym != "" && sym != _Symbol && StringFind(list, "," + sym + ",") >= 0) return sym;
   }
   return "";
}
int g_minLotSkips = 0;
int g_roundUps    = 0;   // So lenh vao lot toi thieu (rui ro that > InpRiskPercent nhung <= InpMaxRiskRoundUp)   // So tin hieu bi bo vi lot tinh ra nho hon lot toi thieu (ghi vao ket qua backtest)
double CalcLots(const double slDistance)
{
   double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE_LOSS);
   if(tickValue <= 0) tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   if(tickSize <= 0 || tickValue <= 0 || slDistance <= 0) return 0;

   // Rui ro tinh tren "von cua bot" (cung moc voi gioi han lo), khong phai equity ca tai khoan.
   // Sau khi nap/rut tien, dat InpResetHalt = true 1 lan de cap nhat moc.
   double riskBase   = BotEquity();
   double riskMoney  = riskBase * InpRiskPercent / 100.0;
   // BTC va ETH di cung nhau (tuong quan cao): ma cung nhom dang co lenh thi giam rui ro lenh moi
   string corr = CorrOpen();
   if(corr != "" && InpCorrRiskScale > 0 && InpCorrRiskScale < 1)
   {
      riskMoney *= InpCorrRiskScale;
      PrintFormat("%s dang co lenh, giam rui ro lenh nay x%.2f.", corr, InpCorrRiskScale);
   }
   double lossPerLot = slDistance / tickSize * tickValue;
   double lots       = NormalizeVolume(riskMoney / lossPerLot);
   double minL = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxL = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   if(lots < minL && InpMaxRiskRoundUp > 0 && riskBase > 0 && minL * lossPerLot <= riskBase * InpMaxRiskRoundUp / 100.0)
   {
      g_roundUps++;
      PrintFormat("Lam tron len %.2f lot: rui ro that %.2f%% (tran %.2f%%).", minL, minL * lossPerLot / riskBase * 100.0, InpMaxRiskRoundUp);
      lots = minL;
   }
   if(lots < minL)
   {
      g_status = "Von qua nho cho SL nay, bo qua lenh";
      g_minLotSkips++;
      PrintFormat("Can %.4f lot < toi thieu %.2f. Bo qua de khong vuot rui ro.", riskMoney / lossPerLot, minL);
      return 0;
   }
   if(lots > maxL) lots = maxL;
   return lots;
}

//--- Quan ly lenh dang mo ------------------------------------------
//--- Doi soat vi the da dong het -----------------------------------
// Khong dua vao thu tu su kien OnTradeTransaction: moi vi the bot quan ly co marker O_<id>.
// Dinh ky (va ngay sau moi deal) kiem tra: vi the khong con mo VA lich su da co du khoi luong
// dong >= khoi luong vao thi moi chot (cooldown + don trang thai). Chua du thi thu lai lan sau.
bool     g_reconcile     = true;
datetime g_lastReconcile = 0;
void MarkTracked(const ulong posId)
{
   string k = GVName("O_" + (string)posId);
   if(!GlobalVariableCheck(k)) GlobalVariableSet(k, (double)TimeCurrent());
}
void FinalizeClosed(const ulong posId)
{
   double total = 0, inVol = 0, outVol = 0;
   datetime lastOut = 0;
   if(HistorySelectByPosition(posId))
      for(int i = 0; i < HistoryDealsTotal(); i++)
      {
         ulong d = HistoryDealGetTicket(i);
         if(d == 0) continue;
         long e = HistoryDealGetInteger(d, DEAL_ENTRY);
         total += DealNet(d);
         if(e == DEAL_ENTRY_IN) inVol += HistoryDealGetDouble(d, DEAL_VOLUME);
         else
         {
            outVol += HistoryDealGetDouble(d, DEAL_VOLUME);
            lastOut = (datetime)MathMax((double)lastOut, (double)HistoryDealGetInteger(d, DEAL_TIME));
         }
      }
   string oKey = GVName("O_" + (string)posId);
   // Vi the tu ban cu chi co R_: gan marker de dong ho "bo sau 1 ngay" bat dau tu bay gio
   if(!GlobalVariableCheck(oKey)) MarkTracked(posId);
   if(inVol <= 0 || outVol < inVol - 1e-8)
   {
      // Lich su chua ve kip: thu lai sau. Qua 1 ngay van khong co thi bo marker cho khoi ton.
      datetime seen = (datetime)(GlobalVariableCheck(oKey) ? GlobalVariableGet(oKey) : TimeCurrent());
      if(TimeCurrent() - seen < 86400) return;
   }
   else
   {
      string rKey      = GVName("R_" + (string)posId);
      double rDist     = GlobalVariableCheck(rKey) ? GlobalVariableGet(rKey) : 0;
      double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
      double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE_LOSS);
      double riskMoney = (rDist > 0 && tickSize > 0) ? rDist / tickSize * tickValue * inVol : 0;
      // Chi tinh la lenh thua khi lo hon 10% cua 1R; lenh hoa von am vai cent khong kich hoat nghi
      if(total < -MathMax(riskMoney * 0.1, 0.01) && lastOut > lastLossTime)
      {
         lastLossTime = lastOut;
         GlobalVariableSet(GVName("lastLoss"), (double)lastLossTime);   // giu qua khi khoi dong lai
      }
   }
   GlobalVariableDel(oKey);
   GlobalVariableDel(GVName("R_"  + (string)posId));
   GlobalVariableDel(GVName("P_"  + (string)posId));
   GlobalVariableDel(GVName("C_"  + (string)posId));
   GlobalVariableDel(GVName("PT_" + (string)posId));
   GlobalVariableDel(GVName("PV_" + (string)posId));
}
void ReconcileClosed()
{
   if(!g_reconcile && TimeCurrent() - g_lastReconcile < 5) return;
   g_reconcile = false;
   g_lastReconcile = TimeCurrent();
   string pO = GVName("O_"), pR = GVName("R_");     // R_ de bat ca vi the tu ban cu chua co marker
   ulong ids[];
   for(int i = GlobalVariablesTotal() - 1; i >= 0; i--)
   {
      string n = GlobalVariableName(i), rest = "";
      if(StringFind(n, pO) == 0)      rest = StringSubstr(n, StringLen(pO));
      else if(StringFind(n, pR) == 0) rest = StringSubstr(n, StringLen(pR));
      else continue;
      ulong id = (ulong)StringToInteger(rest);
      if(id == 0 || (string)id != rest) continue;  // bo qua ten kieu cu khong phai so
      int sz = ArraySize(ids); ArrayResize(ids, sz + 1); ids[sz] = id;
   }
   for(int j = 0; j < ArraySize(ids); j++)
      if(!PositionOpenById(ids[j])) FinalizeClosed(ids[j]);
}

void ManagePositions()
{
   double atr = 0;
   bool haveAtr = GetValue(hATR, 0, 1, atr);
   double minL  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double minDist = (double)MathMax(SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL),
                                    SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL)) * _Point;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !IsOwnSelected()) continue;
      // Trang thai va lich su gan voi POSITION_IDENTIFIER (khong doi suot doi vi the),
      // con lenh gui len server dung ticket.
      ulong posId = (ulong)PositionGetInteger(POSITION_IDENTIFIER);
      MarkTracked(posId);

      double open = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl   = PositionGetDouble(POSITION_SL);
      double tp   = PositionGetDouble(POSITION_TP);
      double vol  = PositionGetDouble(POSITION_VOLUME);
      bool   isBuy = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);

      // Luu khoang rui ro ban dau (1R) ngay lan dau thay lenh
      string rKey = GVName("R_" + (string)posId);
      string pKey = GVName("P_" + (string)posId);
      if(!GlobalVariableCheck(rKey))
      {
         // 1) Nhan lai trang thai tu ten bien cua ban cu (truoc v2.3: chi co magic)
         string oldR = "BTCEA_" + (string)InpMagic + "_R_" + (string)ticket;   // ban <= 2.2
         string oldP = "BTCEA_" + (string)InpMagic + "_P_" + (string)ticket;
         if(!GlobalVariableCheck(oldR))                                         // ban 2.3-2.5 (theo ticket)
         {
            oldR = GVName("R_" + (string)ticket);
            oldP = GVName("P_" + (string)ticket);
         }
         if(GlobalVariableCheck(oldR))
         {
            GlobalVariableSet(rKey, GlobalVariableGet(oldR));
            if(GlobalVariableCheck(oldP)) GlobalVariableSet(pKey, GlobalVariableGet(oldP));
            GlobalVariableDel(oldR); GlobalVariableDel(oldP);
         }
         else
         {
            if(sl <= 0) continue;
            bool slOnProfitSide = isBuy ? (sl >= open) : (sl <= open);
            double estR = haveAtr ? atr * InpATRMult : 0;
            if(slOnProfitSide || (estR > 0 && MathAbs(open - sl) < 0.3 * estR))
            {
               // 2) Mat trang thai va SL da doi ve hoa von/lai: khong suy ra duoc 1R that.
               //    Uoc luong 1R bang ATR x he so, va coi nhu da chot mot phan de khong chot nham.
               if(estR <= 0) continue;
               GlobalVariableSet(rKey, estR);
               GlobalVariableSet(pKey, 1);
               PrintFormat("Lenh #%s: khong co trang thai cu, uoc luong 1R = %.2f", (string)ticket, estR);
            }
            else
               GlobalVariableSet(rKey, MathAbs(open - sl));
         }
      }
      double risk = GlobalVariableGet(rKey);
      if(risk <= 0) continue;

      // Muc hoa von thuc: gia vao + (phi 2 chieu + swap am) quy ra gia + buffer
      string cKey = GVName("C_" + (string)posId);
      if(!GlobalVariableCheck(cKey))
      {
         double comm = 0, inVol = 0;
         if(HistorySelectByPosition(posId))
            for(int k = 0; k < HistoryDealsTotal(); k++)
            {
               ulong d = HistoryDealGetTicket(k);
               if(d > 0 && HistoryDealGetInteger(d, DEAL_ENTRY) == DEAL_ENTRY_IN)
               {
                  comm  += HistoryDealGetDouble(d, DEAL_COMMISSION) + HistoryDealGetDouble(d, DEAL_FEE);
                  inVol += HistoryDealGetDouble(d, DEAL_VOLUME);
               }
            }
         // Phi mot chieu tren 1 lot, chia cho khoi luong LUC VAO LENH (khong phai khoi luong con lai)
         GlobalVariableSet(cKey, MathAbs(comm) / MathMax(inVol > 0 ? inVol : vol, 1e-8));
      }
      double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
      double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE_LOSS);
      double costMoney = GlobalVariableGet(cKey) * vol * 2.0 + MathMax(0.0, -PositionGetDouble(POSITION_SWAP));
      double costPrice = (tickSize > 0 && tickValue > 0) ? costMoney / (tickValue * vol) * tickSize : 0;
      double beOffset  = costPrice + InpBEBufferR * risk;
      double beLevel   = isBuy ? open + beOffset : open - beOffset;

      double price = isBuy ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double rNow  = (isBuy ? price - open : open - price) / risk;

      // 1) Chot loi mot phan
      // Luu khoi luong CON LAI muc tieu (PV_) o lan dau. Moi lan chi dong phan con thieu so voi muc tieu,
      // nen neu server chi khop mot phan (DONE_PARTIAL) thi lan sau bot dong not, khong dong lo qua tay.
      string vKey = GVName("PV_" + (string)posId);
      if(InpUsePartial && !GlobalVariableCheck(pKey) && (rNow >= InpPartialR || GlobalVariableCheck(vKey)))
      {
         if(!GlobalVariableCheck(vKey))
         {
            double firstClose = NormalizeVolume(vol * InpPartialPct / 100.0);
            if(firstClose < minL || vol - firstClose < minL - 1e-9)
            {
               GlobalVariableSet(pKey, 1);              // lot qua nho de chia, bo qua
               continue;
            }
            GlobalVariableSet(vKey, vol - firstClose);
         }
         double target   = GlobalVariableGet(vKey);
         double closeVol = NormalizeVolume(vol - target);
         if(vol <= target + 1e-9 || closeVol < minL - 1e-9)
         {
            GlobalVariableSet(pKey, 1);                 // da dat muc tieu (hoac phan thieu nho hon lot toi thieu)
            GlobalVariableDel(vKey);
            GlobalVariableDel(GVName("PT_" + (string)posId));
            continue;
         }
         // Thu lai toi da 1 lan / 10 giay moi lenh (tu choi, hoac cho vi the cap nhat sau khop mot phan)
         string tKey = GVName("PT_" + (string)posId);
         bool sentNow = false;
         if(TimeCurrent() - (datetime)(GlobalVariableCheck(tKey) ? GlobalVariableGet(tKey) : 0) >= 10)
         {
            sentNow = true;
            GlobalVariableSet(tKey, (double)TimeCurrent());
            bool sent;
            if(IsHedging())
               sent = PrepSend() && trade.PositionClosePartial(ticket, closeVol);
            else   // Netting: gui lenh nguoc chieu cung magic de giam khoi luong vi the
               sent = PrepSend() && (isBuy ? trade.Sell(closeVol, _Symbol, 0, 0, 0, "partial")
                                           : trade.Buy (closeVol, _Symbol, 0, 0, 0, "partial"));
            if(TradeDone(sent, "Chot mot phan", "#" + (string)ticket))
            {
               // Chi khi khop DU moi danh dau xong; DONE_PARTIAL thi giu PV_ de lan sau dong not phan thieu
               if(trade.ResultRetcode() == TRADE_RETCODE_DONE && trade.ResultVolume() >= closeVol - 1e-9)
               {
                  GlobalVariableSet(pKey, 1);
                  GlobalVariableDel(vKey);
                  GlobalVariableDel(tKey);
               }
               // Netting: neu server xoa SL/TP cua vi the sau deal giam, dat lai nhu cu
               if(!IsHedging() && PositionSelect(_Symbol) &&
                  ((sl > 0 && PositionGetDouble(POSITION_SL) <= 0) || (tp > 0 && PositionGetDouble(POSITION_TP) <= 0)))
                  TradeDone(PrepSend() && trade.PositionModify(_Symbol, sl, tp), "Dat lai SL/TP", _Symbol);
            }
         }
         // Vua gui lenh dong thi de tick sau moi sua SL (khoi luong/vi the co the vua doi).
         // Neu dang cho thu lai (bi tu choi), van chay hoa von + trailing ben duoi de SL khong bi dung.
         if(sentNow) continue;
      }

      // 2) Hoa von va 3) trailing ATR
      double newSL = sl;
      if(InpUseBreakeven && rNow >= InpBreakevenR)
      {
         if(isBuy  && (sl <= 0 || sl < beLevel)) newSL = beLevel;
         if(!isBuy && (sl <= 0 || sl > beLevel)) newSL = beLevel;
      }
      if(InpUseTrailing && haveAtr && rNow >= InpTrailStartR)
      {
         double cand = isBuy ? price - atr * InpTrailATRMult : price + atr * InpTrailATRMult;
         if(isBuy  && cand > newSL) newSL = cand;
         if(!isBuy && (newSL <= 0 || cand < newSL)) newSL = cand;
      }
      newSL = NormalizeDouble(newSL, _Digits);

      double minStep = MathMax(_Point * 10, risk * 0.05);   // tranh sua lenh lien tuc
      bool better    = isBuy ? (newSL > sl + minStep) : (sl <= 0 || newSL < sl - minStep);
      bool validDist = isBuy ? (price - newSL > minDist) : (newSL - price > minDist);
      if(newSL > 0 && better && validDist)
         TradeDone(PrepSend() && trade.PositionModify(ticket, newSL, tp), "Sua SL", "#" + (string)ticket);
   }
}

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
         HistoryDealGetInteger(d, DEAL_MAGIC) == (long)InpMagic &&
         HistoryDealGetInteger(d, DEAL_ENTRY) == DEAL_ENTRY_IN) n++;
   }
   return n;
}

void UpdatePanel()
{
   if(!InpShowPanel) return;
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
      InpStrategy == STRAT_DONCHIAN ? "Donchian" : "EMA pullback", _Symbol, IsHalted() ? "DUNG HAN (sut giam)" : g_status,
      eq, cur, dayPL, cur, dayStartEquity > 0 ? dayPL / dayStartEquity * 100.0 : 0,
      DailyLocked() ? "  [DA KHOA HOM NAY]" : "", g_closedToday, cur,
      TradesToday(), dd, InpMaxDrawdownPct,
      (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD),
      InpUseFunding ? "\nFunding: " + (g_fundState == "" ? "chua kiem tra" : g_fundState) : ""));
}

//+------------------------------------------------------------------+
int OnInit()
{
   if(InpUseFunding) LoadFunding();
   if(InpUseFearGreed) LoadDaily("fng.csv", g_fngT, g_fngV);
   if(InpUseAttention && WikiArticle() != "") LoadDaily("wiki_" + WikiArticle() + ".csv", g_wikT, g_wikV);
   if(InpUseMarketFilter)
   {
      g_mktSym = InpMarketSymbol;
      if(!SymbolSelect(g_mktSym, true)) g_mktSym = InpMarketSymbol + "m";
      if(!SymbolSelect(g_mktSym, true))
      { Print("Khong tim thay ma ", InpMarketSymbol, " / ", g_mktSym, ": tat bo loc Nasdaq."); g_mktSym = ""; }
      else hMkt = iMA(g_mktSym, PERIOD_D1, 200, 0, MODE_EMA, PRICE_CLOSE);
   }
   hFast  = iMA(_Symbol, InpTF,  InpFastEMA,  0, MODE_EMA, PRICE_CLOSE);
   hTrend = iMA(_Symbol, InpTF,  InpTrendEMA, 0, MODE_EMA, PRICE_CLOSE);
   hHTF   = iMA(_Symbol, InpHTF, InpHTFEMA,   0, MODE_EMA, PRICE_CLOSE);
   hATR   = iATR(_Symbol, InpTF, InpATRPeriod);
   hADX   = iADX(_Symbol, InpTF, InpADXPeriod);
   if(hFast == INVALID_HANDLE || hTrend == INVALID_HANDLE || hHTF == INVALID_HANDLE ||
      hATR == INVALID_HANDLE || hADX == INVALID_HANDLE)
   {
      Print("Khong tao duoc chi bao");
      return INIT_FAILED;
   }
   trade.SetExpertMagicNumber(InpMagic);
   trade.SetTypeFillingBySymbol(_Symbol);
   trade.SetDeviationInPoints(100);

   TryInitState();          // neu chua dang nhap, se thu lai o cac tick sau
   return INIT_SUCCEEDED;
}

// Khoi tao trang thai (moc von, thoi gian nghi...) CHI KHI da dang nhap va ket noi server.
// Tranh truong hop VPS khoi dong lai: OnInit chay luc login = 0, moc von bi luu sai ten.
bool g_stateReady = false;
bool TryInitState()
{
   if(g_stateReady) return true;
   if(AccountInfoInteger(ACCOUNT_LOGIN) <= 0 || !TerminalInfoInteger(TERMINAL_CONNECTED))
   {
      g_status = "Cho dang nhap tai khoan...";
      return false;
   }
   // Doi InpCapital so voi lan truoc thi tu dat lai moc, tranh dinh cu (vd. 3000) so voi von moi (1000)
   // bi hieu nham la sut giam 66% va bot dung han.
   bool capitalChanged = GlobalVariableCheck(GVName("capital")) && GVGet("capital") != InpCapital;
   if(InpResetHalt || capitalChanged || !GlobalVariableCheck(GVName("base")))
   {
      ResetBaseline(InpResetHalt);
      if(InpResetHalt)   Print("Da mo khoa bot va dat lai moc von. Nho doi InpResetHalt ve false.");
      if(capitalChanged) Print("InpCapital da thay doi, tu dat lai moc von va dinh von.");
      if(capitalChanged && !InpResetHalt && (IsHalted() || GlobalVariableCheck(GVName("dayLock"))))
         Print("Bot VAN DANG DUNG / KHOA LO NGAY. Doi von khong mo khoa; muon mo, dat InpResetHalt = true mot lan.");
   }
   GlobalVariableSet(GVName("capital"), InpCapital);
   lastLossTime = (datetime)GVGet("lastLoss", 0);
   g_plDirty = true;
   RefreshClosedPL();
   UpdateDay();
   if(!IsHedging())
      Print("CANH BAO: tai khoan NETTING. Bot duoc thiet ke cho tai khoan HEDGING; chot mot phan se dong theo symbol.");
   g_stateReady = true;
   Notify(StringFormat("[%s] Bot v" + BOT_VERSION + " khoi dong. Von cua bot %.2f %s", _Symbol,
                       BotEquity(), AccountInfoString(ACCOUNT_CURRENCY)));
   return true;
}

void OnDeinit(const int reason)
{
   IndicatorRelease(hFast);
   IndicatorRelease(hTrend);
   IndicatorRelease(hHTF);
   IndicatorRelease(hATR);
   IndicatorRelease(hADX);
   if(hMkt != INVALID_HANDLE) IndicatorRelease(hMkt);
   Comment("");
}

// Cac bo loc tu nghien cuu tam ly / thi truong. Thieu so lieu thi KHONG chan (bot van chay nhu cu).
bool MarketFiltersOk(const bool isBuy)
{
   RefreshDailyLive();
   datetime yday = DayOf(TimeCurrent()) - 86400;          // chi dung so lieu da biet: hom qua tro ve truoc
   if(InpUseFearGreed)
   {
      double f = DailyAvg(g_fngT, g_fngV, yday, 1);
      if(f != EMPTY_VALUE && ((isBuy && f >= InpFngGreedMax) || (!isBuy && f <= InpFngFearMin)))
      {
         g_fngBlocked++;
         g_status = StringFormat("Bo tin hieu vi Fear & Greed = %.0f", f);
         return false;
      }
   }
   if(InpUseAttention)
   {
      double a7 = DailyAvg(g_wikT, g_wikV, yday, 7), a30 = DailyAvg(g_wikT, g_wikV, yday, 30);
      if(a7 != EMPTY_VALUE && a30 != EMPTY_VALUE && a7 <= a30)
      {
         g_attBlocked++;
         g_status = "Bo tin hieu vi su chu y dang giam (Wikipedia)";
         return false;
      }
   }
   if(hMkt != INVALID_HANDLE)
   {
      double ema, cl = iClose(g_mktSym, PERIOD_D1, 1);
      if(cl > 0 && GetValue(hMkt, 0, 1, ema) && ((isBuy && cl < ema) || (!isBuy && cl > ema)))
      {
         g_mktBlocked++;
         g_status = "Bo tin hieu vi Nasdaq nguoc chieu";
         return false;
      }
   }
   string news;
   if(InpAvoidUSNews && USNewsNear(news))
   {
      g_newsBlocked++;
      g_status = "Gan tin My: " + news;
      return false;
   }
   return true;
}

//+------------------------------------------------------------------+
void OnTick()
{
   if(!TryInitState()) return;      // chua dang nhap: chua lam gi ca
   bool ready = LimitsReady();
   RefreshClosedPL();
   UpdateDay();
   if(ready) CheckDrawdown();
   // Da dung han ma van con lenh (vd. dong that bai lan truoc) thi thu dong lai moi tick
   if(IsHalted() && InpCloseOnHalt && HasOwnPosition()) CloseAll();
   if(ready) CheckDailyLoss();
   ManagePositions();
   ReconcileClosed();
   UpdatePanel();

   datetime barTime = iTime(_Symbol, InpTF, 0);
   if(barTime == 0 || barTime == lastBarTime) return;
   lastBarTime = barTime;

   if(IsHalted())       { g_status = "DUNG HAN (sut giam)"; return; }
   if(HasOwnPosition()) { g_status = "Dang giu lenh";       return; }
   if(DailyLossHit())   { g_status = "Cham gioi han lo ngay, nghi den mai"; return; }
   string why = "";
   if(!TimeAllowed(why)) { g_status = "Tam nghi: " + why; return; }
   if(InpMaxSpreadPoints > 0 && SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) > InpMaxSpreadPoints)
   {
      g_status = "Spread qua rong";
      return;
   }
   if(InpMaxTradesPerDay > 0 && TradesToday() >= InpMaxTradesPerDay)
   {
      g_status = "Du so lenh trong ngay";
      return;
   }
   if(InpCooldownBars > 0 && lastLossTime > 0 &&
      TimeCurrent() - lastLossTime < (long)InpCooldownBars * PeriodSeconds(InpTF))
   {
      g_status = "Nghi sau lenh thua";
      return;
   }

   double fast, trend, atr, adx = 0, htfEma = 0;
   if(!GetValue(hFast, 0, 1, fast) || !GetValue(hTrend, 0, 1, trend) || !GetValue(hATR, 0, 1, atr)) return;
   if(InpUseADX && !GetValue(hADX, 0, 1, adx)) return;          // buffer 0 = ADX chinh
   if(InpUseHTF && !GetValue(hHTF, 0, 1, htfEma)) return;
   double htfClose = iClose(_Symbol, InpHTF, 1);

   double c1 = iClose(_Symbol, InpTF, 1);
   double h1 = iHigh(_Symbol,  InpTF, 1);
   double l1 = iLow(_Symbol,   InpTF, 1);

   bool adxOk = !InpUseADX || adx >= InpADXMin;
   bool buyBase, sellBase;
   if(InpStrategy == STRAT_DONCHIAN)
   {
      // Pha vo: nen "b" dong vuot dinh/day cao nhat/thap nhat cua N nen truoc no.
      // b = 1 (nen vua dong); neu InpBreakConfirm thi b = 2 va nen 1 phai van dong ngoai kenh.
      int b = InpBreakConfirm ? 2 : 1;
      int hiIdx = iHighest(_Symbol, InpTF, MODE_HIGH, InpDonchianPeriod, b + 1);
      int loIdx = iLowest(_Symbol,  InpTF, MODE_LOW,  InpDonchianPeriod, b + 1);
      if(hiIdx < 0 || loIdx < 0) return;
      double chHigh = iHigh(_Symbol, InpTF, hiIdx);
      double chLow  = iLow(_Symbol,  InpTF, loIdx);
      double cb = iClose(_Symbol, InpTF, b), ob = iOpen(_Symbol, InpTF, b);
      double hb = iHigh(_Symbol, InpTF, b),  lb = iLow(_Symbol, InpTF, b);
      double margin = InpBreakMinATR * atr;                         // vuot kenh bao xa
      double range  = hb - lb;
      // Nen qua dai thuong la thanh ly day chuyen (lenh bi ep dong tren so lenh mong): vao theo la duoi gia
      bool   tooLong = InpBreakMaxATR > 0 && range > InpBreakMaxATR * atr;
      double body   = MathAbs(cb - ob);
      // Than nen: nen pha vo phai la nen cung chieu, than chiem it nhat X% bien do (khong phai chi rau dai)
      bool   bodyBuy  = InpBreakMinBody <= 0 || (cb > ob && range > 0 && body >= range * InpBreakMinBody / 100.0);
      bool   bodySell = InpBreakMinBody <= 0 || (cb < ob && range > 0 && body >= range * InpBreakMinBody / 100.0);
      buyBase  = cb > chHigh + margin && bodyBuy  && c1 > trend && (b == 1 || c1 > chHigh);
      sellBase = cb < chLow  - margin && bodySell && c1 < trend && (b == 1 || c1 < chLow);
      if(tooLong && (buyBase || sellBase)) { g_status = "Nen pha vo qua dai, bo qua"; return; }
   }
   else
   {
      buyBase  = c1 > trend && fast > trend && l1 <= fast && c1 > fast;
      sellBase = c1 < trend && fast < trend && h1 >= fast && c1 < fast;
   }
   bool buySignal  = InpAllowBuy && buyBase
                     && (!InpUseHTF || htfClose > htfEma) && adxOk
                     && (!InpUseCandle || BullCandle());
   bool sellSignal = InpAllowSell && sellBase
                     && (!InpUseHTF || htfClose < htfEma) && adxOk
                     && (!InpUseCandle || BearCandle());
   if(InpUseFunding && (buySignal || sellSignal))
   {
      // Funding qua duong: phe Long dang dong va tra phi cao, de bi thanh ly dong loat -> khong mua duoi.
      // Funding qua am: nguoc lai voi Sell.
      double f = FundingNow();
      if(f != EMPTY_VALUE && ((buySignal && f > InpFundingMax) || (sellSignal && f < -InpFundingMax)))
      {
         g_fundBlocked++;
         g_status = StringFormat("Bo tin hieu vi funding %.3f%%", f);
         return;
      }
   }

   if((buySignal || sellSignal) && !MarketFiltersOk(buySignal)) return;

   g_status = "Cho tin hieu";
   if(!buySignal && !sellSignal) return;

   double slDist   = atr * InpATRMult;
   double minStops = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
   if(slDist < minStops * 1.1) slDist = minStops * 1.1;

   double lots = CalcLots(slDist);
   if(lots <= 0) return;

   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick)) return;

   bool ok;
   if(buySignal)
   {
      double price = tick.ask;
      ok = PrepSend() && trade.Buy(lots, _Symbol, price,
                     NormalizeDouble(price - slDist, _Digits),
                     InpRR > 0 ? NormalizeDouble(price + slDist * InpRR, _Digits) : 0.0, "BTC bot BUY");
   }
   else
   {
      double price = tick.bid;
      ok = PrepSend() && trade.Sell(lots, _Symbol, price,
                      NormalizeDouble(price + slDist, _Digits),
                      InpRR > 0 ? NormalizeDouble(price - slDist * InpRR, _Digits) : 0.0, "BTC bot SELL");
   }
   TradeDone(ok, "Vao lenh", buySignal ? "BUY" : "SELL");
}

//--- Thong bao vao / thoat lenh ------------------------------------
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
{
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD || !g_stateReady) return;
   if(!HistoryDealSelect(trans.deal)) return;
   if(HistoryDealGetInteger(trans.deal, DEAL_MAGIC) != (long)InpMagic ||
      HistoryDealGetString(trans.deal, DEAL_SYMBOL) != _Symbol) return;
   g_plDirty = true;                                // tinh lai lai/lo cua bot o tick sau

   long   entry = HistoryDealGetInteger(trans.deal, DEAL_ENTRY);
   double vol   = HistoryDealGetDouble(trans.deal, DEAL_VOLUME);
   double price = HistoryDealGetDouble(trans.deal, DEAL_PRICE);
   string cur   = AccountInfoString(ACCOUNT_CURRENCY);

   if(entry == DEAL_ENTRY_IN)
   {
      bool isBuy = HistoryDealGetInteger(trans.deal, DEAL_TYPE) == DEAL_TYPE_BUY;
      MarkTracked((ulong)HistoryDealGetInteger(trans.deal, DEAL_POSITION_ID));
      Notify(StringFormat("[%s] VAO %s %.2f lot @ %s", _Symbol, isBuy ? "BUY" : "SELL",
                          vol, DoubleToString(price, _Digits)));
   }
   else if(entry == DEAL_ENTRY_OUT || entry == DEAL_ENTRY_OUT_BY)
   {
      double pnl = DealNet(trans.deal);
      Notify(StringFormat("[%s] THOAT %.2f lot @ %s | Lai/lo: %.2f %s | Equity: %.2f",
                          _Symbol, vol, DoubleToString(price, _Digits), pnl, cur,
                          AccountInfoDouble(ACCOUNT_EQUITY)));
      // Khong chot o day: thu tu su kien khong dam bao. Doi soat o ReconcileClosed().
      g_reconcile = true;
   }
}
//+------------------------------------------------------------------+

//--- Ghi ket qua backtest ra file chung de so sanh nhieu cau hinh -----
double OnTester()
{
   double trades   = TesterStatistics(STAT_TRADES);
   double wins     = TesterStatistics(STAT_PROFIT_TRADES);
   double losses   = TesterStatistics(STAT_LOSS_TRADES);
   double gProfit  = TesterStatistics(STAT_GROSS_PROFIT);
   double gLoss    = TesterStatistics(STAT_GROSS_LOSS);
   double pf       = TesterStatistics(STAT_PROFIT_FACTOR);

   // Lai/lo theo tung nam (theo thoi diem cua tung deal, gom ca phi vao lenh) de xem co lai deu hay chi nho 1 dot
   double yearPL[]; int years[];
   datetime firstDeal = 0;   // lenh dau tien: neu muon hon ngay bat dau nhieu thi MT5 thieu du lieu
   if(HistorySelect(0, TimeCurrent()))
      for(int i = 0; i < HistoryDealsTotal(); i++)
      {
         ulong d = HistoryDealGetTicket(i);
         if(d == 0) continue;
         // Moi deal mua/ban (ca deal vao lenh, de tinh phi vao lenh), bo qua nap tien / credit
         long dt = HistoryDealGetInteger(d, DEAL_TYPE);
         if(dt != DEAL_TYPE_BUY && dt != DEAL_TYPE_SELL) continue;
         if(firstDeal == 0) firstDeal = (datetime)HistoryDealGetInteger(d, DEAL_TIME);
         MqlDateTime t; TimeToStruct((datetime)HistoryDealGetInteger(d, DEAL_TIME), t);
         int k = -1;
         for(int j = 0; j < ArraySize(years); j++) if(years[j] == t.year) { k = j; break; }
         if(k < 0) { k = ArraySize(years); ArrayResize(years, k + 1); ArrayResize(yearPL, k + 1); years[k] = t.year; yearPL[k] = 0; }
         yearPL[k] += DealNet(d);
      }
   // Phep thu chiu dung: tru them chi phi truot gia + spread moi chieu = % gia, cong theo tung vi the
   double stressPL[2], stressGP[2], stressGL[2];
   double stressPct[2] = {0.05, 0.10};
   ArrayInitialize(stressPL, 0); ArrayInitialize(stressGP, 0); ArrayInitialize(stressGL, 0);
   ulong  posIds[]; double posNet[]; double posCost[];
   double contract = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_CONTRACT_SIZE);
   if(HistorySelect(0, TimeCurrent()))
      for(int i = 0; i < HistoryDealsTotal(); i++)
      {
         ulong d = HistoryDealGetTicket(i);
         if(d == 0) continue;
         long ty = HistoryDealGetInteger(d, DEAL_TYPE);
         if(ty != DEAL_TYPE_BUY && ty != DEAL_TYPE_SELL) continue;
         ulong pid = (ulong)HistoryDealGetInteger(d, DEAL_POSITION_ID);
         int k = -1;
         for(int j = ArraySize(posIds) - 1; j >= 0; j--) if(posIds[j] == pid) { k = j; break; }
         if(k < 0) { k = ArraySize(posIds); ArrayResize(posIds, k + 1); ArrayResize(posNet, k + 1); ArrayResize(posCost, k + 1);
                     posIds[k] = pid; posNet[k] = 0; posCost[k] = 0; }
         posNet[k]  += DealNet(d);
         posCost[k] += HistoryDealGetDouble(d, DEAL_VOLUME) * contract * HistoryDealGetDouble(d, DEAL_PRICE) / 100.0;  // = 1% gia
      }
   // Thoi gian giu lenh TB (gio) va tong swap
   double holdSum = 0, swapSum = 0; int holdN = 0;
   if(HistorySelect(0, TimeCurrent()))
      for(int j = 0; j < ArraySize(posIds); j++)
      {
         datetime tin = 0, tout = 0;
         if(!HistorySelectByPosition(posIds[j])) continue;
         for(int i = 0; i < HistoryDealsTotal(); i++)
         {
            ulong d = HistoryDealGetTicket(i);
            long en = HistoryDealGetInteger(d, DEAL_ENTRY);
            datetime tt = (datetime)HistoryDealGetInteger(d, DEAL_TIME);
            if(en == DEAL_ENTRY_IN && tin == 0) tin = tt;
            if(en == DEAL_ENTRY_OUT || en == DEAL_ENTRY_OUT_BY) tout = tt;
            swapSum += HistoryDealGetDouble(d, DEAL_SWAP);
         }
         if(tin > 0 && tout > tin) { holdSum += (double)(tout - tin) / 3600.0; holdN++; }
      }
   for(int s2 = 0; s2 < 2; s2++)
      for(int j = 0; j < ArraySize(posIds); j++)
      {
         double net = posNet[j] - posCost[j] * stressPct[s2];
         stressPL[s2] += net;
         if(net > 0) stressGP[s2] += net; else stressGL[s2] -= net;
      }

   // Monte Carlo (bootstrap): rut ngau nhien co hoan lai tu lai/lo cac vi the, 1000 lan, de xem
   // sut giam co the te toi dau neu thu tu lenh khac di. Mau duoi ~200 lenh thi chi nen xem la tham khao.
   double dep = TesterStatistics(STAT_INITIAL_DEPOSIT);
   int    nPos = ArraySize(posNet), sims = 1000, ruin = 0, blk = 5;
   double stopDD = InpMaxDrawdownPct > 0 ? InpMaxDrawdownPct : 15.0;   // nguong bot tu dung han
   double mcDD[];
   ArrayResize(mcDD, sims);
   MathSrand(12345);                                   // co dinh de chay lai ra cung so
   for(int m = 0; m < sims; m++)
   {
      double eq = dep, pk = dep, dd = 0;
      // Rut theo khoi 5 lenh lien tiep (giu cac chuoi thua theo cum khi thi truong di ngang)
      for(int j = 0; j < nPos; j += blk)
      {
         int st = (int)((double)MathRand() / 32768.0 * nPos);
         for(int q = 0; q < blk && j + q < nPos; q++)
         {
            eq += posNet[(st + q) % nPos];
            if(eq > pk) pk = eq;
            if(pk > 0) dd = MathMax(dd, (pk - eq) / pk * 100.0);
         }
      }
      mcDD[m] = dd;
      if(dd >= stopDD) ruin++;
   }
   ArraySort(mcDD);
   double mcMed = nPos > 0 ? mcDD[sims / 2] : 0;
   double mc95  = nPos > 0 ? mcDD[(int)(sims * 0.95)] : 0;

   string byYear = "";
   for(int j = 0; j < ArraySize(years); j++)
      byYear += (j > 0 ? " " : "") + StringFormat("%d=%+.0f", years[j], yearPL[j]);

   string file = "BTC_EMA_results.csv";
   int h = FileOpen(file, FILE_READ | FILE_WRITE | FILE_CSV | FILE_ANSI | FILE_COMMON, ',');
   if(h != INVALID_HANDLE)
   {
      if(FileSize(h) == 0)
         FileWrite(h, "Lan", "LoiNhuan", "ProfitFactor", "SoLenh", "TyLeThang%", "LaiTB", "LoTB",
                   "SutGiamMax%", "RecoveryFactor", "Sharpe", "Buy", "Sell", "BoQuaLot", "LenhDau", "LaiTheoNam",
                   "LoiNhuan_Truot0.05%", "PF_Truot0.05%", "LoiNhuan_Truot0.1%", "PF_Truot0.1%",
                   "MC_SutGiamTB%", "MC_SutGiam95%", "MC_XacSuatDungHan%", "ChanFunding", "ChanFearGreed", "ChanChuY", "ChanNasdaq",
                   "LamTronLot", "GiuLenhTB_gio", "TongSwap");
      FileSeek(h, 0, SEEK_END);
      FileWrite(h,
                InpTestLabel == "" ? "khong-ten" : InpTestLabel,
                DoubleToString(TesterStatistics(STAT_PROFIT), 2),
                DoubleToString(pf, 2),
                (int)trades,
                DoubleToString(trades > 0 ? wins / trades * 100.0 : 0, 1),
                DoubleToString(wins > 0 ? gProfit / wins : 0, 2),
                DoubleToString(losses > 0 ? gLoss / losses : 0, 2),
                DoubleToString(TesterStatistics(STAT_EQUITY_DDREL_PERCENT), 2),
                DoubleToString(TesterStatistics(STAT_RECOVERY_FACTOR), 2),
                DoubleToString(TesterStatistics(STAT_SHARPE_RATIO), 2),
                (int)TesterStatistics(STAT_LONG_TRADES),
                (int)TesterStatistics(STAT_SHORT_TRADES),
                g_minLotSkips,
                firstDeal > 0 ? TimeToString(firstDeal, TIME_DATE) : "-",
                byYear,
                DoubleToString(stressPL[0], 2), DoubleToString(stressGL[0] > 0 ? stressGP[0] / stressGL[0] : 0, 2),
                DoubleToString(stressPL[1], 2), DoubleToString(stressGL[1] > 0 ? stressGP[1] / stressGL[1] : 0, 2),
                DoubleToString(mcMed, 2), DoubleToString(mc95, 2), DoubleToString(100.0 * ruin / sims, 1), g_fundBlocked,
                g_fngBlocked, g_attBlocked, g_mktBlocked,
                g_roundUps, DoubleToString(holdN > 0 ? holdSum / holdN : 0, 1), DoubleToString(swapSum, 2));
      FileClose(h);
   }
   else
      PrintFormat("Khong ghi duoc file ket qua: %d", GetLastError());
   return pf;
}
//+------------------------------------------------------------------+
