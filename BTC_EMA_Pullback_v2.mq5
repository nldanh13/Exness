//+------------------------------------------------------------------+
//| BTC_EMA_Pullback_v2.mq5 (TrendBot)                               |
//| EA theo xu huong: Donchian breakout (mac dinh) hoac EMA pullback |
//| File nay chi chua tham so va thu tu chay; logic nam trong        |
//| thu muc TrendBot/ (moi file mot viec, xem dau moi file).         |
//| CHI DUNG DE THU NGHIEM - BACKTEST VA CHAY DEMO TRUOC             |
//+------------------------------------------------------------------+
#define  BOT_VERSION "5.42.1"
#property version   "5.4210"
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
   STRAT_IMOM         = 8,   // Thử nghiệm: quán tính trong ngày
   STRAT_FIBVP        = 9,   // Thử nghiệm: Fibonacci + Volume Profile
   STRAT_DIVCVD       = 10,  // Thử nghiệm: phân kỳ RSI xác nhận bằng CVD
   STRAT_BIGTRADE     = 11,  // Thử nghiệm: Big Trades (lệnh lớn) tại vùng quan trọng
   STRAT_DISTRIB      = 12,  // Thử nghiệm: hộp phân phối / tích lũy, vào ở lần test lại
   STRAT_GRID         = 13,  // Thử nghiệm: đánh lưới trong vùng đi ngang
   STRAT_KNIFE        = 14,  // Thử nghiệm: không bắt dao rơi – thử nhỏ, vào lớn sau đáy, giữ lệnh
   STRAT_OB           = 15,  // Thử nghiệm: order block – vào theo cách giá phản ứng tại vùng
   STRAT_DOW          = 16,  // Thử nghiệm: lý thuyết Dow – theo thủy triều, vào ở cuối con sóng ngược chiều
   STRAT_VWAP         = 17,  // Thử nghiệm: VWAP trong ngày + 3 cặp dải – theo xu hướng / bắt nhịp kéo về
   STRAT_KEYVOL       = 18,  // Thử nghiệm: vùng Key Volume – nơi thị trường giao dịch nhiều nhất
   STRAT_SIMPLE       = 19,  // Thử nghiệm: 3 câu hỏi – mùa gì, cá tụ ở đâu, phao đã động chưa
   STRAT_NEWS         = 20,  // Thử nghiệm: ngày có tin – chờ cú quét thanh khoản xong rồi đi theo hướng thật
   STRAT_PD           = 21,  // Thử nghiệm: premium / discount khung ngày + quét, xác nhận, FVG khung chính
   STRAT_CHAIN        = 22,  // Thử nghiệm: chuỗi phân tích – thủy triều → vị trí → setup đồng thuận trên 1 khung
   STRAT_AUTO         = 23,  // Tự động: 1 chart tự chuyển sang chiến lược đứng đầu bảng xếp hạng
   STRAT_SMART        = 24   // Thử nghiệm: theo tình huống – nhận diện thị trường rồi dùng đúng bộ kiến thức
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
input bool            InpBreakRetest      = false;      // Chỉ vào khi giá hồi về test lại vùng vừa phá và giữ được
input int             InpBreakRetestBars  = 6;          // Chờ test lại tối đa (số nến)
input double          InpBreakRetestATR   = 0.3;        // Test lại: chạm trong (× ATR quanh mép kênh)
input int             InpBreakSkipOpenMin = 0;          // Bỏ phá vỡ trong (phút) đầu phiên Á / London / New York (0 = tắt)
input bool            InpFakeoutFade      = false;      // Phá vỡ giả (đóng cửa quay vào): đánh chiều ngược lại

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
input bool            InpFvgCandle        = false;      // FVG: chờ nến xác nhận (búa, nhấn chìm, sao mai...)
input int             InpRangeBars        = 20;         // Spring: độ dài vùng đi ngang (số nến)
input double          InpRangeMaxATR      = 4.0;        // Spring: vùng đi ngang rộng tối đa (× ATR)
input bool            InpSpringFull       = false;      // Spring: chờ đủ chuỗi spring – test – phá nắp – hồi về
input double          InpSpringDepthATR   = 1.5;        // Spring: thủng đáy hộp không quá (× ATR)
input double          InpSpringDropATR    = 4.0;        // Spring: cú giảm trước hộp ít nhất (× ATR)
input int             InpImomMode         = 0;          // Quán tính: 0 = kết hợp, 1 = nửa giờ đầu, 2 = nửa giờ kế cuối
input int             InpFibLookback      = 100;        // Fib + VP: tìm con sóng trong (số nến)
input double          InpFibMinSwingATR   = 4.0;        // Fib + VP: con sóng tối thiểu (× ATR)
input int             InpVPBins           = 40;         // Fib + VP: số ô giá của Volume Profile
input double          InpVPHighMult       = 1.2;        // Fib + VP: vùng dày khi số tick ≥ (× trung bình các ô)
input int             InpVPTFmin          = 5;          // Fib + VP: khung đếm tick (phút, 0 = khung chính)
input double          InpFibMinRR         = 1.0;        // Fib + VP: lãi tới đỉnh/đáy sóng tối thiểu (× SL)
input int             InpDivRsiPeriod     = 14;         // RSI + CVD: chu kỳ RSI (số nến)
input int             InpDivLookback      = 40;         // RSI + CVD: tìm đỉnh / đáy trong (số nến)
input int             InpDivPivot         = 3;          // RSI + CVD: đỉnh / đáy cần thấp hơn / cao hơn (số nến mỗi bên)
input double          InpDivRsiLow        = 30.0;       // RSI + CVD: quá bán dưới (quá mua = 100 − mức này)
input int             InpAbsorbBars       = 5;          // RSI + CVD: hấp thụ xét trong (số nến gần nhất)
input double          InpAbsorbDelta      = 0.15;       // RSI + CVD: CVD đổ ít nhất (× tổng khối lượng các nến đó)
input double          InpBigMult          = 3.0;        // Big Trades: bong bóng khi khối lượng nến ≥ (× TB 20 nến)
input double          InpBigMinDelta      = 0.10;       // Big Trades: phe chủ động áp đảo tối thiểu (delta)
input int             InpBigLookback      = 60;         // Big Trades: xét trong (số nến)
input double          InpBigZoneATR       = 0.5;        // Big Trades: gần đỉnh / đáy cũ trong (× ATR)
input int             InpBigClusterMin    = 3;          // Big Trades: chuỗi thanh lý cần ít nhất (bong bóng)
input int             InpBigClusterBars   = 6;          // Big Trades: chuỗi thanh lý trong (số nến)
input int             InpDistLookback     = 120;        // Phân phối: xét trong (số nến)
input double          InpDistClimaxATR    = 1.5;        // Phân phối: nến hưng phấn dài tối thiểu (× ATR)
input int             InpDistBoxMin       = 8;          // Phân phối: hộp đi ngang tối thiểu (số nến)
input double          InpDistBoxMaxATR    = 8.0;        // Phân phối: hộp cao tối đa (× ATR)
input bool            InpDistNeedUT       = false;      // Phân phối: bắt buộc có cú phá đỉnh giả
input int             InpGridBars         = 100;        // Lưới: tìm vùng đi ngang trong (số nến)
input double          InpGridMinATR       = 4.0;        // Lưới: vùng cao tối thiểu (× ATR)
input double          InpGridMaxATR       = 15.0;       // Lưới: vùng cao tối đa (× ATR)
input double          InpGridMaxADX       = 20.0;       // Lưới: chỉ giăng khi ADX dưới
input int             InpGridLevels       = 8;          // Lưới: số nấc tối đa
input double          InpGridMinStepCost  = 5.0;        // Lưới: mỗi mắt lưới ≥ (× spread)
input double          InpGridStopATR      = 0.5;        // Lưới: điểm dừng dưới đáy vùng (× ATR)

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
input bool            InpDowFilter        = false;      // Lý thuyết Dow: chỉ giao dịch theo chiều thủy triều
input ENUM_TIMEFRAMES InpDowTF            = PERIOD_D1;  // Dow: khung của thủy triều
input int             InpDowPivot         = 3;          // Dow: đỉnh / đáy = cao / thấp nhất trong ± (số nến)
input int             InpDowLateLegs      = 4;          // Dow: giai đoạn cuối từ lần phá đỉnh thứ (0 = không xét)
input bool            InpDowVolume        = false;      // Dow: volume phải xác nhận thủy triều

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
input int             InpNewsPreMin       = 0;          // Trước giờ tin (phút): không mở lệnh mới (0 = tắt)
input int             InpNewsProtect      = 0;          // Trước giờ tin, lệnh đang lời: 0 = để yên, 1 = SL về hòa vốn, 2 = chốt nửa + hòa vốn
input bool            InpNewsNFP          = false;      // Backtest: thêm lịch NFP ước lượng (chưa đối chiếu BLS)
input bool            InpNewsWeekly       = false;      // Sáng thứ Hai: gửi lịch tin Mỹ quan trọng trong tuần
input bool            InpUseFlow          = false;      // Xác nhận bằng dòng tiền Binance (chưa kiểm thử)
input double          InpFlowMinDelta     = 0.10;       // Dòng tiền: phá vỡ cần delta chủ động ≥
input double          InpFlowBigMult      = 1.5;        // Dòng tiền: khối lượng nến ≥ (× TB 20 nến, 0 = tắt)
input double          InpFlowHoldPos      = 0.6;        // Dòng tiền: nến giữ được ≥ (phần biên độ theo chiều lệnh)

input group "6. Cách vào lệnh"
input bool            InpManualEntry      = false;      // Tự bấm BUY / SELL trên chart (bot không tự vào)
input double          InpEntryPullATR     = 0;          // Chờ giá hồi trước khi vào (× ATR, 0 = vào ngay)
input int             InpEntryPullMode    = 0;          // Hết nến mà giá chưa hồi: 0 = bỏ, 1 = vào giá thị trường
input int             InpScaleParts       = 1;          // Giải vốn: chia lệnh thành (phần, 1 = vào hết một lần)
input double          InpScaleStepATR     = 0.5;        // Giải vốn: mỗi phần sau đặt sâu hơn (× ATR)
input int             InpScaleBars        = 6;          // Giải vốn: hủy phần chưa khớp sau (số nến)
input int             InpReEntryMax       = 0;          // Vào lại sau khi dính SL: tối đa (lần, 0 = tắt)
input int             InpReEntryBars      = 6;          // Chỉ vào lại trong vòng (số nến khung chính)
input bool            InpAutoSelect       = false;      // Tự chọn chiến lược: chỉ vào lệnh khi chiến lược này đứng đầu
input int             InpSelectMaxAgeDays = 10;         // Bảng xếp hạng cũ hơn (ngày) thì chỉ Donchian H4 được vào
input double          InpPyramidLotFactor = 0.5;        // Hệ số giảm lot mỗi lớp nhồi chính (0–1)
input int             InpPyramidMax       = 1;          // Nhồi lệnh: tổng số lớp tối đa (1 = tắt)
input double          InpPyramidStepATR   = 1.0;        // Nhồi thêm khi giá đi tiếp (× ATR)
input int             InpPyramidTFmin     = 0;          // Kiểm tra nhồi mỗi (phút, 0 = mỗi nến khung chính)
input bool            InpPyramidRetest    = false;      // Chỉ nhồi khi giá phá đỉnh mới rồi hồi về giữ được
input double          InpPyramidStopPct   = 0;          // Ngừng nhồi khi giá đã đi (% đường tới mục tiêu, 0 = tắt)
input int             InpTrailSwingBars   = 0;          // Giữ lệnh: SL dưới đáy / trên đỉnh mới (số nến, 0 = tắt)
input int             InpPyramidSLBars    = 0;          // Nhồi: SL chung dưới đáy / trên đỉnh (số nến, 0 = tắt)

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
input int             InpBESwingBars      = 0;          // Hoặc khi nến đóng cửa qua đỉnh gần nhất trước lệnh (số nến, 0 = tắt)
input double          InpBEBufferR        = 0.05;       // Cộng thêm vào mức hòa vốn (R)
input bool            InpUsePartial       = false;      // Chốt lời một phần
input double          InpPartialR         = 1.0;        // Chốt một phần khi lãi đạt (R)
input double          InpPartialPct       = 50.0;       // Tỷ lệ khối lượng chốt (%)
input bool            InpExitOnEMA        = false;      // Đóng hết khi nến cắt EMA nhanh ngược chiều
input bool            InpExitOnBar        = false;      // Đóng hết ở nến đầu tiên đóng ngược chiều
input int             InpSLStructBars     = 0;          // SL dưới cấu trúc: đáy / đỉnh của (số nến, 0 = tắt)
input double          InpSLStructMinATR   = 1.5;        // SL dưới cấu trúc: không sát hơn (× ATR)
input int             InpStallBars        = 0;          // Lệnh đứng yên: thoát sau (số nến, 0 = tắt)
input double          InpStallMinATR      = 0.5;        // Lệnh đứng yên: chưa đi được (× ATR) thì thoát
input double          InpSessPartialR     = 0;          // Hết giờ cao điểm: chốt một nửa nếu đang lời (R, 0 = tắt)
input int             InpKnifeLookback    = 60;         // Dao rơi: tìm đáy trong (số nến)
input int             InpKnifeBars        = 30;         // Dao rơi: cú giảm diễn ra trong tối đa (số nến)
input double          InpKnifeDropATR     = 6.0;        // Dao rơi: cú giảm dài ít nhất (× ATR)
input double          InpKnifeProbePct    = 25;         // Dao rơi: lệnh thử ở đáy dùng (% rủi ro chuẩn, 0 = không thử)
input double          InpKnifeRetestATR   = 0.3;        // Dao rơi: nến test lại cách đỉnh gần nhất tối đa (× ATR)
input int             InpOBLookback       = 60;         // Order block: tìm trong (số nến)
input double          InpOBImpulseATR     = 1.5;        // Order block: cú đẩy sau nến OB ít nhất (× ATR)
input double          InpOBMaxATR         = 2.5;        // Order block: vùng rộng tối đa (× ATR)
input int             InpOBStallBars      = 6;          // Order block: lình xình trong vùng quá (số nến) thì đứng ngoài
input bool            InpOBBreaker        = true;       // Order block thủng: đánh khi giá hồi lên vùng thành kháng cự
input int             InpVwapMode         = 0;          // VWAP: 0 = cả hai cách, 1 = theo xu hướng, 2 = bắt nhịp kéo về
input double          InpVwapBand1        = 1.0;        // VWAP: cặp đường 1 (× độ lệch chuẩn)
input double          InpVwapBand2        = 2.0;        // VWAP: cặp đường 2 – chốt lời cách 1 (× độ lệch chuẩn)
input double          InpVwapBand3        = 3.0;        // VWAP: cặp đường 3 – bắt nhịp kéo về (× độ lệch chuẩn)
input double          InpVwapMinRR        = 1.0;        // VWAP: bỏ nếu lời tới mục tiêu nhỏ hơn (× SL)
input int             InpKVLookback       = 200;        // Key Volume: Volume Profile trong (số nến)
input int             InpKVBins           = 50;         // Key Volume: số ô giá của Volume Profile
input double          InpKVHighMult       = 1.5;        // Key Volume: ô volume cao ≥ (× trung bình)
input double          InpKVMaxATR         = 2.0;        // Key Volume: vùng rộng tối đa (× ATR)
input int             InpKVMinBars        = 8;          // Key Volume: giá từng đi ngang trong vùng ít nhất (số nến)
input int             InpKVMinReact       = 1;          // Key Volume: giá đã quay về và phản ứng ít nhất (lần)
input int             InpSimpleLevels     = 3;          // 3 câu hỏi: số đường kẻ ngang
input int             InpSimpleLookback   = 200;        // 3 câu hỏi: tìm chỗ giá từng quay đầu trong (số nến)
input int             InpSimplePivot      = 5;          // 3 câu hỏi: chỗ quay đầu = cao / thấp nhất trong ± (số nến)
input bool            InpLearnApply       = false;      // Cho kết quả thực chiến can thiệp quyết định (tắt = chỉ theo kiến thức)
input bool            InpLearn            = true;       // Ghi lại kết quả thực chiến (lệnh giấy + lệnh thật) để tham khảo
input int             InpLearnMinN        = 20;         // Học: đánh giá sau (số lệnh giấy mỗi cặp tình huống / chiến lược)
input double          InpLearnTryRisk     = 0.5;        // Học: rủi ro khi chưa đủ dữ liệu (× rủi ro chuẩn)
input int             InpLearnMaxBars     = 48;         // Học: lệnh giấy hết hạn sau (số nến)
input double          InpSmartTrendADX    = 25;         // Tình huống: xu hướng mạnh khi ADX từ
input double          InpSmartRangeADX    = 20;         // Tình huống: đi ngang khi ADX dưới
input int             InpSmartRangeBars   = 40;         // Tình huống: hộp đi ngang (số nến)
input double          InpSmartRangeATR    = 6.0;        // Tình huống: hộp đi ngang cao tối đa (× ATR)
input int             InpSmartNewsMin     = 60;         // Tình huống: đứng ngoài trước tin lớn (phút)
input string          InpChainList        = "15,5,18,19,21,6,16,1,17"; // Chuỗi: các chiến lược soi setup (thứ tự ưu tiên)
input bool            InpChainPD          = true;       // Chuỗi: mua chỉ ở vùng rẻ, bán chỉ ở vùng đắt (hộp D1)
input int             InpChainFullCount   = 2;          // Chuỗi: đủ rủi ro khi có từ (số setup cùng chiều)
input double          InpChainOneRisk     = 0.5;        // Chuỗi: rủi ro khi chỉ có 1 setup (× rủi ro chuẩn)
input int             InpPDDays           = 60;         // Premium / discount: hộp giá khung ngày (số nến D1)
input int             InpPDLookback       = 60;         // Premium / discount: tìm cú quét + FVG trong (số nến khung chính)
input int             InpNewsWindowMin    = 240;        // Quét tin: tìm tín hiệu trong (phút) sau giờ tin
input int             InpNewsRangeMin     = 180;        // Quét tin: vùng đi ngang trước tin (phút)
input double          InpNewsRangeMaxATR  = 4.0;        // Quét tin: vùng trước tin cao tối đa (× ATR)
input double          InpHedgeLockLossR   = 0;          // Khóa lỗ: lệnh lỗ (R) thì mở lệnh ngược chiều (0 = tắt)
input double          InpHedgeLockProfitR = 0;          // Khóa lời trước tin / cuối tuần: lệnh lời (R, 0 = tắt)
input bool            InpHedgeNews        = true;       // Khóa lời trước tin Mỹ
input int             InpHedgeFriHour     = 20;         // Khóa lời cuối tuần: từ giờ thứ Sáu (giờ server, −1 = tắt)
input int             InpHedgeZoneBars    = 20;         // Vùng giá quan trọng khi khóa (số nến)
input double          InpHedgeRetestATR   = 0.3;        // Mở khóa: nến test lại cách mép vùng tối đa (× ATR)
input int             InpHedgeMaxBars     = 48;         // Khóa quá (số nến) chưa xác nhận thì đóng cả hai (0 = không giới hạn)

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
input int             InpSessionStartH    = -1;         // Chỉ vào lệnh từ giờ (giờ server, −1 = cả ngày)
input int             InpSessionEndH      = -1;         // Chỉ vào lệnh đến giờ
input int             InpSession2StartH   = -1;         // Giờ cao điểm 2: từ giờ (−1 = không dùng)
input int             InpSession2EndH     = -1;         // Giờ cao điểm 2: đến giờ

input group "10. Bảo vệ tài khoản"
input double          InpMaxDailyLossPct  = 3.0;        // Khóa lỗ trong ngày (% vốn bot, 0 = tắt)
input bool            InpCloseOnDailyLoss = true;       // Đóng lệnh đang mở khi chạm khóa lỗ ngày
input double          InpMaxDrawdownPct   = 15.0;       // Dừng hẳn khi sụt từ đỉnh (% vốn bot, 0 = tắt)
input bool            InpCloseOnHalt      = true;       // Đóng hết lệnh khi dừng hẳn
input bool            InpResetHalt        = false;      // Mở khóa và đặt lại mốc vốn (bật 1 lần rồi tắt)
input double          InpCapital          = 0;          // Vốn dành cho bot (0 = cả tài khoản)
input double          InpLiveExpR         = 0.31;       // Theo dõi chạy thật: kỳ vọng mỗi lệnh từ backtest (R, 0 = tắt)
input double          InpLiveSdR          = 1.69;       // Theo dõi chạy thật: độ lệch chuẩn mỗi lệnh từ backtest (R)

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
input int             InpTrials           = 1;          // Backtest: số cấu hình đã thử cạnh tranh (để tính Sharpe điều chỉnh)
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
double          P_BreakMaxATR, P_BreakRetestATR;
bool            P_BreakRetest, P_FakeoutFade, P_FvgCandle, P_DowFilter, P_DowVolume;
ENUM_TIMEFRAMES P_DowTF;
int             P_DowPivot, P_DowLateLegs, P_VwapMode;
double          P_VwapBand1, P_VwapBand2, P_VwapBand3, P_VwapMinRR, P_KVHighMult, P_KVMaxATR;
int             P_KVLookback, P_KVBins, P_KVMinBars, P_KVMinReact, P_SimpleLevels, P_SimpleLookback, P_SimplePivot;
int             P_NewsPreMin, P_NewsProtect, P_NewsWindowMin, P_NewsRangeMin;
bool            P_NewsWeekly, P_NewsNFP;
int             P_ScaleParts, P_ScaleBars, P_BESwingBars;
bool            P_SpringFull;
int             P_PDDays, P_PDLookback, P_ChainFullCount;
string          P_ChainList;
bool            P_ChainPD;
double          P_ChainOneRisk, P_SmartTrendADX, P_SmartRangeADX, P_SmartRangeATR, P_LearnTryRisk;
bool            P_Learn, P_LearnApply;
int             P_LearnMinN, P_LearnMaxBars;
int             P_SmartRangeBars, P_SmartNewsMin;
double          P_SpringDepthATR, P_SpringDropATR;
double          P_ScaleStepATR;
double          P_NewsRangeMaxATR;
int             P_BreakRetestBars, P_BreakSkipOpenMin;
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
bool            P_AutoSelect;
bool            P_UseFlow;
double          P_FlowMinDelta, P_FlowBigMult, P_FlowHoldPos;
int             P_SelectMaxAgeDays;
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
int             P_FibLookback, P_VPBins, P_VPTFmin;
double          P_FibMinSwingATR, P_VPHighMult, P_FibMinRR;
int             P_DivRsiPeriod, P_DivLookback, P_DivPivot, P_AbsorbBars;
double          P_DivRsiLow, P_AbsorbDelta;
int             P_BigLookback, P_BigClusterMin, P_BigClusterBars;
double          P_BigMult, P_BigMinDelta, P_BigZoneATR;
int             P_DistLookback, P_DistBoxMin;
double          P_DistClimaxATR, P_DistBoxMaxATR;
bool            P_DistNeedUT;
int             P_GridBars, P_GridLevels;
int             P_SessionStartH, P_SessionEndH, P_SLStructBars, P_StallBars;
int             P_Session2StartH, P_Session2EndH, P_PyramidSLBars, P_HedgeFriHour, P_HedgeZoneBars, P_HedgeMaxBars;
bool            P_PyramidRetest, P_HedgeNews;
int             P_TrailSwingBars, P_KnifeLookback, P_KnifeBars;
double          P_KnifeDropATR, P_KnifeProbePct, P_KnifeRetestATR, P_PyramidStopPct, P_OBImpulseATR, P_OBMaxATR;
int             P_OBLookback, P_OBStallBars;
bool            P_OBBreaker;
double          P_SessPartialR, P_HedgeLockLossR, P_HedgeLockProfitR, P_HedgeRetestATR;
double          P_SLStructMinATR, P_StallMinATR;
double          P_GridMinATR, P_GridMaxATR, P_GridMaxADX, P_GridMinStepCost, P_GridStopATR;
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
   P_BreakRetest = InpBreakRetest; P_BreakRetestBars = InpBreakRetestBars; P_BreakRetestATR = InpBreakRetestATR;
   P_BreakSkipOpenMin = InpBreakSkipOpenMin; P_FakeoutFade = InpFakeoutFade;
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
   P_AutoSelect = InpAutoSelect; P_SelectMaxAgeDays = InpSelectMaxAgeDays;
   P_UseFlow = InpUseFlow; P_FlowMinDelta = InpFlowMinDelta; P_FlowBigMult = InpFlowBigMult; P_FlowHoldPos = InpFlowHoldPos;
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
   P_FvgLookback = InpFvgLookback; P_FvgCandle = InpFvgCandle;
   P_Learn = InpLearn; P_LearnApply = InpLearnApply; P_LearnMinN = InpLearnMinN; P_LearnTryRisk = InpLearnTryRisk; P_LearnMaxBars = InpLearnMaxBars;
   P_SmartTrendADX = InpSmartTrendADX; P_SmartRangeADX = InpSmartRangeADX; P_SmartRangeBars = InpSmartRangeBars;
   P_SmartRangeATR = InpSmartRangeATR; P_SmartNewsMin = InpSmartNewsMin;
   P_ChainList = InpChainList; P_ChainPD = InpChainPD; P_ChainFullCount = InpChainFullCount; P_ChainOneRisk = InpChainOneRisk;
   P_PDDays = InpPDDays; P_PDLookback = InpPDLookback;
   P_SpringFull = InpSpringFull; P_SpringDepthATR = InpSpringDepthATR; P_SpringDropATR = InpSpringDropATR;
   P_ScaleParts = InpScaleParts; P_ScaleStepATR = InpScaleStepATR; P_ScaleBars = InpScaleBars; P_BESwingBars = InpBESwingBars;
   P_NewsPreMin = InpNewsPreMin; P_NewsProtect = InpNewsProtect; P_NewsWeekly = InpNewsWeekly; P_NewsNFP = InpNewsNFP;
   P_NewsWindowMin = InpNewsWindowMin; P_NewsRangeMin = InpNewsRangeMin; P_NewsRangeMaxATR = InpNewsRangeMaxATR;
   P_SimpleLevels = InpSimpleLevels; P_SimpleLookback = InpSimpleLookback; P_SimplePivot = InpSimplePivot;
   P_KVLookback = InpKVLookback; P_KVBins = InpKVBins; P_KVHighMult = InpKVHighMult; P_KVMaxATR = InpKVMaxATR;
   P_KVMinBars = InpKVMinBars; P_KVMinReact = InpKVMinReact;
   P_VwapMode = InpVwapMode; P_VwapBand1 = InpVwapBand1; P_VwapBand2 = InpVwapBand2; P_VwapBand3 = InpVwapBand3; P_VwapMinRR = InpVwapMinRR;
   P_DowFilter = InpDowFilter; P_DowTF = InpDowTF; P_DowPivot = InpDowPivot; P_DowLateLegs = InpDowLateLegs; P_DowVolume = InpDowVolume;
   P_RangeBars = InpRangeBars;
   P_RangeMaxATR = InpRangeMaxATR;
   P_FibLookback = InpFibLookback; P_FibMinSwingATR = InpFibMinSwingATR; P_VPBins = InpVPBins;
   P_VPHighMult = InpVPHighMult; P_VPTFmin = InpVPTFmin; P_FibMinRR = InpFibMinRR;
   P_DivRsiPeriod = InpDivRsiPeriod; P_DivLookback = InpDivLookback; P_DivPivot = InpDivPivot;
   P_DivRsiLow = InpDivRsiLow; P_AbsorbBars = InpAbsorbBars; P_AbsorbDelta = InpAbsorbDelta;
   P_BigMult = InpBigMult; P_BigMinDelta = InpBigMinDelta; P_BigLookback = InpBigLookback; P_BigZoneATR = InpBigZoneATR;
   P_BigClusterMin = InpBigClusterMin; P_BigClusterBars = InpBigClusterBars;
   P_DistLookback = InpDistLookback; P_DistClimaxATR = InpDistClimaxATR; P_DistBoxMin = InpDistBoxMin;
   P_DistBoxMaxATR = InpDistBoxMaxATR; P_DistNeedUT = InpDistNeedUT;
   P_GridBars = InpGridBars; P_GridMinATR = InpGridMinATR; P_GridMaxATR = InpGridMaxATR; P_GridMaxADX = InpGridMaxADX;
   P_GridLevels = InpGridLevels; P_GridMinStepCost = InpGridMinStepCost; P_GridStopATR = InpGridStopATR;
   P_SessionStartH = InpSessionStartH; P_SessionEndH = InpSessionEndH; P_SLStructBars = InpSLStructBars;
   P_Session2StartH = InpSession2StartH; P_Session2EndH = InpSession2EndH; P_PyramidRetest = InpPyramidRetest;
   P_PyramidSLBars = InpPyramidSLBars; P_SessPartialR = InpSessPartialR; P_HedgeLockLossR = InpHedgeLockLossR;
   P_HedgeLockProfitR = InpHedgeLockProfitR; P_HedgeNews = InpHedgeNews; P_HedgeFriHour = InpHedgeFriHour;
   P_OBLookback = InpOBLookback; P_OBImpulseATR = InpOBImpulseATR; P_OBMaxATR = InpOBMaxATR;
   P_OBStallBars = InpOBStallBars; P_OBBreaker = InpOBBreaker;
   P_PyramidStopPct = InpPyramidStopPct; P_TrailSwingBars = InpTrailSwingBars; P_KnifeLookback = InpKnifeLookback; P_KnifeBars = InpKnifeBars;
   P_KnifeDropATR = InpKnifeDropATR; P_KnifeProbePct = InpKnifeProbePct; P_KnifeRetestATR = InpKnifeRetestATR;
   P_HedgeZoneBars = InpHedgeZoneBars; P_HedgeRetestATR = InpHedgeRetestATR; P_HedgeMaxBars = InpHedgeMaxBars;
   P_SLStructMinATR = InpSLStructMinATR; P_StallBars = InpStallBars; P_StallMinATR = InpStallMinATR;
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
   if(k == "InpBreakRetest") { P_BreakRetest = (v == "true" || v == "1"); return true; }
   if(k == "InpBreakRetestBars") { P_BreakRetestBars = (int)StringToInteger(v); return true; }
   if(k == "InpBreakRetestATR") { P_BreakRetestATR = StringToDouble(v); return true; }
   if(k == "InpBreakSkipOpenMin") { P_BreakSkipOpenMin = (int)StringToInteger(v); return true; }
   if(k == "InpFakeoutFade") { P_FakeoutFade = (v == "true" || v == "1"); return true; }
   if(k == "InpBreakMinVol") { P_BreakMinVol = StringToDouble(v); return true; }
   if(k == "InpRsiPeriod") { P_RsiPeriod = (int)StringToInteger(v); return true; }
   if(k == "InpRsiLow") { P_RsiLow = StringToDouble(v); return true; }
   if(k == "InpRsiHigh") { P_RsiHigh = StringToDouble(v); return true; }
   if(k == "InpExhaustATR") { P_ExhaustATR = StringToDouble(v); return true; }
   if(k == "InpFvgBigATR") { P_FvgBigATR = StringToDouble(v); return true; }
   if(k == "InpFvgLookback") { P_FvgLookback = (int)StringToInteger(v); return true; }
   if(k == "InpLearnApply") { P_LearnApply = (v == "true" || v == "1"); return true; }
   if(k == "InpLearn") { P_Learn = (v == "true" || v == "1"); return true; }
   if(k == "InpLearnMinN") { P_LearnMinN = (int)StringToInteger(v); return true; }
   if(k == "InpLearnTryRisk") { P_LearnTryRisk = StringToDouble(v); return true; }
   if(k == "InpLearnMaxBars") { P_LearnMaxBars = (int)StringToInteger(v); return true; }
   if(k == "InpSmartTrendADX") { P_SmartTrendADX = StringToDouble(v); return true; }
   if(k == "InpSmartRangeADX") { P_SmartRangeADX = StringToDouble(v); return true; }
   if(k == "InpSmartRangeBars") { P_SmartRangeBars = (int)StringToInteger(v); return true; }
   if(k == "InpSmartRangeATR") { P_SmartRangeATR = StringToDouble(v); return true; }
   if(k == "InpSmartNewsMin") { P_SmartNewsMin = (int)StringToInteger(v); return true; }
   if(k == "InpChainList") { P_ChainList = v; return true; }
   if(k == "InpChainPD") { P_ChainPD = (v == "true" || v == "1"); return true; }
   if(k == "InpChainFullCount") { P_ChainFullCount = (int)StringToInteger(v); return true; }
   if(k == "InpChainOneRisk") { P_ChainOneRisk = StringToDouble(v); return true; }
   if(k == "InpPDDays") { P_PDDays = (int)StringToInteger(v); return true; }
   if(k == "InpPDLookback") { P_PDLookback = (int)StringToInteger(v); return true; }
   if(k == "InpSpringFull") { P_SpringFull = (v == "true" || v == "1"); return true; }
   if(k == "InpSpringDepthATR") { P_SpringDepthATR = StringToDouble(v); return true; }
   if(k == "InpSpringDropATR") { P_SpringDropATR = StringToDouble(v); return true; }
   if(k == "InpScaleParts") { P_ScaleParts = (int)StringToInteger(v); return true; }
   if(k == "InpScaleStepATR") { P_ScaleStepATR = StringToDouble(v); return true; }
   if(k == "InpScaleBars") { P_ScaleBars = (int)StringToInteger(v); return true; }
   if(k == "InpBESwingBars") { P_BESwingBars = (int)StringToInteger(v); return true; }
   if(k == "InpNewsPreMin") { P_NewsPreMin = (int)StringToInteger(v); return true; }
   if(k == "InpNewsProtect") { P_NewsProtect = (int)StringToInteger(v); return true; }
   if(k == "InpNewsNFP") { P_NewsNFP = (v == "true" || v == "1"); return true; }
   if(k == "InpNewsWeekly") { P_NewsWeekly = (v == "true" || v == "1"); return true; }
   if(k == "InpNewsWindowMin") { P_NewsWindowMin = (int)StringToInteger(v); return true; }
   if(k == "InpNewsRangeMin") { P_NewsRangeMin = (int)StringToInteger(v); return true; }
   if(k == "InpNewsRangeMaxATR") { P_NewsRangeMaxATR = StringToDouble(v); return true; }
   if(k == "InpSimpleLevels") { P_SimpleLevels = (int)StringToInteger(v); return true; }
   if(k == "InpSimpleLookback") { P_SimpleLookback = (int)StringToInteger(v); return true; }
   if(k == "InpSimplePivot") { P_SimplePivot = (int)StringToInteger(v); return true; }
   if(k == "InpKVLookback") { P_KVLookback = (int)StringToInteger(v); return true; }
   if(k == "InpKVBins") { P_KVBins = (int)StringToInteger(v); return true; }
   if(k == "InpKVHighMult") { P_KVHighMult = StringToDouble(v); return true; }
   if(k == "InpKVMaxATR") { P_KVMaxATR = StringToDouble(v); return true; }
   if(k == "InpKVMinBars") { P_KVMinBars = (int)StringToInteger(v); return true; }
   if(k == "InpKVMinReact") { P_KVMinReact = (int)StringToInteger(v); return true; }
   if(k == "InpVwapMode") { P_VwapMode = (int)StringToInteger(v); return true; }
   if(k == "InpVwapBand1") { P_VwapBand1 = StringToDouble(v); return true; }
   if(k == "InpVwapBand2") { P_VwapBand2 = StringToDouble(v); return true; }
   if(k == "InpVwapBand3") { P_VwapBand3 = StringToDouble(v); return true; }
   if(k == "InpVwapMinRR") { P_VwapMinRR = StringToDouble(v); return true; }
   if(k == "InpDowFilter") { P_DowFilter = (v == "true" || v == "1"); return true; }
   if(k == "InpDowTF") { P_DowTF = (ENUM_TIMEFRAMES)StringToInteger(v); return true; }
   if(k == "InpDowPivot") { P_DowPivot = (int)StringToInteger(v); return true; }
   if(k == "InpDowLateLegs") { P_DowLateLegs = (int)StringToInteger(v); return true; }
   if(k == "InpDowVolume") { P_DowVolume = (v == "true" || v == "1"); return true; }
   if(k == "InpFvgCandle") { P_FvgCandle = (v == "true" || v == "1"); return true; }
   if(k == "InpRangeBars") { P_RangeBars = (int)StringToInteger(v); return true; }
   if(k == "InpRangeMaxATR") { P_RangeMaxATR = StringToDouble(v); return true; }
   if(k == "InpFibLookback") { P_FibLookback = (int)StringToInteger(v); return true; }
   if(k == "InpFibMinSwingATR") { P_FibMinSwingATR = StringToDouble(v); return true; }
   if(k == "InpVPBins") { P_VPBins = (int)StringToInteger(v); return true; }
   if(k == "InpVPHighMult") { P_VPHighMult = StringToDouble(v); return true; }
   if(k == "InpVPTFmin") { P_VPTFmin = (int)StringToInteger(v); return true; }
   if(k == "InpFibMinRR") { P_FibMinRR = StringToDouble(v); return true; }
   if(k == "InpDivRsiPeriod") { P_DivRsiPeriod = (int)StringToInteger(v); return true; }
   if(k == "InpDivLookback") { P_DivLookback = (int)StringToInteger(v); return true; }
   if(k == "InpDivPivot") { P_DivPivot = (int)StringToInteger(v); return true; }
   if(k == "InpDivRsiLow") { P_DivRsiLow = StringToDouble(v); return true; }
   if(k == "InpAbsorbBars") { P_AbsorbBars = (int)StringToInteger(v); return true; }
   if(k == "InpAbsorbDelta") { P_AbsorbDelta = StringToDouble(v); return true; }
   if(k == "InpBigMult") { P_BigMult = StringToDouble(v); return true; }
   if(k == "InpBigMinDelta") { P_BigMinDelta = StringToDouble(v); return true; }
   if(k == "InpBigLookback") { P_BigLookback = (int)StringToInteger(v); return true; }
   if(k == "InpBigZoneATR") { P_BigZoneATR = StringToDouble(v); return true; }
   if(k == "InpBigClusterMin") { P_BigClusterMin = (int)StringToInteger(v); return true; }
   if(k == "InpBigClusterBars") { P_BigClusterBars = (int)StringToInteger(v); return true; }
   if(k == "InpDistLookback") { P_DistLookback = (int)StringToInteger(v); return true; }
   if(k == "InpDistClimaxATR") { P_DistClimaxATR = StringToDouble(v); return true; }
   if(k == "InpDistBoxMin") { P_DistBoxMin = (int)StringToInteger(v); return true; }
   if(k == "InpDistBoxMaxATR") { P_DistBoxMaxATR = StringToDouble(v); return true; }
   if(k == "InpDistNeedUT") { P_DistNeedUT = (v == "true" || v == "1"); return true; }
   if(k == "InpGridBars") { P_GridBars = (int)StringToInteger(v); return true; }
   if(k == "InpGridMinATR") { P_GridMinATR = StringToDouble(v); return true; }
   if(k == "InpGridMaxATR") { P_GridMaxATR = StringToDouble(v); return true; }
   if(k == "InpGridMaxADX") { P_GridMaxADX = StringToDouble(v); return true; }
   if(k == "InpGridLevels") { P_GridLevels = (int)StringToInteger(v); return true; }
   if(k == "InpGridMinStepCost") { P_GridMinStepCost = StringToDouble(v); return true; }
   if(k == "InpGridStopATR") { P_GridStopATR = StringToDouble(v); return true; }
   if(k == "InpSessionStartH") { P_SessionStartH = (int)StringToInteger(v); return true; }
   if(k == "InpSessionEndH") { P_SessionEndH = (int)StringToInteger(v); return true; }
   if(k == "InpSession2StartH") { P_Session2StartH = (int)StringToInteger(v); return true; }
   if(k == "InpSession2EndH") { P_Session2EndH = (int)StringToInteger(v); return true; }
   if(k == "InpPyramidRetest") { P_PyramidRetest = (v == "true" || v == "1"); return true; }
   if(k == "InpPyramidSLBars") { P_PyramidSLBars = (int)StringToInteger(v); return true; }
   if(k == "InpSessPartialR") { P_SessPartialR = StringToDouble(v); return true; }
   if(k == "InpHedgeLockLossR") { P_HedgeLockLossR = StringToDouble(v); return true; }
   if(k == "InpHedgeLockProfitR") { P_HedgeLockProfitR = StringToDouble(v); return true; }
   if(k == "InpHedgeNews") { P_HedgeNews = (v == "true" || v == "1"); return true; }
   if(k == "InpHedgeFriHour") { P_HedgeFriHour = (int)StringToInteger(v); return true; }
   if(k == "InpHedgeZoneBars") { P_HedgeZoneBars = (int)StringToInteger(v); return true; }
   if(k == "InpHedgeRetestATR") { P_HedgeRetestATR = StringToDouble(v); return true; }
   if(k == "InpOBLookback") { P_OBLookback = (int)StringToInteger(v); return true; }
   if(k == "InpOBImpulseATR") { P_OBImpulseATR = StringToDouble(v); return true; }
   if(k == "InpOBMaxATR") { P_OBMaxATR = StringToDouble(v); return true; }
   if(k == "InpOBStallBars") { P_OBStallBars = (int)StringToInteger(v); return true; }
   if(k == "InpOBBreaker") { P_OBBreaker = (v == "true" || v == "1"); return true; }
   if(k == "InpPyramidStopPct") { P_PyramidStopPct = StringToDouble(v); return true; }
   if(k == "InpTrailSwingBars") { P_TrailSwingBars = (int)StringToInteger(v); return true; }
   if(k == "InpKnifeLookback") { P_KnifeLookback = (int)StringToInteger(v); return true; }
   if(k == "InpKnifeBars") { P_KnifeBars = (int)StringToInteger(v); return true; }
   if(k == "InpKnifeDropATR") { P_KnifeDropATR = StringToDouble(v); return true; }
   if(k == "InpKnifeProbePct") { P_KnifeProbePct = StringToDouble(v); return true; }
   if(k == "InpKnifeRetestATR") { P_KnifeRetestATR = StringToDouble(v); return true; }
   if(k == "InpHedgeMaxBars") { P_HedgeMaxBars = (int)StringToInteger(v); return true; }
   if(k == "InpSLStructBars") { P_SLStructBars = (int)StringToInteger(v); return true; }
   if(k == "InpSLStructMinATR") { P_SLStructMinATR = StringToDouble(v); return true; }
   if(k == "InpStallBars") { P_StallBars = (int)StringToInteger(v); return true; }
   if(k == "InpStallMinATR") { P_StallMinATR = StringToDouble(v); return true; }
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
   if(k == "InpAutoSelect") { P_AutoSelect = (v == "true" || v == "1"); return true; }
   if(k == "InpSelectMaxAgeDays") { P_SelectMaxAgeDays = (int)StringToInteger(v); return true; }
   if(k == "InpUseFlow") { P_UseFlow = (v == "true" || v == "1"); return true; }
   if(k == "InpFlowMinDelta") { P_FlowMinDelta = StringToDouble(v); return true; }
   if(k == "InpFlowBigMult") { P_FlowBigMult = StringToDouble(v); return true; }
   if(k == "InpFlowHoldPos") { P_FlowHoldPos = StringToDouble(v); return true; }
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
#include "TrendBot/Ledger.mqh"
#include "TrendBot/Protection.mqh"
#include "TrendBot/Filters.mqh"
#include "TrendBot/OrderFlow.mqh"
#include "TrendBot/Dow.mqh"
#include "TrendBot/Signals.mqh"
#include "TrendBot/Learn.mqh"
#include "TrendBot/Risk.mqh"
#include "TrendBot/Manage.mqh"
#include "TrendBot/Grid.mqh"
#include "TrendBot/Hedge.mqh"
#include "TrendBot/Guard.mqh"
#include "TrendBot/Journal.mqh"
#include "TrendBot/ManualEntry.mqh"
#include "TrendBot/Status.mqh"
#include "TrendBot/LiveR.mqh"
#include "TrendBot/Panel.mqh"
#include "TrendBot/Report.mqh"

// Tao (lai) chi bao theo P_ hien tai. Goi o OnInit va khi che do Tu dong (chien luoc 23) doi chien luoc / khung.
void ReleaseHandles()
{
   if(hATRSL != hATR && hATRSL != INVALID_HANDLE) IndicatorRelease(hATRSL);
   if(hFast != INVALID_HANDLE)  IndicatorRelease(hFast);
   if(hTrend != INVALID_HANDLE) IndicatorRelease(hTrend);
   if(hHTF != INVALID_HANDLE)   IndicatorRelease(hHTF);
   if(hATR != INVALID_HANDLE)   IndicatorRelease(hATR);
   if(hADX != INVALID_HANDLE)   IndicatorRelease(hADX);
   if(hRSI != INVALID_HANDLE)   IndicatorRelease(hRSI);
   if(hATRD1 != INVALID_HANDLE) IndicatorRelease(hATRD1);
   if(hBB != INVALID_HANDLE)    IndicatorRelease(hBB);
   if(hMACD != INVALID_HANDLE)  IndicatorRelease(hMACD);
   if(hMACDH != INVALID_HANDLE) IndicatorRelease(hMACDH);
   hFast = hTrend = hHTF = hATR = hATRSL = hADX = hRSI = hATRD1 = hBB = hMACD = hMACDH = INVALID_HANDLE;
}
bool InitHandles()
{
   ReleaseHandles();
   hFast  = iMA(_Symbol, P_TF,  P_FastEMA,  0, MODE_EMA, PRICE_CLOSE);
   hTrend = iMA(_Symbol, P_TF,  P_TrendEMA, 0, MODE_EMA, PRICE_CLOSE);
   hHTF   = iMA(_Symbol, P_HTF, P_HTFEMA,   0, MODE_EMA, PRICE_CLOSE);
   hATR   = iATR(_Symbol, P_TF, P_ATRPeriod);
   hATRSL = P_SLTFmin > 0 ? iATR(_Symbol, TFFromMin(P_SLTFmin), P_ATRPeriod) : hATR;
   hADX   = iADX(_Symbol, P_TF, P_ADXPeriod);
   if(P_Strategy == STRAT_RSI_REVERT || P_Strategy == STRAT_DIVCVD)
   {
      hRSI = iRSI(_Symbol, P_TF, P_Strategy == STRAT_DIVCVD ? P_DivRsiPeriod : P_RsiPeriod, PRICE_CLOSE);
      if(hRSI == INVALID_HANDLE) { Print("Khong tao duoc RSI"); return false; }
   }
   if(P_Strategy == STRAT_MACD)
   {
      hMACD = iMACD(_Symbol, P_TF, 12, 26, 9, PRICE_CLOSE);
      if(hMACD == INVALID_HANDLE) { Print("Khong tao duoc MACD"); return false; }
   }
   if(P_HTFMacd)
   {
      hMACDH = iMACD(_Symbol, P_HTF, 12, 26, 9, PRICE_CLOSE);
      if(hMACDH == INVALID_HANDLE) { Print("Khong tao duoc MACD khung lon"); return false; }
   }
   if(P_Strategy == STRAT_EXHAUST)
   {
      hATRD1 = iATR(_Symbol, PERIOD_D1, 20);
      hBB    = iBands(_Symbol, P_TF, 20, 0, 2.0, PRICE_CLOSE);
      if(hATRD1 == INVALID_HANDLE || hBB == INVALID_HANDLE) { Print("Khong tao duoc ATR D1 / Bollinger"); return false; }
   }
   if(hFast == INVALID_HANDLE || hTrend == INVALID_HANDLE || hHTF == INVALID_HANDLE ||
      hATR == INVALID_HANDLE || hATRSL == INVALID_HANDLE || hADX == INVALID_HANDLE)
   {
      Print("Khong tao duoc chi bao");
      return false;
   }
   return true;
}

int OnInit()
{
   ResetRuntimeState();     // doi thong so / doi khung: MT5 KHONG nap lai bien toan cuc, phai tu xoa trang thai cu
   LoadParams();
   if(InpPreset > 0 && !ApplyPreset(InpPreset)) return INIT_PARAMETERS_INCORRECT;
   // Tai khoan Cent dung BTCUSDc/ETHUSDc, khong phai BTCUSDm/ETHUSDm.
   // Chi doi Nhom MAC DINH, khong ghi de nhom do nguoi dung chu dong chon.
   if((_Symbol == "BTCUSDc" || _Symbol == "ETHUSDc") &&
      P_CorrSymbols == "BTCUSDm,ETHUSDm")
   {
      P_CorrSymbols = "BTCUSDc,ETHUSDc";
      Print("STANDARD CENT: nhom quan ly rui ro -> ", P_CorrSymbols,
            ". Tai khoan USC: InpCapital phai theo don vi USC, KHONG nhap USD.");
   }
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
   // Che do Tu dong (chien luoc 23): Magic co dinh theo luc gan bot; bat dau bang cau hinh du phong (Donchian H4 + ADX),
   // roi doi sang chien luoc dung dau bang xep hang o tick dau tien (AutoSwitch).
   g_autoMode = P_Strategy == STRAT_AUTO;
   g_autoMagic = P_Magic;
   if(g_autoMode) AutoFallback();
   // Netting/Exchange hop nhat cac lenh cung symbol, khong bao ton quyen so huu theo Magic.
   // Tu choi thay vi canh bao roi de bot tu vao / dong nham vi the cua nguoi dung.
   if(AccountInfoInteger(ACCOUNT_LOGIN) > 0 &&
      (MQLInfoInteger(MQL_TESTER) || TerminalInfoInteger(TERMINAL_CONNECTED)) && !IsHedging())
   {
      Print("KHONG KHOI DONG TrendBot: tai khoan NETTING/EXCHANGE khong ho tro vi the Hedging rieng.");
      return INIT_FAILED;
   }
   if(!MQLInfoInteger(MQL_TESTER) && !ClaimMagic()) return INIT_FAILED;
   if(P_UseFunding) LoadFunding();
   // Lich tin cho backtest: moi tinh nang dung gio tin (tranh tin, truoc tin, khoa loi truoc tin, chien luoc 20)
   if(MQLInfoInteger(MQL_TESTER) && (P_AvoidUSNews || P_NewsPreMin > 0 || P_Strategy == STRAT_NEWS || P_Strategy == STRAT_SMART ||
      (P_HedgeLockProfitR > 0 && P_HedgeNews))) LoadNews();
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
   if(!InitHandles()) return INIT_FAILED;
   if(P_MTFAlign > 0 && !InitMTF()) { Print("Khong tao duoc EMA20 da khung"); return INIT_FAILED; }
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
   // Truong hop OnInit khi VPS chua ket noi: kiem tra lai truoc BAT KY giao dich nao.
   if(!IsHedging())
   {
      g_status = "DUNG: yeu cau tai khoan HEDGING, khong giao dich tren NETTING/EXCHANGE";
      Print(g_status);
      ExpertRemove();
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
   // Tai khoan khong phai Hedging da bi tu choi o OnInit/TryInitState.
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
   // Go bot khoi chart: huy lenh cho cua luoi (lenh dang mo van co SL / TP o server). Doi thong so / khoi dong lai: giu nguyen.
   if(P_Strategy == STRAT_GRID && reason == REASON_REMOVE) GridCancel();
   ManualUIDelete();
   if(P_ExportTFmin > 0 && MQLInfoInteger(MQL_TESTER)) ExportBars();
   if(!MQLInfoInteger(MQL_TESTER)) { ReleaseMagic(); JournalRelease(); StatusRelease(); GuardOwnerRelease(); }
   ReleaseHandles();
   if(hMkt != INVALID_HANDLE) IndicatorRelease(hMkt);
   ReleaseMTF();
   Comment("");
   PanelDelete();
   GuardRelease();
}

datetime g_lastManage = 0;
int      g_pendDir = 0;            // tin hieu dang cho gia hoi ve: 1 buy, -1 sell, 0 khong co
double   g_pendPrice = 0, g_pendATR = 0, g_pendSigSL = 0, g_pendSigTP = 0, g_pendRiskMult = 1, g_pendPartialPx = 0;
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
   g_sigSL = g_pendSigSL; g_sigTP = g_pendSigTP; g_sigRiskMult = g_pendRiskMult; g_sigPartialPx = g_pendPartialPx;
   int r = SendEntry(buy, g_pendATR, true);
   if(r == 0) return;               // chua lay duoc khoa rui ro chung: giu lenh cho, thu lai o tick sau
   g_pendDir = 0;
   if(hit) g_pendHit++; else g_pendMissed++;
   if(r > 0) g_pendFilled++;        // chi dem khi server da khop that
}
// Dieu kien bat buoc truoc moi lan vao lenh moi (dung chung cho vao ngay va vao khi gia hoi ve)
// ---- Che do Tu dong (v5.34, chien luoc 23): MOT chart, MOT bot, tu chuyen chien luoc ----
// Doc Common\Files\TrendBot_xephang.csv (thu hang) + TrendBot_xephang_cauhinh.csv (thong so tung cau hinh, nut 1 > Xep hang ghi).
// Moi 10 phut: neu bang con moi (<= InpSelectMaxAgeDays ngay) thi lay cau hinh dung dau du dieu kien; bang cu / thieu thi dung
// Donchian H4 + ADX (cau hinh da kiem thu); "KHONG" (khong ai du dieu kien) thi dung ngoai. Chi DOI khi bot dang dung ngoai
// (khong lenh, khong lenh cho, khong khoa lenh) de lenh dang mo duoc quan ly dung theo chien luoc da mo no.
// Chi ap dung thong so tin hieu / quan ly lenh (danh sach AutoKeyOk); thong so von, rui ro, gioi han lo, gio nghi, tin, spread
// giu nguyen nhu ban dat tren chart. Magic khong doi khi doi chien luoc.
bool AutoKeyOk(const string k)
{
   string exact[] = {"InpStrategy", "InpTF", "InpHTF", "InpUseHTF", "InpHTFEMA", "InpHTFMacd", "InpUseADX", "InpADXPeriod", "InpADXMin",
                     "InpATRMult", "InpRR", "InpUseTrailing", "InpTrailStartR", "InpTrailATRMult", "InpUsePartial", "InpPartialR",
                     "InpPartialPct", "InpUseBreakeven", "InpBreakevenR", "InpTrailSwingBars", "InpBESwingBars", "InpFastEMA",
                     "InpTrendEMA", "InpEntryPullATR", "InpEntryPullMode", "InpUseCandle", "InpMinSLATRMult", "InpExitOnBar", "InpExitOnEMA"};
   for(int i = 0; i < ArraySize(exact); i++) if(k == exact[i]) return true;
   string pre[] = {"InpDonchian", "InpBreak", "InpFvg", "InpRange", "InpSpring", "InpOB", "InpKV", "InpKnife", "InpVwap", "InpDow",
                   "InpPD", "InpChain", "InpSimple", "InpNewsWindow", "InpNewsRange", "InpNewsNFP", "InpDist", "InpBig", "InpDiv",
                   "InpFib", "InpVP", "InpRsi", "InpOrb", "InpExh", "InpMacd", "InpImom", "InpGrid", "InpFakeout", "InpSmart"};
   for(int i = 0; i < ArraySize(pre); i++) if(StringFind(k, pre[i]) == 0) return true;
   return false;
}
void AutoReset()
{
   LoadParams();
   if((_Symbol == "BTCUSDc" || _Symbol == "ETHUSDc") && P_CorrSymbols == "BTCUSDm,ETHUSDm") P_CorrSymbols = "BTCUSDc,ETHUSDc";
}
void AutoApplied(const string name)
{
   P_Magic = g_autoMagic;
   trade.SetExpertMagicNumber(P_Magic);
   if(!InitHandles()) { Print("Tu dong: khong tao duoc chi bao cho ", name, ", quay ve Donchian H4"); if(name != "Donchian H4 + ADX (du phong)") AutoFallback(); return; }
   lastBarTime = 0;
   g_autoName = name;
   string msg = "Tu dong chuyen sang: " + name + " (" + StrategyName() + " " + EnumToString((ENUM_TIMEFRAMES)P_TF) + ")";
   Print(msg);
   DecisionLog("phan-tich", msg);
}
void AutoFallback()
{
   AutoReset();
   P_Strategy = STRAT_DONCHIAN; P_TF = PERIOD_H4; P_UseADX = true;
   AutoApplied("Donchian H4 + ADX (du phong)");
}
// Thong so cua cau hinh ten 'name' trong TrendBot_xephang_cauhinh.csv (dong: Ten|k=v;k=v;...)
bool AutoApplyConfig(const string name)
{
   int h = OpenCommonRead("TrendBot_xephang_cauhinh.csv", FILE_TXT | FILE_ANSI);
   if(h == INVALID_HANDLE) return false;
   string cfg = "";
   while(!FileIsEnding(h) && cfg == "")
   {
      string l = FileReadString(h);
      int p = StringFind(l, "|");
      if(p > 0 && StringSubstr(l, 0, p) == name) cfg = StringSubstr(l, p + 1);
   }
   FileClose(h);
   if(cfg == "") return false;
   AutoReset();
   string kv[];
   int n = StringSplit(cfg, ';', kv);
   for(int i = 0; i < n; i++)
   {
      int e = StringFind(kv[i], "=");
      if(e <= 0) continue;
      string k = StringSubstr(kv[i], 0, e), v = StringSubstr(kv[i], e + 1);
      if(AutoKeyOk(k)) SetParam(k, v);
   }
   if(P_Strategy == STRAT_AUTO) { AutoFallback(); return true; }
   AutoApplied(name);
   return true;
}
// Ten cau hinh dung dau du dieu kien; "" = bang thieu / cu; "KHONG" = khong ai du dieu kien
string AutoTop()
{
   if(!FileIsExist("TrendBot_xephang.csv", FILE_COMMON)) return "";
   int h = OpenCommonRead("TrendBot_xephang.csv", FILE_TXT | FILE_ANSI);
   if(h == INVALID_HANDLE) return "";
   datetime upd = 0; string top = "KHONG"; bool rows = false;
   while(!FileIsEnding(h))
   {
      string p[];
      int n = StringSplit(FileReadString(h), ',', p);
      if(n < 2) continue;
      if(p[0] == "CapNhat") upd = StringToTime(p[1]);
      if(p[0] == "Hang") { rows = true; continue; }
      if(rows && n >= 4 && top == "KHONG" && p[3] == "1") top = p[1];
   }
   FileClose(h);
   if(upd == 0 || TimeLocal() - upd > (long)P_SelectMaxAgeDays * 86400) return "";
   return top;
}
bool AutoBusy()
{
   if(HasOwnPosition() || HedgeActive()) return true;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
      if(OrderGetTicket(i) != 0 && OrderGetString(ORDER_SYMBOL) == _Symbol && OrderGetInteger(ORDER_MAGIC) == (long)P_Magic) return true;
   return false;
}
void AutoSwitch()
{
   if(!g_autoMode || MQLInfoInteger(MQL_TESTER)) return;
   if(g_autoRead != 0 && TimeCurrent() - g_autoRead < 600) return;
   g_autoRead = TimeCurrent();
   string top = AutoTop();
   g_autoWant = top == "" ? "Donchian H4 + ADX (du phong)" : top;
   if(top == "KHONG") { g_status = "Tu dong: bang xep hang khong co chien luoc nao du dieu kien, dung ngoai"; return; }
   if(g_autoWant == g_autoName) return;
   if(AutoBusy()) { g_status = "Tu dong: se chuyen sang " + g_autoWant + " sau khi lenh hien tai dong"; return; }
   if(top == "") AutoFallback();
   else if(!AutoApplyConfig(top)) { Print("Tu dong: khong thay thong so cua ", top, " trong TrendBot_xephang_cauhinh.csv (chay lai Xep hang)"); if(g_autoName == "") AutoFallback(); }
}
bool AutoStandAside() { return g_autoMode && g_autoWant == "KHONG"; }

// ---- Tu chon chien luoc (v5.11) ----
// Bang xep hang Common\Files\TrendBot_xephang.csv do nut 1 > "Xep hang chien luoc" ghi (ChayThuNghiem.ps1):
//   CapNhat,yyyy.MM.dd HH:mm  /  ChonDung,S<chien luoc>-<so phut khung>  (vd. S1-240 = Donchian H4; KHONG = khong ai)
// Gan nhieu chart, moi chart 1 chien luoc, cung bat InpAutoSelect: chi chart co ma trung ChonDung duoc vao lenh MOI.
// Lenh dang mo van duoc quan ly binh thuong. Bang thieu / cu hon InpSelectMaxAgeDays: chi Donchian H4 (da kiem thu) duoc vao.
// Khi backtest: bo qua (luon cho vao) de ket qua tung chien luoc khong phu thuoc bang xep hang.
string   g_xhTop = "";
datetime g_xhUpd = 0, g_xhRead = 0;
string SelfStrategyKey() { return StringFormat("S%d-%d", (int)P_Strategy, PeriodSeconds(P_TF) / 60); }
void ReadRanking()
{
   g_xhRead = TimeCurrent(); g_xhTop = ""; g_xhUpd = 0;
   if(!FileIsExist("TrendBot_xephang.csv", FILE_COMMON)) return;
   int h = OpenCommonRead("TrendBot_xephang.csv", FILE_TXT | FILE_ANSI);
   if(h == INVALID_HANDLE) return;
   while(!FileIsEnding(h))
   {
      string line = FileReadString(h), part[];
      if(StringSplit(line, ',', part) < 2) continue;
      if(part[0] == "CapNhat")  g_xhUpd = StringToTime(part[1]);
      if(part[0] == "ChonDung") g_xhTop = part[1];
   }
   FileClose(h);
}
bool AutoSelectAllowed()
{
   if(!P_AutoSelect || P_ManualEntry || MQLInfoInteger(MQL_TESTER)) return true;   // ban tu bam lenh: khong chan
   if(g_xhRead == 0 || TimeCurrent() - g_xhRead >= 600) ReadRanking();   // doc lai moi 10 phut
   string me = SelfStrategyKey();
   bool fresh = g_xhUpd > 0 && g_xhTop != "" && TimeCurrent() - g_xhUpd <= (long)P_SelectMaxAgeDays * 86400;
   if(!fresh)
   {
      if(me == "S1-240") return true;
      g_status = "Tu chon: chua co bang xep hang moi (nut 1 > Xep hang), chi Donchian H4 duoc vao";
      return false;
   }
   if(g_xhTop == me) return true;
   g_status = g_xhTop == "KHONG" ? "Tu chon: khong chien luoc nao du dieu kien, tam dung vao lenh"
                                  : "Tu chon: dang uu tien " + g_xhTop + ", chien luoc nay (" + me + ") cho";
   return false;
}

bool EntryGatesOk()
{
   if(AutoStandAside()) { g_status = "Tu dong: khong chien luoc nao du dieu kien, dung ngoai"; return false; }
   if(!AutoSelectAllowed()) return false;
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
   if(f == EMPTY_VALUE)
   {
      g_status = "DUNG TIN HIEU: da bat funding nhung du lieu thieu / qua han";
      if(ShouldNotify("fundingMissing", 3600)) Print(g_status);
      return false;
   }
   if((buy && f > P_FundingMax) || (!buy && f < -P_FundingMax))
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
   AutoSwitch();                    // che do Tu dong: doi sang chien luoc dung dau bang xep hang (khi dang dung ngoai)
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
   HedgeTick();                     // khoa / mo khoa lenh (InpHedgeLockLossR, InpHedgeLockProfitR), truoc quan ly lenh
   ManagePositions();
   SessionEndPartial();             // het gio cao diem: chot mot nua + hoa von (InpSessPartialR)
   if(P_Strategy == STRAT_SMART) LearnUpdate();   // cham lenh giay cua cac setup (hoc tu thuc chien)
   NewsProtect();                   // sap ra tin: lenh dang loi chot bot / SL ve hoa von (InpNewsProtect)
   NewsWeekly();                    // sang thu Hai: lich tin trong tuan (InpNewsWeekly)
   StallExit();                     // lenh dung yen qua lau thi thoat (InpStallBars)
   ScaleCleanup();                  // huy phan giai von chua khop (InpScaleParts)
   ReconcileClosed();
   CheckPendingEntry();             // tin hieu dang cho gia hoi ve: sau khi da cap nhat lo ngay / sut giam cua tick nay
   CheckReEntry();                  // vao lai sau khi bi cat lo (InpReEntryMax)
   UpdateLiveR();                   // tong R that so voi nguong xem lai (5 phut/lan, bao 1 lan khi xuong duoi)
   UpdatePanel();
   // Danh luoi (chien luoc 13): tu tim vung, dat / huy lenh cho, tat luoi khi gia ra khoi vung (Grid.mqh)
   if(P_Strategy == STRAT_GRID) { GridTick(); return; }

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
   EvReset();                       // bang chung cua quyet dinh nen nay (v5.33)
   TraceBegin();                    // qua trinh phan tich nen nay, ghi ra file o lan WriteStatus sau (v5.42)

   if(IsHalted())       { g_status = "DUNG HAN (sut giam)"; return; }
   if(HasOwnPosition())
   {
      g_status = "Dang giu lenh";
      // Dao roi: dang giu lenh thu o day, gio co xac nhan sau day thi vao lenh lon (Signals.mqh KnifeAdd)
      if(P_Strategy == STRAT_KNIFE) KnifeAdd();
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
   bool baseOk = BaseSignals(atr, trend, fast, c1, h1, l1, buyBase, sellBase);
   g_trEvFrom = StringLen(g_ev);    // bang chung tu day tro di: bo loc chung, tinh lot, gui lenh
   if(!baseOk) return;
   bool buySignal  = P_AllowBuy && buyBase
                     && (!P_UseHTF || (P_HTFMacd ? htfUp : htfClose > htfEma)) && adxOk
                     && (!P_UseCandle || BullCandle()) && MTFOk(true);
   bool sellSignal = P_AllowSell && sellBase
                     && (!P_UseHTF || (P_HTFMacd ? htfDn : htfClose < htfEma)) && adxOk
                     && (!P_UseCandle || BearCandle()) && MTFOk(false);
   // Bang chung cac bo loc chung khi chien luoc da co tin hieu goc
   if(buyBase || sellBase)
   {
      bool bb = buyBase;
      string cut = "";
      if(!(bb ? P_AllowBuy : P_AllowSell)) cut += (bb ? " tat chieu mua;" : " tat chieu ban;");
      if(P_UseADX) { EvAdd(StringFormat("ADX %.1f (can >= %.1f)%s", adx, P_ADXMin, adxOk ? "" : " -> chan")); if(!adxOk) cut += " ADX thap;"; }
      if(P_UseHTF)
      {
         bool hOk = P_HTFMacd ? (bb ? htfUp : htfDn) : (bb ? htfClose > htfEma : htfClose < htfEma);
         if(P_HTFMacd) EvAdd(StringFormat("MACD khung lon %s", hOk ? "cung chieu" : "nguoc chieu -> chan"));
         else EvAdd(StringFormat("Khung lon %s: dong cua %s %s EMA%d %s%s", EnumToString(P_HTF), Px(htfClose), htfClose > htfEma ? ">" : "<",
                                 P_HTFEMA, Px(htfEma), hOk ? "" : " -> chan"));
         if(!hOk) cut += " nguoc xu huong khung lon;";
      }
      if(P_UseCandle && !(bb ? BullCandle() : BearCandle())) { EvAdd("Khong co mau nen xac nhan -> chan"); cut += " thieu mau nen;"; }
      if(P_MTFAlign > 0 && !MTFOk(bb)) { EvAdd(StringFormat("Chua du %d khung dong thuan -> chan", P_MTFAlign)); cut += " da khung chua dong thuan;"; }
      if(!buySignal && !sellSignal) { g_status = "Bo tin hieu " + (bb ? "MUA" : "BAN") + ":" + cut; return; }
   }
   if((buySignal || sellSignal) && !FundingOk(buySignal, P_Strategy == STRAT_DONCHIAN)) return;

   if((buySignal || sellSignal) && !MarketFiltersOk(buySignal, P_Strategy == STRAT_DONCHIAN)) return;
   // Duong ho tro / khang cu dat cau hoi, dong tien tra loi: xac nhan cay nen tin hieu (mac dinh tat, OrderFlow.mqh)
   if((buySignal || sellSignal) && !FlowOk(buySignal, h1, l1, c1)) return;
   // Ly thuyet Dow (Dow.mqh): thuy trieu len hay xuong, giai doan nao, volume co xac nhan (InpDowFilter; luon bat voi chien luoc 16)
   if((buySignal || sellSignal) && !DowOk(buySignal)) return;

   // Chuoi phan tich / Theo tinh huong tu ghi trang thai (tinh huong, buoc dung lai): khong ghi de bang "Cho tin hieu"
   if(P_Strategy != STRAT_SMART && P_Strategy != STRAT_CHAIN) g_status = "Cho tin hieu";
   if(!buySignal && !sellSignal) return;

   if(P_EntryPullATR > 0)
   {
      // Cho gia hoi ve x ATR (sau pha vo H4, ~75% lan gia hoi >= 0,25 ATR trong 4 gio sau - du lieu M10 2021-2026)
      g_pendDir = buySignal ? 1 : -1; g_pendATR = atr; g_pendSigSL = g_sigSL; g_pendSigTP = g_sigTP;
      g_pendRiskMult = g_sigRiskMult; g_pendPartialPx = g_sigPartialPx;
      g_pendPrice = buySignal ? c1 - P_EntryPullATR * atr : c1 + P_EntryPullATR * atr;
      g_pendExpire = barTime + PeriodSeconds(P_TF);
      g_status = StringFormat("Cho gia hoi ve %s de %s", DoubleToString(g_pendPrice, _Digits), buySignal ? "BUY" : "SELL");
      return;
   }
   if(SendEntry(buySignal, atr, false) > 0) ReEntryArm(buySignal, barTime);
}

// Truoc khi sang gio vang: lenh dang loi >= InpSessPartialR R thi chot mot nua va doi SL ve hoa von (1 lan / lenh,
// dung chung dau "da chot mot phan" voi InpUsePartial). Kich hoat o lan dau tien bot thay gio da ra khoi khung cao diem.
void SessionEndPartial()
{
   static int wasIn = -1;
   if(P_SessPartialR <= 0 || !SessionsSet()) return;
   MqlDateTime dt; TimeToStruct(TimeCurrent(), dt);
   int inNow = InSession(dt.hour) ? 1 : 0;
   bool edge = wasIn == 1 && inNow == 0;
   wasIn = inNow;
   if(!edge || HedgeActive() || P_Strategy == STRAT_GRID) return;
   double minL = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong t = PositionGetTicket(i);
      if(t == 0 || !IsOwnSelected()) continue;
      ulong id = (ulong)PositionGetInteger(POSITION_IDENTIFIER);
      string rK = GVName("R_" + (string)id), pK = GVName("P_" + (string)id);
      double r = GlobalVariableCheck(rK) ? GlobalVariableGet(rK) : 0;
      if(r <= 0 || GlobalVariableCheck(pK)) continue;
      bool buy = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY;
      double op = PositionGetDouble(POSITION_PRICE_OPEN), cur = PositionGetDouble(POSITION_PRICE_CURRENT);
      double sl = PositionGetDouble(POSITION_SL), tp = PositionGetDouble(POSITION_TP), vol = PositionGetDouble(POSITION_VOLUME);
      if((buy ? cur - op : op - cur) < P_SessPartialR * r) continue;
      double half = NormalizeVolume(vol * 0.5);
      if(half >= minL && vol - half >= minL - 1e-9 && PrepSend() && trade.PositionClosePartial(t, half)) g_sessPartials++;
      GlobalVariableSet(pK, 1);
      if(PositionSelectByTicket(t) && (buy ? sl < op : (sl <= 0 || sl > op)))
         TradeDone(PrepSend() && trade.PositionModify(t, NormalizeDouble(op, _Digits), tp), "Het gio cao diem: SL ve hoa von", "#" + (string)t);
   }
}

// Truoc gio tin InpNewsPreMin phut: lenh dang loi thi keo SL ve hoa von (1) hoac chot mot nua + hoa von (2). Lenh dang lo giu
// nguyen SL (khong the dat hoa von phia tren gia). Moi lenh 1 lan (NP_). Chien luoc 20 danh sau tin nen bo qua.
void NewsProtect()
{
   if(P_NewsProtect <= 0 || P_NewsPreMin <= 0 || P_Strategy == STRAT_GRID || HedgeActive()) return;
   string nm;
   if(MinutesToNews(P_NewsPreMin, nm) < 0) return;
   double minL = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double minDist = (double)MathMax(SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL), SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL)) * _Point + _Point * 2;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong t = PositionGetTicket(i);
      if(t == 0 || !IsOwnSelected()) continue;
      ulong id = (ulong)PositionGetInteger(POSITION_IDENTIFIER);
      string k = GVName("NP_" + (string)id);
      if(GlobalVariableCheck(k)) continue;
      bool buy = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY;
      double op = PositionGetDouble(POSITION_PRICE_OPEN), cur = PositionGetDouble(POSITION_PRICE_CURRENT);
      double sl = PositionGetDouble(POSITION_SL), tp = PositionGetDouble(POSITION_TP), vol = PositionGetDouble(POSITION_VOLUME);
      GlobalVariableSet(k, 1);
      if((buy ? cur - op : op - cur) <= minDist) continue;                 // chua loi: giu nguyen SL
      if(P_NewsProtect == 2)
      {
         double half = NormalizeVolume(vol * 0.5);
         if(half >= minL && vol - half >= minL - 1e-9) TradeDone(PrepSend() && trade.PositionClosePartial(t, half), "Truoc tin: chot mot nua", "#" + (string)t);
         GlobalVariableSet(GVName("P_" + (string)id), 1);
      }
      if(PositionSelectByTicket(t) && (buy ? sl < op : (sl <= 0 || sl > op)))
         TradeDone(PrepSend() && trade.PositionModify(t, NormalizeDouble(op, _Digits), tp), "Truoc tin " + nm + ": SL ve hoa von", "#" + (string)t);
      g_newsProtects++;
   }
}

// Giai von (v5.28): da xac dinh xu huong va vung vao thi chia so von dinh vao thanh 2-3 phan. Phan dau vao khi gia cham vung,
// phan sau la lenh cho Limit sau hon InpScaleStepATR x ATR moi nac (gia di sau hon thi gia trung binh dep hon). TAT CA chung 1 SL
// va TP; moi phan rui ro 1/n -> tong rui ro van chi InpRiskPercent. Day la ke hoach co tu truoc khi vao, KHONG phai nhoi khi dang lo:
// so phan, muc gia va khoi luong co dinh ngay luc vao lenh. Phan chua khop bi huy sau InpScaleBars nen hoac khi khong con lenh.
void ScalePlace(const bool buy, const double entry, const double slDist, const double atr, const int parts, const double baseMult)
{
   if(entry <= 0 || atr <= 0) return;
   double sl = buy ? entry - slDist : entry + slDist;
   double tp = 0;
   for(int i = PositionsTotal() - 1; i >= 0 && tp == 0; i--)
      if(PositionGetTicket(i) != 0 && IsOwnSelected()) tp = PositionGetDouble(POSITION_TP);
   double minDist = (double)MathMax(SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL), SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL)) * _Point + _Point * 2;
   for(int k = 1; k < parts; k++)
   {
      double px = buy ? entry - k * P_ScaleStepATR * atr : entry + k * P_ScaleStepATR * atr;
      double d = buy ? px - sl : sl - px;
      if(d < MathMax(minDist, 0.2 * atr)) break;                       // qua sat SL: khong dat them
      g_sigRiskMult = baseMult / parts;
      double lots = CalcLots(d);
      if(lots < SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN) - 1e-9) break;
      bool ok = PrepSend() && (buy ? trade.BuyLimit(lots, NormalizeDouble(px, _Digits), _Symbol, NormalizeDouble(sl, _Digits), tp > 0 ? NormalizeDouble(tp, _Digits) : 0, ORDER_TIME_GTC, 0, "BTC bot SCALE")
                                   : trade.SellLimit(lots, NormalizeDouble(px, _Digits), _Symbol, NormalizeDouble(sl, _Digits), tp > 0 ? NormalizeDouble(tp, _Digits) : 0, ORDER_TIME_GTC, 0, "BTC bot SCALE"));
      TradeDone(ok, "Giai von: dat phan " + IntegerToString(k + 1), buy ? "BUY LIMIT" : "SELL LIMIT");
   }
   g_sigRiskMult = 1;
}
// Huy phan giai von chua khop: qua InpScaleBars nen, hoac khong con lenh nao (lenh dau da dong)
void ScaleCleanup()
{
   if(P_ScaleParts <= 1) return;
   bool has = HasOwnPosition();
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong t = OrderGetTicket(i);
      if(t == 0 || OrderGetString(ORDER_SYMBOL) != _Symbol || OrderGetInteger(ORDER_MAGIC) != (long)P_Magic) continue;
      if(StringFind(OrderGetString(ORDER_COMMENT), "SCALE") < 0) continue;
      datetime ts = (datetime)OrderGetInteger(ORDER_TIME_SETUP);
      if(!has || TimeCurrent() - ts >= (long)P_ScaleBars * PeriodSeconds(P_TF) || HedgeActive())
         TradeDone(PrepSend() && trade.OrderDelete(t), "Huy phan giai von chua khop", "#" + (string)t);
   }
}

// Lenh dung yen qua lau (scalp): giu >= InpStallBars nen khung chinh ma gia chua di duoc InpStallMinATR ATR theo chieu
// lenh -> dong. Khong ap dung cho luoi (moi nac co TP rieng).
void StallExit()
{
   if(P_StallBars <= 0 || P_Strategy == STRAT_GRID || HedgeActive()) return;
   double atr = 0;
   if(!GetValue(hATR, 0, 1, atr) || atr <= 0) return;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong t = PositionGetTicket(i);
      if(t == 0 || !IsOwnSelected()) continue;
      datetime ot = (datetime)PositionGetInteger(POSITION_TIME);
      if(TimeCurrent() - ot < (long)P_StallBars * PeriodSeconds(P_TF)) continue;
      bool buy = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY;
      double op = PositionGetDouble(POSITION_PRICE_OPEN), cur = PositionGetDouble(POSITION_PRICE_CURRENT);
      if((buy ? cur - op : op - cur) >= P_StallMinATR * atr) continue;
      if(PrepSend() && trade.PositionClose(t))
      {
         g_stallExits++;
         Print("Dong lenh dung yen qua lau: ", t);
      }
   }
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
   // Swing: SL duoi CAU TRUC (day thap nhat / dinh cao nhat InpSLStructBars nen + 0,25 ATR), khong sat hon InpSLStructMinATR ATR.
   // Chi khi chien luoc khong tu dat SL.
   if(g_sigSL <= 0 && P_SLStructBars > 0 && slAtr > 0)
   {
      double cur = SymbolInfoDouble(_Symbol, buySignal ? SYMBOL_ASK : SYMBOL_BID);
      int ix = buySignal ? iLowest(_Symbol, P_TF, MODE_LOW, P_SLStructBars, 1) : iHighest(_Symbol, P_TF, MODE_HIGH, P_SLStructBars, 1);
      if(ix >= 0 && cur > 0)
      {
         double lvl = buySignal ? iLow(_Symbol, P_TF, ix) - 0.25 * atr : iHigh(_Symbol, P_TF, ix) + 0.25 * atr;
         double d = buySignal ? cur - lvl : lvl - cur;
         if(d > 0) slDist = MathMax(d, P_SLStructMinATR * slAtr);
      }
   }
   if(P_MinSLATRMult > 0 && slAtr > 0) slDist = MathMax(slDist, slAtr * P_MinSLATRMult);
   double minStops = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
   if(slDist < minStops * 1.1) slDist = minStops * 1.1;

   // Tu day toi khi gui lenh xong: giu khoa chung voi bot ma cung nhom. Khong lay duoc khoa thi KHONG vao lenh,
   // vi khong biet bot kia dang dung bao nhieu rui ro; thu lai o tick sau (van trong nen nay).
   // Giai von (InpScaleParts): phan dau vao ngay voi 1/n rui ro, cac phan sau la lenh cho sau hon trong vung, chung SL
   int parts = (P_ScaleParts > 1 && P_Strategy != STRAT_GRID) ? MathMin(P_ScaleParts, 3) : 1;
   double baseMult = (g_sigRiskMult > 0 && g_sigRiskMult < 1) ? g_sigRiskMult : 1.0;
   if(parts > 1) g_sigRiskMult = baseMult / parts;
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
      if(!EntryMarginOk(true, lots, price, price - slDist, tp))
      { g_status = "OrderCheck / du tru ky quy chua dat"; GroupClear(); GroupUnlock(); return -1; }
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
      if(!EntryMarginOk(false, lots, price, price + slDist, tp))
      { g_status = "OrderCheck / du tru ky quy chua dat"; GroupClear(); GroupUnlock(); return -1; }
      ok = PrepSend() && trade.Sell(lots, _Symbol, price,
                      NormalizeDouble(price + slDist, _Digits),
                      tp > 0 ? NormalizeDouble(tp, _Digits) : 0.0, "BTC bot SELL");
   }
   // trade.Buy/Sell tra true chi la gui duoc; server van co the tu choi -> xem ma ket qua.
   // Chua khop that thi bo phan rui ro da giu cho ngay, khong de treo 2 phut chan bot khac.
   uint rc = trade.ResultRetcode();
   bool filled = ok && (rc == TRADE_RETCODE_DONE || rc == TRADE_RETCODE_DONE_PARTIAL);
   if(!filled) GroupClear();
   // Hoc tu thuc chien: gan tinh huong + chien luoc cho vi the de ghi ket qua that khi dong (LearnRealClose)
   if(filled && P_Strategy == STRAT_SMART && g_sigMember >= 0)
   {
      ulong lp = trade.ResultOrder(), ld = trade.ResultDeal();
      if(ld > 0 && HistoryDealSelect(ld)) lp = (ulong)HistoryDealGetInteger(ld, DEAL_POSITION_ID);
      if(lp > 0) GlobalVariableSet(GVName("LS_" + (string)lp), g_smartSit * 100 + g_sigMember);
   }
   if(filled && parts > 1) ScalePlace(buySignal, trade.ResultPrice(), slDist, atr, parts, baseMult);
   // Muc chot mot phan theo gia (vd. dinh cu cua cu giam): ManagePositions chot InpPartialPct khi gia cham
   if(filled && g_sigPartialPx > 0)
   {
      ulong pid = trade.ResultOrder(), dl = trade.ResultDeal();
      if(dl > 0 && HistoryDealSelect(dl)) pid = (ulong)HistoryDealGetInteger(dl, DEAL_POSITION_ID);
      if(pid > 0) GlobalVariableSet(GVName("PX_" + (string)pid), g_sigPartialPx);
   }
   GroupUnlock();                                    // mo khoa truoc khi gui thong bao (Telegram co the cham)
   if(filled)
   {
      double sl0 = buySignal ? trade.ResultPrice() - slDist : trade.ResultPrice() + slDist;
      g_lastEntryWhy = StringFormat("%s %.2f lot @ %s, SL %s | %s", buySignal ? "MUA" : "BAN", trade.ResultVolume(),
                                    DoubleToString(trade.ResultPrice(), _Digits), DoubleToString(sl0, _Digits),
                                    P_Strategy == STRAT_CHAIN && g_chainWhy != "" ? g_chainWhy : StrategyName() + " " + EnumToString((ENUM_TIMEFRAMES)P_TF));
      g_lastEntryAt = TimeLocal();
      double tpNow = 0;
      if(PositionSelectByTicket(trade.ResultOrder())) tpNow = PositionGetDouble(POSITION_TP);
      EvAdd(StringFormat("Vao lenh: SL cach %s (= %.2f ATR), TP %s, %.2f lot, rui ro %.2f %s (%.2f%% von)%s", Px(slDist),
                         atr > 0 ? slDist / atr : 0, tpNow > 0 ? Px(tpNow) : "khong (giu theo SL / chot phan)", trade.ResultVolume(),
                         g_lastRisk, AccountInfoString(ACCOUNT_CURRENCY), BotEquity() > 0 ? g_lastRisk / BotEquity() * 100.0 : 0,
                         parts > 1 ? StringFormat(", giai von %d phan", parts) : ""));
      if(g_ev != "") g_lastEntryWhy += " || " + g_ev;
      DecisionLog("vao-lenh", g_lastEntryWhy);
   }
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
      DecisionLog("thoat", StringFormat("%.2f lot @ %s | lai/lo %.2f %s", vol, DoubleToString(price, _Digits), pnl, cur));
      Notify(StringFormat("[%s] THOAT %.2f lot @ %s | Lai/lo: %.2f %s | Equity: %.2f",
                          _Symbol, vol, DoubleToString(price, _Digits), pnl, cur,
                          AccountInfoDouble(ACCOUNT_EQUITY)));
      // Khong chot o day: thu tu su kien khong dam bao. Doi soat o ReconcileClosed().
      g_reconcile = true;
   }
}
//+------------------------------------------------------------------+
