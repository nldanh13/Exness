//+------------------------------------------------------------------+
//| BTC_EMA_Pullback_v2.mq5                                          |
//| EA theo xu huong: loc EMA200 (H1 + H4), ADX, vao khi hoi EMA20   |
//| SL theo ATR, TP theo RR, chot mot phan, hoa von, trailing ATR    |
//| Bo loc gio, gioi han lo ngay, gioi han sut giam tu dinh          |
//| Thong bao push MT5 / Telegram, bang thong tin tren bieu do       |
//| CHI DUNG DE THU NGHIEM - BACKTEST VA CHAY DEMO TRUOC             |
//+------------------------------------------------------------------+
#property version   "2.30"
#property description "EMA200 trend + EMA20 pullback, ATR stop, partial close, trailing, filters, alerts"

#include <Trade\Trade.mqh>

enum ENUM_STRATEGY
{
   STRAT_EMA_PULLBACK = 0,   // Hoi ve EMA20 theo xu huong
   STRAT_DONCHIAN     = 1    // Pha vo kenh Donchian (breakout)
};

input group "=== Tin hieu ==="
input ENUM_STRATEGY   InpStrategy        = STRAT_EMA_PULLBACK; // Chien luoc vao lenh
input int             InpDonchianPeriod  = 20;        // So nen cua kenh Donchian (breakout)
input ENUM_TIMEFRAMES InpTF              = PERIOD_H1; // Khung tin hieu
input int             InpFastEMA         = 20;        // EMA nhanh (vung hoi)
input int             InpTrendEMA        = 200;       // EMA xu huong
input int             InpATRPeriod       = 14;        // Chu ky ATR

input group "=== Bo loc thi truong ==="
input bool            InpUseHTF          = true;      // Xac nhan xu huong khung lon
input ENUM_TIMEFRAMES InpHTF             = PERIOD_H4; // Khung lon
input int             InpHTFEMA          = 200;       // EMA khung lon
input bool            InpUseADX          = true;      // Loc thi truong di ngang bang ADX
input int             InpADXPeriod       = 14;        // Chu ky ADX
input double          InpADXMin          = 20.0;      // ADX toi thieu de vao lenh
input bool            InpUseCandle       = false;     // Bat buoc mau nen (pin bar / engulfing)

input group "=== SL / TP / Khoi luong ==="
input double          InpATRMult         = 1.5;       // SL = ATR x he so
input double          InpRR              = 2.0;       // TP = SL x RR (0 = khong dat TP, de trailing thoat)
input double          InpRiskPercent     = 1.0;       // % von rui ro moi lenh

input group "=== Quan ly lenh ==="
input bool            InpUsePartial      = true;      // Chot loi mot phan
input double          InpPartialR        = 1.0;       // Chot khi lai dat (R)
input double          InpPartialPct      = 50.0;      // % khoi luong chot
input bool            InpUseBreakeven    = true;      // Doi SL ve hoa von
input double          InpBreakevenR      = 1.0;       // Khi lai dat (R)
input int             InpBEBufferPoints  = 100;       // Cong them vao muc hoa von (point), ngoai phi + swap
input bool            InpUseTrailing     = true;      // Trailing stop theo ATR
input double          InpTrailStartR     = 1.0;       // Bat dau trailing khi lai dat (R)
input double          InpTrailATRMult    = 2.0;       // Khoang trailing = ATR x he so

input group "=== Bo loc thoi gian (gio server) ==="
input bool            InpSkipWeekend     = true;      // Khong vao lenh moi Thu 7, Chu nhat
input int             InpBlock1Start     = 12;        // Khung nghi 1: tu gio (-1 = tat)
input int             InpBlock1End       = 14;        // Khung nghi 1: den gio
input int             InpBlock2Start     = 18;        // Khung nghi 2: tu gio (-1 = tat)
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

// Xac nhan server da thuc hien lenh (khong chi dua vao gia tri tra ve cua CTrade)
bool TradeDone(const bool sent, const string what)
{
   uint rc = trade.ResultRetcode();
   bool ok = sent && (rc == TRADE_RETCODE_DONE || rc == TRADE_RETCODE_DONE_PARTIAL || rc == TRADE_RETCODE_PLACED);
   if(!ok)
   {
      string msg = StringFormat("[%s] %s that bai: %u %s", _Symbol, what, rc, trade.ResultRetcodeDescription());
      // Loi sua SL thuong lap lai moi tick, chi in log; loi vao/dong lenh thi bao ve dien thoai
      if(StringFind(what, "Sua SL") == 0) Print(msg); else Notify(msg);
   }
   return ok;
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
      TradeDone(trade.PositionClose(ticket), "Dong lenh #" + (string)ticket);
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

double BotEquity() { return GVGet("base") + g_closedPL + FloatingPL(); }

// Dat moc von cua bot (lan dau chay, hoac khi InpResetHalt = true)
void ResetBaseline()
{
   GlobalVariableSet(GVName("epoch"), (double)TimeCurrent());
   GlobalVariableSet(GVName("base"),  AccountInfoDouble(ACCOUNT_BALANCE));
   GlobalVariableDel(GVName("halt"));
   GlobalVariableDel(GVName("dayId"));
   g_plDirty = true;
   RefreshClosedPL();
   GlobalVariableSet(GVName("peak"), BotEquity());
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
         dayStartEquity = BotEquity();
         GlobalVariableSet(GVName("dayId"), dayId);
         GlobalVariableSet(GVName("dayEq"), dayStartEquity);
      }
   }
}

double DayPL() { return BotEquity() - dayStartEquity; }

bool DailyLossHit()
{
   if(InpMaxDailyLossPct <= 0 || dayStartEquity <= 0) return false;
   return DayPL() <= -dayStartEquity * InpMaxDailyLossPct / 100.0;
}

// Kiem tra lo ngay moi tick: chan lenh moi va (tuy chon) dong lenh dang mo
void CheckDailyLoss()
{
   if(!DailyLossHit()) return;
   if(!dailyNotified)
   {
      Notify(StringFormat("[%s] Cham gioi han lo ngay %.1f%% (%.2f). Ngung vao lenh den mai%s.",
                          _Symbol, InpMaxDailyLossPct, DayPL(), InpCloseOnDailyLoss ? ", da dong lenh dang mo" : ""));
      dailyNotified = true;
   }
   if(InpCloseOnDailyLoss && HasOwnPosition()) CloseAll();
}

bool IsHalted() { return GVGet("halt") > 0; }

void CheckDrawdown()
{
   double eq   = BotEquity();
   double peak = GVGet("peak");
   if(eq > peak) { GlobalVariableSet(GVName("peak"), eq); peak = eq; }
   if(InpMaxDrawdownPct <= 0 || IsHalted() || peak <= 0) return;
   if(eq <= peak * (1.0 - InpMaxDrawdownPct / 100.0))
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
double CalcLots(const double slDistance)
{
   double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE_LOSS);
   if(tickValue <= 0) tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   if(tickSize <= 0 || tickValue <= 0 || slDistance <= 0) return 0;

   double riskMoney  = AccountInfoDouble(ACCOUNT_EQUITY) * InpRiskPercent / 100.0;
   double lossPerLot = slDistance / tickSize * tickValue;
   double lots       = NormalizeVolume(riskMoney / lossPerLot);
   double minL = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxL = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   if(lots < minL)
   {
      g_status = "Von qua nho cho SL nay, bo qua lenh";
      PrintFormat("Can %.4f lot < toi thieu %.2f. Bo qua de khong vuot rui ro.", riskMoney / lossPerLot, minL);
      return 0;
   }
   if(lots > maxL) lots = maxL;
   return lots;
}

//--- Quan ly lenh dang mo ------------------------------------------
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

      double open = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl   = PositionGetDouble(POSITION_SL);
      double tp   = PositionGetDouble(POSITION_TP);
      double vol  = PositionGetDouble(POSITION_VOLUME);
      bool   isBuy = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);

      // Luu khoang rui ro ban dau (1R) ngay lan dau thay lenh
      string rKey = GVName("R_" + (string)ticket);
      string pKey = GVName("P_" + (string)ticket);
      if(!GlobalVariableCheck(rKey))
      {
         if(sl <= 0) continue;
         GlobalVariableSet(rKey, MathAbs(open - sl));
      }
      double risk = GlobalVariableGet(rKey);
      if(risk <= 0) continue;

      // Muc hoa von thuc: gia vao + (phi 2 chieu + swap am) quy ra gia + buffer
      string cKey = GVName("C_" + (string)ticket);
      if(!GlobalVariableCheck(cKey))
      {
         double comm = 0;
         if(HistorySelectByPosition(ticket))
            for(int k = 0; k < HistoryDealsTotal(); k++)
            {
               ulong d = HistoryDealGetTicket(k);
               if(d > 0 && HistoryDealGetInteger(d, DEAL_ENTRY) == DEAL_ENTRY_IN)
                  comm += HistoryDealGetDouble(d, DEAL_COMMISSION) + HistoryDealGetDouble(d, DEAL_FEE);
            }
         GlobalVariableSet(cKey, MathAbs(comm) / MathMax(vol, 1e-8));   // phi mot chieu tren 1 lot
      }
      double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
      double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE_LOSS);
      double costMoney = GlobalVariableGet(cKey) * vol * 2.0 + MathMax(0.0, -PositionGetDouble(POSITION_SWAP));
      double costPrice = (tickSize > 0 && tickValue > 0) ? costMoney / (tickValue * vol) * tickSize : 0;
      double beOffset  = costPrice + InpBEBufferPoints * _Point;
      double beLevel   = isBuy ? open + beOffset : open - beOffset;

      double price = isBuy ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double rNow  = (isBuy ? price - open : open - price) / risk;

      // 1) Chot loi mot phan
      if(InpUsePartial && !GlobalVariableCheck(pKey) && rNow >= InpPartialR)
      {
         double closeVol = NormalizeVolume(vol * InpPartialPct / 100.0);
         if(closeVol >= minL && vol - closeVol >= minL - 1e-9)
         {
            if(TradeDone(trade.PositionClosePartial(ticket, closeVol), "Chot mot phan #" + (string)ticket)) GlobalVariableSet(pKey, 1);
         }
         else
            GlobalVariableSet(pKey, 1);                // lot qua nho de chia, bo qua
         continue;                                      // xu ly SL o tick sau
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
         TradeDone(trade.PositionModify(ticket, newSL, tp), "Sua SL #" + (string)ticket);
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
   double dd    = peak > 0 ? (1.0 - eq / peak) * 100.0 : 0;
   string cur   = AccountInfoString(ACCOUNT_CURRENCY);

   Comment(StringFormat(
      "BTC bot v2.2 (%s)  |  %s\n"
      "Trang thai: %s\n"
      "Von cua bot: %.2f %s\n"
      "Lai/lo hom nay: %.2f %s (%.2f%%)\n"
      "Lenh hom nay: %d\n"
      "Sut giam tu dinh: %.2f%% / gioi han %.1f%%\n"
      "Spread: %d point",
      InpStrategy == STRAT_DONCHIAN ? "Donchian" : "EMA pullback", _Symbol, IsHalted() ? "DUNG HAN (sut giam)" : g_status,
      eq, cur, dayPL, cur, dayStartEquity > 0 ? dayPL / dayStartEquity * 100.0 : 0,
      TradesToday(), dd, InpMaxDrawdownPct,
      (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD)));
}

//+------------------------------------------------------------------+
int OnInit()
{
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

   if(InpResetHalt || !GlobalVariableCheck(GVName("base")))
   {
      ResetBaseline();
      if(InpResetHalt) Print("Da mo khoa bot va dat lai moc von. Nho doi InpResetHalt ve false.");
   }
   lastLossTime = (datetime)GVGet("lastLoss", 0);
   g_plDirty = true;
   RefreshClosedPL();
   UpdateDay();
   Notify(StringFormat("[%s] Bot v2 khoi dong. Equity %.2f %s", _Symbol,
                       AccountInfoDouble(ACCOUNT_EQUITY), AccountInfoString(ACCOUNT_CURRENCY)));
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   IndicatorRelease(hFast);
   IndicatorRelease(hTrend);
   IndicatorRelease(hHTF);
   IndicatorRelease(hATR);
   IndicatorRelease(hADX);
   Comment("");
}

//+------------------------------------------------------------------+
void OnTick()
{
   RefreshClosedPL();
   UpdateDay();
   CheckDrawdown();
   // Da dung han ma van con lenh (vd. dong that bai lan truoc) thi thu dong lai moi tick
   if(IsHalted() && InpCloseOnHalt && HasOwnPosition()) CloseAll();
   CheckDailyLoss();
   ManagePositions();
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
      // Pha vo: nen vua dong vuot dinh/day cao nhat/thap nhat cua N nen truoc do
      int hiIdx = iHighest(_Symbol, InpTF, MODE_HIGH, InpDonchianPeriod, 2);
      int loIdx = iLowest(_Symbol,  InpTF, MODE_LOW,  InpDonchianPeriod, 2);
      if(hiIdx < 0 || loIdx < 0) return;
      double chHigh = iHigh(_Symbol, InpTF, hiIdx);
      double chLow  = iLow(_Symbol,  InpTF, loIdx);
      buyBase  = c1 > chHigh && c1 > trend;
      sellBase = c1 < chLow  && c1 < trend;
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
      ok = trade.Buy(lots, _Symbol, price,
                     NormalizeDouble(price - slDist, _Digits),
                     InpRR > 0 ? NormalizeDouble(price + slDist * InpRR, _Digits) : 0.0, "BTC bot BUY");
   }
   else
   {
      double price = tick.bid;
      ok = trade.Sell(lots, _Symbol, price,
                      NormalizeDouble(price + slDist, _Digits),
                      InpRR > 0 ? NormalizeDouble(price - slDist * InpRR, _Digits) : 0.0, "BTC bot SELL");
   }
   TradeDone(ok, buySignal ? "Vao lenh BUY" : "Vao lenh SELL");
}

//--- Thong bao vao / thoat lenh ------------------------------------
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
{
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD) return;
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
      Notify(StringFormat("[%s] VAO %s %.2f lot @ %s", _Symbol, isBuy ? "BUY" : "SELL",
                          vol, DoubleToString(price, _Digits)));
   }
   else if(entry == DEAL_ENTRY_OUT || entry == DEAL_ENTRY_OUT_BY)
   {
      double pnl = HistoryDealGetDouble(trans.deal, DEAL_PROFIT) +
                   HistoryDealGetDouble(trans.deal, DEAL_SWAP) +
                   HistoryDealGetDouble(trans.deal, DEAL_COMMISSION);
      Notify(StringFormat("[%s] THOAT %.2f lot @ %s | Lai/lo: %.2f %s | Equity: %.2f",
                          _Symbol, vol, DoubleToString(price, _Digits), pnl, cur,
                          AccountInfoDouble(ACCOUNT_EQUITY)));
      ulong posId = (ulong)HistoryDealGetInteger(trans.deal, DEAL_POSITION_ID);
      if(!PositionSelectByTicket(posId))            // vi the da dong het
      {
         // Tong lai/lo ca vi the (gom cac lan chot mot phan, swap, phi)
         double total = 0, inVol = 0;
         if(HistorySelectByPosition(posId))
            for(int i = 0; i < HistoryDealsTotal(); i++)
            {
               ulong d = HistoryDealGetTicket(i);
               if(d == 0) continue;
               total += HistoryDealGetDouble(d, DEAL_PROFIT) + HistoryDealGetDouble(d, DEAL_SWAP) +
                        HistoryDealGetDouble(d, DEAL_COMMISSION);
               if(HistoryDealGetInteger(d, DEAL_ENTRY) == DEAL_ENTRY_IN) inVol += HistoryDealGetDouble(d, DEAL_VOLUME);
            }
         string rKey      = GVName("R_" + (string)posId);
         double rDist     = GlobalVariableCheck(rKey) ? GlobalVariableGet(rKey) : 0;
         double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
         double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE_LOSS);
         double riskMoney = (rDist > 0 && tickSize > 0) ? rDist / tickSize * tickValue * inVol : 0;
         // Chi tinh la lenh thua khi lo hon 10% cua 1R; lenh hoa von am vai cent khong kich hoat nghi
         if(total < -MathMax(riskMoney * 0.1, 0.01))
         {
            lastLossTime = TimeCurrent();
            GlobalVariableSet(GVName("lastLoss"), (double)lastLossTime);   // giu qua khi khoi dong lai
         }

         GlobalVariableDel(GVName("R_" + (string)posId));
         GlobalVariableDel(GVName("P_" + (string)posId));
         GlobalVariableDel(GVName("C_" + (string)posId));
      }
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

   string file = "BTC_EMA_results.csv";
   int h = FileOpen(file, FILE_READ | FILE_WRITE | FILE_CSV | FILE_ANSI | FILE_COMMON, ',');
   if(h != INVALID_HANDLE)
   {
      if(FileSize(h) == 0)
         FileWrite(h, "Lan", "LoiNhuan", "ProfitFactor", "SoLenh", "TyLeThang%", "LaiTB", "LoTB",
                   "SutGiamMax%", "RecoveryFactor", "Sharpe", "Buy", "Sell");
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
                (int)TesterStatistics(STAT_SHORT_TRADES));
      FileClose(h);
   }
   else
      PrintFormat("Khong ghi duoc file ket qua: %d", GetLastError());
   return pf;
}
//+------------------------------------------------------------------+
