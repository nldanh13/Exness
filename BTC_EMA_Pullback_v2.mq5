//+------------------------------------------------------------------+
//| BTC_EMA_Pullback_v2.mq5 (TrendBot)                               |
//| EA theo xu huong: Donchian breakout (mac dinh) hoac EMA pullback |
//| File nay chi chua tham so va thu tu chay; logic nam trong        |
//| thu muc TrendBot/ (moi file mot viec, xem dau moi file).         |
//| CHI DUNG DE THU NGHIEM - BACKTEST VA CHAY DEMO TRUOC             |
//+------------------------------------------------------------------+
#define  BOT_VERSION "5.10.20"
#property version   "5.1020"
#property description "Bot giao dịch theo xu hướng: phá vỡ kênh Donchian H4, dừng lỗ theo ATR, trailing stop, bảo vệ tài khoản."

#include <Trade\Trade.mqh>

enum ENUM_STRATEGY
{
   STRAT_EMA_PULLBACK = 0,   // Hồi về EMA20 theo xu hướng
   STRAT_DONCHIAN     = 1,   // Phá vỡ kênh Donchian (chiến lược chính)
   STRAT_RSI_REVERT   = 2,   // Thử nghiệm: RSI quá mua / quá bán
   STRAT_ORB          = 3,   // Thử nghiệm: phá vỡ vùng giá đầu phiên Mỹ (ORB)
   STRAT_EXHAUST      = 4,   // Thử nghiệm: đảo chiều sau cú chạy mạnh
   STRAT_FVG          = 5,   // Thử nghiệm: khoảng trống giá (FVG)
   STRAT_SPRING       = 6,   // Thử nghiệm: Wyckoff spring / upthrust
   STRAT_MACD         = 7,   // Thử nghiệm: MACD đa khung
   STRAT_IMOM         = 8    // Thử nghiệm: quán tính trong ngày
};

input group "1. Chiến lược và khung thời gian"
input ENUM_STRATEGY   InpStrategy         = STRAT_DONCHIAN; // Chiến lược vào lệnh
input ENUM_TIMEFRAMES InpTF               = PERIOD_H4;  // Khung thời gian tín hiệu
input int             InpFastEMA          = 20;         // EMA nhanh (số nến)
input int             InpTrendEMA         = 200;        // EMA xu hướng (số nến)
input int             InpATRPeriod        = 14;         // Chu kỳ ATR (số nến)

input group "2. Phá vỡ kênh Donchian"
input int             InpDonchianPeriod   = 20;         // Độ dài kênh (số nến)
input double          InpBreakMinATR      = 0.0;        // Vượt kênh tối thiểu (× ATR, 0 = tắt)
input double          InpBreakMinBody     = 0.0;        // Thân nến phá vỡ tối thiểu (% biên độ nến, 0 = tắt)
input bool            InpBreakConfirm     = false;      // Chờ thêm 1 nến xác nhận
input double          InpBreakMinVol      = 0.0;        // Khối lượng nến phá vỡ tối thiểu (× TB 20 nến, 0 = tắt)
input double          InpBreakMaxATR      = 0.0;        // Bỏ nến phá vỡ dài hơn (× ATR, 0 = tắt)

input group "3. Chiến lược thử nghiệm (chưa đạt kiểm thử)"
input int             InpRsiPeriod        = 2;          // RSI: chu kỳ (số nến)
input double          InpRsiLow           = 10.0;       // RSI: mua khi dưới mức
input double          InpRsiHigh          = 90.0;       // RSI: bán khi trên mức
input bool            InpOrbNewYork       = true;       // ORB: tự tính giờ mở cửa New York
input int             InpOrbStartMin      = 810;        // ORB: giờ bắt đầu vùng giá (phút tính từ 00:00 server)
input int             InpOrbMinutes       = 30;         // ORB: độ dài vùng giá (phút)
input double          InpExhaustATR       = 0.75;       // Đảo chiều: cú chạy trong ngày tối thiểu (× ATR ngày)
input double          InpFvgBigATR        = 2.0;        // FVG: nến lớn tối thiểu (× ATR)
input int             InpFvgLookback      = 20;         // FVG: tìm khoảng trống trong (số nến)
input int             InpRangeBars        = 20;         // Spring: độ dài vùng đi ngang (số nến)
input double          InpRangeMaxATR      = 4.0;        // Spring: vùng đi ngang rộng tối đa (× ATR)
input int             InpImomMode         = 0;          // Quán tính: 0 = kết hợp, 1 = nửa giờ đầu, 2 = nửa giờ kế cuối

input group "4. Bộ lọc xu hướng"
input bool            InpUseHTF           = true;       // Chỉ giao dịch theo xu hướng khung lớn
input ENUM_TIMEFRAMES InpHTF              = PERIOD_D1;  // Khung lớn
input int             InpHTFEMA           = 200;        // EMA khung lớn (số nến)
input bool            InpHTFMacd          = false;      // Xác định xu hướng khung lớn bằng MACD thay cho EMA
input bool            InpUseADX           = true;       // Lọc thị trường đi ngang bằng ADX
input int             InpADXPeriod        = 14;         // Chu kỳ ADX (số nến)
input double          InpADXMin           = 20.0;       // ADX tối thiểu để vào lệnh
input int             InpMTFAlign         = 0;          // Đồng thuận đa khung: số khung tối thiểu (trên 8, 0 = tắt)
input bool            InpUseCandle        = false;      // Bắt buộc mẫu nến (pin bar / nhấn chìm)

input group "5. Bộ lọc dữ liệu bên ngoài"
input bool            InpBreakoutUseSentiment = false;  // Donchian: dùng lọc F&G và funding (mặc định tắt)
input bool            InpUseFunding       = false;      // Lọc theo funding rate Binance Futures
input double          InpFundingMax       = 0.03;       // Ngưỡng funding (% mỗi 8 giờ)
input string          InpFundingSymbol    = "";         // Mã hợp đồng Binance (trống = tự nhận)
input bool            InpUseFearGreed     = false;      // Lọc theo chỉ số Fear & Greed
input int             InpFngGreedMax      = 76;         // Bỏ mua khi chỉ số từ mức (tham lam cực độ)
input int             InpFngFearMin       = 24;         // Bỏ bán khi chỉ số đến mức (sợ hãi cực độ)
input bool            InpUseAttention     = false;      // Chỉ vào lệnh khi lượt xem Wikipedia đang tăng
input string          InpWikiArticle      = "";         // Bài Wikipedia tiếng Anh (trống = tự nhận)
input bool            InpUseMarketFilter  = false;      // Theo xu hướng Nasdaq (EMA200 khung ngày)
input string          InpMarketSymbol     = "USTEC";    // Mã Nasdaq trên sàn
input bool            InpAvoidUSNews      = false;      // Tránh tin kinh tế Mỹ quan trọng
input int             InpNewsHours        = 2;          // Khoảng tránh tin (giờ trước và sau)

input group "6. Cách vào lệnh"
input bool            InpManualEntry      = false;      // Tự bấm BUY / SELL trên chart (bot không tự vào)
input double          InpEntryPullATR     = 0;          // Chờ giá hồi trước khi vào (× ATR, 0 = vào ngay)
input int             InpEntryPullMode    = 0;          // Hết nến mà giá chưa hồi: 0 = bỏ, 1 = vào giá thị trường
input int             InpReEntryMax       = 0;          // Vào lại sau khi dính SL: tối đa (lần, 0 = tắt)
input int             InpReEntryBars      = 6;          // Chỉ vào lại trong vòng (số nến khung chính)
input double          InpPyramidLotFactor = 0.5;        // Hệ số giảm lot mỗi lớp nhồi chính (0–1)
input int             InpPyramidMax       = 1;          // Nhồi lệnh: tổng số lớp tối đa (1 = tắt)
input double          InpPyramidStepATR   = 1.0;        // Nhồi thêm khi giá đi tiếp (× ATR)
input int             InpPyramidTFmin     = 0;          // Kiểm tra nhồi mỗi (phút, 0 = mỗi nến khung chính)

input group "7. Dừng lỗ và chốt lời"
input double          InpMinSLATRMult     = 1.0;        // SL tối thiểu theo ATR (0 = tắt)
input double          InpATRMult          = 2.5;        // Dừng lỗ (SL) = ATR ×
input int             InpSLTFmin          = 0;          // Tính SL theo ATR khung (phút, 0 = khung chính)
input double          InpRR               = 0.0;        // Chốt lời (TP) = SL × (0 = không đặt TP)
input bool            InpUseTrailing      = true;       // Trailing stop theo ATR
input double          InpTrailStartR      = 0.0;        // Bắt đầu trailing khi lãi đạt (R)
input double          InpTrailATRMult     = 3.0;        // Khoảng cách trailing = ATR ×
input bool            InpUseBreakeven     = false;      // Dời SL về hòa vốn
input double          InpBreakevenR       = 1.0;        // Dời về hòa vốn khi lãi đạt (R)
input double          InpBEBufferR        = 0.05;       // Cộng thêm vào mức hòa vốn (R)
input bool            InpUsePartial       = false;      // Chốt lời một phần
input double          InpPartialR         = 1.0;        // Chốt một phần khi lãi đạt (R)
input double          InpPartialPct       = 50.0;       // Tỷ lệ khối lượng chốt (%)
input bool            InpExitOnEMA        = false;      // Đóng hết khi nến cắt EMA nhanh ngược chiều
input bool            InpExitOnBar        = false;      // Đóng hết ở nến đầu tiên đóng ngược chiều

input group "8. Khối lượng và rủi ro"
input double          InpRiskPercent      = 1.0;        // Rủi ro mỗi lệnh (% vốn)
input double          InpMaxRiskRoundUp   = 0.0;        // Vào lot tối thiểu nếu rủi ro thật ≤ (%, 0 = bỏ lệnh)
input bool            InpDDScale          = false;      // Giảm rủi ro khi đang sụt giảm
input string          InpCorrSymbols      = "BTCUSDm,ETHUSDm"; // Nhóm mã đi cùng nhau
input double          InpCorrRiskScale    = 0.5;        // Hệ số rủi ro khi mã cùng nhóm đang có lệnh (1 = tắt)
input double          InpMaxGroupRiskPct  = 1.5;        // Tổng rủi ro tối đa của cả nhóm (%, 0 = tắt)

input group "9. Giờ giao dịch và giới hạn"
input bool            InpAllowBuy         = true;       // Chiến lược chính: cho phép mua (Buy)
input bool            InpAllowSell        = true;       // Chiến lược chính: cho phép bán (Sell)
input int             InpMaxTradesPerDay  = 0;          // Số lệnh tối đa mỗi ngày (0 = không giới hạn)
input int             InpCooldownBars     = 0;          // Nghỉ sau lệnh thua (số nến, 0 = tắt)
input int             InpMaxSpreadPoints  = 0;          // Spread tối đa (point, 0 = tắt)
input bool            InpSkipWeekend      = false;      // Không vào lệnh mới vào thứ Bảy và Chủ nhật
input int             InpBlock1Start      = -1;         // Khung nghỉ 1: từ giờ (giờ server, −1 = tắt)
input int             InpBlock1End        = 14;         // Khung nghỉ 1: đến giờ
input int             InpBlock2Start      = -1;         // Khung nghỉ 2: từ giờ (giờ server, −1 = tắt)
input int             InpBlock2End        = 20;         // Khung nghỉ 2: đến giờ

input group "10. Bảo vệ tài khoản"
input double          InpMaxDailyLossPct  = 3.0;        // Khóa lỗ trong ngày (% vốn bot, 0 = tắt)
input bool            InpCloseOnDailyLoss = true;       // Đóng lệnh đang mở khi chạm khóa lỗ ngày
input double          InpMaxDrawdownPct   = 15.0;       // Dừng hẳn khi sụt từ đỉnh (% vốn bot, 0 = tắt)
input bool            InpCloseOnHalt      = true;       // Đóng hết lệnh khi dừng hẳn
input bool            InpResetHalt        = false;      // Mở khóa và đặt lại mốc vốn (bật 1 lần rồi tắt)
input double          InpCapital          = 0;          // Vốn dành cho bot (0 = cả tài khoản)

input group "11. Bảo vệ lệnh vào tay"
input bool            InpGuardManual      = false;      // Bật bảo vệ lệnh vào tay trên mã của chart này
input double          InpGuardSLPct       = 1.5;        // Lệnh chưa có SL: tự đặt SL cách giá vào (%, 0 = tắt)
input double          InpGuardMaxRiskPct  = 3.0;        // Rủi ro tối đa mỗi lệnh tay (% vốn, 0 = tắt)
input bool            InpGuardNoAverage   = true;       // Đóng ngay lệnh nhồi vào lệnh cùng chiều đang lỗ
input int             InpGuardMaxHoldH    = 24;         // Đóng lệnh tay đang lỗ sau (giờ, 0 = tắt)
input double          InpGuardHumanDayPct = 0.0;        // Bucket lỗ ngày lệnh tay (% vốn, 0 = tắt)
input double          InpGuardAlgoDayPct  = 0.0;        // Bucket lỗ ngày thuật toán (% vốn, 0 = tắt)
input double          InpGuardDayLossPct  = 5.0;        // Lỗ lệnh tay tối đa trong ngày (%, 0 = tắt)
input double          InpGuardMaxDDPct    = 15.0;       // Dừng hẳn khi vốn tài khoản sụt từ đỉnh (%, 0 = tắt)
input bool            InpGuardOldTrades   = false;      // Áp dụng cả cho lệnh đã mở trước khi bật
input bool            InpGuardPending     = true;       // Sửa cả lệnh chờ (Limit / Stop) trước khi khớp
input double          InpGuardBreakevenR  = 1.0;        // Lệnh tay lời bằng x lần rủi ro (R) thì dời SL về hòa vốn (0 = tắt)
input double          InpGuardTrailATR    = 2.0;        // Sau đó kéo SL theo giá, cách x × ATR (0 = tắt)
input int             InpGuardTrailTFmin  = 15;         // Khung ATR để kéo SL lệnh tay (phút, 0 = theo khung vào lệnh)
input double          InpGuardTPR         = 0.0;        // Chốt lời cố định khi lời x R (đặt TP, 0 = tắt)
input int             InpGuardMaxBars     = 0;          // Đóng lệnh chưa tới hòa vốn sau x nến (0 = tắt)
input double          InpGuardPyramidLotFactor = 0.5;   // Hệ số giảm lot nhồi lệnh tay (0–1)
input int             InpGuardPyramidMax  = 1;          // Tự nhồi lệnh tay: tổng số lớp tối đa (1 = tắt)
input double          InpGuardPyramidStepR = 1.0;       // Nhồi thêm khi giá đi tiếp (× R của lớp mới nhất)
input int             InpGuardPyramidTrend = 5;         // Chỉ nhồi khi ít nhất x / 9 khung cùng chiều (0 = bỏ qua)
input double          InpGuardBasketR     = 0.0;        // Chốt tất cả các lớp khi tổng lời đạt x R (0 = tắt)
input int             InpGuardRunTrend    = 0;          // Đạt mức chốt gộp mà còn ≥ x/9 khung cùng chiều thì để lời chạy tiếp (0 = tắt)
input bool            InpGuardRevExit     = false;      // Chốt sớm khi nến báo đảo chiều (đang lời)
input double          InpGuardRevMinR     = 0.5;        // Chỉ chốt đảo chiều khi tổng lời ít nhất x R
input double          InpGuardSpikeATR    = 0.0;        // Chốt ngay khi giá giật ngược x × ATR trong nến đang chạy (0 = tắt)
input int             InpGuardExitScope   = 0;          // Chốt gộp / đảo chiều áp dụng cho: 0 = chỉ lệnh bot mở, 1 = mọi lệnh tay
input bool            InpGuardBacktest    = false;      // Cho phép backtest bảo vệ và tự vào/nhồi
input bool            InpGuardAutoEntry   = false;      // TỰ GIAO DỊCH: bot tự mở lệnh, không cần bạn bấm (thử nghiệm)
input int             InpGuardAutoTrend   = 8;          // Tự vào khi ít nhất x / 9 khung cùng chiều
input bool            InpGuardAutoNeedHTF = true;       // Tự vào chỉ khi H1 và H4 cũng cùng chiều
input int             InpGuardAutoTFmin   = 5;          // Khung tìm điểm vào: nến hồi về EMA20 (phút: 1, 3, 5, 10, 15, 30)
input int             InpGuardAutoMaxDay  = 5;          // Số lệnh tự vào tối đa mỗi ngày (0 = không giới hạn)
input int             InpGuardAutoCooldownMin = 30;     // Nghỉ sau lệnh thua (phút, 0 = tắt)
input double          InpGuardAutoRiskPct = 0.0;        // Rủi ro mỗi lệnh tự vào (% vốn, 0 = lot nhỏ nhất)

input group "12. Nhật ký và kỷ luật giao dịch"
input bool            InpJournal          = true;       // Ghi nhật ký mọi giao dịch của tài khoản
input double          InpWarnProfitPct    = 20.0;       // Nhắc rút tiền khi lãi trong tháng đạt (%, 0 = tắt)
input double          InpWarnBigWinPct    = 10.0;       // Nhắc khi một lệnh lãi trên (% số dư, 0 = tắt)
input int             InpWarnRedepositDays = 7;         // Cảnh báo nạp lại trong (ngày sau khi rút, 0 = tắt)
input double          InpMonthDepositCap  = 0;          // Cảnh báo khi tổng nạp trong tháng vượt (tiền tài khoản, 0 = tắt)
input double          InpWarnLotJump      = 2.0;        // Cảnh báo lot tay lớn hơn (× lot thường dùng, 0 = tắt)
input int             InpWarnMaxTradesDay = 10;         // Cảnh báo khi vào quá (lệnh tay mỗi ngày, 0 = tắt)
input int             InpWarnLossStreak   = 3;          // Nhắc nghỉ sau (lệnh tay thua liên tiếp, 0 = tắt)

input group "13. Hiển thị và thông báo"
input bool            InpShowPanel        = true;       // Hiện bảng thông tin trên chart
input bool            InpTrendBoard       = true;       // Hiện bảng xu hướng M1 → D1
input bool            InpPushNotify       = true;       // Gửi thông báo về app MT5 trên điện thoại
input bool            InpTelegram         = false;      // Gửi thông báo qua Telegram
input string          InpTgToken          = "";         // Telegram: bot token
input string          InpTgChatId         = "";         // Telegram: chat id

input group "14. Hệ thống và backtest"
input ulong           InpMagic            = 20261105;   // Mã nhận diện lệnh của bot (magic number)
input int             InpManageEverySec   = 0;          // Kiểm tra lệnh mỗi (giây, 0 = mỗi tick)
input int             InpPreset           = 0;          // Backtest: số thứ tự cấu hình (0 = dùng thông số trên)
input string          InpTestLabel        = "";         // Backtest: tên lần chạy
input int             InpExportTFmin      = 0;          // Backtest: xuất dữ liệu nến (phút, 0 = tắt)


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
double          P_PyramidLotFactor;
double          P_PyramidStepATR;
int             P_PyramidTFmin;
int             P_SLTFmin;
int             P_ReEntryMax;
int             P_ReEntryBars;
int             P_MTFAlign;
int             P_ExportTFmin;
bool            P_ManualEntry;
bool            P_TrendBoard;
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
bool            P_BreakoutUseSentiment;
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
double          P_MinSLATRMult;
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
double          P_GuardPyramidLotFactor;
double          P_GuardHumanDayPct;
double          P_GuardAlgoDayPct;
bool            P_GuardBacktest;
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
   P_PyramidLotFactor = InpPyramidLotFactor;
   P_PyramidStepATR = InpPyramidStepATR;
   P_PyramidTFmin = InpPyramidTFmin;
   P_SLTFmin = InpSLTFmin;
   P_ReEntryMax = InpReEntryMax;
   P_ReEntryBars = InpReEntryBars;
   P_MTFAlign = InpMTFAlign;
   P_ExportTFmin = InpExportTFmin;
   P_ManualEntry = InpManualEntry;
   P_TrendBoard = InpTrendBoard;
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
   P_BreakoutUseSentiment = InpBreakoutUseSentiment;
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
   P_MinSLATRMult = InpMinSLATRMult;
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
   P_GuardPyramidLotFactor = InpGuardPyramidLotFactor;
   P_GuardHumanDayPct = InpGuardHumanDayPct;
   P_GuardAlgoDayPct = InpGuardAlgoDayPct;
   P_GuardBacktest = InpGuardBacktest;
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
   if(k == "InpPyramidLotFactor") { P_PyramidLotFactor = StringToDouble(v); return true; }
   if(k == "InpEntryPullATR") { P_EntryPullATR = StringToDouble(v); return true; }
   if(k == "InpEntryPullMode") { P_EntryPullMode = (int)StringToInteger(v); return true; }
   if(k == "InpManualEntry") { P_ManualEntry = (v == "true" || v == "1"); return true; }
   if(k == "InpTrendBoard") { P_TrendBoard = (v == "true" || v == "1"); return true; }
   if(k == "InpExportTFmin") { P_ExportTFmin = (int)StringToInteger(v); return true; }
   if(k == "InpMTFAlign") { P_MTFAlign = (int)StringToInteger(v); return true; }
   if(k == "InpSLTFmin") { P_SLTFmin = (int)StringToInteger(v); return true; }
   if(k == "InpReEntryMax") { P_ReEntryMax = (int)StringToInteger(v); return true; }
   if(k == "InpReEntryBars") { P_ReEntryBars = (int)StringToInteger(v); return true; }
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
   if(k == "InpBreakoutUseSentiment") { P_BreakoutUseSentiment = (v == "true" || v == "1"); return true; }
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
   if(k == "InpMinSLATRMult") { P_MinSLATRMult = StringToDouble(v); return true; }
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
   if(k == "InpGuardPyramidLotFactor") { P_GuardPyramidLotFactor = StringToDouble(v); return true; }
   if(k == "InpGuardHumanDayPct") { P_GuardHumanDayPct = StringToDouble(v); return true; }
   if(k == "InpGuardAlgoDayPct") { P_GuardAlgoDayPct = StringToDouble(v); return true; }
   if(k == "InpGuardBacktest") { P_GuardBacktest = (v == "true" || v == "1"); return true; }
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
#include "TrendBot/ManualEntry.mqh"
#include "TrendBot/Status.mqh"
#include "TrendBot/Panel.mqh"
#include "TrendBot/Report.mqh"

int OnInit()
{
   ResetRuntimeState();     // doi thong so / doi khung: MT5 KHONG nap lai bien toan cuc, phai tu xoa trang thai cu
   LoadParams();
   if(InpPreset > 0 && !ApplyPreset(InpPreset)) return INIT_PARAMETERS_INCORRECT;
   if(MQLInfoInteger(MQL_TESTER) && P_GuardBacktest)
   {
      // Moi optimization pass khong duoc thua huong bien global cua pass truoc.
      GlobalVariablesDeleteAll(GKey(""));
      GlobalVariableDel(GAcctKey("peak"));
      GlobalVariableDel(GAcctKey("halt"));
   }   // het cau hinh: bo qua lan nay
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
   hATRSL = P_SLTFmin > 0 ? iATR(_Symbol, TFFromMin(P_SLTFmin), P_ATRPeriod) : hATR;
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
      hATR == INVALID_HANDLE || hATRSL == INVALID_HANDLE || hADX == INVALID_HANDLE)
   {
      Print("Khong tao duoc chi bao");
      return INIT_FAILED;
   }
   if(P_TrendBoard && MEActive() && !TrendBoardInit()) Print("Khong tao duoc bang xu huong (EMA cac khung)");
   trade.SetExpertMagicNumber(P_Magic);
   trade.SetTypeFillingBySymbol(_Symbol);
   trade.SetDeviationInPoints(100);

   TryInitState();          // neu chua dang nhap, se thu lai o cac tick sau
   // Timer 500 ms (v5.10.13): kiem tra an toan lenh tay / chot loi ca khi khong co tick moi (thi truong im, tick bi gop)
   if(!MQLInfoInteger(MQL_TESTER) && InpGuardManual) EventSetMillisecondTimer(500);
   return INIT_SUCCEEDED;
}

// Khoi tao trang thai (moc von, thoi gian nghi...) CHI KHI da dang nhap va ket noi server.
// Tranh truong hop VPS khoi dong lai: OnInit chay luc login = 0, moc von bi luu sai ten.
bool g_stateReady = false;
// Goi dau OnInit. Khi doi thong so (hoac doi khung chart), MT5 chi goi lai OnDeinit/OnInit ma giu nguyen bien toan cuc:
// neu khong xoa, TryInitState bo qua (g_stateReady van true) nen doi "Von danh cho bot" khong dat lai moc, va moc dau ngay
// cu (vd 50 trieu) bi so voi von moi (1 trieu) -> bot tuong lo 98%, dung han va khoa lo ngay.
void ResetRuntimeState()
{
   g_stateReady   = false;
   g_botRiskLoaded = false;
   g_guardRiskLoaded = false;
   currentDay     = -1;
   dayStartEquity = 0;
   g_plDirty      = true;
}
bool TryInitState()
{
   if(g_stateReady) return true;
   if(AccountInfoInteger(ACCOUNT_LOGIN) <= 0 || !TerminalInfoInteger(TERMINAL_CONNECTED))
   {
      g_status = "Cho dang nhap tai khoan...";
      return false;
   }
   BotRiskLoad();  // khoi phuc peak/halt cua P_Magic
   GuardRiskLoad(); // khoi phuc moc peak/halt toan tai khoan; tester khong doc/ghi dia
   // Doi InpCapital so voi lan truoc thi tu dat lai moc, tranh dinh cu (vd. 3000) so voi von moi (1000)
   // bi hieu nham la sut giam 66% va bot dung han.
   bool capitalChanged = GlobalVariableCheck(GVName("capital")) && GVGet("capital") != P_Capital;
   if(P_ResetHalt || capitalChanged || !GlobalVariableCheck(GVName("base")))
   {
      ResetBaseline(P_ResetHalt);
      if(P_ResetHalt && !MQLInfoInteger(MQL_TESTER)) GuardResetHalt();   // mo ca dung han lenh tay / tu vao (InpGuardMaxDDPct)
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

void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   ManualChartEvent(id, sparam);
}

void OnDeinit(const int reason)
{
   EventKillTimer();
   ManualUIDelete();
   if(P_ExportTFmin > 0 && MQLInfoInteger(MQL_TESTER)) ExportBars();
   if(!MQLInfoInteger(MQL_TESTER)) { ReleaseMagic(); JournalRelease(); StatusRelease(); GuardOwnerRelease(); }
   IndicatorRelease(hFast);
   IndicatorRelease(hTrend);
   IndicatorRelease(hHTF);
   IndicatorRelease(hATR);
   if(hATRSL != hATR && hATRSL != INVALID_HANDLE) IndicatorRelease(hATRSL);
   IndicatorRelease(hADX);
   if(hRSI != INVALID_HANDLE) IndicatorRelease(hRSI);
   if(hATRD1 != INVALID_HANDLE) IndicatorRelease(hATRD1);
   if(hBB != INVALID_HANDLE) IndicatorRelease(hBB);
   if(hMACD != INVALID_HANDLE) IndicatorRelease(hMACD);
   if(hMACDH != INVALID_HANDLE) IndicatorRelease(hMACDH);
   if(hMkt != INVALID_HANDLE) IndicatorRelease(hMkt);
   ReleaseMTF();
   Comment("");
   PanelDelete();
   GuardRelease();
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
   if(!mtf || !EntryGatesOk() || !FundingOk(buy, P_Strategy == STRAT_DONCHIAN) || !MarketFiltersOk(buy, P_Strategy == STRAT_DONCHIAN))
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
   if(P_GuardAlgoDayPct > 0 && GuardBucketLocked(2)) { g_status = "Da khoa bucket thuat toan trong ngay"; return false; }
   if(DailyLossHit())   { g_status = "Cham gioi han lo ngay, nghi den mai"; return false; }
   // Khoa sut giam ca tai khoan cua bo bao ve (InpGuardMaxDDPct) chan ca chien luoc chinh (v5.10.16)
   if(GuardHalted())    { g_status = "DUNG HAN: von tai khoan sut qua gioi han"; return false; }
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
bool FundingOk(const bool buy, const bool breakout = false)
{
   // Donchian can giu cac dot bung no; chi loc funding neu nguoi dung chu dong bat.
   if(!P_UseFunding || (breakout && !P_BreakoutUseSentiment)) return true;
   double f = FundingNow();
   if(f != EMPTY_VALUE && ((buy && f > P_FundingMax) || (!buy && f < -P_FundingMax)))
   {
      g_fundBlocked++;
      g_status = StringFormat("Bo tin hieu vi funding %.3f%%", f);
      return false;
   }
   return true;
}
void OnTickBody();
// An toan truoc (bao ve lenh tay, chot loi), hien thi / bao cao sau. Goi tu OnTick va OnTimer (v5.10.13).
ulong g_gvFlush = 0;
void SafetyStep()
{
   GuardManual();                   // bao ve lenh tay (tu kiem tra moi 2 giay)
   GuardExit();                     // chot loi linh hoat: chot gop, de loi chay, chot khi dao chieu
   BotRiskSave();                   // sao luu peak/halt chien luoc chinh toi da 30s (tester skip)
   if((IsHalted() || GuardHalted()) && P_CloseOnHalt && HasOwnPosition()) CloseAll(); // ca khi thi truong khong co tick
   // Ghi Global Variable xuong dia moi 30 giay (v5.10.18): MT5 chi tu ghi khi tat binh thuong; mat dien / treo may thi
   // moc von, R ban dau, bo dem lenh, khoa ngay... khong bi mat qua 30 giay gan nhat.
   if(!MQLInfoInteger(MQL_TESTER) && GetTickCount64() - g_gvFlush >= 30000) { g_gvFlush = GetTickCount64(); GlobalVariablesFlush(); }
}

void OnTimer()
{
   if(!g_stateReady && !TryInitState()) return;
   ulong t0 = GetMicrosecondCount();
   SafetyStep();
   TickTimeRecord(GetMicrosecondCount() - t0);
}

void OnTick()
{
   ulong t0 = GetMicrosecondCount();
   OnTickBody();
   TickTimeRecord(GetMicrosecondCount() - t0);
}

void OnTickBody()
{
   if(!TryInitState()) return;      // chua dang nhap: chua lam gi ca
   SafetyStep();
   JournalScan();                   // nhat ky + canh bao ky luat (moi 15 giay, chi 1 chart / tai khoan)
   WriteStatus();                   // trang thai cho giao dien tren trinh duyet (moi 10 giay)
   ManualUI();                      // nut BUY/SELL (InpManualEntry) + bang xu huong (InpTrendBoard)
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
   // Tu nhoi / tu vao chay SAU khi da cap nhat lo ngay va sut giam cua chien luoc chinh (v5.10.13), va tu bo qua
   // khi chien luoc chinh dang dung han hoac cham lo ngay (MainStopped trong ManualEntry.mqh).
   GuardPyramid();                  // tu nhoi lenh tay theo xu huong (InpGuardPyramidMax)
   GuardAutoEntry();                // thu nghiem: bot tu vao lenh dau (InpGuardAutoEntry)
   ManagePositions();
   ReconcileClosed();
   CheckPendingEntry();             // tin hieu dang cho gia hoi ve: sau khi da cap nhat lo ngay / sut giam cua tick nay
   CheckReEntry();                  // vao lai sau khi bi cat lo (InpReEntryMax)
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
   if(P_ManualEntry) { g_status = "Cho ban bam BUY / SELL tren chart"; return; }
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
   if((buySignal || sellSignal) && !FundingOk(buySignal, P_Strategy == STRAT_DONCHIAN)) return;

   if((buySignal || sellSignal) && !MarketFiltersOk(buySignal, P_Strategy == STRAT_DONCHIAN)) return;

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
   if(SendEntry(buySignal, atr, false) > 0) ReEntryArm(buySignal, barTime);
}

// Vao lai sau khi bi cat lo (InpReEntryMax): nho huong + gia dong cua nen tin hieu trong InpReEntryBars nen khung chinh.
// Moi nen moi cua khung SL (InpSLTFmin), neu bot dang dung ngoai, lenh truoc dong lo, va gia dong cua vuot lai muc
// tin hieu (cung phia EMA nhanh khung chinh) thi vao lai, sau khi kiem tra lai moi dieu kien bat buoc.
int      g_reDir = 0, g_reCount = 0;
double   g_reLevel = 0;
datetime g_reExpire = 0;
void ReEntryArm(const bool buy, const datetime barTime)
{
   if(P_ReEntryMax <= 0) return;
   g_reDir = buy ? 1 : -1; g_reCount = 0;
   g_reLevel = iClose(_Symbol, P_TF, 1);
   int nb = P_ReEntryBars > 0 ? P_ReEntryBars : 1;
   g_reExpire = barTime + nb * PeriodSeconds(P_TF);
}
// Lai/lo cua deal dong gan nhat cua bot (0 neu chua co)
double LastOwnDealProfit()
{
   if(!HistorySelect(TimeCurrent() - 30 * 86400, TimeCurrent() + 60)) return 0;
   for(int i = HistoryDealsTotal() - 1; i >= 0; i--)
   {
      ulong d = HistoryDealGetTicket(i);
      if(d == 0 || HistoryDealGetInteger(d, DEAL_MAGIC) != (long)P_Magic || HistoryDealGetString(d, DEAL_SYMBOL) != _Symbol) continue;
      long e = HistoryDealGetInteger(d, DEAL_ENTRY);
      if(e != DEAL_ENTRY_OUT && e != DEAL_ENTRY_INOUT) continue;
      return HistoryDealGetDouble(d, DEAL_PROFIT) + HistoryDealGetDouble(d, DEAL_SWAP) + HistoryDealGetDouble(d, DEAL_COMMISSION);
   }
   return 0;
}
void CheckReEntry()
{
   if(g_reDir == 0) return;
   if(TimeCurrent() >= g_reExpire || g_reCount >= P_ReEntryMax || IsHalted()) { g_reDir = 0; return; }
   if(HasOwnPosition() || g_pendDir != 0) return;
   static datetime lastReBar = 0;
   ENUM_TIMEFRAMES tf = P_SLTFmin > 0 ? TFFromMin(P_SLTFmin) : P_TF;
   datetime bt = iTime(_Symbol, tf, 0);
   if(bt == 0 || bt == lastReBar) return;
   lastReBar = bt;
   if(LastOwnDealProfit() >= 0) { g_reDir = 0; return; }   // lenh truoc dong co lai (trailing): xong tin hieu, khong vao lai
   bool buy = g_reDir > 0;
   double c = iClose(_Symbol, tf, 1), fast, atr;
   if(!GetValue(hFast, 0, 1, fast) || !GetValue(hATR, 0, 1, atr)) return;
   if(buy ? (c <= g_reLevel || c <= fast) : (c >= g_reLevel || c >= fast)) return;
   if(!MTFOk(buy) || !EntryGatesOk() || !FundingOk(buy, P_Strategy == STRAT_DONCHIAN) || !MarketFiltersOk(buy, P_Strategy == STRAT_DONCHIAN)) return;
   g_sigSL = 0; g_sigTP = 0;
   int r = SendEntry(buy, atr, true);
   if(r == 0) { lastReBar = 0; return; }   // chua lay duoc khoa chung: thu lai o tick sau
   g_reCount++;
   if(r > 0) g_reEntries++;
}

// Gui lenh vao (dung chung cho vao ngay va vao khi gia hoi ve).
// Tra ve 1 = server da khop, 0 = chua lay duoc khoa chung (thu lai o tick sau), -1 = khong vao (lot, TP, server tu choi...).
int SendEntry(const bool buySignal, const double atr, const bool fromPending)
{
   // Mot so chien luoc luot song tu dat SL (theo cau truc gia) va TP (gia cu the)
   double slAtr = SLAtr(atr);
   double slDist   = g_sigSL > 0 ? g_sigSL : slAtr * P_ATRMult;
   if(P_MinSLATRMult > 0 && slAtr > 0) slDist = MathMax(slDist, slAtr * P_MinSLATRMult);
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
   if(g_lastRisk > GuardAlgoBudgetRemaining() + 1e-8)
   {
      g_status = "Bucket thuat toan con lai khong du cho rui ro lenh moi";
      GroupUnlock(); return -1;
   }
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
   LogStopSlippage(trans.deal);                     // truot gia khi cham SL / TP (moi magic tren ma nay, v5.10.13)
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
