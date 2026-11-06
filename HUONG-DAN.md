# Hướng dẫn bot BTC (MT5) v4.4

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
Mở thư mục bot bằng VS Code. Các nút nằm ở **Terminal → Run Task…**. Bạn không cần bấm Sync hay compile: mỗi nút tự lấy code mới nhất từ GitHub và compile trước khi chạy.

| Nút | Khi nào dùng |
|---|---|
| **1. So sanh cau hinh (nhanh)** | Việc chính lúc này. Chạy khoảng 40 lần backtest, song song trên mọi nhân CPU. Xong thì bảng kết quả **tự được đẩy lên GitHub** (thư mục `ket-qua/`), bạn chỉ cần nhắn Claude "xong rồi". Nếu đẩy lên thất bại, gửi file `ket-qua-backtest-....zip` thay thế. |
| **2. Cap nhat bot vao MT5** (Ctrl+Shift+B) | Khi bot đang chạy trên chart và muốn nạp bản mới ngay. |
| **3. So sanh cau hinh (chinh xac, cham)** | Chỉ khi Claude bảo. Chạy lại bằng tick thật cho khoảng 20 cấu hình cuối, chậm hơn nhiều. |

Khi mở VS Code, code đang có trên máy được compile vào MT5. Bước này không tự kéo code mới từ GitHub.

**Chạy song song:** script gom các lần chạy cùng mã, cùng khoảng ngày và cùng vốn thành một đợt *Optimization* của MT5. MT5 tự chia các lần trong đợt cho mọi nhân CPU, nên máy 8 nhân nhanh hơn khoảng 6–8 lần. Mỗi cấu hình có một số thứ tự (`InpPreset`); bot đọc cấu hình đó từ file `TrendBot_presets.csv` mà script ghi vào *Common\Files*. Muốn chạy lần lượt như cũ (để dò lỗi) thì chạy `ChayThuNghiem.ps1 -TuanTu`. Nếu MT5 tắt bớt agent trong *Tester → Agents*, đợt chạy sẽ chậm lại tương ứng.

Bot cũng chỉ kiểm tra lệnh đang mở và giới hạn lỗ mỗi giây một lần (`InpManageEverySec = 1`) thay vì mọi tick. Khi có nến mới hoặc vừa có giao dịch thì vẫn kiểm tra ngay. Lần chạy `C-moiTick` giữ cách cũ để đối chiếu.

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
- `InpAvoidUSNews`: không vào lệnh trong `InpNewsHours` giờ trước và sau tin Mỹ quan trọng (lịch kinh tế của MT5). Chỉ hoạt động khi chạy thật vì backtest không có lịch kinh tế, nên chưa kiểm chứng được.
- Khi backtest, script tự tải Fear & Greed và lượt xem Wikipedia vào *Common\Files*. Khi chạy thật, bot tải lại mỗi 6 giờ; cần thêm `https://api.alternative.me` và `https://wikimedia.org` vào *Allow WebRequest*.

**Giảm rủi ro khi BTC và ETH cùng có lệnh** (đang bật): hai đồng thường đi cùng nhau, nên nếu một mã trong `InpCorrSymbols` (`BTCUSDm,ETHUSDm`) đã có lệnh thì lệnh mới trên mã kia chỉ rủi ro `InpCorrRiskScale` × 1% (mặc định 0,5%). Thêm một trần chung `InpMaxGroupRiskPct` (1,5%): tổng tiền có thể mất của lệnh đang mở trên mã kia (tính từ giá vào tới SL) cộng với lệnh mới không vượt 1,5% vốn của bot. Lệnh kia đã dời SL qua giá vào thì tính là 0. Lệnh không có SL tính bằng 1%. Hết chỗ thì bot bỏ tín hiệu. Làm tròn lot cũng không được vượt các giới hạn này. Hai bot H4 đóng nến cùng giờ, nên trước khi tính lot mỗi bot giữ một khóa chung (biến toàn cục của MT5) và ghi lại phần rủi ro mình sắp dùng, rồi mới gửi lệnh. Bot kia phải chờ, và khi tính sẽ thấy phần đã giữ chỗ. Không lấy được khóa trong 5 giây thì bot **không vào lệnh** và thử lại ở tick sau. Khóa bị bỏ quên quá 60 giây (ví dụ bot kia bị tắt giữa chừng) thì tự hết hạn. Vì vậy hai bot phải chạy trên **cùng một MT5**. Đặt `InpCorrRiskScale = 1` và `InpMaxGroupRiskPct = 0` để tắt. Chỉ có tác dụng khi chạy bot trên cả hai chart; backtest một mã không thấy khác biệt.

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

## Khi chuyển sang tiền thật
- Các nút trong VS Code kéo code mới và compile thẳng vào MT5, nên bot trên chart có thể nạp code bạn chưa kịp xem. Hãy chạy bot thật trên **một bản MT5 cài riêng** (không dùng để backtest) và chỉ cập nhật bản đó bằng tay.
- Muốn tắt hẳn việc tự compile khi mở VS Code, xóa khối `"runOptions"` trong `.vscode/tasks.json`. Nếu compile lỗi, script trả lại file bot cũ nên bot trên chart vẫn chạy bản trước.
- BTC có thể trượt giá qua SL khi có tin, và swap crypto qua đêm có thể cao.
- Không bao giờ chia sẻ mật khẩu MT5. Giữ repo GitHub ở chế độ riêng tư.

## Giờ server
- Khung giờ nghỉ và mốc "đầu ngày" tính theo **giờ server** (cột thời gian trong Market Watch).
- Server Exness thường là GMT+0, tức chậm 7 tiếng so với giờ Việt Nam. Hãy kiểm tra lại giờ server của bạn.
