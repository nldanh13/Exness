//+------------------------------------------------------------------+
//| BTC_EMA_Pullback_v2.mq5 (TrendBot)                               |
//| EA theo xu huong: Donchian breakout (mac dinh) hoac EMA pullback |
//| File nay chi chua tham so va thu tu chay; logic nam trong        |
//| thu muc TrendBot/ (moi file mot viec, xem dau moi file).         |
//| CHI DUNG DE THU NGHIEM - BACKTEST VA CHAY DEMO TRUOC             |
//+------------------------------------------------------------------+
#define  BOT_VERSION "5.9"
#property version   "5.90"
#property description "Donchian breakout (mac dinh) hoac EMA pullback, ATR stop, trailing, bo loc, canh bao"

#include <Trade\Trade.mqh>

enum ENUM_STRATEGY
{
   STRAT_EMA_PULLBACK = 0,   // Hoi ve EMA20 theo xu huong
   STRAT_DONCHIAN     = 1,   // Pha vo kenh Donchian (breakout)
   STRAT_RSI_REVERT   = 2,   // Luot song: RSI qua ban/qua mua, vao theo xu huong lon (an hoi)
   STRAT_ORB          = 3,   // Luot song: pha vo vung gia dau phien My (opening range breakout)
   STRAT_EXHAUST      = 4,   // Luot song: dao chieu sau cu chay manh >= x% ATR ngay, TP o dai Bollinger
   STRAT_FVG          = 5,   // Luot song: gia quay lai khoang trong (FVG) cua nen lon, khoi luong cao
   STRAT_SPRING       = 6,   // Luot song: pha vo gia vung di ngang (Wyckoff spring / upthrust)
   STRAT_MACD         = 7,   // MACD(12,26,9) cat len/xuong (da khung theo Quantpedia: D1 loc huong, H1 vao lenh)
   STRAT_IMOM         = 8    // Quan tinh trong ngay (Shen, Urquhart & Wang 2022): vao 16:30, dong 17:00 gio New York
};

input group "=== Tin hieu ==="
input ENUM_STRATEGY   InpStrategy        = STRAT_DONCHIAN;     // Chien luoc vao lenh
input int             InpDonchianPeriod  = 20;        // So nen cua kenh Donchian (breakout)
input double          InpBreakMinATR     = 0.0;       // Donchian: gia dong cua phai vuot kenh it nhat x ATR (0 = tat)
input double          InpBreakMinBody    = 0.0;       // Donchian: than nen pha vo >= % bien do nen, cung chieu (0 = tat)
input bool            InpBreakConfirm    = false;     // Donchian: cho them 1 nen, gia van giu ngoai kenh moi vao
input double          InpBreakMinVol     = 0.0;       // Donchian: khoi luong (tick) nen pha vo >= x lan TB 20 nen truoc (0 = tat)
input double          InpBreakMaxATR     = 0.0;       // Donchian: bo qua nen pha vo dai hon x ATR (nen thanh ly day chuyen, 0 = tat)
input int             InpRsiPeriod       = 2;         // RSI: so nen
input double          InpRsiLow          = 10.0;      // RSI: Buy khi RSI < muc nay (va gia tren EMA xu huong)
input double          InpRsiHigh         = 90.0;      // RSI: Sell khi RSI > muc nay (va gia duoi EMA xu huong)
input bool            InpOrbNewYork      = true;      // ORB: tu tinh gio mo cua New York 9:30 theo mua he/dong (server = UTC)
input int             InpOrbStartMin     = 810;       // ORB: khi tat dong tren: phut bat dau vung gia tu 00:00 gio server (810 = 13:30)
input int             InpOrbMinutes      = 30;        // ORB: do dai vung gia (phut)
input double          InpExhaustATR      = 0.75;      // Dao chieu: cu chay trong ngay >= x ATR(20) D1
input double          InpFvgBigATR       = 2.0;       // FVG: nen giua dai >= x ATR va tick >= 1,5 lan TB 20 nen
input int             InpFvgLookback     = 20;        // FVG: tim khoang trong trong N nen gan nhat
input int             InpRangeBars       = 20;        // Spring: so nen cua vung di ngang
input double          InpRangeMaxATR     = 4.0;       // Spring: vung di ngang rong toi da x ATR
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
input int             InpPyramidMax      = 1;         // Nhoi lenh theo da: toi da bao nhieu lenh cung chieu (1 = tat)
input double          InpEntryPullATR    = 0;         // Vao lenh: cho gia hoi ve x ATR trong 1 nen sau tin hieu thay vi vao ngay (0 = vao ngay)
input int             InpEntryPullMode   = 0;         // Het nen ma gia chua hoi: 0 = bo tin hieu, 1 = vao gia thi truong
input int             InpPyramidTFmin    = 0;         // Kiem tra nhoi moi x phut (vd 15) thay vi moi nen khung chinh; buoc van tinh theo ATR khung chinh (0 = khung chinh)
input double          InpPyramidStepATR  = 1.0;       // Nhoi them khi gia di them x ATR tu lenh gan nhat (lenh cu doi SL ve hoa von)
input bool            InpExitOnEMA       = false;     // Dong het khi nen dong cat EMA nhanh nguoc chieu (dau hieu het da)
input int             InpImomMode        = 0;         // Quan tinh trong ngay: 0 = ket hop 2 tin hieu, 1 = nua gio dau, 2 = nua gio ke cuoi (dao chieu)
input bool            InpExitOnBar       = false;     // Dong het o nen dau tien dong nguoc chieu (Buy: nen do; Sell: nen xanh)
input int             InpMTFAlign        = 0;         // Dong thuan da khung: can it nhat x/8 khung (M1,M3,M5,M10,M15,M30,H1,H4) cung phia EMA20 moi vao / nhoi (0 = tat)
input bool            InpHTFMacd         = false;     // Loc huong khung lon bang MACD (dong > tin hieu = tang) thay vi EMA
input bool            InpDDScale         = false;     // Giam rui ro khi sut giam: 5-10% -> 50%, >10% -> 25% (ve 100% khi lap dinh moi)
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
input group "=== Bao ve lenh vao tay (rut ra tu sao ke giao dich tay) ==="
input bool            InpGuardManual     = false;     // Bat bao ve lenh tay (magic 0) tren ma cua chart nay
input double          InpGuardSLPct      = 1.5;       // Lenh tay chua co SL: tu dat SL cach gia vao x% (0 = tat)
input double          InpGuardMaxRiskPct = 3.0;       // Lenh tay cham SL lo hon x% von thi giam lot / dong (0 = tat)
input bool            InpGuardNoAverage  = true;      // Dong ngay lenh tay moi neu nhoi vao lenh cung chieu dang lo
input int             InpGuardMaxHoldH   = 24;        // Dong lenh tay dang lo sau x gio (0 = tat)
input double          InpGuardDayLossPct = 5.0;       // Lenh tay lo phat sinh qua x% trong ngay: dong het, khoa lenh tay toi het ngay (0 = tat)
input bool            InpGuardOldTrades  = false;     // Ap dung ca cho lenh tay da mo TRUOC khi bat bao ve (mac dinh: chi canh bao)
input group "=== Nhat ky & canh bao ky luat (tai khoan that) ==="
input bool            InpJournal         = true;      // Ghi moi giao dich cua tai khoan (bot, lenh tay, nap/rut) vao Common\Files\TrendBot_nhatky.csv
input double          InpWarnProfitPct   = 20.0;      // Lai trong thang dat moi x% thi nhac rut tien (0 = tat)
input double          InpWarnBigWinPct   = 10.0;      // 1 lenh lai > x% so du: nhac rut tien, nghi 1-2 ngay, khong tang lot (0 = tat)
input int             InpWarnRedepositDays = 7;       // Nap tien trong x ngay sau khi rut: canh bao (0 = tat)
input double          InpMonthDepositCap = 0;         // Tong nap trong thang vuot muc nay (tien tai khoan, vd 2000000 VND) thi canh bao (0 = tat)
input double          InpWarnLotJump     = 2.0;       // Lenh tay co lot > x lan lot thuong dung (trung vi 20 lenh gan nhat): canh bao (0 = tat)
input int             InpWarnMaxTradesDay = 10;       // Vao qua x lenh tay trong ngay: canh bao (0 = tat)
input int             InpWarnLossStreak  = 3;         // Thua tay x lenh lien tiep: nhac nghi (0 = tat)

input group "=== Thong bao ==="
input bool            InpPushNotify      = true;      // Push ve app MT5 tren dien thoai
input bool            InpTelegram        = false;     // Gui Telegram
input string          InpTgToken         = "";        // Telegram bot token
input string          InpTgChatId        = "";        // Telegram chat id

input group "=== Khac ==="
input bool            InpShowPanel       = true;      // Hien bang thong tin
input ulong           InpMagic           = 20261105;  // Magic number
input int             InpExportTFmin     = 0;         // Chi dung khi backtest: cuoi lan chay, xuat nen x phut (vd 10) ra Common\Files\TrendBot_bars_Mx.csv (0 = tat)
input string          InpTestLabel       = "";        // Ten lan chay backtest (ghi vao file ket qua)
input int             InpManageEverySec  = 0;         // Kiem tra lenh dang mo / gioi han lo moi X giay (0 = moi tick, mac dinh: tick that cho thay 1 giay lam lech 1 lenh)
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
double          P_BreakMinVol;
int             P_RsiPeriod;
double          P_RsiLow;
double          P_RsiHigh;
int             P_OrbStartMin;
bool            P_OrbNewYork;
bool            P_DDScale;
int             P_PyramidMax;
double          P_PyramidStepATR;
int             P_PyramidTFmin;
int             P_MTFAlign;
int             P_ExportTFmin;
double          P_EntryPullATR;
int             P_EntryPullMode;
bool            P_ExitOnEMA;
bool            P_ExitOnBar;
int             P_ImomMode;
bool            P_HTFMacd;
double          P_ExhaustATR;
double          P_FvgBigATR;
int             P_FvgLookback;
int             P_RangeBars;
double          P_RangeMaxATR;
int             P_OrbMinutes;
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
   P_BreakMinVol = InpBreakMinVol;
   P_RsiPeriod = InpRsiPeriod;
   P_RsiLow = InpRsiLow;
   P_RsiHigh = InpRsiHigh;
   P_OrbStartMin = InpOrbStartMin;
   P_OrbNewYork = InpOrbNewYork;
   P_DDScale = InpDDScale;
   P_PyramidMax = InpPyramidMax;
   P_PyramidStepATR = InpPyramidStepATR;
   P_PyramidTFmin = InpPyramidTFmin;
   P_MTFAlign = InpMTFAlign;
   P_ExportTFmin = InpExportTFmin;
   P_EntryPullATR = InpEntryPullATR;
   P_EntryPullMode = InpEntryPullMode;
   P_ExitOnEMA = InpExitOnEMA;
   P_ExitOnBar = InpExitOnBar;
   P_ImomMode = InpImomMode;
   P_HTFMacd = InpHTFMacd;
   P_ExhaustATR = InpExhaustATR;
   P_FvgBigATR = InpFvgBigATR;
   P_FvgLookback = InpFvgLookback;
   P_RangeBars = InpRangeBars;
   P_RangeMaxATR = InpRangeMaxATR;
   P_OrbMinutes = InpOrbMinutes;
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
   if(k == "InpBreakMinVol") { P_BreakMinVol = StringToDouble(v); return true; }
   if(k == "InpRsiPeriod") { P_RsiPeriod = (int)StringToInteger(v); return true; }
   if(k == "InpRsiLow") { P_RsiLow = StringToDouble(v); return true; }
   if(k == "InpRsiHigh") { P_RsiHigh = StringToDouble(v); return true; }
   if(k == "InpExhaustATR") { P_ExhaustATR = StringToDouble(v); return true; }
   if(k == "InpFvgBigATR") { P_FvgBigATR = StringToDouble(v); return true; }
   if(k == "InpFvgLookback") { P_FvgLookback = (int)StringToInteger(v); return true; }
   if(k == "InpRangeBars") { P_RangeBars = (int)StringToInteger(v); return true; }
   if(k == "InpRangeMaxATR") { P_RangeMaxATR = StringToDouble(v); return true; }
   if(k == "InpPyramidMax") { P_PyramidMax = (int)StringToInteger(v); return true; }
   if(k == "InpEntryPullATR") { P_EntryPullATR = StringToDouble(v); return true; }
   if(k == "InpEntryPullMode") { P_EntryPullMode = (int)StringToInteger(v); return true; }
   if(k == "InpExportTFmin") { P_ExportTFmin = (int)StringToInteger(v); return true; }
   if(k == "InpMTFAlign") { P_MTFAlign = (int)StringToInteger(v); return true; }
   if(k == "InpPyramidTFmin") { P_PyramidTFmin = (int)StringToInteger(v); return true; }
   if(k == "InpPyramidStepATR") { P_PyramidStepATR = StringToDouble(v); return true; }
   if(k == "InpImomMode") { P_ImomMode = (int)StringToInteger(v); return true; }
   if(k == "InpExitOnBar") { P_ExitOnBar = (v == "true" || v == "1"); return true; }
   if(k == "InpHTFMacd") { P_HTFMacd = (v == "true" || v == "1"); return true; }
   if(k == "InpExitOnEMA") { P_ExitOnEMA = (v == "true" || v == "1"); return true; }
   if(k == "InpDDScale") { P_DDScale = (v == "true" || v == "1"); return true; }
   if(k == "InpOrbNewYork") { P_OrbNewYork = (v == "true" || v == "1"); return true; }
   if(k == "InpOrbStartMin") { P_OrbStartMin = (int)StringToInteger(v); return true; }
   if(k == "InpOrbMinutes") { P_OrbMinutes = (int)StringToInteger(v); return true; }
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

// Vao lenh cho gia hoi (Report.mqh ghi ra): gia cham muc cho / het nen chua hoi / bi huy khi kiem tra lai / lenh khop that
int      g_pendHit = 0, g_pendMissed = 0, g_pendBlocked = 0, g_pendFilled = 0;

//--- Cac module (thu muc TrendBot/ canh file nay) ---------------------
#include "TrendBot/Core.mqh"
#include "TrendBot/Notify.mqh"
#include "TrendBot/Protection.mqh"
#include "TrendBot/Filters.mqh"
#include "TrendBot/Signals.mqh"
#include "TrendBot/Risk.mqh"
#include "TrendBot/Manage.mqh"
#include "TrendBot/Guard.mqh"
#include "TrendBot/Journal.mqh"
#include "TrendBot/Status.mqh"
#include "TrendBot/Panel.mqh"
#include "TrendBot/Report.mqh"

int OnInit()
{
   LoadParams();
   if(InpPreset > 0 && !ApplyPreset(InpPreset)) return INIT_PARAMETERS_INCORRECT;   // het cau hinh: bo qua lan nay
   // Moi chien luoc / khung co Magic rieng, de nhieu bot tren CUNG ma khong quan ly nham lenh cua nhau.
   // Donchian H4 (cau hinh chinh) giu nguyen Magic goc de khong mat lien ket voi lenh / trang thai cu.
   if(!(P_Strategy == STRAT_DONCHIAN && P_TF == PERIOD_H4))
      P_Magic += (ulong)P_Strategy * 10000 + (ulong)(PeriodSeconds(P_TF) / 60 % 10000);
   if(!MQLInfoInteger(MQL_TESTER) && !ClaimMagic()) return INIT_FAILED;
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
   if(P_Strategy == STRAT_RSI_REVERT)
   {
      hRSI = iRSI(_Symbol, P_TF, P_RsiPeriod, PRICE_CLOSE);
      if(hRSI == INVALID_HANDLE) { Print("Khong tao duoc RSI"); return INIT_FAILED; }
   }
   if(P_Strategy == STRAT_MACD)
   {
      hMACD = iMACD(_Symbol, P_TF, 12, 26, 9, PRICE_CLOSE);
      if(hMACD == INVALID_HANDLE) { Print("Khong tao duoc MACD"); return INIT_FAILED; }
   }
   if(P_MTFAlign > 0 && !InitMTF()) { Print("Khong tao duoc EMA20 da khung"); return INIT_FAILED; }
   if(P_HTFMacd)
   {
      hMACDH = iMACD(_Symbol, P_HTF, 12, 26, 9, PRICE_CLOSE);
      if(hMACDH == INVALID_HANDLE) { Print("Khong tao duoc MACD khung lon"); return INIT_FAILED; }
   }
   if(P_Strategy == STRAT_EXHAUST)
   {
      hATRD1 = iATR(_Symbol, PERIOD_D1, 20);
      hBB    = iBands(_Symbol, P_TF, 20, 0, 2.0, PRICE_CLOSE);
      if(hATRD1 == INVALID_HANDLE || hBB == INVALID_HANDLE) { Print("Khong tao duoc ATR D1 / Bollinger"); return INIT_FAILED; }
   }
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

void ExportBars()
{
   ENUM_TIMEFRAMES tf = P_ExportTFmin == 1 ? PERIOD_M1 : P_ExportTFmin == 5 ? PERIOD_M5 : P_ExportTFmin == 10 ? PERIOD_M10 :
                        P_ExportTFmin == 15 ? PERIOD_M15 : P_ExportTFmin == 30 ? PERIOD_M30 : PERIOD_H1;
   MqlRates r[];
   int n = CopyRates(_Symbol, tf, D'2000.01.01', TimeCurrent(), r);
   if(n <= 0) { Print("Xuat du lieu: khong lay duoc nen, loi ", GetLastError()); return; }
   string fn = "TrendBot_bars_" + _Symbol + "_M" + IntegerToString(P_ExportTFmin) + ".csv";
   int h = FileOpen(fn, FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_COMMON);
   if(h == INVALID_HANDLE) { Print("Xuat du lieu: khong ghi duoc ", fn); return; }
   FileWriteString(h, "time,open,high,low,close,tickvol,spread\r\n");
   for(int i = 0; i < n; i++)
      FileWriteString(h, StringFormat("%I64d,%.2f,%.2f,%.2f,%.2f,%I64d,%d\r\n", (long)r[i].time, r[i].open, r[i].high, r[i].low, r[i].close, r[i].tick_volume, r[i].spread));
   FileClose(h);
   PrintFormat("Xuat du lieu: %d nen M%d -> Common\\Files\\%s", n, P_ExportTFmin, fn);
}

void OnDeinit(const int reason)
{
   if(P_ExportTFmin > 0 && MQLInfoInteger(MQL_TESTER)) ExportBars();
   if(!MQLInfoInteger(MQL_TESTER)) { ReleaseMagic(); JournalRelease(); StatusRelease(); }
   IndicatorRelease(hFast);
   IndicatorRelease(hTrend);
   IndicatorRelease(hHTF);
   IndicatorRelease(hATR);
   IndicatorRelease(hADX);
   if(hRSI != INVALID_HANDLE) IndicatorRelease(hRSI);
   if(hATRD1 != INVALID_HANDLE) IndicatorRelease(hATRD1);
   if(hBB != INVALID_HANDLE) IndicatorRelease(hBB);
   if(hMACD != INVALID_HANDLE) IndicatorRelease(hMACD);
   if(hMACDH != INVALID_HANDLE) IndicatorRelease(hMACDH);
   if(hMkt != INVALID_HANDLE) IndicatorRelease(hMkt);
   ReleaseMTF();
   Comment("");
}

datetime g_lastManage = 0;
int      g_pendDir = 0;            // tin hieu dang cho gia hoi ve: 1 buy, -1 sell, 0 khong co
double   g_pendPrice = 0, g_pendATR = 0, g_pendSigSL = 0, g_pendSigTP = 0;
datetime g_pendExpire = 0;
void CheckPendingEntry()
{
   if(g_pendDir == 0) return;
   if(HasOwnPosition() || IsHalted()) { g_pendDir = 0; return; }
   MqlTick tk;
   if(!SymbolInfoTick(_Symbol, tk)) return;
   bool buy = g_pendDir > 0;
   bool hit = buy ? tk.ask <= g_pendPrice : tk.bid >= g_pendPrice;
   bool expired = TimeCurrent() >= g_pendExpire;
   if(!hit && !expired) return;
   if(!hit && P_EntryPullMode == 0) { g_pendDir = 0; g_pendMissed++; g_status = "Gia khong hoi ve, bo tin hieu"; return; }
   // Kiem tra LAI moi dieu kien bat buoc ngay truoc khi gui: tu luc co tin hieu toi gio co the da het khung gio,
   // spread gian rong, du so lenh trong ngay, cham lo ngay, gan tin My, hoac cac khung nho het dong thuan.
   bool mtf = MTFOk(buy);
   if(!mtf) g_status = "cac khung nho het dong thuan";
   if(!mtf || !EntryGatesOk() || !FundingOk(buy) || !MarketFiltersOk(buy))
   {
      g_pendDir = 0;
      if(hit) g_pendHit++; else g_pendMissed++;
      g_pendBlocked++;
      g_status = "Huy lenh cho: " + g_status;
      return;
   }
   g_sigSL = g_pendSigSL; g_sigTP = g_pendSigTP;
   int r = SendEntry(buy, g_pendATR, true);
   if(r == 0) return;               // chua lay duoc khoa rui ro chung: giu lenh cho, thu lai o tick sau
   g_pendDir = 0;
   if(hit) g_pendHit++; else g_pendMissed++;
   if(r > 0) g_pendFilled++;        // chi dem khi server da khop that
}
// Dieu kien bat buoc truoc moi lan vao lenh moi (dung chung cho vao ngay va vao khi gia hoi ve)
bool EntryGatesOk()
{
   if(DailyLossHit())   { g_status = "Cham gioi han lo ngay, nghi den mai"; return false; }
   string why = "";
   if(!TimeAllowed(why)) { g_status = "Tam nghi: " + why; return false; }
   if(P_MaxSpreadPoints > 0 && SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) > P_MaxSpreadPoints)
   {
      g_status = "Spread qua rong";
      return false;
   }
   if(P_MaxTradesPerDay > 0 && TradesToday() >= P_MaxTradesPerDay)
   {
      g_status = "Du so lenh trong ngay";
      return false;
   }
   if(P_CooldownBars > 0 && lastLossTime > 0 &&
      TimeCurrent() - lastLossTime < (long)P_CooldownBars * PeriodSeconds(P_TF))
   {
      g_status = "Nghi sau lenh thua";
      return false;
   }
   return true;
}
// Funding qua duong: phe Long dang dong va tra phi cao, de bi thanh ly dong loat -> khong mua duoi.
// Funding qua am: nguoc lai voi Sell.
bool FundingOk(const bool buy)
{
   if(!P_UseFunding) return true;
   double f = FundingNow();
   if(f != EMPTY_VALUE && ((buy && f > P_FundingMax) || (!buy && f < -P_FundingMax)))
   {
      g_fundBlocked++;
      g_status = StringFormat("Bo tin hieu vi funding %.3f%%", f);
      return false;
   }
   return true;
}
void OnTick()
{
   if(!TryInitState()) return;      // chua dang nhap: chua lam gi ca
   GuardManual();                   // bao ve lenh tay (tu kiem tra moi 2 giay)
   JournalScan();                   // nhat ky + canh bao ky luat (moi 15 giay, chi 1 chart / tai khoan)
   WriteStatus();                   // trang thai cho giao dien tren trinh duyet (moi 10 giay)
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
   CheckPendingEntry();             // tin hieu dang cho gia hoi ve: sau khi da cap nhat lo ngay / sut giam cua tick nay
   UpdatePanel();

   datetime barTime = iTime(_Symbol, P_TF, 0);
   // Nhoi lenh tren khung nho hon (vd moi 15 phut): chi them lop, thoat lenh van theo khung chinh
   if(P_PyramidTFmin > 0 && P_PyramidMax > 1 && barTime == lastBarTime)
   {
      static datetime lastPyrBar = 0;
      ENUM_TIMEFRAMES ptf = PyrTF();
      datetime pt = iTime(_Symbol, ptf, 0);
      if(pt != 0 && pt != lastPyrBar)
      {
         lastPyrBar = pt;
         if(!IsHalted() && HasOwnPosition()) PyramidStep(true);
      }
   }
   if(barTime == 0 || barTime == lastBarTime) return;
   lastBarTime = barTime;

   if(IsHalted())       { g_status = "DUNG HAN (sut giam)"; return; }
   if(HasOwnPosition())
   {
      g_status = "Dang giu lenh";
      if(P_PyramidMax > 1 || P_ExitOnEMA || P_ExitOnBar || P_Strategy == STRAT_IMOM) PyramidStep();
      return;
   }
   if(!EntryGatesOk()) return;

   double fast, trend, atr, adx = 0, htfEma = 0;
   if(!GetValue(hFast, 0, 1, fast) || !GetValue(hTrend, 0, 1, trend) || !GetValue(hATR, 0, 1, atr)) return;
   if(P_UseADX && !GetValue(hADX, 0, 1, adx)) return;          // buffer 0 = ADX chinh
   if(P_UseHTF && !GetValue(hHTF, 0, 1, htfEma)) return;
   bool htfUp = true, htfDn = true;
   if(P_UseHTF && P_HTFMacd)
   {
      // MACD khung lon cua nen DA DONG (shift 1): dong MACD tren duong tin hieu = xu huong tang
      double hm, hs;
      if(!GetValue(hMACDH, 0, 1, hm) || !GetValue(hMACDH, 1, 1, hs)) return;
      htfUp = hm > hs; htfDn = hm < hs;
   }
   if(P_Strategy == STRAT_RSI_REVERT && !GetValue(hRSI, 0, 1, g_rsi)) return;
   double htfClose = iClose(_Symbol, P_HTF, 1);

   double c1 = iClose(_Symbol, P_TF, 1);
   double h1 = iHigh(_Symbol,  P_TF, 1);
   double l1 = iLow(_Symbol,   P_TF, 1);

   bool adxOk = !P_UseADX || adx >= P_ADXMin;
   bool buyBase, sellBase;
   if(!BaseSignals(atr, trend, fast, c1, h1, l1, buyBase, sellBase)) return;
   bool buySignal  = P_AllowBuy && buyBase
                     && (!P_UseHTF || (P_HTFMacd ? htfUp : htfClose > htfEma)) && adxOk
                     && (!P_UseCandle || BullCandle()) && MTFOk(true);
   bool sellSignal = P_AllowSell && sellBase
                     && (!P_UseHTF || (P_HTFMacd ? htfDn : htfClose < htfEma)) && adxOk
                     && (!P_UseCandle || BearCandle()) && MTFOk(false);
   if((buySignal || sellSignal) && !FundingOk(buySignal)) return;

   if((buySignal || sellSignal) && !MarketFiltersOk(buySignal)) return;

   g_status = "Cho tin hieu";
   if(!buySignal && !sellSignal) return;

   if(P_EntryPullATR > 0)
   {
      // Cho gia hoi ve x ATR (sau pha vo H4, ~75% lan gia hoi >= 0,25 ATR trong 4 gio sau - du lieu M10 2021-2026)
      g_pendDir = buySignal ? 1 : -1; g_pendATR = atr; g_pendSigSL = g_sigSL; g_pendSigTP = g_sigTP;
      g_pendPrice = buySignal ? c1 - P_EntryPullATR * atr : c1 + P_EntryPullATR * atr;
      g_pendExpire = barTime + PeriodSeconds(P_TF);
      g_status = StringFormat("Cho gia hoi ve %s de %s", DoubleToString(g_pendPrice, _Digits), buySignal ? "BUY" : "SELL");
      return;
   }
   SendEntry(buySignal, atr, false);
}

// Gui lenh vao (dung chung cho vao ngay va vao khi gia hoi ve).
// Tra ve 1 = server da khop, 0 = chua lay duoc khoa chung (thu lai o tick sau), -1 = khong vao (lot, TP, server tu choi...).
int SendEntry(const bool buySignal, const double atr, const bool fromPending)
{
   // Mot so chien luoc luot song tu dat SL (theo cau truc gia) va TP (gia cu the)
   double slDist   = g_sigSL > 0 ? g_sigSL : atr * P_ATRMult;
   double minStops = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
   if(slDist < minStops * 1.1) slDist = minStops * 1.1;

   // Tu day toi khi gui lenh xong: giu khoa chung voi bot ma cung nhom. Khong lay duoc khoa thi KHONG vao lenh,
   // vi khong biet bot kia dang dung bao nhieu rui ro; thu lai o tick sau (van trong nen nay).
   if(!GroupLock())
   {
      g_status = "Cho khoa rui ro chung voi bot cung nhom, chua vao lenh";
      if(ShouldNotify("grplock", 3600)) Print("Khong lay duoc khoa chung cua nhom sau 5 giay: bo qua lan nay, thu lai o tick sau.");
      if(!fromPending) lastBarTime = 0;   // lenh cho gia hoi tu thu lai (CheckPendingEntry giu lenh cho)
      return 0;
   }
   double lots = CalcLots(slDist);
   MqlTick tick;
   if(lots <= 0 || !SymbolInfoTick(_Symbol, tick)) { GroupUnlock(); return -1; }
   GroupReserve(g_lastRisk);

   bool ok;
   if(buySignal)
   {
      double price = tick.ask;
      g_reqPrice = price; g_reqSpread = (long)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      double tp = g_sigTP > 0 ? g_sigTP : (P_RR > 0 ? price + slDist * P_RR : 0.0);
      if(tp > 0 && tp <= price + minStops) { g_status = "TP qua gan gia, bo qua"; GroupClear(); GroupUnlock(); return -1; }
      ok = PrepSend() && trade.Buy(lots, _Symbol, price,
                     NormalizeDouble(price - slDist, _Digits),
                     tp > 0 ? NormalizeDouble(tp, _Digits) : 0.0, "BTC bot BUY");
   }
   else
   {
      double price = tick.bid;
      g_reqPrice = price; g_reqSpread = (long)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      double tp = g_sigTP > 0 ? g_sigTP : (P_RR > 0 ? price - slDist * P_RR : 0.0);
      if(tp > 0 && tp >= price - minStops) { g_status = "TP qua gan gia, bo qua"; GroupClear(); GroupUnlock(); return -1; }
      ok = PrepSend() && trade.Sell(lots, _Symbol, price,
                      NormalizeDouble(price + slDist, _Digits),
                      tp > 0 ? NormalizeDouble(tp, _Digits) : 0.0, "BTC bot SELL");
   }
   // trade.Buy/Sell tra true chi la gui duoc; server van co the tu choi -> xem ma ket qua.
   // Chua khop that thi bo phan rui ro da giu cho ngay, khong de treo 2 phut chan bot khac.
   uint rc = trade.ResultRetcode();
   bool filled = ok && (rc == TRADE_RETCODE_DONE || rc == TRADE_RETCODE_DONE_PARTIAL);
   if(!filled) GroupClear();
   GroupUnlock();                                    // mo khoa truoc khi gui thong bao (Telegram co the cham)
   TradeDone(ok, "Vao lenh", buySignal ? "BUY" : "SELL");
   return filled ? 1 : -1;
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
      LogSlippage(isBuy, price);
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
