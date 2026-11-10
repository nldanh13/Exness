# Hướng dẫn bot BTC (MT5) v5.10.5

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

**Dọn file:** mỗi lần chạy, sau khi đóng gói xong, script xóa báo cáo HTML/PNG của MT5 (đã nằm trong zip) và chỉ giữ file zip mới nhất trong thư mục bot. Thư mục `ket-qua/` chỉ giữ lần chạy mới nhất của mỗi chế độ (`nhanh`, `chinhxac`); file cũ bị xóa trong cùng commit đẩy kết quả mới, nên vẫn xem lại được trong lịch sử git.

**Khi đang backtest:**
- Script sẽ hỏi đóng MT5. Đóng MT5 là **dừng mọi bot đang chạy trên MT5 đó**.
- Tắt terminal VS Code hay tắt máy giữa chừng thì lượt chạy dừng và không có file zip. Không hỏng gì cả, chỉ cần chạy lại. Dữ liệu giá đã tải vẫn được giữ.

## Giao diện trên trình duyệt (không cần VS Code)
Bấm đúp **`GiaoDien.cmd`** trong thư mục bot. Trình duyệt mở `http://localhost:8765` với hai trang:

Giao diện dùng từ ngữ trung tính (phương án, mô phỏng, môi trường chính/thử, mục mở) để người khác nhìn vào không biết là bot giao dịch. Bảng đối chiếu:

| Trên giao diện | Nghĩa là |
|---|---|
| Ứng dụng | MT5 |
| Môi trường **chính** / **thử** | Tài khoản thật / demo |
| Mục mở | Lệnh bot đang giữ |
| Phương án | Chiến lược (cấu hình backtest); `Dc` = Donchian, đuôi `-B` = chạy trên ETH |
| Mô phỏng nhanh / chi tiết | Nút 1 (thử các chiến lược) / nút 3 (kiểm tra kỹ) |
| Cập nhật | Nút 2 (lấy code mới + cập nhật bot) |
| Gửi nhật ký | Nút 4 |
| Kết quả, Sụt giảm lớn nhất, Tỷ lệ tốt, Số lượt | Lời/lỗ (USD), DD max, tỷ lệ thắng, số lệnh |
| Giai đoạn gần / trước, Bộ dữ liệu B | 3 năm gần đây / 3 năm trước, ETH |
| Chiều + / − | Mua / Bán |

- **Điều khiển**, từ trên xuống: *Tình trạng* (ba ô Ứng dụng, Môi trường, Phiên bản; bot từ v5.4 mới báo được, qua file `TrendBot_trangthai_*.txt` trong Common\Files, không ghi số tài khoản), *Tiến trình* (chỉ hiện khi có việc), *Kết luận gần nhất*, rồi *Chạy việc mới*: nhóm Mô phỏng (1. Nhanh, 2. Chi tiết) và nhóm Khác (Cập nhật, Gửi nhật ký, Tự chạy 1 lần).
- **Kết quả**: mỗi phương án có kết luận *Đạt*, *Chưa đạt* hoặc *Chưa đủ dữ liệu*. Bấm một dòng để xem giải thích và kết quả cộng dồn; "Chỉ số chi tiết" hiện PF, Recovery, t-stat…

Tiêu chí "đạt": PF sau trượt giá 0,05% từ 1,3 trở lên ở **cả** 3 năm gần đây và 3 năm trước đó, mỗi giai đoạn ít nhất 30 lệnh.

Giữ cửa sổ đen của giao diện mở trong lúc dùng; đóng nó là tắt giao diện. Giao diện chỉ mở trên máy này (localhost).

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
- **Lỗ ngày:** lỗ 3% so với đầu ngày (00:00 giờ server) thì bot khóa tới hôm sau, và đóng lệnh đang mở nếu `InpCloseOnDailyLoss = true`. Lệnh đang lãi trả bớt lãi không bị tính là lỗ. Khóa này **không mở được trong ngày**, kể cả bằng `InpResetHalt` (chỉ mở được trạng thái dừng hẳn), để chống việc muốn "gỡ lại" ngay sau khi thua.
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
| `E_R`, `tStat` | Lãi trung bình mỗi lệnh tính theo R (1R = số tiền rủi ro ở SL ban đầu), và độ tin cậy thống kê t = E[R] / (độ lệch chuẩn / √số lệnh). t > 2 là tối thiểu; vì đã thử rất nhiều cấu hình, đòi **t > 3** |
| `TyLeThang_CanDuoi95%` | Cận dưới Wilson 95% của tỷ lệ thắng: tỷ lệ thắng "thật" gần như chắc chắn không thấp hơn số này |
| `MC_ChuoiThua95` | Chuỗi thua liên tiếp dài nhất ở trường hợp xấu (95%) trong Monte Carlo. Chuẩn bị tinh thần cho chuỗi dài cỡ này |
| `GiamCoDD` | Số lệnh bị giảm cỡ vì đang sụt giảm (chỉ khi bật `InpDDScale`) |
| `SoDot` | Từ v5.8: số **đợt**. Các lớp nhồi vào khi lớp trước cùng chiều còn mở được gộp thành một đợt, vì chúng thắng thua cùng nhau. `E_R`, `tStat`, `TyLeThang_CanDuoi95%`, bỏ top 5 và Monte Carlo đều tính theo đợt (1R = rủi ro của lớp đầu). Không nhồi lệnh thì số đợt = số lệnh, các cột này không đổi so với trước |
| `ChoHoi_ChamGia`, `ChoHoi_HetNen`, `ChoHoi_BiHuy`, `ChoHoi_Khop` | Chỉ khi bật `InpEntryPullATR`: số lần giá chạm mức chờ, số lần hết nến mà giá chưa hồi, số lần bị hủy vì kiểm tra lại thấy không đủ điều kiện (giờ, spread, số lệnh/ngày, lỗ ngày, tin Mỹ, đồng thuận khung nhỏ, các bộ lọc), và số lệnh **server đã khớp thật**. Chạm giá chưa chắc là khớp |
| `RuiRoMoMax%` | Rủi ro mở lớn nhất của bot ngay sau khi vào một lớp: rủi ro còn lại của các lớp cũ (giá vào → SL hiện tại) cộng lớp mới, theo % vốn của bot. Nhồi lệnh đúng thiết kế thì xấp xỉ `InpRiskPercent` |
| `NhoiBiBoVoiRuiRo` | Số lần nhồi bị bỏ vì các lớp cũ vẫn còn rủi ro bằng một lệnh chuẩn (chưa dời được SL về hòa vốn) |
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

**Giảm rủi ro khi BTC và ETH cùng có lệnh** (đang bật): hai đồng thường đi cùng nhau, nên nếu một mã trong `InpCorrSymbols` (`BTCUSDm,ETHUSDm`) đã có lệnh thì lệnh mới trên mã kia chỉ rủi ro `InpCorrRiskScale` × 1% (mặc định 0,5%). Thêm một trần chung `InpMaxGroupRiskPct` (1,5%): tổng tiền có thể mất của lệnh đang mở trên mã kia (tính từ giá vào tới SL) cộng với lệnh mới không vượt 1,5% vốn của bot. Lệnh kia đã dời SL qua giá vào thì tính là 0. Lệnh không có SL tính bằng 1%. Từ v5.9 trần này cộng cả các lớp nhồi đang mở của chính bot, và riêng chuỗi nhồi của một bot không được vượt rủi ro của 1 lệnh chuẩn (1%). **Đây là giới hạn theo mô hình, không phải mức lỗ tối đa được bảo đảm:** mô hình giả định SL khớp đúng giá. Khi giá nhảy mạnh (gap cuối tuần, tin lớn, thanh lý dây chuyền), SL có thể khớp xa hơn và nhiều lớp cùng lỗ, nên lỗ thật có thể vượt 1–1,5%. Hết chỗ thì bot bỏ tín hiệu. Làm tròn lot cũng không được vượt các giới hạn này. Hai bot H4 đóng nến cùng giờ, nên trước khi tính lot mỗi bot giữ một khóa chung (biến toàn cục của MT5) và ghi lại phần rủi ro mình sắp dùng, rồi mới gửi lệnh. Bot kia phải chờ, và khi tính sẽ thấy phần đã giữ chỗ. Không lấy được khóa trong 5 giây thì bot **không vào lệnh** và thử lại ở tick sau. Khóa bị bỏ quên quá 60 giây (ví dụ bot kia bị tắt giữa chừng) thì tự hết hạn. Vì vậy hai bot phải chạy trên **cùng một MT5** (cùng một thư mục cài đặt trên cùng máy / VPS). Khóa và phần giữ chỗ dùng biến toàn cục của MT5, nên **không đồng bộ giữa hai terminal, hai máy hay hai VPS**: chạy BTC ở terminal này và ETH ở terminal khác thì mỗi bot chỉ thấy lệnh đã khớp của bot kia, không thấy phần đang giữ chỗ. Bot ghi nhắc điều này vào nhật ký lúc khởi động. Đặt `InpCorrRiskScale = 1` và `InpMaxGroupRiskPct = 0` để tắt. Chỉ có tác dụng khi chạy bot trên cả hai chart; backtest một mã không thấy khác biệt.

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
| `ADX`, `ER20`, `ATR_PhanVi90ngay`, `GioUTC`, `Thu` | Chế độ thị trường lúc vào lệnh: ADX, Efficiency Ratio 20 nến (gần 1 = đi thẳng, gần 0 = nhiễu), ATR hiện tại so với 90 ngày (0–100), giờ và thứ (0 = Chủ nhật). Sau 200+ lệnh mới xem E[R] theo từng nhóm |
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

## Vốn nhỏ (1–2 triệu VNĐ) và lướt sóng ngắn
Chỉ giao dịch BTC. Bot H4 không chạy được với vốn này: lot nhỏ nhất 0,01 BTC với SL 2,5 × ATR H4 (khoảng 3.000 USD) là mất khoảng 30 USD mỗi lần dính SL. Tài khoản Standard Cent của Exness không có BTC.

Nút 1 chạy thêm cùng cấu trúc C trên khung M30, M15, M10, M5, M3 và M1 (`Ngan-M30` … `Ngan-M1`, cả 3 năm gần đây lẫn 3 năm trước), vốn 30.000 để đo lợi thế mà lot tối thiểu không cắt lệnh. Tiêu chí đặt trước: `PF_Truot0.05%` ≥ 1,3 ở cả hai giai đoạn. Khung đạt phải chạy lại bằng tick thật rồi demo. Mỗi khung có thêm bản `+khoiLuong` (`InpBreakMinVol = 1,5`): nến phá vỡ phải có số tick ít nhất 1,5 lần trung bình 20 nến trước. MT5 của Exness chỉ có số tick, không có khối lượng thật. Chi phí trong backtest lấy từ spread lịch sử của MT5; "Phí" hiện trong app Exness chính là spread (6,4 USD × 0,01 BTC ≈ 1.660 VNĐ), tài khoản Standard không có hoa hồng riêng. Với M3 và M1, chế độ nhanh chỉ có 4 giá mỗi phút nên kết quả rất thô, chỉ dùng để loại bớt. Kể cả lướt sóng, với 1 triệu VNĐ, SL khoảng 95 USD đã là khoảng 2,5% tài khoản mỗi lệnh.

**Hai chiến thuật lướt sóng khác** (tham số cố định từ đầu, không dò tìm, có TP, không trailing):
- **RSI hồi** (`InpStrategy = 2`, `Ngan-RSI-M5`, `Ngan-RSI-M15`): giá trên EMA200 của khung nhưng RSI(2) dưới 10 (vừa giảm mạnh ngắn hạn) thì Buy, ngược lại thì Sell. Thêm bộ lọc xu hướng D1 (giá D1 đúng phía EMA200 D1), vì EMA200 của M5 chỉ chứa khoảng 17 giờ dữ liệu. SL 1,5 ATR, TP 1R, nên cần thắng trên 50% số lệnh (cao hơn nữa sau chi phí) mới có lãi. Ý tưởng: trong xu hướng, các cú giảm ngắn thường hồi lại.
- **ORB phiên Mỹ** (`InpStrategy = 3`, `Ngan-ORB-M5`): lấy 30 phút đầu từ lúc New York mở cửa 9:30. Bot tự tính theo giờ mùa hè/đông của Mỹ (13:30 UTC từ Chủ nhật thứ 2 tháng 3 tới Chủ nhật đầu tháng 11, còn lại 14:30 UTC), giả định giờ server là UTC như Exness. Tắt `InpOrbNewYork` để tự đặt giờ bằng `InpOrbStartMin`. Trong 4 giờ sau, nến đầu tiên đóng ngoài vùng thì vào theo hướng đó. Bỏ qua thứ Bảy và Chủ nhật (chứng khoán Mỹ nghỉ; ngày lễ Mỹ chưa loại). SL 1 ATR, TP 2R, tối đa 1 lệnh/ngày. Ý tưởng: lúc thị trường Mỹ mở, khối lượng BTC tăng mạnh và giá hay chạy một chiều.

**Ba chiến thuật thêm ngày 06/11** (luật cố định, chưa dò tham số):
- **Đảo chiều sau cú chạy mạnh** (`InpStrategy = 4`, M5): giá trong ngày đã chạy một chiều ít nhất 75% ATR(20) của khung ngày, đỉnh/đáy vừa lập trong 6 nến gần nhất, và nến vừa đóng bắt đầu quay đầu (đóng qua đáy/đỉnh nến trước). Vào ngược lại; SL quá đỉnh/đáy 0,3 ATR; TP ở dải Bollinger(20) bên kia.
- **Fair Value Gap** (`InpStrategy = 5`, M30 và H1): nến lớn (≥ 2 ATR, số tick ≥ 1,5 lần trung bình) để lại khoảng trống giữa nến trước và nến sau nó. Lần đầu giá quay lại chạm khoảng trống thì vào theo hướng nến lớn; SL quá khoảng trống 0,5 ATR; TP 2R. Chưa có bước xem khung 1 phút.
- **Wyckoff spring / upthrust** (`InpStrategy = 6`, M5 và M15): vùng đi ngang 20 nến, rộng không quá 4 ATR, mỗi biên được chạm ít nhất 2 lần. Nến phá ra ngoài rồi đóng lại bên trong thì vào ngược hướng phá; SL quá râu nến 0,2 ATR; TP ở biên bên kia.

Cùng tiêu chí: `PF_Truot0.05%` ≥ 1,3 ở cả hai giai đoạn, rồi chạy lại bằng tick thật. Mọi lần chạy lướt sóng không vào lệnh khi spread trên 1.500 point (15 USD, khoảng gấp đôi bình thường). Xét bằng lãi ròng sau spread, swap, phí và kịch bản trượt giá, không xét tỷ lệ thắng.

**Kết quả 06/11/2026 (đợt nhanh 1756): không chiến thuật lướt sóng nào đạt.** Ngay cả khi chưa cộng trượt giá, mọi cấu hình đều có PF dưới 1 ở 3 năm trước (Donchian M1–M30, có và không có lọc khối lượng, RSI M5/M15, ORB M5). Cấu hình khá nhất ở 3 năm gần đây là Donchian M30 + khối lượng (PF 1,51), nhưng 3 năm trước chỉ 0,74, và 1,18 sau trượt giá. Với vốn 1 triệu, gần như mọi tín hiệu bị bỏ vì 0,01 BTC đã rủi ro quá 1% (RSI M15: 1.011 tín hiệu bị bỏ, 0 lệnh). Đối chiếu: Donchian H4 (C) vẫn PF 2,09 / 2,82 ở hai giai đoạn, nhưng bỏ 5 lệnh lớn nhất thì PF chỉ còn 1,15 / 1,36. Không thêm cấu hình nào vào `chinh-xac.txt`.

**Kết quả đợt 2357 (06/11/2026):** ba chiến thuật mới (đảo chiều M5, FVG M30/H1, Wyckoff M5/M15) đều không đạt: E[R] âm hoặc gần 0, t-stat từ −9 tới 0,3. Vốn 1 triệu với rủi ro tới 5%/lệnh: các bản có đủ lệnh để đánh giá đều lỗ hoặc gần hòa, sụt giảm 40–76% trong 3 năm (Monte Carlo 95% có bản trên 100%, tức cháy tài khoản); vài bản dương chỉ có 2–11 lệnh, không đủ để tin. Giảm cỡ theo sụt giảm: không đổi gì trên BTC (sụt giảm chưa từng quá 5%), trên ETH lãi giảm 500 → 398, PF 1,39 → 1,33; giữ tắt. Donchian H4: t-stat 2,09 (3 năm gần đây) và 2,48 (3 năm trước), chưa tới mức 3 nên càng cần demo.

**Nhồi lệnh theo đà** (`InpPyramidMax`, `InpPyramidStepATR`, `InpExitOnEMA`; thêm 07/11): vào lệnh khi phá vỡ Donchian 20; giá đi thuận thêm 1 ATR từ lệnh gần nhất và vẫn ở đúng phía EMA20 thì vào thêm một lệnh cùng chiều (tối đa 3). Trước khi vào thêm, các lệnh cũ dời SL về hòa vốn, nên rủi ro cả chuỗi chỉ khoảng 1 lệnh. Không bao giờ nhồi khi đang lỗ. Có dấu hiệu hết đà (nến đóng cắt EMA20 ngược chiều) thì đóng hết. Thử trên H4 (`C+nhoi3` giữ trailing như C; `Nhoi3-H4` thoát theo EMA20) và H1, M30, M15, M5 (`Ngan-Nhoi3-*`). Cột `NhoiLenh` là số lệnh vào thêm. Bản `+huongH4` / `+huongH1`: khung nhỏ chỉ dùng để vào lệnh, còn hướng do khung lớn quyết định (giá H4 hoặc H1 đóng trên EMA50 thì chỉ mua, dưới thì chỉ bán).

**Từ nghiên cứu (07/11):**
- *Nhồi lệnh bước 2R* (`C+nhoi3-buoc2R`): theo Concretum Group (40 thị trường futures từ 1980), thêm một lớp mỗi khi giá đi thêm 2 lần khoảng rủi ro ban đầu. Lãi tăng mạnh nhưng sụt giảm tối đa gần gấp đôi (48,7% so với 25,7%), tỷ lệ thắng thấp hơn, lãi dồn vào vài sóng rất lớn. Bước 1 ATR (0,4R) của `Nhoi3` dày hơn nhiều, nên lệnh thêm dễ bị cắt hơn.
- *MACD đa khung* (`InpStrategy = 7`, `Ngan-MACD-H1+D1`): chép đúng luật đã công bố của Quantpedia trên BTC 2018–2025: MACD(12,26,9) khung H1 cắt lên thì mua, chỉ khi MACD khung ngày đang tăng; chỉ mua; thoát ở nến H1 đầu tiên đóng đỏ (`InpExitOnBar`). Họ báo Sharpe từ 0,33 (chỉ H1) lên 0,80 (thêm lọc ngày) và 1,07 (thêm thoát nến đỏ). Bot thêm SL 2,5 ATR để an toàn. Lưu ý: giai đoạn của họ trùng dữ liệu của ta, và họ dùng sàn Gemini không có spread CFD.

**Vốn 1 triệu VNĐ:** các cấu hình lướt sóng ưu tiên (RSI M15, RSI M5, Donchian M15, M30, ORB M5) có thêm bản `-von1tr` với vốn 38 USD (≈ 1 triệu VNĐ). Bản 30.000 trả lời "chiến lược có lợi thế không"; bản `-von1tr` cho thấy kết quả thật với tài khoản của bạn, gồm số tín hiệu bị bỏ (`BoQuaLot`) vì 0,01 BTC đã rủi ro quá 1%.

Bản `-von1tr-rr5`: vẫn vào 0,01 lot nếu dính SL mất tối đa 5% tài khoản (`InpMaxRiskRoundUp = 5`), để thấy kết quả thật khi lướt sóng với 1 triệu.

**Chọn nhóm khi bấm nút 1:** VS Code hiện menu: *Theo chi-chay.txt (Claude chọn)* (mặc định), *H4 và các bộ lọc*, *Lướt sóng (vốn 30.000)*, *Lướt sóng với vốn 1 triệu VNĐ*, *Chạy hết*.

**Chọn chiến thuật khi gắn bot lên chart:** mỗi lần cập nhật, các bộ cài đặt sẵn trong `cai-dat/` được chép vào MT5 (bộ tên cũ trước v5.10.1 tự bị xóa). Khi gắn bot, mở tab *Inputs*, bấm **Load** và chọn một file:

| File | Nội dung | Trạng thái |
|---|---|---|
| `01-Chuan-Donchian-H4.set` | Cấu hình C: phá vỡ Donchian 20 nến H4, SL 2,5 ATR, trailing 3 ATR, rủi ro 1% | **Đã kiểm thử.** Cần vốn từ 3.000 USD |
| `02-Tu-bam-lenh-H4.set` | Bạn tự bấm BUY/SELL, bot tính lot, đặt SL, nhồi tối đa 3 lớp, trailing | Công cụ hỗ trợ |
| `03-Bao-ve-lenh-tay.set` | Bot không vào lệnh, chỉ canh lệnh vào tay (tự đặt SL, giới hạn rủi ro và lỗ ngày) | Công cụ hỗ trợ |
| `TN1` … `TN7` | Nhồi lệnh, M30, RSI, ORB, Wyckoff, demo 1 triệu (M5 và SL M5) | **Chưa đạt** kiểm thử, chỉ chạy demo |

Mỗi file ghi đủ thông số giao dịch, nên Load một bộ không còn sót giá trị của bộ nạp trước (trước đây file chỉ ghi một phần, và MT5 giữ nguyên các thông số không có trong file). Cài đặt riêng của bạn (thông báo, Telegram, nhật ký, vốn dành cho bot, mã nhận diện) không nằm trong file nên Load giữ nguyên. Mỗi chiến thuật tự có mã nhận diện riêng, nên gắn nhiều chiến thuật trên cùng `BTCUSDm` (mỗi cái một chart) không lẫn lệnh.

**Chỉ chạy một phần:** nếu có file `chi-chay.txt` với các mẫu tên (ví dụ `*-von1tr*`), nút 1 chỉ chạy các cấu hình khớp. Xóa hết các dòng trong file để chạy toàn bộ.

**Chạy tick thật cho lướt sóng:** chế độ nhanh chỉ có 4 giá mỗi phút, nên với M1–M5 việc chạm SL/TP có thể sai nhiều. Nút 3 chạy các cấu hình ghi trong file `chinh-xac.txt`. Sau mỗi đợt nhanh, Claude ghi vào file đó các cấu hình lướt sóng qua được tiêu chí; bạn chỉ cần bấm nút 3.

**Khối lượng tick:** chỉ là số lần báo giá thay đổi trên Exness, không phải số BTC thật được mua bán trên toàn thị trường. Nó cho biết thị trường đang sôi động, không cho biết cá voi có tham gia hay không.

## Chạy nhiều bot trên cùng BTC
Mỗi chiến lược / khung tự có Magic Number riêng: `InpMagic` + 10.000 × chiến lược + số phút của khung (ví dụ RSI M5 = 20261105 + 20.000 + 5). Riêng Donchian H4 giữ nguyên `InpMagic` để không mất liên kết với lệnh cũ. Nhờ vậy Donchian H4 và RSI M5 trên cùng `BTCUSDm` không quản lý nhầm lệnh, trailing hay giới hạn lỗ của nhau. Nếu gắn hai bot cùng chiến lược, cùng khung trên cùng mã, bot thứ hai sẽ báo lỗi và không chạy; muốn chạy thật thì đặt `InpMagic` khác cho bot đó. Kiểm tra này chỉ có tác dụng trong cùng một MT5.

Lưu ý: giới hạn lỗ ngày và sụt giảm tính riêng cho từng bot, không cộng gộp.

## Áp dụng tài liệu "Kiến thức nâng cao" (06/11/2026)
Đã làm:
- **Đo bằng R:** bảng kết quả có `E_R`, `tStat`, cận dưới Wilson của tỷ lệ thắng, chuỗi thua Monte Carlo 95%. R tính từ SL thật gửi kèm lệnh.
- **Giảm cỡ theo sụt giảm** (`InpDDScale`, mặc định tắt, đang thử bằng `C+giamTheoDD` ở cả 3 nơi): sụt 5–10% từ đỉnh thì rủi ro còn 50%, trên 10% còn 25%, chỉ về 100% khi lập đỉnh mới.
- **Nhãn chế độ thị trường** cho từng lệnh trong file lệnh (ADX, Efficiency Ratio, phân vị ATR, giờ, thứ). Chưa dùng làm bộ lọc vì chưa đủ 200 lệnh mỗi chiến lược.
- **Trần rủi ro chung cho nhiều chiến lược trên cùng BTC:** tổng rủi ro của mọi lệnh đang mở trên `InpCorrSymbols` (kể cả bot khác và lệnh tay trên cùng mã) không vượt `InpMaxGroupRiskPct` (1,5%). Lệnh thứ hai trên BTC từ chiến lược khác rủi ro giảm còn `InpCorrRiskScale` (50%).
- **Đo trượt giá thật:** khi chạy demo/thật, mỗi lệnh vào được ghi giá yêu cầu, giá khớp và spread vào `Common\Files\TrendBot_truotgia.csv`. Gửi file này cùng lịch sử demo để so với backtest.

Chưa làm và lý do:
- *Deflated Sharpe, PBO, purged CV:* cần nhiều lệnh hơn và tính ngoài MT5. Thay vào đó dùng t > 3 và tiêu chí đặt trước ở 3 nơi.
- *Kelly:* cần ước lượng tỷ lệ thắng và lãi/lỗ trung bình ổn định (vài trăm lệnh). Với 60–90 lệnh, Kelly bị thổi phồng; giữ 1% cố định.
- *Meta-labeling / ML / HMM:* vài trăm lệnh gần như chắc chắn quá khớp. Chỉ đáng làm khi có chiến lược gốc đã qua kiểm thử và hàng nghìn lệnh.
- *Lọc theo giờ, quán tính trong ngày:* mỗi bộ lọc là thêm một lần thử. Dữ liệu giờ/thứ đã có trong file lệnh để kiểm tra sau.

## Quy tắc cho người vận hành
- Chỉ xem kết quả và đổi thông số vào **một ngày cố định mỗi tuần** (ví dụ Chủ nhật). Mọi thay đổi phải backtest lại trước khi gắn lên chart.
- Không tắt bot vì vừa thua. Không bật lại bot đã tự khóa trong cùng ngày (bot cũng không cho mở khóa lỗ ngày).
- Không vào lệnh tay song song trên cùng tài khoản với bot. Bot sẽ nhắc qua thông báo nếu thấy lệnh tay, vì giới hạn lỗ của bot không tính các lệnh đó.
- Không nạp thêm tiền để "gỡ" khi bot đang sụt giảm.
- Ghi lại mỗi lần muốn can thiệp và lý do (file `nhat-ky-can-thiep.md`), xem lại cuối tuần để nhận ra lúc nào cảm xúc kích hoạt.

## Khi chuyển sang tiền thật
- Các nút trong VS Code hỏi trước khi lấy code mới, nhưng vẫn compile thẳng vào MT5 (MT5 tự nạp lại bot đang chạy khi file đổi). Hãy chạy bot thật trên **một bản MT5 cài riêng** (không dùng để backtest) và chỉ cập nhật bản đó bằng tay.
- Muốn tắt hẳn việc tự compile khi mở VS Code, xóa khối `"runOptions"` trong `.vscode/tasks.json`. Nếu compile lỗi, script trả lại file bot cũ nên bot trên chart vẫn chạy bản trước.
- BTC có thể trượt giá qua SL khi có tin, và swap crypto qua đêm có thể cao.
- Không bao giờ chia sẻ mật khẩu MT5. Giữ repo GitHub ở chế độ riêng tư.

## Giờ server
- Khung giờ nghỉ và mốc "đầu ngày" tính theo **giờ server** (cột thời gian trong Market Watch).
- Server Exness thường là GMT+0, tức chậm 7 tiếng so với giờ Việt Nam. Hãy kiểm tra lại giờ server của bạn.

## Quan tinh trong ngay (bai Shen, Urquhart & Wang 2022) - chien luoc 8

Bai nghien cuu: BTC 2013-2020 tren 5 san giao ngay. "Ngay" tinh tu 17:00 hom truoc toi 17:00 gio New York (luc CME nghi).
- Nua gio dau: gia tu 17:00 hom truoc toi 9:30 sang. Nua gio ke cuoi: 16:00 -> 16:30.
- Ket hop (InpImomMode = 0): Buy luc 16:30 neu nua gio dau tang VA 16:00-16:30 giam; Sell neu nua gio dau giam VA 16:00-16:30 tang; con lai khong vao.
- Che do 1: chi theo nua gio dau. Che do 2: chi dao chieu 16:00-16:30.
- Dong lenh luc 17:00 New York (tu tinh gio mua he/dong, gia dinh gio server = UTC). SL an toan 2,5 ATR M5.

Ket qua trong bai (chua tru phi): ket hop 16,7%/nam, Sharpe 1,72, dung 58%; chi dao chieu 17,3%/nam; chi nua gio dau 7,8%/nam.
Can than: moi ngay chi 1 lenh 30 phut, bien do trung binh rat nho (~0,07%, ~50 USD) so voi spread Exness (~6-20 USD);
du lieu cua bai dung o 2020, hieu ung co the da yeu di sau khi cong bo. Chi tin khi backtest dat tieu chi da dat truoc.
Lan chay: Ngan-IMOM-M5 (ket hop), -dau30, -dao; moi cai co ban 3 nam gan day va 3 nam truoc; ban ket hop co them -von1tr.

## Ket qua dot 7/11/2026 13:42 (61 lan)

- C+nhoi3 (Donchian H4 + nhoi toi 3 lop): loi nhuan gan gap doi C o ca 2 giai doan (1740 vs 962; 1926 vs 1014), t = 2,66 / 3,10,
  PF truot 0,05% = 1,73 / 2,43, it phu thuoc top 5 hon (PF bo top 5: 1,38 / 1,68). Nhung sut giam tang 2-3 lan (12% / 9%),
  loi nhuan chia sut giam thap hon C mot chut: nhoi lenh giong tang rui ro, khong phai "an mien phi". Ung vien duy nhat dang xem them; da them vao chinh-xac.txt.
- C+nhoi3-buoc2R: gan nhu bang C. Nhoi3-H4 khong ADX: kem hon C+nhoi3.
- Luot song nhoi lenh M5-H1, co/khong loc huong H1/H4: deu lo o 3 nam truoc; M5 lo nang (sut giam 62-98%).
- MACD da khung (Quantpedia): lo ca 2 giai doan.
- Quan tinh trong ngay (Shen 2022): truoc phi PF ~1,06-1,09, sau truot 0,05% PF ~0,2. Phi giet chien luoc, nhu du doan.
- Tat ca ban von 1 trieu: lo hoac khong vao duoc lenh.

## Bao ve lenh vao tay (v5.1) - rut ra tu sao ke giao dich tay

Sao ke 9/2025-3/2026 (210 lenh BTC): thang 66% so lenh nhung lo rong, vi lenh lo trung binh gap doi lenh lai.
- Lenh giu > 1 ngay: thang 29%, lo nang nhat. Lenh giu 4-24 gio: thang 88%.
- 44% so lenh la nhoi them khi lenh cung chieu dang lo: nhom nay lo. Nhoi khi dang lai: hoa.
- Lenh <= 0,5 lot: lai. Lenh > 0,5 lot: lo nang. Vai ngay lo lon (16/9, 30/9, 19-20/1) xoa het lai.
- Tinh theo % gia (bo qua co lot), diem vao cua ban trung binh -0,06%/lenh: khong co loi the an de bot copy.

Vi vay bot co che do bao ve lenh tay (InpGuardManual, preset 7-Bao-ve-lenh-tay, chi chay that / demo):
- Lenh tay chua co SL: tu dat SL cach gia vao 1,5%.
- Neu cham SL ma lo hon 3% von: tu dong bot lot (lot nho nhat van qua rui ro thi dong lenh).
- Mo lenh moi cung chieu voi lenh tay dang lo (trung binh gia): dong lenh moi ngay.
- Lenh tay dang lo giu qua 24 gio: dong.
- Lenh tay lo qua 5% trong ngay: dong het va dong moi lenh tay moi toi 0:00 gio server.
Moi lan can thiep deu gui thong bao. Keo preset 7 vao 1 chart BTCUSDm (bot khong tu vao lenh).

Khung gio: lenh tay vao 6-12h UTC thang 90%, vao 0-6h UTC thang 41%. Mau nho, nen da them lan chay "+gio6-12" va "+bo0-6"
cho cac cau hinh luot song de kiem tra tren 6 nam truoc khi tin.

## Nhat ky va canh bao ky luat (v5.2, tai khoan that / demo)

Bot (1 chart moi tai khoan, mac dinh bat InpJournal) tu ghi vao MT5 Common\Files:
- TrendBot_nhatky.csv: MOI giao dich cua tai khoan (bot va lenh tay, moi ma), nap, rut, SL luc vao, thoi gian giu,
  va moi canh bao. Lan dau bat se ghi lai toan bo lich su cu.
- TrendBot_tongket.csv: moi ngay 1 dong (lai/lo bot, lai/lo tay, so lenh, nap, rut, so canh bao) + thong bao ve dien thoai.

Canh bao (gui ve dien thoai, ghi vao nhat ky), rut ra tu sao ke giao dich tay:
- Nap tien trong 7 ngay sau khi rut ("da rut thi khong nap lai de go").
- Tong nap trong thang vuot InpMonthDepositCap (ban tu dat, vd 2000000).
- Lenh tay co lot > 2 lan lot thuong dung; lenh tay khong co SL.
- Qua 10 lenh tay trong ngay; thua tay 3 lenh lien tiep.
- 1 lenh lai > 10% so du, hoac tai khoan lai moi 20% trong thang: nhac RUT tien goc + mot nua lai, nghi 1-2 ngay, khong tang lot.

Nut 4 "Gui nhat ky tai khoan that": chep 3 file (nhatky, tongket, truotgia) vao ket-qua\thuc-te\, hoi y roi day len GitHub
de Claude doi chieu voi backtest (ty le thang, R trung binh, truot gia, thoi gian giu).

### Sua theo review (v5.3)
- Nhoi lenh: sau khi gui lenh doi SL lop cu ve hoa von, bot DOC LAI tung vi the; lop nao chua co SL >= hoa von thi khong nhoi (thu lai nen sau).
- Bao ve lenh tay, lo ngay: chi tinh lo PHAT SINH trong ngay (tru phan lai/lo da co truoc 0:00 theo gia mo cua D1). Khoa lo ngay luu
  qua khoi dong lai (Global Variable), tu het sang ngay moi.
- Lenh tay da mo TRUOC lan dau bat bao ve: mac dinh chi canh bao, khong tu dat SL / giam lot / dong. Muon ap dung: InpGuardOldTrades = true.
  Van nen thu bao ve lenh tay tren demo truoc khi bat o tai khoan that.
- Nhat ky: nut 4 ghi ro file chua MOI giao dich, nap/rut va so du cua ca tai khoan. Dong nap/rut khong ghi ma giao dich ngan hang.

## Ket qua dot 7/11/2026 15:46 (khung gio tu sao ke)
- Chi vao 6-12h UTC ("+gio6-12") hoac bo 0-6h UTC ("+bo0-6"): giai doan 3 nam gan day tot hon mot chut, nhung 3 nam truoc van lo
  o moi cau hinh (PF truot 0,05% tu 0,30 den 0,85). Tot nhat: Ngan-Nhoi3-M30+gio6-12 (PF truot 1,32 / 0,85) - van khong dat tieu chi 1,3 ca 2 giai doan.
- Ket luan: khung gio "thang 90%" trong sao ke la do mau nho / giai doan do, khong phai loi the ben vung. Khong dua vao bot.

## Tach nut lay code va nut chay (7/11)
- Nut 2 "Lay code moi + cap nhat bot vao MT5": viec DUY NHAT lay code tu GitHub (hoi y truoc), roi compile vao MT5.
- Nut 1, 3, 4 va backtest 1 lan: KHONG lay code moi, chi chay ban dang co tren may. Neu GitHub co thay doi chua lay, chi in ra 1 dong nhac.
- Giao dien trinh duyet: o "Lay phien ban bot moi" chi hien khi chon "Lay code moi + cap nhat bot".

## Nhoi lenh 15 phut va dong thuan da khung (v5.4 - v5.5)
- InpPyramidTFmin = 15: van vao / thoat theo H4, nhung kiem tra nhoi moi 15 phut (buoc van theo ATR H4).
- InpMTFAlign = x: chi vao lenh va nhoi khi it nhat x/8 khung (M1, M3, M5, M10, M15, M30, H1, H4) co nen da dong cung phia EMA20.
- Lan chay: C+nhoi3-kt15, C+nhoi5-buoc0.5(-kt15), C+nhoi3+dongthuan6/8, C+nhoi3-kt15+dongthuan6, Ngan-M15/H1+nhoi3+dongthuan7,
  Ngan-M15/M30/H1+nhoi3-nhuH4. Tat ca co ban 3 nam truoc. Tieu chi: PF truot 0,05% >= 1,3 ca 2 giai doan va tot hon C+nhoi3.

## Ket qua dot 7/11/2026 17:23 + phan tich nen M10 (2021-07 -> 2026-11)
Nhoi lenh (von 3000, PF truot 0,05% | t | sut giam, 3 nam gan day / 3 nam truoc):
- C+nhoi3: +1740 / +1926, PF 1,73 / 2,43, t 2,66 / 3,10, DD 12,2% / 8,8%.
- C+nhoi5-buoc0.5 (5 lop, moi 0,5 ATR): +3607 / +2268, PF 2,09 / 2,26, t 4,00 / 3,22, DD 16,9% / 9,5%. TOT NHAT; lai/sut giam cung tot hon. Da them vao chay tick that.
- C+nhoi3-kt15 (kiem tra nhoi moi 15 phut): +2038 / +2353, t 2,77 / 3,51, DD 16,9% / 8,4%. Tot hon C+nhoi3 mot chut.
- Dong thuan da khung 6/8: gan nhu bang C+nhoi3; 8/8: it lai hon. Khong giup.
- Nhoi tren M15/M30/H1 (luat H4), co hay khong dong thuan: lo o 3 nam truoc.
Nen M10 (Exness BTCUSDm):
- 4 gio trong nen H4 bien dong ngang nhau, khong gio nao "quyet dinh" hon; gio dau khong du bao 3 gio sau (tuong quan ~0); gio cuoi khong du bao nen sau.
- Dot mua/ban o at M10 (gia > 4 do lech chuan, khoi luong > 3 lan): KHONG keo tiep; 2021-24 con hoi lai nhe (-0,27% trong 4 gio), 2024-26 ~0.
- Spread ~23,8 USD moi gio nhu nhau (Exness gan nhu co dinh).
- Sau khi H4 dong cua pha vo kenh 20 nen: trong 4 gio sau, ~75% lan gia hoi lai >= 0,25 ATR, ~45% hoi >= 0,5 ATR (ca 2 giai doan).
  -> v5.7 them InpEntryPullATR / InpEntryPullMode: cho gia hoi ve moi vao (het nen: bo hoac vao gia thi truong). Dang thu.

## Ket qua tick that 7/11/2026 19:24 va cach tinh moi (v5.8)
Tick that khop che do nhanh (lech vai %): C+nhoi5-buoc0.5 PF truot 0,05% = 2,14 / 2,13, sut giam 17,0% / 10,9%.
Nhung bang cu dem moi lop nhoi la 1 lenh doc lap. Gom lop chong nhau cung chieu thanh dot (tinh lai tu file lenh):
- C+nhoi5-buoc0.5: 276 lenh -> 92 dot, t theo dot 1,97 / 1,65 (bang ghi 4,04 / 3,05). Top 5 dot chiem 105% / 116% lai.
- C+nhoi3: 194 -> 90 dot, t 1,69 / 1,77. C (khong nhoi): t 2,08 / 2,41, top 5 chiem 88% / 82%.
- Lai chia sut giam gan bang C (216 vs 204 o 3 nam gan day; 184 vs 237 o 3 nam truoc): nhoi5 ~ C voi rui ro ~4 lan.
- Sut giam 17% vuot muc dung han 15%: chay that voi cai dat mac dinh thi bot da tu dung.
Ket luan: giu C cho demo. v5.8 tinh t / top 5 / Monte Carlo theo dot, va them lan chay:
- C+nhoi5-buoc0.5-rr0.3 (von 30000, 0,3%/lop) so voi C-von30000 / C-von30000-truoc: cung muc sut giam thi co hon C khong.
- C-nhuThat, C+nhoi5-buoc0.5-nhuThat (von 3000, bat dung han 15% + lo ngay 3%).

## Sua theo review (v5.9)
- Cho gia hoi (InpEntryPullATR): khi gia cham muc cho, bot KIEM TRA LAI moi dieu kien bat buoc truoc khi gui lenh
  (lo ngay, khung gio, spread, so lenh/ngay, nghi sau lenh thua, dong thuan khung nho, funding, Fear & Greed, chu y, Nasdaq, tin My).
  Khong dat thi huy lenh cho. Viec kiem tra lenh cho chay SAU khi cap nhat lo ngay / sut giam cua tick do.
  Chua lay duoc khoa rui ro chung voi bot cung nhom: giu lenh cho, thu lai o tick sau (truoc day mat tin hieu).
- Cot ChoHoi_*: tach gia cham / het nen / bi huy / lenh khop that (truoc day dem "vao" ngay khi gia cham, chua biet server co khop).
- Nhoi lenh: CalcLots cong rui ro con mo cua cac lop cu cua chinh bot. Lop cu + lop moi <= 1 lenh chuan; tran nhom 1,5% cung
  tinh ca lop cu. Binh thuong lop cu da o hoa von nen ket qua backtest khong doi.
- R cua dot van lay rui ro lop dau lam mau so: luc vao moi lop, cac lop cu da o hoa von nen rui ro mo chi ~1 lenh. Muc rui ro
  them cua ca chuoi xem o cot RuiRoMoMax% va SutGiamMax% (sut giam that, tinh ca lai/lo tha noi).
- Monte Carlo chi tron thu tu lai/lo cua cac dot da dong, khong tai tao lai/lo tha noi hay viec bot dung han giua chung.
  Muon biet bot that co bi dung khong, xem cac lan "-nhuThat" (bat dung han 15% + lo ngay 3%, chay bang gia that).

## Ket qua dot 7/11/2026 20:42 (v5.9, che do nhanh) - KET THUC thu nhoi lenh va cho gia hoi
Ban v5.9 compile va chay binh thuong; t / top 5 theo dot khop voi tinh tay (nhoi5: t 1,96 so voi 1,97).
So sanh cong bang, cung muc sut giam (von 30000; nhoi5 rui ro 0,3%/lop, C 1%):
- 3 nam gan day: nhoi5-rr0.3 +10.484, sut giam 6,8% | C +9.842, sut giam 6,4%. Lai/sut giam bang nhau (~1.540).
- 3 nam truoc:   nhoi5-rr0.3 +6.309, sut giam 4,9%  | C +11.481, sut giam 5,2%. C hon han (2.230 so voi 1.300).
- Moi ban nhoi: top 5 dot chiem 104-125% lai, PF bo top 5 < 1. C: 81-96%, PF bo top 5 > 1.
=> Nhoi lenh khong co loi the rieng, chi doi rui ro. Khong dung.
Cho gia hoi (so voi C+nhoi5 cung von): -bo kem ro (bo lo 33-44 lan pha vo chay thang, dung nhom lai lon);
-vao 0,25 / 0,5 kem nhe ca 2 giai doan. C+nhoi3+hoi0.25-vao: PF +0,22 / +0,04 so voi C+nhoi3, khong dat tieu chi (+0,2 o ca 2).
=> Khong dung. ChoHoi_BiHuy = 0 vi backtest khong bat bo loc nao.
Dung han 15% (C-nhuThat, C+nhoi5-nhuThat): ra GIONG HET ban tat dung han, du nhoi5 co SutGiamMax 16,9%. Khong phai loi:
bot tinh sut giam theo lai da chot + lo dang chay, KHONG tinh lai dang chay bi tra lai (xem "Bao ve tai khoan").
Sut giam theo lai da chot cua nhoi5 chi 10,9% (C 2,8%). Phan con lai cua 16,9% la lai tha noi bi tra lai, muc dung han khong chan.
ETH nhoi5: PF truot 1,46, top 5 chiem 154%, Monte Carlo 54% cham dung han. Loai.
Ket luan: giu C (Donchian 20 H4 + ADX, 1 lenh, khong nhoi, vao ngay) cho demo.

## Ket qua dot 7/11/2026 21:09 - C tren 10 thi truong (von 30000, cung tham so, khong chinh)
PF truot 0,05% (3 nam gan day / 3 nam truoc):
- BTC 1,61 / 2,34 (DAT). ETH 1,30 / 0,93. Vang 1,57 / 0,74. Bac 1,53 / 0,82. Nasdaq 0,88 / 0,82. Dow 0,78 / 0,56. Dau 0,91 / 1,01.
- Ngoai hoi (PF tho, chua truot): EURUSD 0,94 / 0,96, GBPUSD 1,06 / 0,96, USDJPY 0,89 / 1,76.
  (PF truot cua ngoai hoi trong bang sai: USDJPY ra 0 vi chi phi tinh bang JPY. Da sua v5.9.1 - quy ra USD qua tick value;
  ngoai ra 0,05% gia la qua nang voi ngoai hoi, spread that ~0,01%.)
- Chi BTC dat o ca 2 giai doan. Vang / bac / ETH chi tot o 2024-2026 (dot tang manh cua kim loai), lo o 2020-2023.
Gop danh muc (chia deu rui ro, lai da chot):
- Ca 10 ma: lai/sut giam 3,4 / 1,3 so voi chi BTC 6,2 / 12,7. BTC + ETH + vang + bac: 8,5 / 2,2.
- Tuong quan lai thang voi BTC thap (tru ETH +0,62), nhung cac ma khac khong co loi the nen chi pha loang.
Ket luan: khong mo rong sang ma khac. Loi the cua C (Donchian 20 H4 + ADX) chi thay o BTC: co the do BTC co xu huong manh
dac thu, hoac mot phan may man. BTC da qua 3 nam ngoai mau, nhung chi 63-71 lenh -> demo la phep thu tiep theo.

## Thu open interest / ban do thanh ly voi C (7/11/2026 21:25, cong-cu/thu_oi_C.py)
Du lieu: OI BTCUSDT Binance theo gio tu 12/2021. Du lieu thanh ly THAT tai ve deu loi 404 (Binance khong con cho tai),
nen "cum thanh ly" la uoc tinh tu OI moi mo + don bay pho bien (giong cach Coinglass doan), khong phai so that.
Mo phong Python (H4, chi phi 0,06%/vong). Tong R, GD1 = 12/2021-02/2024, GD2 = 03/2024-11/2026:
- C goc: 59,1 / 15,3 (71 / 99 lenh). Moc ngau nhien: bo ngau nhien con 75% lenh -> TB 53,7 / 14,0, 90% cao nhat 59,4 / 19,3;
  con 60% -> TB 47,8 / 12,2, 90% cao nhat 56,2 / 19,4. Bo loc that phai vuot moc ngau nhien moi dang tin.
- OI tang 24h: 45,3 / 1,4 (kem ngau nhien). OI giam 24h: 47,3 / 14,0 (bang ngau nhien, sut giam thap hon chi vi it lenh).
- OI khong qua nong (bo khi OI tang 24h o phan vi > 90%): 53,6 / 19,4 - chi cham moc 90% o GD2, GD1 binh thuong. Chua du.
- Dam dong nguoc chieu (ty le tai khoan long/short): gan nhu khong chan lenh nao. Taker xac nhan: 49,3 / 8,3 (kem).
- Chot loi truoc cum thanh ly: 35,6 / 0,5 (kem rat ro: cat mat cac lenh lai lon).
- Ne SL khoi cum thanh ly: 59,5 / 17,9 (+0,4 / +2,6 R, ~0,03 R/lenh) - qua nho, trong muc nhieu.
Ket luan: khong them bo loc OI / thanh ly. Giu C.

## SL nho, nhoi lenh va vao lai (v5.92)
- InpSLTFmin = x: SL, trailing va buoc nhoi tinh theo ATR khung x phut (vd 5 = M5) thay vi khung chinh. Tin hieu vao van theo
  khung chinh (InpTF). SL M5 ~ 1/7 SL H4, nen 0,01 BTC thua chi ~3-5 USD thay vi ~20-39 USD.
- InpReEntryMax = x: lenh bi cat lo thi vao lai toi da x lan cho cung tin hieu, trong InpReEntryBars nen khung chinh (mac dinh 6),
  khi nen khung SL dong cua vuot lai gia dong cua cua nen tin hieu va cung phia EMA nhanh. Kiem tra lai moi dieu kien bat buoc
  (lo ngay, khung gio, spread, ...) truoc khi vao. Lenh truoc dong co lai thi khong vao lai. Cot VaoLai dem so lan vao lai da khop.
- Lan chay SLnho-*: tin hieu H4 voi SL M30/M15/M5/M3; SL M5 + nhoi 5 lop (kiem tra moi 5 phut, buoc 1 ATR M5) va/hoac vao lai
  3 lan; tin hieu M30 voi SL M5. Moi cau hinh co ban von 30000 va von 1 trieu (-1tr, InpMaxRiskRoundUp = 20), ca 2 giai doan.
- Du doan truoc khi chay (de doi chieu): SL cang nho thi spread (~24 USD) chiem phan lon hon va bi quet nhieu hon,
  nen nhieu kha nang PF duoi 1,3. Che do nhanh chi co gia M1 nen ket qua SL M3/M5 con tho; cau hinh nao dat phai chay tick that.

## Ket qua dot 7/11/2026 22:58 (danh muc nhieu thi truong + von 1 trieu tren nhieu ma)
- DM-* (cau hinh C, von 30000): chi BTC dat ca 2 giai doan (PF truot 0,05% 1,61 / 2,34). ETH 1,30 / 0,93; vang 1,57 / 0,74;
  bac 1,53 / 0,82; USDJPY 0,62 / 1,39; Nasdaq, US30, dau, EURUSD, GBPUSD deu duoi 1 o it nhat 1 giai doan. Khong them ma nao.
- 1tr-* (von 38 USD, cho rui ro that toi 3%): BTC, ETH, vang, EURUSD, USDJPY: 0 lenh (moi tin hieu bi bo vi 0,01 lot qua lon).
  Cac altcoin vao duoc lenh nhung khong ma nao dat: LTC PF 0,46 / 0,70 (t -4,2), XRP 0,34 / 1,42, SOL 0,98 / 1,35,
  ADA 0,34 / 1,25, DOGE 1,01 / 0,85, LINK, DOT, BNB deu thua; sut giam toi 25-35%.
- Ket luan: voi 1 trieu khong co ma nao chay C an toan. Dang thu huong SL nho (SLnho-*, v5.92).

## Tab "Thong so" trong giao dien (8/11/2026)
Mo GiaoDien.cmd -> tab "Thong so". Doc thang moi thong so tu code bot (luon khop phien ban), chia theo nhom, co mo ta.
- Bat dau tu: mac dinh cua bot, mot bo cai dat san (cai-dat/*.set) hoac bo ban da luu. Thong so khac mac dinh duoc to mau, bam ↺ de tra lai.
- Muc "Can chu y" canh bao khi rui ro > 2%/lenh, tat khoa lo ngay / dung han, SL < 1 ATR, khac cau hinh C da kiem thu...
- Luu: ghi file .set day du (UTF-16, dung dinh dang MT5) vao cai-dat-rieng/ (KHONG dua len git, co the chua token Telegram)
  va chep vao MQL5\Presets. Trong MT5: chart -> F7 -> Inputs -> Load -> chon file.
- "Luu roi backtest": chay CaiDatBot.ps1 voi bo nay (chon von, 1/3/6 nam), MT5 mo ra va chay bang tick that.
## Tu bam vao lenh + bang xu huong (v5.10)
- InpManualEntry = true (bo 02-Tu-bam-lenh-H4): bot khong tu vao lenh. Goc phai chart co nut BUY / SELL / DONG HET LENH CUA BOT.
  Bam 1 lan nut doi mau cam "BAM LAN NUA DE ..." trong 5 giay, bam lan 2 moi gui lenh (tranh bam nham).
  Lenh dung Magic cua bot: lot theo rui ro InpRiskPercent, SL InpATRMult x ATR, doi SL ve hoa von, nhoi (InpPyramidMax), trailing.
  Van bi chan boi: lo ngay, sut giam toi da, so lenh/ngay, nghi sau lenh thua, spread. Bam BUY khi dang giu Buy = nhoi them, chi khi lop cu
  dang lai va da doi duoc SL ve hoa von; khong cho nhoi vao lenh dang lo; khong cho vao nguoc chieu khi dang giu lenh.
- InpTrendBoard = true (mac dinh): bang xu huong M1, M3, M5, M10, M15, M30, H1, H4, D1. TANG = gia dong cua > EMA20 > EMA50,
  GIAM = nguoc lai, NGANG = con lai. Dong cuoi dem so khung tang / giam. Chi hien khi chay that / demo (khong anh huong backtest).

## Viết lại toàn bộ cài đặt (v5.10.1, 8/11/2026)
- Bảng Inputs trong MT5: 114 thông số có nhãn tiếng Việt có dấu, kèm đơn vị, chia 14 nhóm theo thứ tự dùng
  (chiến lược → Donchian → thử nghiệm → bộ lọc → vào lệnh → SL/TP → rủi ro → giờ → bảo vệ tài khoản → ...).
  Chỉ đổi nhãn, nhóm và thứ tự: tên, kiểu, giá trị mặc định giữ nguyên, file .set và backtest cũ vẫn dùng được.
  File .mq5 nay lưu dạng UTF-8 có BOM để MetaEditor đọc đúng dấu.
- Nguồn nhãn duy nhất: `cong-cu/nhan_thong_so.py` (nhãn + giải thích). Thêm thông số mới vào bot thì thêm vào bảng này rồi chạy
  `python cong-cu/viet_lai_nhan.py` (ghi lại nhãn trong .mq5 và `giao-dien/giai-thich-thong-so.json`)
  và `python cong-cu/tao_cai_dat.py` (tạo lại các bộ cài đặt sẵn). Thiếu nhãn thì script báo lỗi.
- Tab Thông số lấy nhãn từ code bot, hiện thêm dòng giải thích, chia bộ cài đặt sẵn thành "Cài đặt sẵn" và "Thử nghiệm",
  và hiện trạng thái (đã kiểm thử / chưa đạt) khi nạp một bộ.

## Bảo vệ cả lệnh chờ đặt tay (v5.10.2, 10/11/2026)
Trước đây bot chỉ canh lệnh tay sau khi đã khớp. Nay với `InpGuardPending = true` (mặc định, dùng cùng bộ `03-Bao-ve-lenh-tay.set`),
lệnh Buy/Sell Limit, Stop, Stop Limit bạn đặt tay trên mã của chart được sửa ngay khi còn đang chờ, kiểm tra mỗi 2 giây:
- Chưa có SL: tự đặt SL cách giá sẽ khớp `InpGuardSLPct` (1,5%).
- Nếu khớp rồi chạm SL mà lỗ hơn `InpGuardMaxRiskPct` (3%) vốn: MT5 không cho sửa lot lệnh chờ, nên bot hủy lệnh và đặt lại
  lệnh cùng loại, cùng giá, SL, TP, hạn với lot nhỏ hơn (có thông báo số lệnh mới). Lot nhỏ nhất vẫn quá rủi ro thì chỉ hủy.
- Lệnh chờ cùng chiều với một lệnh tay đang lỗ, ở giá tệ hơn giá vào của lệnh đó (Buy Limit dưới Buy đang lỗ, Sell Limit trên Sell
  đang lỗ): hủy, vì nếu để khớp thì luật "không nhồi vào lệnh lỗ" cũng đóng nó ngay và bạn mất spread.
- Ngày đã chạm giới hạn lỗ lệnh tay: hủy mọi lệnh chờ tới 0:00 giờ server.
- Lệnh chờ đặt trước khi bật bảo vệ lần đầu: chỉ cảnh báo (trừ khi `InpGuardOldTrades = true`).
Chưa chạy được trong backtest (không có lệnh tay). Hãy thử trên demo: đặt một Buy Limit không SL, lot lớn, và xem thông báo.

## Bảng thông tin dễ đọc hơn (v5.10.3, 10/11/2026)
- Bảng góc trái và bảng xu hướng góc phải nằm trong hộp nền tối, chữ tiếng Việt có dấu, không còn đè lên nến.
- Khi chạy bộ 03 / 04 (chỉ bảo vệ lệnh tay), bảng trái hiện đúng việc đang làm: Algo Trading bật hay tắt, số dư,
  lãi/lỗ tay hôm nay so với giới hạn ngày, số lệnh tay đang mở và lệnh chờ, các luật đang áp dụng.
- Tắt bảng trái: `InpShowPanel = false`; tắt bảng xu hướng: `InpTrendBoard = false`.

## Tự chốt lời cho lệnh tay (v5.10.4, 10/11/2026)
Sao kê lệnh tay cũ: thắng 66% nhưng lệnh lỗ trung bình gấp đôi lệnh lời (chốt lời sớm, gồng lỗ). Backtest của bot: lãi đến từ vài
lệnh chạy xa, nhờ trailing thay vì TP cố định. Nên phần bảo vệ lệnh tay (bộ 03 / 04) giờ tự quản lý phần chốt lời:
- R = khoảng cách giá vào → SL lúc bot thấy lệnh lần đầu (lưu theo lệnh, giữ qua khởi động lại).
- Lời `InpGuardBreakevenR` (mặc định 1) × R: dời SL về giá vào + spread. Từ đó lệnh không còn lỗ; có thông báo.
- Sau đó kéo SL theo giá, cách `InpGuardTrailATR` (2) × ATR khung `InpGuardTrailTFmin` (15 phút). SL chỉ đi theo hướng có lời.
- Không đặt, không sửa TP. Nếu bạn tự đặt TP thì TP vẫn giữ nguyên.
- Đặt 0 để tắt từng phần. Mức 2 × ATR M15 là ước lượng, chưa backtest cho lệnh tay: xem lại sau vài tuần demo.

## Tự nhồi lệnh tay theo xu hướng (v5.10.4)
Bộ 03 / 04 chỉ canh lệnh, không tự mở lệnh. Nay có thêm `InpGuardPyramidMax` (bộ 04 đặt 3, mặc định 1 = tắt):
bot tự thêm một lớp cùng chiều với lệnh tay của bạn, cùng lot với lớp đầu, SL cách 1R, khi đủ cả 4 điều kiện:
1. Mọi lớp đang mở cùng chiều và **đã dời SL về hòa vốn** (nên rủi ro mở của cả chuỗi chỉ khoảng 1 lớp).
2. Giá đi thêm `InpGuardPyramidStepR` (1) × R tính từ giá vào của lớp mới nhất.
3. Ít nhất `InpGuardPyramidTrend` (5) / 9 khung trong bảng xu hướng cùng chiều. Mua ngược khi đa số khung GIẢM thì không nhồi.
4. Chưa khóa lỗ ngày, spread dưới 20% R, không có lệnh chờ tay, tài khoản hedging.
Lớp mới vẫn là lệnh tay (ghi chú "TB nhoi tay"): hòa vốn, kéo SL, giới hạn lỗ ngày đều áp dụng. Mỗi lần nhồi có thông báo.

## Thử nghiệm: bot tự vào lệnh với vốn nhỏ (v5.10.5, bộ 05)
Theo yêu cầu: chạy thẳng trên demo với số liệu hiện tại, không backtest trước. `InpGuardAutoEntry = true` (bộ
`05-Tu-vao-lenh-von-1-trieu-THU-NGHIEM.set`): khi không có lệnh tay nào trên mã, bot tự vào 0,01 lot (magic 0, ghi chú "TB tu vao") nếu
- ít nhất `InpGuardAutoTrend` (8) / 9 khung trong bảng xu hướng cùng chiều, và
- nến M5 vừa đóng chạm EMA20 M5 rồi đóng cửa trở lại về phía xu hướng (giá hồi rồi bật lại).
Giới hạn: tối đa `InpGuardAutoMaxDay` (5) lệnh tự vào mỗi ngày, nghỉ `InpGuardAutoCooldownMin` (30) phút sau lệnh tay thua, không vào khi
đã khóa lỗ ngày. Sau khi vào, lệnh được xử lý như lệnh tay của bộ 04 (SL 0,25%, hòa vốn 1R, kéo SL, nhồi tối đa 3 lớp).
Ghi lại kết quả sau 1–2 tuần (nút Gửi nhật ký) rồi mới quyết định có giữ hay không.
