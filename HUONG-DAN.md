# Hướng dẫn bot BTC (MT5) v4.9

> Bot chỉ để thử nghiệm và không đảm bảo có lãi. Luôn backtest, rồi chạy demo vài tuần trước khi dùng tiền thật.

File bot: `BTC_EMA_Pullback_v2.mq5`, chỉ chứa tham số và thứ tự chạy. Phần logic nằm trong thư mục `TrendBot/`, mỗi file một việc:

| File | Việc |
|---|---|
| `Core.mqh` | Biến chung, tiện ích gửi lệnh, vị thế của bot |
| `Signals.mqh` | Tín hiệu gốc: Donchian breakout hoặc EMA pullback |
| `Filters.mqh` | Bộ lọc giờ, mẫu nến, funding, Fear & Greed, Wikipedia, Nasdaq, tin Mỹ |
| `Risk.mqh` | Tính lot, trần rủi ro nhóm BTC/ETH, khóa chung giữa các bot |
| `Manage.mqh` | Trailing, hòa vốn, chốt một phần, đối soát lệnh đã đóng |
| `Protection.mqh` | Mốc vốn, lỗ ngày, dừng hẳn khi sụt giảm |
| `Notify.mqh`, `Panel.mqh` | Thông báo và bảng thông tin |
| `Report.mqh` | Ghi kết quả backtest |

Các nút trong VS Code tự chép cả thư mục này vào MT5 khi compile. Bot chạy được cho mã khác ngoài BTC/ETH: đặt `InpFundingSymbol` và `InpWikiArticle` nếu dùng hai bộ lọc đó. Phiên bản hiện ra ở bảng thông tin trên chart. Lịch sử thay đổi xem trong GitHub (Commits).

## Dùng hằng ngày với VS Code
Mở thư mục bot bằng VS Code. Các nút nằm ở **Terminal → Run Task…**. Bạn không cần bấm Sync hay compile. Mỗi nút kiểm tra GitHub; nếu có code mới, script liệt kê các thay đổi và **hỏi bạn** (gõ `y` để lấy về, phím khác để giữ bản cũ) rồi mới compile. Vì mọi nút đều compile lại bot vào MT5, hãy gõ `n` nếu MT5 đó đang chạy bot trên tài khoản thật.

| Nút | Khi nào dùng |
|---|---|
| **1. So sanh cau hinh (nhanh)** | Việc chính lúc này. Chạy khoảng 40 lần backtest, song song trên mọi nhân CPU. Xong thì bảng kết quả **tự được đẩy lên GitHub** (thư mục `ket-qua/`), bạn chỉ cần nhắn Claude "xong rồi". Nếu đẩy lên thất bại, gửi file `ket-qua-backtest-....zip` thay thế. |
| **2. Cap nhat bot vao MT5** (Ctrl+Shift+B) | Khi bot đang chạy trên chart và muốn nạp bản mới ngay. |
| **3. So sanh cau hinh (chinh xac, cham)** | Chỉ khi Claude bảo. Chạy lại bằng tick thật cho 5 cấu hình chính, **lần lượt từng cái** (tick thật tốn nhiều RAM, chạy song song sẽ treo máy 8 GB). Khoảng 1,5 giờ; nên tắt bớt ứng dụng khác. |

Khi mở VS Code, code đang có trên máy được compile vào MT5. Bước này không tự kéo code mới từ GitHub.

**Đợt chạy thiếu kết quả:** nếu thiếu dù chỉ một cấu hình, script báo lỗi đỏ, lưu file có đuôi `-CHUADU` và **không** đẩy lên GitHub. Không dùng đợt đó để chọn chiến lược; chạy lại hoặc gửi zip cho Claude.

**Chạy song song:** script gom các lần chạy cùng mã, cùng khoảng ngày và cùng vốn thành một đợt *Optimization* của MT5. MT5 tự chia các lần trong đợt cho mọi nhân CPU, nên máy 8 nhân nhanh hơn khoảng 6–8 lần. Mỗi cấu hình có một số thứ tự (`InpPreset`); bot đọc cấu hình đó từ file `TrendBot_presets.csv` mà script ghi vào *Common\Files*. Muốn chạy lần lượt như cũ (để dò lỗi) thì chạy `ChayThuNghiem.ps1 -TuanTu`. Nếu MT5 tắt bớt agent trong *Tester → Agents*, đợt chạy sẽ chậm lại tương ứng.

Bot kiểm tra lệnh đang mở và giới hạn lỗ ở mọi tick (`InpManageEverySec = 0`). Tick thật ngày 06/11 cho thấy chỉ kiểm tra mỗi giây làm một lệnh (11/2025) đóng sớm, lãi giảm 50 USD (5%), nên mặc định giữ mọi tick. Lần chạy `C-moiGiay` để đối chiếu.

**Dọn file:** mỗi lần chạy script xóa báo cáo cũ của MT5 và chỉ giữ 3 file zip mới nhất trong thư mục bot. Kết quả vẫn lưu đủ trong `ket-qua/` trên GitHub.

**Khi đang backtest:**
- Script sẽ hỏi đóng MT5. Đóng MT5 là **dừng mọi bot đang chạy trên MT5 đó**.
- Tắt terminal VS Code hay tắt máy giữa chừng thì lượt chạy dừng và không có file zip. Không hỏng gì cả, chỉ cần chạy lại. Dữ liệu giá đã tải vẫn được giữ.

## Bot làm gì (cài đặt mặc định)
**Vào lệnh (khung H4, chiến lược Donchian breakout):** nến H4 vừa đóng cửa vượt lên trên đỉnh cao nhất của 20 nến trước đó thì Buy. Nếu đóng cửa xuống dưới đáy thấp nhất thì Sell. Lệnh phải qua thêm các bộ lọc:
- **Xu hướng:** giá nằm đúng phía EMA200 H4, và giá đóng cửa D1 nằm đúng phía EMA200 D1.
- **ADX ≥ 20:** bỏ qua khi thị trường đi ngang.

**SL / TP / lot:**
- SL = 2,5 × ATR, **không đặt TP**.
- Lot tự tính để mỗi lệnh chỉ rủi ro 1% vốn.
- Nếu lot tính ra nhỏ hơn 0,01 thì bot **bỏ qua tín hiệu** chứ không vào lệnh vượt rủi ro. Vì vậy với vốn nhỏ, bot có thể vào ít lệnh hơn.

**Quản lý lệnh đang mở:**
- Trailing stop cách 3 × ATR, bật ngay từ đầu, chỉ dời theo hướng có lợi. Lệnh thoát khi chạm SL hoặc trailing.
- Chốt một phần và dời về hòa vốn mặc định tắt. Bật lại bằng `InpUsePartial` và `InpUseBreakeven`.

**Bộ lọc thời gian:** mặc định tắt vì BTC giao dịch 24/7. Có thể bật nghỉ cuối tuần (`InpSkipWeekend`) và hai khung giờ tin (`InpBlock1Start/End`, `InpBlock2Start/End`). Đặt `-1` để tắt.

**Chiến lược cũ (EMA pullback):** vẫn dùng được bằng cách đặt `InpStrategy = STRAT_EMA_PULLBACK`. Backtest 3 năm cho kết quả kém hơn hẳn Donchian.

**Giới hạn vào lệnh:**
- `InpAllowBuy` / `InpAllowSell`: bật/tắt từng chiều.
- `InpMaxTradesPerDay`: số lệnh tối đa mỗi ngày (0 = tắt).
- `InpCooldownBars`: nghỉ N nến sau một lệnh thua (0 = tắt).

## Bảo vệ tài khoản
Các mốc dưới đây chỉ tính lãi/lỗ của chính bot (theo magic + symbol), không tính tiền nạp/rút hay EA khác.
- **Lỗ ngày:** lỗ 3% so với đầu ngày (00:00 giờ server) thì bot khóa tới hôm sau, và đóng lệnh đang mở nếu `InpCloseOnDailyLoss = true`. Lệnh đang lãi trả bớt lãi không bị tính là lỗ.
- **Sụt giảm:** sụt 15% so với đỉnh vốn thì bot **dừng hẳn** và đóng hết lệnh. Muốn chạy lại, đặt `InpResetHalt = true` một lần rồi đổi về `false`.
- **Vốn của bot:** mặc định là balance lúc bot bắt đầu theo dõi. Muốn chỉ định vốn riêng, đặt `InpCapital`. Đổi `InpCapital` thì bot tự đặt lại mốc, nhưng **không** mở khóa nếu bot đang dừng hẳn hay đang khóa lỗ ngày (muốn mở phải dùng `InpResetHalt`). Sau khi nạp/rút tiền, đặt `InpResetHalt = true` một lần.

Bot được thiết kế cho tài khoản **Hedging** (Exness mặc định). Trên tài khoản Netting, bot sẽ hiện cảnh báo.

## Gắn bot lên chart (demo)
1. Bấm nút **2. Cap nhat bot vao MT5**.
2. Trong MT5, mở biểu đồ `BTCUSDm`, khung nào cũng được (bot tự dùng H4). Kéo `BTC_EMA_Pullback_v2` từ Navigator vào chart, rồi bật **Algo Trading**.
3. **Đổi cài đặt mặc định sau một bản mới?** EA đang gắn trên chart vẫn giữ tham số cũ. Muốn dùng mặc định mới, gỡ EA khỏi chart rồi gắn lại, hoặc mở tab *Inputs* và bấm *Reset*.

**Bảng thông tin** ở góc chart cho biết phiên bản, trạng thái bot, equity, lãi/lỗ hôm nay, số lệnh, mức sụt giảm và spread.

**Tắt máy hoặc tắt MT5 thì sao?**
- Bot dừng, nhưng lệnh đang mở vẫn nằm trên server Exness và SL vẫn có hiệu lực.
- Trailing, giới hạn lỗ ngày và lệnh mới sẽ chờ tới khi bạn mở lại MT5.
- Muốn chạy 24/7 thì dùng VPS: chuột phải vào tài khoản trong Navigator, chọn *Register a Virtual Server*.

**Cập nhật khi đang có lệnh mở:** nên cập nhật lúc không có lệnh. Nếu buộc phải cập nhật, bot sẽ đọc lại trạng thái đã lưu và tiếp tục quản lý lệnh.

## Bật thông báo
**Push về app MT5 (dễ nhất):**
1. Cài app MetaTrader 5 trên điện thoại → *Settings → Messages* → chép **MetaQuotes ID**.
2. Trên máy tính: *Tools → Options → Notifications* → tích *Enable Push Notifications*, dán ID → bấm *Test*.

**Telegram (tùy chọn):**
1. Chat với `@BotFather` → `/newbot` → lấy **token**.
2. Nhắn một tin bất kỳ cho bot vừa tạo, rồi mở `https://api.telegram.org/bot<TOKEN>/getUpdates` để lấy **chat id**.
3. MT5: *Tools → Options → Expert Advisors* → tích *Allow WebRequest for listed URL* → thêm `https://api.telegram.org`.
4. Trong cài đặt EA: `InpTelegram = true`, điền `InpTgToken` và `InpTgChatId`. **Không đưa token lên GitHub.**

Bot báo khi khởi động, vào lệnh, thoát lệnh (kèm lãi/lỗ), gặp lỗi và chạm giới hạn lỗ. Mỗi loại báo lỗi tối đa 1 lần / 5 phút. Bot không gửi thông báo khi đang backtest.

## Đọc kết quả backtest
File `ket-qua-so-sanh.csv` trong zip có một dòng cho mỗi lần chạy:

| Cột | Ý nghĩa |
|---|---|
| `LoiNhuan`, `ProfitFactor` | Lãi ròng và tỷ lệ tổng lãi / tổng lỗ (trên 1,3 mới đáng xem) |
| `SoLenh` | Số lệnh. Dưới 100 lệnh thì kết quả còn nhiều may rủi |
| `SutGiamMax%` | Mức sụt giảm lớn nhất của equity |
| `BoQuaLot` | Số tín hiệu bị bỏ vì 0,01 lot đã rủi ro hơn 1% (hoặc hơn `InpMaxRiskRoundUp` nếu bật làm tròn) |
| `LamTronLot` | Chỉ có khi bật làm tròn: số lệnh vào 0,01 lot dù rủi ro thật cao hơn 1% |
| `TongPhiHoaHong`, `LoiNhuanTruocPhi` | Tổng hoa hồng + phí, và lãi nếu không có swap lẫn phí. So với `LoiNhuan` để thấy chi phí ăn bao nhiêu |
| `GiuLenhTB_gio`, `TongSwap` | Thời gian giữ lệnh trung bình (giờ) và tổng phí qua đêm. Swap crypto của Exness có thể đổi so với lúc backtest |
| `LenhDau` | Ngày của lệnh đầu tiên. Nếu muộn hơn nhiều so với ngày bắt đầu, MT5 thiếu dữ liệu |
| `LaiTheoNam` | Lãi/lỗ từng năm, để xem có lãi đều hay chỉ nhờ một đợt |
| `LoiNhuan_Truot0.05%`, `PF_Truot0.05%` (và `0.1%`) | Kết quả nếu mỗi lần vào/ra lệnh tốn thêm 0,05% (hoặc 0,1%) giá vì trượt giá và spread. Ví dụ BTC 100.000 USD: thêm 50 (hoặc 100) USD mỗi chiều cho 1 BTC. PF vẫn trên 1,2 ở mức 0,1% thì chiến lược chịu được chi phí xấu |
| `ChanFunding`, `ChanFearGreed`, `ChanChuY`, `ChanNasdaq` | Số tín hiệu bị bộ lọc tương ứng chặn. Bằng 0 khi bộ lọc bật thì có thể thiếu dữ liệu |
| `LoiNhuan_BoTop5`, `PF_BoTop5`, `TyTrongTop5%` | Kết quả nếu bỏ 5 lệnh lãi lớn nhất, và phần lãi ròng mà 5 lệnh đó đóng góp. Tỷ trọng gần hoặc trên 100% nghĩa là phần còn lại chỉ hòa hoặc lỗ: lỡ 1–2 lệnh lớn (VPS tắt, lot bị bỏ, tự tắt bot giữa chuỗi thua) là mất phần lớn lợi nhuận |
| `MC_SutGiamTB%`, `MC_SutGiam95%`, `MC_XacSuatDungHan%` | Monte Carlo: rút lại các lệnh 1.000 lần theo khối 5 lệnh liền nhau (giữ các chuỗi thua theo cụm). Cho biết sụt giảm thường gặp, sụt giảm ở trường hợp xấu (chỉ 5% số lần tệ hơn), và xác suất bot chạm mức dừng hẳn `InpMaxDrawdownPct` (15%). Dưới 200 lệnh thì chỉ nên xem là tham khảo |

Lượt so sánh hiện tại kiểm tra độ bền của Donchian H4: B (không lọc ADX), C (có ADX), D (Donchian 55), cùng các lần chạy với vốn 30.000, trên `ETHUSDm`, và trên 3 năm **trước** giai đoạn đã dùng để chọn cấu hình. Các lần này tắt giới hạn sụt giảm để so sánh chiến lược. Lần cuối `MacDinh-nhu-chay-that` dùng nguyên cài đặt mặc định của bot, gồm cả dừng hẳn khi sụt 15% và khóa lỗ ngày 3%, đúng như khi chạy thật. **Bộ lọc chất lượng breakout** (mặc định tắt, đang thử trên cấu hình C):
- `InpBreakMinBody`: thân nến phá vỡ phải chiếm ít nhất X% biên độ nến và cùng chiều (loại nến chỉ có râu dài).
- `InpBreakMinATR`: giá đóng cửa phải vượt kênh ít nhất X × ATR (loại phá vỡ sát mép).
- `InpBreakConfirm`: chờ thêm 1 nến, giá vẫn đóng ngoài kênh mới vào lệnh.
- `InpBreakMaxATR`: bỏ qua nến phá vỡ dài hơn X × ATR. Nến quá dài thường là thanh lý dây chuyền (lệnh đòn bẩy bị ép đóng trên sổ lệnh mỏng), vào theo lúc đó là đuổi giá.
- `InpSkipWeekend` cũng được thử lại cho Donchian, vì cuối tuần khối lượng BTC chỉ khoảng một nửa ngày thường và sổ lệnh mỏng.

**Bộ lọc funding rate** (`InpUseFunding`, mặc định tắt): lấy funding rate của hợp đồng BTCUSDT/ETHUSDT trên Binance Futures. Funding dương cao nghĩa là phe Long đang đông và trả phí cao, dễ bị thanh lý dây chuyền, nên bot bỏ lệnh Buy khi funding > `InpFundingMax` (mặc định 0,03% mỗi 8 giờ). Ngược lại bỏ lệnh Sell khi funding < −0,03%.
- Khi backtest: script tự tải lịch sử funding miễn phí từ Binance vào thư mục *Common\Files* của MT5.
- Khi chạy thật: bot hỏi Binance mỗi giờ. Cần vào *Tools → Options → Expert Advisors → Allow WebRequest* và thêm `https://fapi.binance.com`. Bảng thông tin có dòng `Funding`; nếu ghi "KHONG CO DU LIEU" thì bộ lọc đang không chặn gì.
- Khi chạy thật, bot lấy mức funding **đã chốt** gần nhất (giống dữ liệu backtest), không lấy mức dự kiến của kỳ tới.
- Funding là của Binance, không phải của Exness, và không đại diện cho toàn thị trường.

**Bộ lọc từ nghiên cứu tâm lý và tương quan** (xem [tai-lieu/tam-ly-hanh-vi-va-bot.md](tai-lieu/tam-ly-hanh-vi-va-bot.md)). Tất cả mặc định tắt, đang thử trên cấu hình C. Thiếu dữ liệu thì bộ lọc không chặn lệnh nào.
- `InpUseFearGreed`: bỏ Buy khi Fear & Greed Index của hôm qua ≥ `InpFngGreedMax` (76, tham lam cực độ), bỏ Sell khi ≤ `InpFngFearMin` (24, sợ hãi cực độ). Dữ liệu từ alternative.me, có từ 2018.
- `InpUseAttention`: chỉ vào lệnh khi lượt xem Wikipedia bài "Bitcoin" (hoặc "Ethereum") trung bình 7 ngày cao hơn trung bình 30 ngày, tức sự chú ý đang tăng.
- `InpUseMarketFilter`: chỉ Buy khi Nasdaq (`USTEC`, bot tự thử `USTECm`) đóng cửa D1 trên EMA200, chỉ Sell khi dưới.
- `InpAvoidUSNews`: không vào lệnh trong `InpNewsHours` (2) giờ trước và sau tin Mỹ quan trọng. Khi chạy thật bot dùng lịch kinh tế của MT5. Khi backtest bot dùng file `du-lieu/tin_my.csv`: lịch họp Fed (FOMC, 14:00 giờ New York) và ngày công bố CPI (8:30 giờ New York) từ 2020, đã đổi sang giờ UTC, lấy từ trang của Fed và BLS. Cần cập nhật file này khi có lịch năm mới. File lệnh có thêm cột `GioToiTin` (số giờ từ lúc vào lệnh tới tin gần nhất, âm là tin đã ra trước đó).
- Khi backtest, script tự tải Fear & Greed và lượt xem Wikipedia vào *Common\Files*. Khi chạy thật, bot tải lại mỗi 6 giờ; cần thêm `https://api.alternative.me` và `https://wikimedia.org` vào *Allow WebRequest*.

**Giảm rủi ro khi BTC và ETH cùng có lệnh** (đang bật): hai đồng thường đi cùng nhau, nên nếu một mã trong `InpCorrSymbols` (`BTCUSDm,ETHUSDm`) đã có lệnh thì lệnh mới trên mã kia chỉ rủi ro `InpCorrRiskScale` × 1% (mặc định 0,5%). Thêm một trần chung `InpMaxGroupRiskPct` (1,5%): tổng tiền có thể mất của lệnh đang mở trên mã kia (tính từ giá vào tới SL) cộng với lệnh mới không vượt 1,5% vốn của bot. Lệnh kia đã dời SL qua giá vào thì tính là 0. Lệnh không có SL tính bằng 1%. Hết chỗ thì bot bỏ tín hiệu. Làm tròn lot cũng không được vượt các giới hạn này. Hai bot H4 đóng nến cùng giờ, nên trước khi tính lot mỗi bot giữ một khóa chung (biến toàn cục của MT5) và ghi lại phần rủi ro mình sắp dùng, rồi mới gửi lệnh. Bot kia phải chờ, và khi tính sẽ thấy phần đã giữ chỗ. Không lấy được khóa trong 5 giây thì bot **không vào lệnh** và thử lại ở tick sau. Khóa bị bỏ quên quá 60 giây (ví dụ bot kia bị tắt giữa chừng) thì tự hết hạn. Vì vậy hai bot phải chạy trên **cùng một MT5** (cùng một thư mục cài đặt trên cùng máy / VPS). Khóa và phần giữ chỗ dùng biến toàn cục của MT5, nên **không đồng bộ giữa hai terminal, hai máy hay hai VPS**: chạy BTC ở terminal này và ETH ở terminal khác thì mỗi bot chỉ thấy lệnh đã khớp của bot kia, không thấy phần đang giữ chỗ. Bot ghi nhắc điều này vào nhật ký lúc khởi động. Đặt `InpCorrRiskScale = 1` và `InpMaxGroupRiskPct = 0` để tắt. Chỉ có tác dụng khi chạy bot trên cả hai chart; backtest một mã không thấy khác biệt.

**Chưa làm được và lý do:**
- *Open interest:* Binance chỉ cho tải miễn phí 30 ngày gần nhất, không đủ để backtest.
- *Liquidation heatmap (CoinGlass)* và *on-chain (Glassnode):* cần gói trả phí. On-chain lại thay đổi theo ngày, chậm so với bot khung H4.

**Tiêu chí chọn bộ lọc (đặt trước khi xem số):** mỗi lần chạy chỉ có 60–110 lệnh, nên chênh PF 0,1–0,2 có thể chỉ là may. Thử nhiều bộ lọc thì gần như chắc có một bộ "thắng" nhờ may. Vì vậy một bộ lọc chỉ được bật làm mặc định khi đạt **cả hai** điều kiện ở **cả** 3 nơi (3 năm gần đây, 3 năm trước đó, ETH):
- PF cao hơn C ít nhất 0,2.
- Số lệnh không giảm quá 25% so với C.

Không đạt thì giữ C. Mỗi bộ lọc thêm vào là một tham số có thể chỉ khớp với dữ liệu cũ.

**Nên kỳ vọng bao nhiêu:** lấy lần chạy vốn 30.000 làm chuẩn, vì nó không bị lot tối thiểu cắt bớt lệnh: PF khoảng 1,7, sụt giảm Monte Carlo 95% khoảng 15%, khoảng 4–5% khả năng chạm mức dừng hẳn. PF trên 2 của các lần vốn 3.000 là lạc quan.

**Vốn khi backtest:** vốn nhỏ thì nhiều tín hiệu có lot dưới 0,01, đúng vào lúc ATR cao. Bot bỏ các tín hiệu đó, không làm tròn lên. Bản v3.8 từng thử làm tròn lên 0,01 lot khi rủi ro không quá 1,5%: có thêm 10 lệnh nhưng PF giảm từ 2,09 xuống 1,92, lãi gần như không đổi. Vì vậy từ v3.9 làm tròn mặc định tắt (`InpMaxRiskRoundUp = 0`). Các lần chạy `C-lamTronLot1.5` vẫn được giữ để đối chiếu. Hãy backtest với đúng số vốn sẽ chạy thật (sửa `$Deposit` ở đầu `ChayThuNghiem.ps1`, đang là 3000).

Muốn thử cấu hình khác, sửa danh sách `$Runs` trong `ChayThuNghiem.ps1`.

## Vào lệnh "đầu", "giữa" hay "muộn" của xu hướng
Câu hỏi: sau khi bot vào lệnh, thị trường còn bao nhiêu dư địa để đi tiếp so với rủi ro phải chịu? Không đoán "cá voi đã mua chưa", mà đo. Mỗi lần backtest, bot ghi đặc điểm từng lệnh vào `ket-qua/<ngay>-<che-do>-lenh.csv`:

| Cột | Ý nghĩa |
|---|---|
| `KhoangCach_ATR` | Giá vào đã vượt mép kênh Donchian bao xa, tính bằng ATR (mua đuổi) |
| `DoRongKenh_ATR` | Độ rộng kênh trước khi phá vỡ. Hẹp = vừa thoát tích lũy |
| `TuoiXuHuong_nen` | Số nến H4 kể từ lần cuối giá đóng cửa ở nửa kia của giữa kênh |
| `NenTuPhaVoDau`, `SoLanPhaVo` | Số nến kể từ lần phá vỡ đầu tiên của đợt này, và đợt này đã phá vỡ mấy lần |
| `Funding%`, `FundingPhanVi` | Funding lúc vào và phân vị của nó so với 365 ngày trước (0–100) |
| `R`, `MFE_R`, `MAE_R` | Lãi ròng, mức đi thuận lớn nhất và mức đi ngược lớn nhất, đều tính theo R (khoảng SL ban đầu). Từ v4.9 tính bằng nến M1 nằm trọn từ lúc vào tới lúc thoát, cộng giá vào/thoát thật (sai số tối đa 1 phút mỗi đầu). Bản trước dùng nến H4 gồm cả nến thoát nên tính cả giá sau khi đã đóng lệnh: đừng dùng số MFE/MAE của file trước v4.9 |
| `Spread_diem` | Spread (point) của phút vào lệnh, theo dữ liệu MT5. Dùng để chọn ngưỡng `InpMaxSpreadPoints` (đang tắt) từ số đo thay vì đoán |

Open interest chưa có: Binance chỉ cho tải miễn phí 30 ngày gần nhất.

**Ngưỡng đặt trước (ghi ngày 06/11/2026, trước khi xem số):**
- Khoảng cách: đầu < 0,3 ATR, giữa 0,3–1,0, muộn > 1,0.
- Nến từ lần phá vỡ đầu: đầu 0–2 nến, giữa 3–15, muộn > 15 (hơn 2,5 ngày).
- Funding: thấp < phân vị 50, trung bình 50–80, cao > 80.

So sánh lãi ròng, R trung bình, tỷ lệ thắng và MFE giữa ba nhóm. Chỉ khi nhóm "muộn" kém rõ ràng ở **cả** 3 năm gần đây, 3 năm trước đó và ETH thì mới thêm bộ lọc tương ứng. Bộ lọc đó vẫn phải qua tiêu chí chung (PF +0,2 ở cả 3 nơi, số lệnh không giảm quá 25%). Không chỉnh lại ngưỡng sau khi đã xem số.

## Giai đoạn tiếp theo: chốt C và chạy demo
- **Ngừng thêm bộ lọc.** Đã thử hơn 40 cấu hình; càng thử nhiều, cấu hình "tốt nhất" càng dễ chỉ là may trên dữ liệu cũ. Giữ C (Donchian 20 H4 + ADX). Các bộ lọc vẫn có trong code nhưng tắt.
- **Chạy demo 2–3 tháng**, rồi so từng lệnh demo với backtest cùng giai đoạn: giờ vào, giá khớp, trượt giá, spread, swap. Đây là phép thử còn thiếu.
- **Vốn:** với 3.000, khoảng 27% tín hiệu bị bỏ vì lot dưới 0,01, và chúng rơi đúng lúc ATR cao (thị trường chạy mạnh). Hãy backtest và demo với đúng số vốn sẽ dùng thật, hoặc bật `InpMaxRiskRoundUp` (ví dụ 1,5) để không bỏ các tín hiệu đó.
- **ETH yếu hơn BTC** (PF khoảng 1,35–1,4 so với khoảng 2, sụt giảm Monte Carlo 95% khoảng 15%). Giai đoạn demo nên chỉ chạy BTC; nếu chạy cả ETH thì đặt rủi ro ETH thấp hơn (ví dụ một nửa) trong cài đặt của chart ETH.
- **Lợi nhuận dồn vào vài lệnh:** trong lần tick thật, 5 lệnh tốt nhất chiếm khoảng 29,7R trên tổng 33R của 85 lệnh. Chuẩn bị tinh thần cho những đợt dài hòa hoặc lỗ nhẹ, không tắt bot giữa chuỗi thua, và ưu tiên bot chạy liên tục (VPS).

## Vốn nhỏ (1–2 triệu VNĐ) và tài khoản Cent
BTC không chạy được với vốn này: lot nhỏ nhất 0,01 BTC với SL 2,5 × ATR H4 (khoảng 3.000 USD) là mất khoảng 30 USD mỗi lần dính SL. Tài khoản Standard Cent của Exness không có BTC.

Tài khoản Cent có vàng và forex, nơi 0,01 lot rủi ro nhỏ hơn nhiều. Nút 1 vì vậy chạy thêm cấu hình C trên `XAUUSDm`, `EURUSDm`, `GBPUSDm`, `USDJPYm` với vốn 3.800 (bằng 1 triệu VNĐ ≈ 3.800 USC, vì lot Cent bằng 1/100 lot thường), cả 3 năm gần đây lẫn 3 năm trước đó. Một mã chỉ được xem xét khi đạt **cả** ba điều kiện (đặt trước khi xem số): PF ≥ 1,3 ở cả hai giai đoạn, ít nhất 30 lệnh mỗi giai đoạn, và `BoQuaLot` thấp. Mã đạt vẫn phải chạy demo trước khi dùng tiền thật.

## Khi chuyển sang tiền thật
- Các nút trong VS Code hỏi trước khi lấy code mới, nhưng vẫn compile thẳng vào MT5 (MT5 tự nạp lại bot đang chạy khi file đổi). Hãy chạy bot thật trên **một bản MT5 cài riêng** (không dùng để backtest) và chỉ cập nhật bản đó bằng tay.
- Muốn tắt hẳn việc tự compile khi mở VS Code, xóa khối `"runOptions"` trong `.vscode/tasks.json`. Nếu compile lỗi, script trả lại file bot cũ nên bot trên chart vẫn chạy bản trước.
- BTC có thể trượt giá qua SL khi có tin, và swap crypto qua đêm có thể cao.
- Không bao giờ chia sẻ mật khẩu MT5. Giữ repo GitHub ở chế độ riêng tư.

## Giờ server
- Khung giờ nghỉ và mốc "đầu ngày" tính theo **giờ server** (cột thời gian trong Market Watch).
- Server Exness thường là GMT+0, tức chậm 7 tiếng so với giờ Việt Nam. Hãy kiểm tra lại giờ server của bạn.
