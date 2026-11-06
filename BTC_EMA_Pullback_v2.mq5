//+------------------------------------------------------------------+
//| BTC_EMA_Pullback_v2.mq5 (TrendBot)                               |
//| EA theo xu huong: Donchian breakout (mac dinh) hoac EMA pullback |
//| File nay chi chua tham so va thu tu chay; logic nam trong        |
//| thu muc TrendBot/ (moi file mot viec, xem dau moi file).         |
//| CHI DUNG DE THU NGHIEM - BACKTEST VA CHAY DEMO TRUOC             |
//+------------------------------------------------------------------+
#define  BOT_VERSION "4.7"
#property version   "4.70"
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
input int             InpManageEverySec  = 1;         // Kiem tra lenh dang mo / gioi han lo toi da moi X giay (0 = moi tick). Nhanh hon khi backtest
input int             InpPreset          = 0;         // Backtest: so thu tu cau hinh trong file TrendBot_presets.csv (0 = dung tham so tren)


//--- Ban sao co the doi cua cac tham so (code dung P_..., khong dung Inp... truc tiep) ----
// De backtest song song: moi lan chay trong che do Optimization chon 1 dong cau hinh (InpPreset)
// trong file TrendBot_presets.csv (Common\Files) va ghi de cac P_ tuong ung.
// THEM INPUT MOI: them ca dong khai bao P_, dong trong LoadParams va dong trong SetParam.
ENUM_STRATEGY   P_Strategy;
int             P_DonchianPeriod;
double          P_BreakMinATR;
double          P_BreakMinBody;
bool            P_BreakConfirm;
double          P_BreakMaxATR;
ENUM_TIMEFRAMES P_TF;
int             P_FastEMA;
int             P_TrendEMA;
int             P_ATRPeriod;
bool            P_UseFunding;
double          P_FundingMax;
string          P_FundingSymbol;
bool            P_UseFearGreed;
int             P_FngGreedMax;
int             P_FngFearMin;
bool            P_UseAttention;
string          P_WikiArticle;
bool            P_UseMarketFilter;
string          P_MarketSymbol;
bool            P_AvoidUSNews;
int             P_NewsHours;
bool            P_UseHTF;
ENUM_TIMEFRAMES P_HTF;
int             P_HTFEMA;
bool            P_UseADX;
int             P_ADXPeriod;
double          P_ADXMin;
bool            P_UseCandle;
double          P_ATRMult;
double          P_RR;
double          P_RiskPercent;
double          P_MaxRiskRoundUp;
string          P_CorrSymbols;
double          P_CorrRiskScale;
double          P_MaxGroupRiskPct;
bool            P_UsePartial;
double          P_PartialR;
double          P_PartialPct;
bool            P_UseBreakeven;
double          P_BreakevenR;
double          P_BEBufferR;
bool            P_UseTrailing;
double          P_TrailStartR;
double          P_TrailATRMult;
bool            P_SkipWeekend;
int             P_Block1Start;
int             P_Block1End;
int             P_Block2Start;
int             P_Block2End;
int             P_MaxSpreadPoints;
bool            P_AllowBuy;
bool            P_AllowSell;
int             P_MaxTradesPerDay;
int             P_CooldownBars;
double          P_MaxDailyLossPct;
bool            P_CloseOnDailyLoss;
double          P_MaxDrawdownPct;
bool            P_CloseOnHalt;
bool            P_ResetHalt;
double          P_Capital;
bool            P_PushNotify;
bool            P_Telegram;
string          P_TgToken;
string          P_TgChatId;
bool            P_ShowPanel;
ulong           P_Magic;
string          P_TestLabel;
int             P_ManageEverySec;
int             P_Preset;
void LoadParams()
{
   P_Strategy = InpStrategy;
   P_DonchianPeriod = InpDonchianPeriod;
   P_BreakMinATR = InpBreakMinATR;
   P_BreakMinBody = InpBreakMinBody;
   P_BreakConfirm = InpBreakConfirm;
   P_BreakMaxATR = InpBreakMaxATR;
   P_TF = InpTF;
   P_FastEMA = InpFastEMA;
   P_TrendEMA = InpTrendEMA;
   P_ATRPeriod = InpATRPeriod;
   P_UseFunding = InpUseFunding;
   P_FundingMax = InpFundingMax;
   P_FundingSymbol = InpFundingSymbol;
   P_UseFearGreed = InpUseFearGreed;
   P_FngGreedMax = InpFngGreedMax;
   P_FngFearMin = InpFngFearMin;
   P_UseAttention = InpUseAttention;
   P_WikiArticle = InpWikiArticle;
   P_UseMarketFilter = InpUseMarketFilter;
   P_MarketSymbol = InpMarketSymbol;
   P_AvoidUSNews = InpAvoidUSNews;
   P_NewsHours = InpNewsHours;
   P_UseHTF = InpUseHTF;
   P_HTF = InpHTF;
   P_HTFEMA = InpHTFEMA;
   P_UseADX = InpUseADX;
   P_ADXPeriod = InpADXPeriod;
   P_ADXMin = InpADXMin;
   P_UseCandle = InpUseCandle;
   P_ATRMult = InpATRMult;
   P_RR = InpRR;
   P_RiskPercent = InpRiskPercent;
   P_MaxRiskRoundUp = InpMaxRiskRoundUp;
   P_CorrSymbols = InpCorrSymbols;
   P_CorrRiskScale = InpCorrRiskScale;
   P_MaxGroupRiskPct = InpMaxGroupRiskPct;
   P_UsePartial = InpUsePartial;
   P_PartialR = InpPartialR;
   P_PartialPct = InpPartialPct;
   P_UseBreakeven = InpUseBreakeven;
   P_BreakevenR = InpBreakevenR;
   P_BEBufferR = InpBEBufferR;
   P_UseTrailing = InpUseTrailing;
   P_TrailStartR = InpTrailStartR;
   P_TrailATRMult = InpTrailATRMult;
   P_SkipWeekend = InpSkipWeekend;
   P_Block1Start = InpBlock1Start;
   P_Block1End = InpBlock1End;
   P_Block2Start = InpBlock2Start;
   P_Block2End = InpBlock2End;
   P_MaxSpreadPoints = InpMaxSpreadPoints;
   P_AllowBuy = InpAllowBuy;
   P_AllowSell = InpAllowSell;
   P_MaxTradesPerDay = InpMaxTradesPerDay;
   P_CooldownBars = InpCooldownBars;
   P_MaxDailyLossPct = InpMaxDailyLossPct;
   P_CloseOnDailyLoss = InpCloseOnDailyLoss;
   P_MaxDrawdownPct = InpMaxDrawdownPct;
   P_CloseOnHalt = InpCloseOnHalt;
   P_ResetHalt = InpResetHalt;
   P_Capital = InpCapital;
   P_PushNotify = InpPushNotify;
   P_Telegram = InpTelegram;
   P_TgToken = InpTgToken;
   P_TgChatId = InpTgChatId;
   P_ShowPanel = InpShowPanel;
   P_Magic = InpMagic;
   P_TestLabel = InpTestLabel;
   P_ManageEverySec = InpManageEverySec;
   P_Preset = InpPreset;
}
bool SetParam(const string k, const string v)
{
   if(k == "InpStrategy") { P_Strategy = (ENUM_STRATEGY)StringToInteger(v); return true; }
   if(k == "InpDonchianPeriod") { P_DonchianPeriod = (int)StringToInteger(v); return true; }
   if(k == "InpBreakMinATR") { P_BreakMinATR = StringToDouble(v); return true; }
   if(k == "InpBreakMinBody") { P_BreakMinBody = StringToDouble(v); return true; }
   if(k == "InpBreakConfirm") { P_BreakConfirm = (v == "true" || v == "1"); return true; }
   if(k == "InpBreakMaxATR") { P_BreakMaxATR = StringToDouble(v); return true; }
   if(k == "InpTF") { P_TF = (ENUM_TIMEFRAMES)StringToInteger(v); return true; }
   if(k == "InpFastEMA") { P_FastEMA = (int)StringToInteger(v); return true; }
   if(k == "InpTrendEMA") { P_TrendEMA = (int)StringToInteger(v); return true; }
   if(k == "InpATRPeriod") { P_ATRPeriod = (int)StringToInteger(v); return true; }
   if(k == "InpUseFunding") { P_UseFunding = (v == "true" || v == "1"); return true; }
   if(k == "InpFundingMax") { P_FundingMax = StringToDouble(v); return true; }
   if(k == "InpFundingSymbol") { P_FundingSymbol = v; return true; }
   if(k == "InpUseFearGreed") { P_UseFearGreed = (v == "true" || v == "1"); return true; }
   if(k == "InpFngGreedMax") { P_FngGreedMax = (int)StringToInteger(v); return true; }
   if(k == "InpFngFearMin") { P_FngFearMin = (int)StringToInteger(v); return true; }
   if(k == "InpUseAttention") { P_UseAttention = (v == "true" || v == "1"); return true; }
   if(k == "InpWikiArticle") { P_WikiArticle = v; return true; }
   if(k == "InpUseMarketFilter") { P_UseMarketFilter = (v == "true" || v == "1"); return true; }
   if(k == "InpMarketSymbol") { P_MarketSymbol = v; return true; }
   if(k == "InpAvoidUSNews") { P_AvoidUSNews = (v == "true" || v == "1"); return true; }
   if(k == "InpNewsHours") { P_NewsHours = (int)StringToInteger(v); return true; }
   if(k == "InpUseHTF") { P_UseHTF = (v == "true" || v == "1"); return true; }
   if(k == "InpHTF") { P_HTF = (ENUM_TIMEFRAMES)StringToInteger(v); return true; }
   if(k == "InpHTFEMA") { P_HTFEMA = (int)StringToInteger(v); return true; }
   if(k == "InpUseADX") { P_UseADX = (v == "true" || v == "1"); return true; }
   if(k == "InpADXPeriod") { P_ADXPeriod = (int)StringToInteger(v); return true; }
   if(k == "InpADXMin") { P_ADXMin = StringToDouble(v); return true; }
   if(k == "InpUseCandle") { P_UseCandle = (v == "true" || v == "1"); return true; }
   if(k == "InpATRMult") { P_ATRMult = StringToDouble(v); return true; }
   if(k == "InpRR") { P_RR = StringToDouble(v); return true; }
   if(k == "InpRiskPercent") { P_RiskPercent = StringToDouble(v); return true; }
   if(k == "InpMaxRiskRoundUp") { P_MaxRiskRoundUp = StringToDouble(v); return true; }
   if(k == "InpCorrSymbols") { P_CorrSymbols = v; return true; }
   if(k == "InpCorrRiskScale") { P_CorrRiskScale = StringToDouble(v); return true; }
   if(k == "InpMaxGroupRiskPct") { P_MaxGroupRiskPct = StringToDouble(v); return true; }
   if(k == "InpUsePartial") { P_UsePartial = (v == "true" || v == "1"); return true; }
   if(k == "InpPartialR") { P_PartialR = StringToDouble(v); return true; }
   if(k == "InpPartialPct") { P_PartialPct = StringToDouble(v); return true; }
   if(k == "InpUseBreakeven") { P_UseBreakeven = (v == "true" || v == "1"); return true; }
   if(k == "InpBreakevenR") { P_BreakevenR = StringToDouble(v); return true; }
   if(k == "InpBEBufferR") { P_BEBufferR = StringToDouble(v); return true; }
   if(k == "InpUseTrailing") { P_UseTrailing = (v == "true" || v == "1"); return true; }
   if(k == "InpTrailStartR") { P_TrailStartR = StringToDouble(v); return true; }
   if(k == "InpTrailATRMult") { P_TrailATRMult = StringToDouble(v); return true; }
   if(k == "InpSkipWeekend") { P_SkipWeekend = (v == "true" || v == "1"); return true; }
   if(k == "InpBlock1Start") { P_Block1Start = (int)StringToInteger(v); return true; }
   if(k == "InpBlock1End") { P_Block1End = (int)StringToInteger(v); return true; }
   if(k == "InpBlock2Start") { P_Block2Start = (int)StringToInteger(v); return true; }
   if(k == "InpBlock2End") { P_Block2End = (int)StringToInteger(v); return true; }
   if(k == "InpMaxSpreadPoints") { P_MaxSpreadPoints = (int)StringToInteger(v); return true; }
   if(k == "InpAllowBuy") { P_AllowBuy = (v == "true" || v == "1"); return true; }
   if(k == "InpAllowSell") { P_AllowSell = (v == "true" || v == "1"); return true; }
   if(k == "InpMaxTradesPerDay") { P_MaxTradesPerDay = (int)StringToInteger(v); return true; }
   if(k == "InpCooldownBars") { P_CooldownBars = (int)StringToInteger(v); return true; }
   if(k == "InpMaxDailyLossPct") { P_MaxDailyLossPct = StringToDouble(v); return true; }
   if(k == "InpCloseOnDailyLoss") { P_CloseOnDailyLoss = (v == "true" || v == "1"); return true; }
   if(k == "InpMaxDrawdownPct") { P_MaxDrawdownPct = StringToDouble(v); return true; }
   if(k == "InpCloseOnHalt") { P_CloseOnHalt = (v == "true" || v == "1"); return true; }
   if(k == "InpResetHalt") { P_ResetHalt = (v == "true" || v == "1"); return true; }
   if(k == "InpCapital") { P_Capital = StringToDouble(v); return true; }
   if(k == "InpPushNotify") { P_PushNotify = (v == "true" || v == "1"); return true; }
   if(k == "InpTelegram") { P_Telegram = (v == "true" || v == "1"); return true; }
   if(k == "InpTgToken") { P_TgToken = v; return true; }
   if(k == "InpTgChatId") { P_TgChatId = v; return true; }
   if(k == "InpShowPanel") { P_ShowPanel = (v == "true" || v == "1"); return true; }
   if(k == "InpMagic") { P_Magic = (ulong)StringToInteger(v); return true; }
   if(k == "InpTestLabel") { P_TestLabel = v; return true; }
   if(k == "InpManageEverySec") { P_ManageEverySec = (int)StringToInteger(v); return true; }
   if(k == "InpPreset") { P_Preset = (int)StringToInteger(v); return true; }
   return false;
}
// Mo file chung de DOC. Khi chay song song nhieu agent cung doc 1 file: phai cho phep doc chung
// (FILE_SHARE_READ), va thu lai vai lan neu file dang bi giu.
int OpenCommonRead(const string name, const int flags, const ushort delim = '\t')
{
   for(int i = 0; i < 20; i++)
   {
      int h = FileOpen(name, flags | FILE_READ | FILE_SHARE_READ | FILE_COMMON, delim);
      if(h != INVALID_HANDLE) return h;
      Sleep(100);
   }
   return INVALID_HANDLE;
}
// Dong cau hinh: id;ten;Inp1=gia_tri;Inp2=gia_tri...
bool ApplyPreset(const int id)
{
   int h = OpenCommonRead("TrendBot_presets.csv", FILE_TXT | FILE_ANSI);
   if(h == INVALID_HANDLE) { Print("Khong mo duoc TrendBot_presets.csv"); return false; }
   bool found = false;
   while(!FileIsEnding(h) && !found)
   {
      string parts[];
      int n = StringSplit(FileReadString(h), ';', parts);
      if(n < 2 || (int)StringToInteger(parts[0]) != id) continue;
      found = true;
      P_TestLabel = parts[1];
      for(int i = 2; i < n; i++)
      {
         int e = StringFind(parts[i], "=");
         if(e <= 0) continue;
         string k = StringSubstr(parts[i], 0, e), v = StringSubstr(parts[i], e + 1);
         if(!SetParam(k, v)) { PrintFormat("Cau hinh %d: khong biet tham so %s", id, k); found = false; break; }
      }
   }
   FileClose(h);
   return found;
}

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
   LoadParams();
   if(InpPreset > 0 && !ApplyPreset(InpPreset)) return INIT_PARAMETERS_INCORRECT;   // het cau hinh: bo qua lan nay
   if(P_UseFunding) LoadFunding();
   if(P_AvoidUSNews && MQLInfoInteger(MQL_TESTER)) LoadNews();
   if(P_UseFearGreed) LoadDaily("fng.csv", g_fngT, g_fngV);
   if(P_UseAttention && WikiArticle() != "") LoadDaily("wiki_" + WikiArticle() + ".csv", g_wikT, g_wikV);
   if(P_UseMarketFilter)
   {
      g_mktSym = P_MarketSymbol;
      if(!SymbolSelect(g_mktSym, true)) g_mktSym = P_MarketSymbol + "m";
      if(!SymbolSelect(g_mktSym, true))
      { Print("Khong tim thay ma ", P_MarketSymbol, " / ", g_mktSym, ": tat bo loc Nasdaq."); g_mktSym = ""; }
      else hMkt = iMA(g_mktSym, PERIOD_D1, 200, 0, MODE_EMA, PRICE_CLOSE);
   }
   hFast  = iMA(_Symbol, P_TF,  P_FastEMA,  0, MODE_EMA, PRICE_CLOSE);
   hTrend = iMA(_Symbol, P_TF,  P_TrendEMA, 0, MODE_EMA, PRICE_CLOSE);
   hHTF   = iMA(_Symbol, P_HTF, P_HTFEMA,   0, MODE_EMA, PRICE_CLOSE);
   hATR   = iATR(_Symbol, P_TF, P_ATRPeriod);
   hADX   = iADX(_Symbol, P_TF, P_ADXPeriod);
   if(hFast == INVALID_HANDLE || hTrend == INVALID_HANDLE || hHTF == INVALID_HANDLE ||
      hATR == INVALID_HANDLE || hADX == INVALID_HANDLE)
   {
      Print("Khong tao duoc chi bao");
      return INIT_FAILED;
   }
   trade.SetExpertMagicNumber(P_Magic);
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
   bool capitalChanged = GlobalVariableCheck(GVName("capital")) && GVGet("capital") != P_Capital;
   if(P_ResetHalt || capitalChanged || !GlobalVariableCheck(GVName("base")))
   {
      ResetBaseline(P_ResetHalt);
      if(P_ResetHalt)   Print("Da mo khoa bot va dat lai moc von. Nho doi InpResetHalt ve false.");
      if(capitalChanged) Print("InpCapital da thay doi, tu dat lai moc von va dinh von.");
      if(capitalChanged && !P_ResetHalt && (IsHalted() || GlobalVariableCheck(GVName("dayLock"))))
         Print("Bot VAN DANG DUNG / KHOA LO NGAY. Doi von khong mo khoa; muon mo, dat InpResetHalt = true mot lan.");
   }
   GlobalVariableSet(GVName("capital"), P_Capital);
   lastLossTime = (datetime)GVGet("lastLoss", 0);
   g_plDirty = true;
   RefreshClosedPL();
   UpdateDay();
   if(!IsHedging())
      Print("CANH BAO: tai khoan NETTING. Bot duoc thiet ke cho tai khoan HEDGING; chot mot phan se dong theo symbol.");
   if(!MQLInfoInteger(MQL_TESTER) && InGroup() && (P_CorrRiskScale < 1 || P_MaxGroupRiskPct > 0))
      Print("Luu y: tran rui ro chung BTC/ETH chi dong bo giua cac bot chay tren CUNG terminal MT5 nay. ",
            "Bot o terminal / VPS khac khong biet phan rui ro da giu cho.");
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

datetime g_lastManage = 0;
void OnTick()
{
   if(!TryInitState()) return;      // chua dang nhap: chua lam gi ca
   // Moi tick BTC deu goi day; kiem tra lenh / gioi han moi P_ManageEverySec giay la du
   // (server cung khong cho sua SL nhanh hon), tru khi vua co nen moi hoac vua co giao dich.
   datetime barNow = iTime(_Symbol, P_TF, 0);
   if(P_ManageEverySec > 0 && barNow == lastBarTime && !g_reconcile &&
      TimeCurrent() - g_lastManage < P_ManageEverySec) return;
   g_lastManage = TimeCurrent();
   bool ready = LimitsReady();
   RefreshClosedPL();
   UpdateDay();
   if(ready) CheckDrawdown();
   // Da dung han ma van con lenh (vd. dong that bai lan truoc) thi thu dong lai moi tick
   if(IsHalted() && P_CloseOnHalt && HasOwnPosition()) CloseAll();
   if(ready) CheckDailyLoss();
   ManagePositions();
   ReconcileClosed();
   UpdatePanel();

   datetime barTime = iTime(_Symbol, P_TF, 0);
   if(barTime == 0 || barTime == lastBarTime) return;
   lastBarTime = barTime;

   if(IsHalted())       { g_status = "DUNG HAN (sut giam)"; return; }
   if(HasOwnPosition()) { g_status = "Dang giu lenh";       return; }
   if(DailyLossHit())   { g_status = "Cham gioi han lo ngay, nghi den mai"; return; }
   string why = "";
   if(!TimeAllowed(why)) { g_status = "Tam nghi: " + why; return; }
   if(P_MaxSpreadPoints > 0 && SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) > P_MaxSpreadPoints)
   {
      g_status = "Spread qua rong";
      return;
   }
   if(P_MaxTradesPerDay > 0 && TradesToday() >= P_MaxTradesPerDay)
   {
      g_status = "Du so lenh trong ngay";
      return;
   }
   if(P_CooldownBars > 0 && lastLossTime > 0 &&
      TimeCurrent() - lastLossTime < (long)P_CooldownBars * PeriodSeconds(P_TF))
   {
      g_status = "Nghi sau lenh thua";
      return;
   }

   double fast, trend, atr, adx = 0, htfEma = 0;
   if(!GetValue(hFast, 0, 1, fast) || !GetValue(hTrend, 0, 1, trend) || !GetValue(hATR, 0, 1, atr)) return;
   if(P_UseADX && !GetValue(hADX, 0, 1, adx)) return;          // buffer 0 = ADX chinh
   if(P_UseHTF && !GetValue(hHTF, 0, 1, htfEma)) return;
   double htfClose = iClose(_Symbol, P_HTF, 1);

   double c1 = iClose(_Symbol, P_TF, 1);
   double h1 = iHigh(_Symbol,  P_TF, 1);
   double l1 = iLow(_Symbol,   P_TF, 1);

   bool adxOk = !P_UseADX || adx >= P_ADXMin;
   bool buyBase, sellBase;
   if(!BaseSignals(atr, trend, fast, c1, h1, l1, buyBase, sellBase)) return;
   bool buySignal  = P_AllowBuy && buyBase
                     && (!P_UseHTF || htfClose > htfEma) && adxOk
                     && (!P_UseCandle || BullCandle());
   bool sellSignal = P_AllowSell && sellBase
                     && (!P_UseHTF || htfClose < htfEma) && adxOk
                     && (!P_UseCandle || BearCandle());
   if(P_UseFunding && (buySignal || sellSignal))
   {
      // Funding qua duong: phe Long dang dong va tra phi cao, de bi thanh ly dong loat -> khong mua duoi.
      // Funding qua am: nguoc lai voi Sell.
      double f = FundingNow();
      if(f != EMPTY_VALUE && ((buySignal && f > P_FundingMax) || (sellSignal && f < -P_FundingMax)))
      {
         g_fundBlocked++;
         g_status = StringFormat("Bo tin hieu vi funding %.3f%%", f);
         return;
      }
   }

   if((buySignal || sellSignal) && !MarketFiltersOk(buySignal)) return;

   g_status = "Cho tin hieu";
   if(!buySignal && !sellSignal) return;

   double slDist   = atr * P_ATRMult;
   double minStops = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
   if(slDist < minStops * 1.1) slDist = minStops * 1.1;

   // Tu day toi khi gui lenh xong: giu khoa chung voi bot ma cung nhom. Khong lay duoc khoa thi KHONG vao lenh,
   // vi khong biet bot kia dang dung bao nhieu rui ro; thu lai o tick sau (van trong nen nay).
   if(!GroupLock())
   {
      g_status = "Cho khoa rui ro chung voi bot cung nhom, chua vao lenh";
      if(ShouldNotify("grplock", 3600)) Print("Khong lay duoc khoa chung cua nhom sau 5 giay: bo qua lan nay, thu lai o tick sau.");
      lastBarTime = 0;
      return;
   }
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
                     P_RR > 0 ? NormalizeDouble(price + slDist * P_RR, _Digits) : 0.0, "BTC bot BUY");
   }
   else
   {
      double price = tick.bid;
      ok = PrepSend() && trade.Sell(lots, _Symbol, price,
                      NormalizeDouble(price + slDist, _Digits),
                      P_RR > 0 ? NormalizeDouble(price - slDist * P_RR, _Digits) : 0.0, "BTC bot SELL");
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
   if(HistoryDealGetInteger(trans.deal, DEAL_MAGIC) != (long)P_Magic ||
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
