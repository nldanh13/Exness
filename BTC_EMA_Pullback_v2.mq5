//+------------------------------------------------------------------+
//| BTC_EMA_Pullback_v2.mq5 (TrendBot)                               |
//| EA theo xu huong: Donchian breakout (mac dinh) hoac EMA pullback |
//| File nay chi chua tham so va thu tu chay; logic nam trong        |
//| thu muc TrendBot/ (moi file mot viec, xem dau moi file).         |
//| CHI DUNG DE THU NGHIEM - BACKTEST VA CHAY DEMO TRUOC             |
//+------------------------------------------------------------------+
#define  BOT_VERSION "4.1"
#property version   "4.10"
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
input string          InpFundingSymbol   = "";        // Ma hop dong Binance cho funding (de trong = tu doan: BTC -> BTCUSDT, ETH -> ETHUSDT)
input bool            InpUseFearGreed    = false;     // Loc Fear & Greed Index (tam ly dam dong, alternative.me)
input int             InpFngGreedMax     = 76;        // Bo Buy khi chi so hom qua >= muc nay (tham lam cuc do)
input int             InpFngFearMin      = 24;        // Bo Sell khi chi so hom qua <= muc nay (so hai cuc do)
input bool            InpUseAttention    = false;     // Chi vao lenh khi luot xem Wikipedia TB 7 ngay > TB 30 ngay (su chu y tang)
input string          InpWikiArticle     = "";        // Bai Wikipedia tieng Anh (de trong = tu doan: BTC -> Bitcoin, ETH -> Ethereum)
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
input double          InpMaxRiskRoundUp  = 0.0;       // Lot tinh ra < lot toi thieu: van vao lot toi thieu neu rui ro that <= X% (0 = tat, bo qua lenh)
input string          InpCorrSymbols     = "BTCUSDm,ETHUSDm"; // Cac ma di cung nhau (BTC/ETH): dang co lenh ma khac thi giam rui ro
input double          InpCorrRiskScale   = 0.5;       // He so rui ro khi ma cung nhom dang co lenh (1 = tat)
input double          InpMaxGroupRiskPct = 1.5;       // Tong rui ro toi da % cua ca nhom (lenh dang mo + lenh moi), 0 = tat

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

//--- Cac module (thu muc TrendBot/ canh file nay) ---------------------
#include "TrendBot/Core.mqh"
#include "TrendBot/Notify.mqh"
#include "TrendBot/Protection.mqh"
#include "TrendBot/Filters.mqh"
#include "TrendBot/Signals.mqh"
#include "TrendBot/Risk.mqh"
#include "TrendBot/Manage.mqh"
#include "TrendBot/Panel.mqh"
#include "TrendBot/Report.mqh"

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
   if(!BaseSignals(atr, trend, fast, c1, h1, l1, buyBase, sellBase)) return;
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

   GroupLock();                         // tu day toi khi gui lenh xong: giu khoa chung voi bot ma cung nhom
   double lots = CalcLots(slDist);
   MqlTick tick;
   if(lots <= 0 || !SymbolInfoTick(_Symbol, tick)) { GroupUnlock(); return; }
   GroupReserve(g_lastRisk);

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
   if(!ok) GroupClear();
   GroupUnlock();
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
