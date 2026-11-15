# Hướng dẫn bot BTC (MT5) v5.36

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
| `SkewR`, `KurtR` | Độ lệch và độ nhọn của R mỗi đợt. Skew dương (vài lệnh thắng rất lớn) là bình thường với Donchian và giúp cần ít lệnh hơn để tin kết quả |
| `SoLanThu`, `SR0`, `DSR%` | Từ v5.10.21. `SoLanThu` = `InpTrials`: số cấu hình đã thử cạnh tranh trên cùng dữ liệu. `SR0` = Sharpe mỗi đợt mà cấu hình tốt nhất trong ngần ấy lần thử đạt được dù không có lợi thế. `DSR%` = xác suất Sharpe thật cao hơn `SR0` (Bailey & López de Prado). Trên 95% mới đáng tin |
| `MinTRL_dot` | Số đợt tối thiểu để tin Sharpe > `SR0` với độ tin cậy 95%. Nhỏ hơn `SoDot` là đủ dữ liệu; −1 là không bao giờ đủ (Sharpe chưa vượt `SR0`) |
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
| `04-Bao-ve-lenh-tay-von-1-trieu.set` | Bot không tự vào lệnh, chỉ canh lệnh bạn vào tay (cả lệnh chờ): SL 0,25%, rủi ro tối đa 6%, khóa lỗ ngày 10%, hòa vốn ở 1R, kéo SL, tự nhồi tối đa 3 lớp | Công cụ hỗ trợ cho vốn 1 triệu |
| `05-Tu-vao-lenh-von-1-trieu-THU-NGHIEM.set` | Như 04, thêm bot tự vào 0,01 lot khi ≥ 6/9 khung cùng chiều (có H1 và H4) và nến M1 hồi về EMA20 | **Chưa backtest**, chỉ chạy demo |

Các bộ 01, 02, 03 và TN1 … TN7 đã bỏ (11/2026) vì cần vốn từ 3.000 USD hoặc chưa đạt kiểm thử. Lần cập nhật kế tiếp tự xóa chúng khỏi danh sách Load trong MT5. Muốn dùng lại, lấy từ lịch sử GitHub hoặc tự lưu bộ riêng trong `cai-dat-rieng`.

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
Trước đây bot chỉ canh lệnh tay sau khi đã khớp. Nay với `InpGuardPending = true` (mặc định, dùng cùng bộ `04` hoặc `05`),
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
Cập nhật cùng ngày theo yêu cầu "nhiều, nhanh, không nghỉ": bộ 05 giờ dùng 6/9 khung, điểm vào trên nến M1
(`InpGuardAutoTFmin = 1`), không giới hạn số lệnh/ngày, không nghỉ sau lệnh thua. Khóa lỗ ngày 10% vẫn giữ.
Thêm `InpGuardAutoNeedHTF` (mặc định bật): ngoài 6/9 khung, H1 và H4 bắt buộc cùng chiều, để 6 khung nhỏ quay đầu không kéo bot vào ngược xu hướng lớn.

## Bảng thông tin ghi thêm số tiền (v5.10.6)
Các mức theo % trên bảng góc trái nay ghi kèm số tiền theo đơn vị tài khoản (VND với tài khoản của bạn):
- Giới hạn lỗ ngày, trên một dòng riêng (v5.10.7), ví dụ `Khóa lệnh tay khi lỗ ngày tới -10% = -97.909 VND`.
- SL tự đặt: 1R bằng bao nhiêu tiền với lot nhỏ nhất (0,01).
- Rủi ro tối đa mỗi lệnh bằng bao nhiêu tiền.
- Spread: mỗi lệnh 0,01 lot mất bao nhiêu tiền phí chênh lệch.

Giá trên chart vẫn là USD vì BTCUSDm niêm yết bằng USD, không đổi được.

## Cảnh báo chế độ tự giao dịch (v5.10.7)
Trong bộ 05, `InpAllowBuy` và `InpAllowSell` bằng false nhưng `InpGuardAutoEntry` bằng true. Hai ô Cho phép mua / bán chỉ tắt chiến lược chính; chế độ tự vào lệnh là phần riêng và vẫn mở lệnh. Để không hiểu nhầm:
- Bảng trên chart có dòng đỏ "TỰ GIAO DỊCH ĐANG BẬT: bot tự mở lệnh, không cần bạn bấm BUY/SELL".
- Tab Thông số trong GiaoDien báo đỏ khi `InpGuardAutoEntry` bật.
- Nhãn các thông số và đầu file `05-...set` ghi rõ điều này.

Muốn bot chỉ canh lệnh, không tự mở lệnh: dùng bộ 04, hoặc đặt `InpGuardAutoEntry = false`.

## Chốt lời theo khung vào lệnh (v5.10.8)
Vào lệnh ở khung nhỏ thì giá đảo chiều nhanh, để lâu dễ ôm lỗ. Trước đây bot luôn kéo SL theo ATR M15, quá lỏng với lệnh vào ở M1. Ba thông số mới:
- `InpGuardTrailTFmin = 0`: kéo SL theo ATR của chính khung vào lệnh (`InpGuardAutoTFmin`). Vào M1 thì kéo theo ATR M1, sát hơn nhiều.
- `InpGuardTPR`: đặt TP cố định ở x R cho lệnh chưa có TP. TP nằm trên máy chủ nên vẫn chốt khi bot tắt. TP bạn tự đặt được giữ nguyên.
- `InpGuardMaxBars`: lệnh chưa tới hòa vốn sau x nến của khung vào lệnh thì đóng, không ôm.

Bộ 05: điểm vào chuyển từ M1 sang M5 (M1 bị quét liên tục trong ngày giằng co 10/11), kéo SL 2 × ATR M5, TP 2R, đóng lệnh chưa hòa vốn sau 12 nến M5 (1 giờ). Bộ 04 giữ như cũ (M15, không TP, không đóng theo nến), vì lệnh bạn tự vào thường theo khung lớn hơn.

## Nhồi lệnh và chốt gộp (v5.10.9)
Trước đây mỗi lớp nhồi có TP riêng: lớp đầu chốt ở 2R trong khi lớp sau còn cách TP xa, nên cả chuỗi chốt chậm và rời rạc.
- `InpGuardBasketR` (nhóm 11, mặc định 0 = tắt): cộng lãi đang chạy (lãi + swap) của mọi lệnh tay cùng chiều trên mã của chart.
  Khi tổng đạt x R thì đóng hết một lượt. R = số tiền lớp đầu mất nếu chạm SL ban đầu (các lớp nhồi cùng lot nên 1R chuỗi = 1R lớp đầu).
- Bật chốt gộp thì bot không đặt TP từng lớp (`InpGuardTPR` bị bỏ qua). TP đã đặt từ trước vẫn còn trên lệnh, xóa tay nếu muốn.
- Chốt gộp do bot kiểm tra mỗi giây, nên chỉ chạy khi MT5 đang mở (khác TP nằm trên máy chủ). SL từng lớp vẫn nằm trên máy chủ.
- Lệnh mở trước khi bật bảo vệ không được tính, trừ khi `InpGuardOldTrades = true`. Đang giữ cả Buy và Sell thì không chốt gộp.

Bộ `06-Nhoi-chot-gop-von-1-trieu-THU-NGHIEM.set` (CHƯA BACKTEST, chỉ demo): như bộ 05 nhưng SL 0,15%, hòa vốn và nhồi ở 0,5R,
chốt gộp 2R, không TP từng lớp. Đủ 3 lớp thì chốt khi giá đi khoảng 1,2R từ lớp đầu; chỉ 1 lớp thì chốt ở 2R.
SL gần hơn nên dễ bị quét hơn, spread chiếm khoảng 6% của R.

Bộ `07-Nhoi-nhanh-von-1-trieu-THU-NGHIEM.set` (CHƯA BACKTEST, nên chạy demo trước): như bộ 06 nhưng vào nhanh hơn và nhồi được với 0,01 lot.
Tìm điểm hồi EMA20 trên M3, chỉ cần ≥ 5/9 khung cùng chiều (vẫn bắt buộc H1 và H4), tối đa 20 lệnh tự vào/ngày, nhồi cùng lot (hệ số 1,0).
Rủi ro tự vào, bucket thuật toán và trần nhóm BTC/ETH cùng 4%: với vốn ~800 nghìn VND, 0,01 lot SL 0,15% ≈ 3,5% vốn, nên bộ 06 (2%) bỏ mọi tín hiệu.
Thua 1 lệnh là gần hết bucket 4%, bot ngừng tự vào tới hôm sau. Các đợt backtest khung nhỏ / nhiều lệnh trước đây đều lỗ vì spread.

**Chốt lời linh hoạt** (cùng bản, mặc định tắt cả, tính trên tổng lời của chuỗi lớp):
- `InpGuardRunTrend`: đạt mức chốt gộp mà còn ≥ x/9 khung cùng chiều thì để lời chạy tiếp. Chốt khi xu hướng yếu đi (dưới x/9),
  khi có dấu hiệu đảo chiều, hoặc khi tổng lời rút về dưới mức chốt gộp (nên không trả lại phần đã đạt).
- `InpGuardRevExit` + `InpGuardRevMinR`: đang lời ≥ x R mà nến vừa đóng (khung kéo SL, mặc định khung vào lệnh) báo đảo chiều thì chốt hết:
  đóng cửa vượt lại EMA20 ngược chiều lệnh, nến nhấn chìm ngược chiều, hoặc râu nến dài về phía lệnh.
- `InpGuardSpikeATR`: không chờ nến đóng. Giá vừa chạy về phía lệnh rồi giật ngược x × ATR (râu nến đang hình thành) thì chốt ngay.
  Dùng cùng ngưỡng lời tối thiểu `InpGuardRevMinR`.
- Bộ 06 bật: để lời chạy khi ≥ 7/9 khung, chốt đảo chiều khi lời ≥ 0,5R, chốt khi giật ngược 1 ATR M5.

## Tính lot trước khi tự vào lệnh (v5.10.10)
Trước đây `GuardAutoEntry` luôn vào lot nhỏ nhất, còn giới hạn `InpGuardMaxRiskPct` chỉ được kiểm tra SAU khi lệnh đã khớp.
Nếu lot nhỏ nhất quá lớn so với vốn, bot mở lệnh rồi đóng ngay, mất spread và trượt giá.
- Bây giờ bot tính số tiền lỗ tại SL TRƯỚC khi gửi lệnh. Lot nhỏ nhất đã vượt giới hạn thì **bỏ tín hiệu**, không mở lệnh,
  và báo về điện thoại 1 lần mỗi ngày (kèm số tiền và % vốn sẽ lỗ).
- `InpGuardAutoRiskPct` (mới, mặc định 0 = lot nhỏ nhất): đặt > 0 thì lot = vốn × % / số tiền lỗ của 1 lot tại SL, làm tròn xuống.
  Vốn tăng thì lot tăng, thua thì lot tự nhỏ lại. Không bao giờ vượt `InpGuardMaxRiskPct`.
- Lớp nhồi dùng cùng lot với lớp đầu và SL cách 1R, nên rủi ro mỗi lớp bằng lớp đầu, đã qua kiểm tra này.

## Chốt gộp đúng nhóm lệnh, mỗi mã một chart bảo vệ (v5.10.11)
- Trước đây chốt gộp / chốt khi đảo chiều cộng MỌI lệnh magic 0 cùng chiều trên mã, nên lệnh bạn tự đặt cũng bị cộng và đóng theo.
- `InpGuardExitScope` (mặc định 0): chỉ tính lệnh do bot mở (ghi chú `TB tu vao` hoặc `TB nhoi tay`). Đặt 1 để gộp cả lệnh bạn tự đặt như cũ.
- Mỗi tài khoản + mã chỉ một chart được bảo vệ lệnh tay. Chart bật sau không làm gì (không đặt SL, không nhồi, không tự vào,
  không chốt) và hiện dòng đỏ "CHART KHÁC đang bảo vệ ...". Gỡ bot khỏi một trong hai chart. Đóng chart giữ quyền thì chart kia tự nhận.
- Vẫn không nên chạy EA khác cùng quản lý lệnh magic 0 trên mã này.
- Chốt khi giật ngược (`InpGuardSpikeATR`) trước đây đo từ đỉnh / đáy của nến đang chạy, có thể là đỉnh tạo ra TRƯỚC lúc vào lệnh
  (vào giữa nến M5), nên đóng sớm hơn ý định. Nay bot ghi giá tốt nhất kể từ khi lớp đầu khớp (cập nhật mỗi giây) và chỉ đo từ đó.

## Giám sát lệnh tự vào và bảo mật giao diện (v5.10.12)
- Tệp trạng thái (`TrendBot_trangthai_<chart>.txt`): trước đây `lenhbot` chỉ đếm lệnh có magic của bot, nên bộ 05 / 06 (tự vào, magic 0)
  luôn báo 0 lệnh dù đang giữ vị thế. Nay `lenhbot` = lệnh magic + lệnh bot tự vào / tự nhồi (ghi chú `TB tu vao` / `TB nhoi tay`),
  kèm các dòng mới `lenhmagic`, `lenhtuvao`, `lenhtay`. Giao diện hiện "N mục mở (x tự vào) · y lệnh tay".
  Nếu máy chủ cắt ghi chú lệnh, lệnh tự vào sẽ bị đếm vào `lenhtay` (tổng vẫn đúng ở `lenhtaikhoan`).
- Giao diện web (`GiaoDien.ps1`):
  - Từ chối mọi yêu cầu không đến từ chính máy này, hoặc có Host khác `localhost` / `127.0.0.1`.
  - Mỗi lần mở GiaoDien.cmd sinh một mã truy cập ngẫu nhiên; trình duyệt mở `http://localhost:8765/#k=<mã>`, trang tự cất mã vào tab
    và xoá khỏi thanh địa chỉ. Mọi lệnh gọi `/api/*` và `/ket-qua/*` phải kèm mã. Tab cũ (mở trước khi khởi động lại giao diện)
    sẽ báo "chưa có mã truy cập": đóng tab và mở lại bằng GiaoDien.cmd.
  - Vẫn KHÔNG mở cổng 8765 ra Internet / mạng LAN (port forward, ngrok, Cloudflare Tunnel...). Mã truy cập chỉ là lớp bảo vệ phụ,
    giao diện không có HTTPS và có thể chạy mô phỏng, đóng MT5, lấy code mới.
- Gửi nhật ký (`GuiNhatKy.ps1`, nút 4): mặc định gửi BẢN RÚT GỌN, bỏ dòng NẠP / RÚT, bỏ cột số dư (`SoDuHienTai`, `SoDu`, `Equity`, `Nap`, `Rut`)
  và che số tiền trong dòng cảnh báo. Lệnh, lot, giá, lãi/lỗ, trượt giá vẫn giữ để đối chiếu với backtest.
  Cần bản đầy đủ: `GuiNhatKy.ps1 -DayDu` (hoặc biến môi trường `TRENDBOT_NHATKY_DAYDU=y`).
- Chính sách lưu giữ nhật ký thật:
  - Repo phải để Private, chỉ chủ tài khoản có quyền; không thêm người cộng tác, không fork. Kiểm tra định kỳ ở GitHub > Settings > Collaborators.
  - File đã đẩy lên nằm trong LỊCH SỬ git; xoá file sau đó không xoá được lịch sử. Muốn xoá hẳn phải viết lại lịch sử
    (`git filter-repo --path ket-qua/thuc-te --invert-paths`) rồi force push, hoặc dùng một repo riêng chỉ để chứa nhật ký và xoá repo đó khi xong.
  - Khuyến nghị: sau khi Claude đối chiếu xong, xoá thư mục `ket-qua/thuc-te/` khỏi repo; giữ bản gốc trên máy (Common\Files của MT5).
  - `ket-qua/thuc-te/` đã có trong `.gitignore` để không bị đưa lên nhầm bằng `git add .`; chỉ nút 4 mới đẩy (sau khi hỏi).

## Dừng hẳn theo sụt giảm cả tài khoản cho lệnh tay / tự vào (v5.10.13)
Chiến lược chính dùng magic của bot (`InpMagic`) và tự dừng ở lỗ 3%/ngày, sụt 15%. Lệnh tay và lệnh tự vào của bộ 04/05/06
dùng magic 0 nên KHÔNG nằm trong hai mốc đó; trước bản này chúng chỉ có khóa lỗ ngày riêng (`InpGuardDayLossPct`, bộ 05/06 là 10%).
- `InpGuardMaxDDPct` (mới, mặc định 15): equity CẢ TÀI KHOẢN sụt từ đỉnh quá mức này thì bot đóng lệnh tay trên mã của chart,
  ngừng tự vào và tự nhồi, và giữ trạng thái dừng qua khởi động lại. Mọi chart bảo vệ trên cùng tài khoản đều thấy trạng thái này.
- Mở lại: đặt `InpResetHalt = true` một lần (đặt lại đỉnh bằng equity hiện tại), rồi đổi về `false`.
- Rút tiền làm equity giảm và có thể bị tính là sụt giảm: sau khi rút, bật `InpResetHalt` một lần.
- Bảng trên chart có dòng "Sụt giảm tài khoản: x% / dừng hẳn ở 15%".- Chiến lược chính đang dừng hẳn (sụt giảm `InpMaxDrawdownPct`) hoặc chạm lỗ ngày (`InpMaxDailyLossPct`) thì bot cũng KHÔNG tự vào,
  không tự nhồi. Hai bước này nay chạy sau khi đã cập nhật lỗ ngày / sụt giảm của tick đó (trước đây chạy trước và không kiểm tra).

**Rà soát thêm (cùng bản 5.10.13):**
- Tự vào lệnh nay dùng chung bộ lọc giờ nghỉ / cuối tuần / tin và spread tối đa (`InpMaxSpreadPoints`) với chiến lược chính,
  và bỏ tín hiệu khi spread lớn hơn 20% khoảng cách SL (như luật nhồi). Giới hạn số lệnh/ngày và nghỉ sau thua của chiến lược chính
  không áp dụng; tự vào có giới hạn riêng (`InpGuardAutoMaxDay`, `InpGuardAutoCooldownMin`).
- Bộ 05/06: tối đa 10 lệnh tự vào mỗi ngày, nghỉ 15 phút sau lệnh thua (trước là không giới hạn, không nghỉ).
- Nhồi lệnh: trước khi gửi, cộng rủi ro tiền còn mở của các lớp (lớp đã hòa vốn tính 0) với lớp mới; vượt `InpGuardMaxRiskPct` thì không nhồi.
- Nhận diện lệnh bot mở: ngoài ghi chú `TB ...`, bot lưu ticket vào Global Variable lúc mở, nên sàn đổi ghi chú vẫn nhận ra.
- Chốt gộp tính lãi THẬT: trừ ước 2 lần phí (commission + fee) lúc vào. Tài khoản Standard của Exness không có phí nên không đổi.
- Vẫn còn (không sửa trong code):
  - Bảo vệ lệnh tay (`InpGuardManual`) cố ý sửa SL / đóng cả lệnh bạn tự đặt trên mã đó: đó là chức năng của bộ 04. Không muốn thì
    đừng vào lệnh tay trên mã đang chạy bộ 05/06, hoặc vào lệnh tay trên mã khác.
  - Khóa "một chart mỗi mã" và trạng thái dừng hẳn dùng Global Variable, chỉ có hiệu lực trong CÙNG một MT5. Không chạy bot cho
    cùng tài khoản trên hai máy / hai VPS cùng lúc.

**Tốc độ phản ứng (cùng bản 5.10.13):**
- Thêm timer 500 ms: bảo vệ lệnh tay và chốt lời linh hoạt chạy cả khi không có tick mới, không chỉ trong `OnTick()`.
  Các bước an toàn chạy trước, hiển thị / nhật ký chạy sau. Bộ đếm dùng đồng hồ máy (`GetTickCount64`) thay vì giờ server
  (giờ server đứng yên khi không có tick). Bảo vệ lệnh tay kiểm tra mỗi 1 giây (trước 2 giây), chốt linh hoạt 4 lần / giây.
- Giá tốt nhất kể từ khi khớp (cho chốt khi giật ngược) đọc MỌI tick bằng `CopyTicksRange`, không bỏ sót đỉnh / đáy giữa hai lần kiểm tra.
- Đo thời gian xử lý: bảng trên chart và file trạng thái (`xuly=`) ghi thời gian trung bình, lớn nhất và số lần > 100 ms.
- Trượt giá khi chạm SL / TP: ghi thêm vào `TrendBot_truotgia.csv` (cột Chiều = "SL Buy", "TP Sell"..., cả lệnh magic 0),
  GiaYeuCau = mức SL / TP, GiaKhop = giá đóng thật. Bấm "Gửi nhật ký" sau vài tuần demo để đo.
- Giới hạn không sửa được: EA chỉ chạy khi MT5 mở và có mạng. SL / TP nằm trên máy chủ nên vẫn hoạt động, còn chốt gộp,
  chốt khi đảo chiều, kéo SL, tự vào thì dừng. Dùng VPS để chạy liên tục. SL không bảo đảm khớp đúng giá khi thị trường chạy mạnh.

## Rà soát lần 2 (v5.10.14)
- Đếm số lệnh tự vào mỗi ngày (`InpGuardAutoMaxDay`): ngoài ghi chú `TB tu vao`, bot lưu ticket lệnh tự vào và một bộ đếm riêng
  theo ngày (Global Variable), lấy số lớn hơn. Sàn đổi / cắt ghi chú cũng không làm đếm thiếu.
- Dừng hẳn vì sụt giảm cả tài khoản: nay đóng CẢ lệnh tay mở trước khi bật bảo vệ và hủy CẢ lệnh chờ đặt trước đó
  (trước đây chúng bị bỏ qua theo luật "lệnh cũ chỉ cảnh báo"). Đây là điểm dừng khẩn cấp, không bỏ sót lệnh nào trên mã.
- Bộ 06: rủi ro tối đa mỗi lệnh giảm từ 6% xuống 4% (0,01 lot với SL 0,15% khoảng 3% vốn ~900 nghìn).
  Bộ 05 giữ 6% vì với SL 0,25%, lot nhỏ nhất đã khoảng 5% vốn; giảm nữa thì bot bỏ mọi tín hiệu. Muốn rủi ro thấp hơn cần vốn lớn hơn.
- Không sửa được trong code (giới hạn của MT5): khóa giữa các bot chỉ trong một terminal; chốt gộp / đảo chiều / kéo SL cần MT5 mở
  và có mạng. Chạy MỘT terminal trên VPS cho mỗi tài khoản.

## Khóa lỗ ngày đóng cả lệnh cũ, và cách thử trên demo (v5.10.15)
- Lỗ của lệnh tay mở trước khi bật bảo vệ vẫn được cộng vào lỗ ngày, nhưng trước đây khi khóa thì chúng không bị đóng. Nay khóa lỗ ngày
  (cũng như dừng hẳn) đóng CẢ lệnh cũ và hủy CẢ lệnh chờ cũ. `InpGuardOldTrades` chỉ còn quyết định việc tự đặt SL / dời hòa vốn cho lệnh cũ.
- Rủi ro 6% (bộ 05) / 4% (bộ 06) là mức tính tại giá SL. Khi giá nhảy (tin, mở cửa cuối tuần), SL có thể khớp xấu hơn, lỗ thật vượt mức đó.
  Code không chặn được; xem cột trượt giá SL trong `TrendBot_truotgia.csv` sau vài tuần demo.
- Thử trên demo trước tiền thật (mỗi mục chụp lại bảng chart / thông báo):
  1. Khởi động lại MT5 khi đang giữ 1 lệnh tự vào: bảng vẫn đếm đúng số lệnh tự vào trong ngày, chốt gộp vẫn nhận lệnh đó.
  2. Đặt `InpGuardAutoMaxDay = 1`: sau lệnh tự vào đầu tiên trong ngày, bot không vào thêm (kể cả sau khởi động lại).
  3. Đóng tay một nửa lot của lệnh tự vào (khớp một phần): lệnh còn lại vẫn được chốt gộp / kéo SL.
  4. Gắn bot lên 2 chart BTC cùng lúc: chart thứ hai hiện dòng đỏ "CHART KHÁC đang bảo vệ".
  5. Đặt `InpGuardDayLossPct` rất nhỏ (ví dụ 0,5): khi chạm, mọi lệnh tay trên mã bị đóng và bot ngừng tự vào tới hết ngày.

## Các khóa chặn mọi đường vào lệnh, giới hạn lỗ ngày của lệnh tự vào (v5.10.16)
- Dừng hẳn vì cả tài khoản sụt quá `InpGuardMaxDDPct` (15%) nay chặn luôn chiến lược chính (vào lệnh mới, vào khi giá hồi, vào lại),
  nhồi lớp của chiến lược chính và nút BUY / SELL trên chart. Trước đây chỉ chặn lệnh tay, tự vào và nhồi lệnh tay.
  Lệnh đang mở của chiến lược chính vẫn giữ SL / TP của nó, không bị đóng.
- Có HAI mức khóa lỗ ngày, mỗi mức cho một nhóm lệnh:

  | Mức | Áp dụng cho | Bộ 05 / 06 |
  |---|---|---|
  | `InpMaxDailyLossPct` | chỉ lệnh của chiến lược chính | 3% |
  | `InpGuardDayLossPct` | lệnh tay, lệnh tự vào, lệnh nhồi | 6% (trước: 10%) |
  | `InpGuardMaxDDPct` | cả tài khoản, tính từ đỉnh | 15% |

  Chỉ chạy bộ 05 / 06 thì mức thật sự chặn bot tự vào là 6% / ngày, không phải 3%. Bảng điều khiển ghi rõ "Khóa tay + tự vào khi lỗ ngày".
- Chế độ tự vào lệnh nay dùng cùng bộ lọc thị trường với chiến lược chính: tin kinh tế Mỹ (`InpAvoidUSNews`), funding, Fear & Greed,
  sự chú ý (Wikipedia), Nasdaq. Bộ lọc nào đang tắt thì không xét. Bộ 05 / 06 nay BẬT tránh tin Mỹ.

## Khớp một phần, khóa chart, nhận diện lệnh, trượt giá lệnh tự vào (v5.10.17)
- **Khớp một phần khi đóng:** sau mỗi lệnh đóng, bot kiểm tra vị thế còn hay không thay vì tin vào mã trả về. Chốt gộp mà còn khối lượng
  thì bot nhớ trạng thái "đang chốt" và đóng nốt ở lần kiểm tra sau (khoảng 0,25 giây), không xét lại điều kiện chốt.
  Báo "đã đóng" chỉ gửi khi vị thế thật sự hết.
- **Một chart bảo vệ mỗi mã:** dùng một khóa duy nhất cho mỗi tài khoản + mã, chiếm quyền bằng thao tác nguyên tử của MT5.
  Hai chart khởi động cùng lúc thì chỉ một chart thắng; chart kia hiện "CHART KHÁC". Chart chủ đóng thì chart kia tự nhận quyền.
- **Nhận diện lệnh bot mở:** tra theo mã định danh vị thế (không đổi suốt đời vị thế), ticket và ghi chú chỉ là dự phòng.
- **Trượt giá vào lệnh của bộ 05 / 06:** lệnh tự vào và lệnh nhồi (magic 0) nay cũng ghi vào `TrendBot_truotgia.csv`, cột Magic = 0.
- **Đọc tick:** tối đa 5000 tick mỗi lần; lỗi đọc thì giữ mốc cũ, đọc lại lần sau, ghi log tối đa 1 lần / phút.
- **Trạng thái trên trình duyệt:** hiện rõ "DỪNG HẲN: vốn tài khoản sụt quá giới hạn" và khi đang khóa lệnh tay + tự vào tới hết ngày.

## Chuẩn bị kiểm thử demo (v5.10.18)
- Bảng 8 bài thử và cách làm từng bài: xem `KIEM-THU-DEMO.md`.
- Bot ghi Global Variable xuống đĩa mỗi 30 giây: tắt MT5 đột ngột (mất điện) không mất mốc vốn, R ban đầu, bộ đếm lệnh, khóa ngày.
- R ban đầu, giá tốt nhất, trạng thái "để lời chạy" lưu theo mã định danh vị thế (không đổi khi sàn đổi ticket). Lệnh cũ vẫn đọc được.
- Nhồi lệnh (magic 0) nay cũng tuân thủ giờ nghỉ / cuối tuần, spread tối đa và tránh tin Mỹ, như lệnh tự vào.

## Bảng điều kiện chặn ở mọi đường vào lệnh, xử lý lỗi (v5.10.19)
✓ = có kiểm tra trước khi gửi lệnh. "—" = không áp dụng theo thiết kế (hai nhóm lệnh có hạn mức lỗ ngày riêng).

| Đường vào lệnh | Dừng hẳn cả tài khoản (15%) | Dừng hẳn / lỗ ngày chiến lược chính (3%) | Khóa ngày lệnh tay (6%) | Giờ nghỉ, cuối tuần | Spread tối đa | Tin Mỹ | Funding, F&G, Nasdaq |
|---|---|---|---|---|---|---|---|
| Chiến lược chính: vào mới, chờ giá hồi, vào lại | ✓ | ✓ | — | ✓ | ✓ | ✓ | ✓ |
| Chiến lược chính: nhồi lớp | ✓ | ✓ | — | ✓ (mới) | ✓ | ✓ (mới) | — |
| Nút BUY / SELL: vào mới | ✓ | ✓ | — | ✓ | ✓ | ✓ (mới) | — |
| Nút BUY / SELL: nhồi | ✓ | ✓ (mới) | — | ✓ (mới) | ✓ (mới) | ✓ (mới) | — |
| Tự vào (bộ 05 / 06) | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Nhồi lệnh tay / tự vào | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | — |

Nhồi không xét funding, Fear & Greed, Nasdaq vì đó là bộ lọc chọn hướng vào lệnh; lệnh nhồi đã cùng hướng lệnh đầu.

Xử lý lỗi:
- **Mất kết nối:** bảo vệ lệnh tay tạm dừng quyết định (số dư, giá lúc đó là số cũ); tự vào, nhồi, chốt lời đều chờ có kết nối lại.
- **Mã ở chế độ "chỉ đóng lệnh":** không mở lệnh mới, vẫn chốt lời / đóng được.
- **Đóng lệnh thất bại** (thị trường đóng, giá đổi, sàn từ chối): chờ 5 giây rồi thử lại, không gửi liên tục mỗi giây và không làm đầy nhật ký.
- **Tự vào:** bỏ qua khi chưa có giá hoặc SL gần hơn khoảng cách tối thiểu sàn cho phép (sàn sẽ từ chối).

## Rà soát rủi ro v5.10.20

Xem [phân tích định lượng và hướng dẫn thử nghiệm](RA-SOAT-RUI-RO-5.10.20.md): SL theo ATR và vốn tối thiểu dựa trên giá trị tick / lot thực tế; lọc tâm lý theo chiến lược; nhồi giảm khối lượng nếu sàn cho phép; khóa theo bucket lệnh tay 1%/thuật toán 2%; snapshot peak equity và backtest bộ 05/06 khi bật `InpGuardBacktest`. Chế độ đóng lệnh vẫn đồng bộ và cần xác nhận server vì lệnh async không bảo đảm đóng nguyên tử. Chưa compile hay xác minh lợi nhuận trên MT5.

## Đo độ tin cậy và theo dõi khi chạy thật (v5.10.21, 11/11/2026)

Không đổi cách bot vào lệnh. Thêm ba thứ để đánh giá đúng kết quả:

- **Sharpe điều chỉnh trong file kết quả:** đặt `InpTrials` = số cấu hình khác nhau đã thử trên cùng dữ liệu trước khi chọn cấu hình đang chạy. File kết quả có thêm `SkewR`, `KurtR`, `SoLanThu`, `SR0`, `DSR%`, `MinTRL_dot` (xem bảng ở mục Đọc kết quả backtest). Tính lại tay trên 98 lệnh C (2023–2026): `InpTrials` = 1 cho DSR 99% và cần 54 đợt; 10 lần thử cho DSR 74% và cần khoảng 610 đợt; 50 lần thử cho DSR 48%, không đạt.
- **Tổng R thật trên bảng thông tin:** dòng "Tổng R thật: … / n lệnh · ngưỡng xem lại …". Ngưỡng = `InpLiveExpR` × n − 2 × `InpLiveSdR` × √n (mặc định 0,31 và 1,69 lấy từ backtest C). Sau ít nhất 10 lệnh mà tổng R xuống dưới ngưỡng thì bot báo một lần qua điện thoại/Telegram. Bot **không** tự dừng: đây là lúc dừng tay và xem lại, không phải lúc sửa cấu hình. Sau 20 lệnh ngưỡng khoảng −9R, sau 50 lệnh khoảng −8R. Chỉ tính lệnh bot (magic của bot) đã đóng có SL lúc vào, theo từng vị thế; khi nhồi lệnh thì chỉ gần đúng vì backtest tính theo đợt. Đặt `InpLiveExpR` = 0 để tắt.
- **Kiểm thử chia tổ hợp (CPCV):** `python cong-cu/cpcv.py ket-qua/gia-BTCUSDm_M10.zip`. Chia 11/2020–11/2026 thành 6 khối 1 năm, thử 15 cách chọn 2 khối làm kiểm tra với lưới 9 cấu hình định trước (Donchian 10/20/40 × SL 2/2,5/3 ATR), bỏ lệnh chạm khối kiểm tra cộng 1 tuần.

Kết quả CPCV lần đầu (mô phỏng Python, 11/11/2026):
- Cả 9 cấu hình đều dương trên toàn kỳ; Donchian 20 với SL 2,5–3 ATR tốt nhất (t ≈ 2,0, khoảng 120 lệnh).
- Cấu hình được chọn trong mẫu có Sharpe ngoài mẫu **dương ở 15/15 cách chia** (trung vị 0,14 mỗi lệnh).
- PBO 60%: chọn cấu hình "tốt nhất" trong lưới không giúp gì so với chọn bừa một cấu hình trong lưới.
- Nghĩa là lợi thế nằm ở cả họ chiến lược (phá kênh theo xu hướng), không nằm ở con số 20 hay 2,5. Đừng dò thêm tham số; nếu muốn cải thiện thì gộp nhiều chu kỳ thay vì tìm chu kỳ tốt nhất.

Chưa compile trên MetaEditor. Cần compile và chạy một lần backtest để kiểm tra các cột mới trước khi dùng.

### Thử 3 ý tưởng nâng cấp bằng mô phỏng (11/11/2026, `cpcv.py --bien-the`)

Ba phương án định trước từ báo cáo nghiên cứu, so với cấu hình gốc C (Donchian 20, SL 2,5 ATR, trailing 3 ATR), 11/2020–11/2026:

| Phương án | Lệnh | Tổng R | Sharpe/tháng | R khi bỏ 5 lệnh lớn nhất | Hơn gốc ở cùng mức rủi ro (15 cách chia) |
|---|---|---|---|---|---|
| Gốc | 120 | +41,7 | 0,256 | +8,1 | — |
| Gộp Donchian 10/20/40/80, mỗi kênh 1/4 rủi ro | 472 | +36,1 | 0,232 | +22,8 | 4/15 |
| Khối lượng theo ATR (×1,25 khi ATR thấp, ×0,75 khi cao) | 120 | +46,2 | 0,250 | +8,7 | 7/15 |
| Trailing siết theo bậc (2 ATR sau khi lãi 4R) | 126 | +36,6 | 0,237 | +4,2 | 3/15 |

Kết luận: không phương án nào tốt hơn gốc khi so ở cùng mức rủi ro, nên **không thêm vào bot**. Khối lượng theo ATR có tổng R cao hơn chỉ vì đánh lớn hơn ở trung bình. Trailing theo bậc cắt mất lệnh thắng lớn (R bỏ top 5 giảm một nửa). Gộp nhiều chu kỳ ít phụ thuộc vào vài lệnh lớn hơn hẳn (+22,8R khi bỏ top 5), đổi lại Sharpe thấp hơn một chút và gấp 4 lần số lệnh: đáng xem lại nếu sau này ưu tiên độ bền hơn lợi nhuận.

## Rà soát an toàn v5.10.22

Xem [tài liệu kiểm tra riêng v5.10.22](RA-SOAT-RUI-RO-5.10.22.md). Bản mới tách R thực tế của `P_Magic` và `magic 0`; không đếm partial close thành vị thế đã đóng; không cho chạy trên Netting; khóa nhóm BTC/ETH bao gồm lệnh tự vào/nhồi; bucket human/algo tách quyền nhồi, và nhận biết dữ liệu bộ lọc bị thiếu. Mốc DD tài khoản được điều chỉnh theo deal Balance nạp/rút và lưu watermark; khi sàn dùng Balance cho điều chỉnh khác, cần xem History. Chưa có xác nhận compile MQL5 hoặc kết quả demo ở thời điểm cập nhật.

## Rà soát chuyên sâu v5.10.23

Xem [kiểm toán và các bài kiểm thử v5.10.23](RA-SOAT-RUI-RO-5.10.23.md): hạch toán human/algo theo vị thế mở; bucket lỗ chung toàn account, trần rủi ro nhóm áp dụng cho cả lệnh đầu tiên; OrderCalcMargin/OrderCheck; BTCUSDc trên MT5 Standard Cent (đơn vị USC); drawdown mark-to-market riêng; xác minh lịch CPI và block bootstrap. Nhánh chưa được biên dịch/Strategy Tester trên MT5 thật. 

## v5.11: chiến lược Fibonacci + Volume Profile và bot tự chọn chiến lược (16/11/2026)

**Chiến lược 9 – Fibonacci + Volume Profile** (`InpStrategy = 9`, bộ `08-Fib-Volume-Profile-H1-THU-NGHIEM.set`):
1. Tìm con sóng gần nhất trong `InpFibLookback` nến (≥ `InpFibMinSwingATR` ATR). Sóng tăng: đáy thấp nhất xuất hiện trước đỉnh cao nhất.
2. Dựng Volume Profile của con sóng: chia biên độ thành `InpVPBins` ô, rải số tick của từng nến khung `InpVPTFmin` (mặc định M5) lên các ô nến đó đi qua. Ô "dày" khi số tick ≥ `InpVPHighMult` × trung bình.
3. Xét các mức 0,382 / 0,5 / 0,618 / 0,786 từ nông tới sâu: mức rơi vào ô mỏng bỏ qua; mức trong ô dày là vùng chờ.
4. Xác nhận: nến vừa đóng cùng chiều, râu chạm vùng, không xuyên quá 0,5 ATR, đóng lại phía trên mức. SL ngoài vùng dày 0,25 ATR; TP ở đỉnh (đáy) con sóng; bỏ nếu lãi tới TP < `InpFibMinRR` × SL. Mỗi con sóng chỉ vào 1 lần.
Exness chỉ có số tick, không có khối lượng thật, nên đây là ước lượng của "dấu chân tiền".
Mô phỏng thô bằng Python trên nến M10 (H1, theo xu hướng D1, chi phí 0,06%/vòng) để kiểm tra logic: 283 lệnh, thắng 30%,
PF 0,69 (12/2020–11/2023) và 0,79 (11/2023–11/2026). Kết quả thật trong MT5 xem ở đợt xếp hạng.

**Xếp hạng chiến lược:** nút 1, nhóm *Xếp hạng chiến lược*. Chạy 26 cấu hình (mỗi chiến lược 1 cấu hình đại diện, không dò tìm) trên 6 năm gần nhất,
vốn 30.000 USD. Tính R theo đợt (lệnh nhồi chồng nhau gộp 1 đợt):
- Đủ điều kiện: R trung bình trên cả 6 năm > 0 và ≥ 20 đợt. Chiến lược không có lợi thế lâu dài không bao giờ được chọn, dù vài tháng gần đây gặp may.
- Điểm = cận dưới 90% của R trung bình 12 tháng gần nhất (cần ≥ 8 đợt). Đứng đầu = được vào lệnh.
- Ghi `TrendBot_xephang.csv` vào Common\Files (bot đọc) và `ket-qua/<ngày>-nhanh-xephang.csv` (đưa lên GitHub).

**Bot tự chọn:** gắn mỗi chiến lược lên một chart BTCUSDm riêng, bật `InpAutoSelect` ở tất cả. Bot đọc bảng mỗi 10 phút; chỉ chart có
chiến lược đứng đầu (mã `S<chiến lược>-<số phút khung>`, vd. `S1-240` = Donchian H4) được vào lệnh mới, lệnh đang mở vẫn quản lý bình thường.
Bảng thiếu hoặc cũ hơn `InpSelectMaxAgeDays` ngày: chỉ Donchian H4 được vào. Nên chạy lại xếp hạng mỗi tuần.
Backtest bỏ qua tự chọn; tự bấm lệnh không bị chặn.

**Kiểm chứng bộ chọn trước khi tin:** `python cong-cu/danh_gia_bo_chon.py ket-qua/<ngày>-nhanh-lenh.csv` mô phỏng bộ chọn kiểu walk-forward
(mỗi tháng chỉ nhìn quá khứ, cùng luật như trên). Tiêu chí đặt trước: tổng R của bộ chọn phải cao hơn "luôn Donchian H4" ở CẢ HAI nửa giai đoạn.
Chưa đạt thì để `InpAutoSelect = false` và chỉ chạy Donchian H4.

## v5.12: xác nhận bằng dòng tiền (16/11/2026) – mặc định TẮT, CHƯA KIỂM THỬ
Kiến thức: đường hỗ trợ / kháng cự chỉ đặt câu hỏi (giá từng quay đầu ở đây), dòng tiền mới trả lời lần này ra sao.
Kẻ vùng trước, khi giá tới mới nhìn dòng tiền. Bot làm việc đó ở cây nến tín hiệu, sau khi mọi điều kiện khác đã đạt (`TrendBot/OrderFlow.mqh`, bật `InpUseFlow`):
- **Chiến lược phá vỡ** (Donchian, ORB, MACD, quán tính): cần phe theo chiều lệnh chủ động áp đảo (delta ≥ `InpFlowMinDelta`),
  khối lượng lớn bất thường (≥ `InpFlowBigMult` × trung bình 20 nến, thay cho "big trades") và nến giữ được giá (đóng ở phần
  ≥ `InpFlowHoldPos` của biên độ theo chiều lệnh). Mua rất nhiều mà nến đóng thấp = lệnh bán lớn chặn sẵn nuốt hết lực mua
  (bị hấp thụ), người mua phá vỡ bị kẹt trên đỉnh: bỏ tín hiệu.
- **Chiến lược bật lại ở vùng giá** (EMA pullback, RSI, đảo chiều, FVG, spring, Fib + VP): cần khối lượng lớn bất thường và bên kia
  chủ động đổ vào (Buy: bán chủ động nhiều hơn mua) mà nến vẫn đóng theo chiều lệnh: có người đỡ, vùng giá sẽ giữ.
Giới hạn dữ liệu: Exness (CFD) không có chiều mua/bán chủ động hay kích thước từng lệnh, nên bot lấy nến cùng khung của Binance Futures
(khối lượng + khối lượng mua chủ động). Đây là "footprint" rút gọn của cả cây nến, không phải từng mức giá; không có bong bóng từng lệnh lớn.
Chạy thật: thêm `https://fapi.binance.com` vào Tools > Options > Expert Advisors > Allow WebRequest. Backtest: cần file
`du-lieu/flow_BTCUSDT_<khung>.csv` (`openTime_ms,volume,takerBuyVolume`), chưa có thì bộ lọc không chặn lệnh nào
(cột `DongTienThieuDuLieu` đếm số lần thiếu, `ChanDongTien` đếm số lần chặn).
Lưu ý khi kiểm thử sau này: biến thể gần giống (vào khi phe chủ động cùng chiều phá vỡ, dữ liệu taker ratio Binance) đã thử ngày
07/11 với Donchian H4 và làm tổng R giảm (49,3 / 8,3 so với 59,1 / 15,3). Phần "hấp thụ" (mua nhiều mà giá không giữ) chưa thử.

## v5.13: chiến lược 10 – phân kỳ RSI xác nhận bằng CVD (16/11/2026) – CHƯA KIỂM THỬ
Kiến thức: RSI và CVD cùng đo lực mua bán, nhưng RSI tính từ giá đóng cửa đã qua nên chỉ thấy giá **mất đà** (cảnh báo);
CVD tính từ lệnh mua / bán chủ động lúc khớp nên thấy **ai đang bấm nút** (bằng chứng). Có cảnh báo mà chưa có bằng chứng thì chờ.
Bộ `09-Phan-ky-RSI-CVD-H1-THU-NGHIEM.set` (`InpStrategy = 10`, H1, TP 2R):
- **Phân kỳ ở đỉnh:** hai đỉnh gần nhất (đỉnh = cao hơn `InpDivPivot` nến mỗi bên), đỉnh sau cao hơn, RSI đỉnh sau thấp hơn (cảnh báo)
  **và** CVD đỉnh sau không cao hơn (người mua chủ động đã rút) → bán khi đỉnh vừa được xác nhận và giá đóng dưới nến đỉnh.
  RSI phân kỳ mà CVD vẫn lập đỉnh mới = người mua vẫn đổ tiền vào: không bán (đúng lúc người chỉ nhìn RSI bị quét). Đáy: ngược lại.
- **Hấp thụ ở đáy:** RSI quá bán (`InpDivRsiLow`, cảnh báo) + trong `InpAbsorbBars` nến gần nhất bán chủ động đổ vào ≥ `InpAbsorbDelta`
  tổng khối lượng (CVD lao dốc) mà giá không giảm thêm, giá ở 1/4 dưới của vùng `InpDivLookback` nến → có người hấp thụ, mua. Đỉnh: ngược lại.
- SL qua đỉnh / đáy 0,25 ATR (tối thiểu 0,5 ATR). Đỉnh / đáy chỉ được xác nhận sau `InpDivPivot` nến nên tín hiệu (a) đến chậm bấy nhiêu nến.
- CVD lấy từ nến Binance Futures cùng khung (như bộ lọc dòng tiền v5.12). Thiếu dữ liệu thì không vào lệnh. Backtest cần
  `du-lieu/flow_BTCUSDT_1h.csv`; đã thêm vào nhóm xếp hạng (`XH-RSICVD-H1`), chưa có file thì nó không có lệnh nên không đủ điều kiện.
- CVD tính trên cửa sổ `InpDivLookback` nến (chỉ cần so tương đối giữa hai đỉnh), không phải CVD tích lũy từ đầu.

## v5.14: chiến lược 11 – Big Trades tại vùng quan trọng (16/11/2026) – CHƯA KIỂM THỬ
Kiến thức: lệnh lớn để lại dấu chân trên biểu đồ, nhưng bong bóng chỉ cho biết **có** lệnh lớn, không cho biết lệnh đó thắng hay thua.
Phải nhìn giá làm gì ngay sau bong bóng, và chỉ chú ý ở vùng quan trọng (đỉnh cũ, đáy cũ). Mua theo bong bóng xanh / bán theo bong bóng đỏ là sai.
Bộ `10-Big-Trades-H1-THU-NGHIEM.set` (`InpStrategy = 11`, H1, TP 2R). "Bong bóng" = nến có khối lượng ≥ `InpBigMult` × trung bình
20 nến trên Binance Futures, xanh / đỏ theo phe chủ động áp đảo (delta ≥ `InpBigMinDelta`). Exness không có kích thước từng lệnh,
lấy từng lệnh khớp qua mạng thì quá nặng, nên đây là xấp xỉ theo cả cây nến. Thứ tự ưu tiên:
1. **Hấp thụ** (mạnh nhất): bong bóng đỏ to sát đáy cũ (trong `InpBigZoneATR` ATR) mà giá không giảm thêm rồi bật lên → người bán lớn
   bị nuốt, thường là đáy → mua. Bong bóng xanh to sát đỉnh cũ mà giá không lên nổi → người mua bị kẹt → bán.
2. **Chuỗi thanh lý**: ≥ `InpBigClusterMin` bong bóng đỏ trong `InpBigClusterBars` nến, giá rơi ≥ 3 ATR. Thường là cắt lỗ / thanh lý
   hàng loạt, không phải tay to bán. Chuỗi kết thúc mà giá ngừng rơi → người bán đã cạn → mua. Đỉnh: ngược lại.
3. **Giá đi theo bong bóng**: bong bóng xanh rồi giá tăng mạnh (đóng vượt đỉnh nến bong bóng ≥ 0,5 ATR trong 3 nến) → lệnh lớn đã thắng,
   vùng bong bóng thành hỗ trợ (họ bảo vệ giá vốn) → mua ở lần chạm lại đầu tiên khi nến đóng tăng. Bong bóng đỏ: ngược lại.
SL ngoài vùng / đáy / đỉnh 0,25 ATR (tối thiểu 0,5 ATR). Mỗi bong bóng hoặc chuỗi chỉ vào 1 lần. Kết hợp CVD (chiến lược 10)
hoặc bộ lọc dòng tiền (v5.12) để thấy ai đang thắng. Thiếu dữ liệu Binance thì không vào lệnh. Đã thêm vào xếp hạng (`XH-BigTrade-H1`).

## v5.15: chiến lược 12 – hộp phân phối / tích lũy, vào ở lần test lại (16/11/2026) – CHƯA KIỂM THỬ
Kiến thức: cú sập nào cũng để lại dấu vết trước khi xảy ra. 5 nhịp lặp lại ở hầu hết các cú sập:
1. **Nến hưng phấn:** tăng rất dài (≥ `InpDistClimaxATR` ATR), khối lượng lớn nhất 20 nến, râu trên ≥ 20% biên độ, sau một nhịp tăng ≥ 2 ATR.
   Đám đông mua đuổi, tay to bắt đầu bán.
2. **Giá không còn tạo đỉnh mới:** đi ngang trong hộp (≥ `InpDistBoxMin` nến, cao ≤ `InpDistBoxMaxATR` ATR), chạm nắp bị đạp xuống.
3. **Phá đỉnh giả:** vọt qua nắp rồi đóng lại trong hộp (bắt buộc khi bật `InpDistNeedUT`).
4. **Đỉnh thấp hơn:** đỉnh gần nhất trong hộp thấp hơn nắp ≥ 0,3 ATR, cấu trúc tăng bắt đầu gãy.
5. **Nến sập:** đóng dưới đáy hộp, dài ≥ 1 ATR, khối lượng ≥ 1,2 × trung bình.
Không bán đuổi nến sập. Bot chờ **lần test lại đầu tiên** của đáy hộp (nay là kháng cự): nến chạm vùng, đóng lại dưới đáy hộp,
nến giảm hoặc râu trên ≥ 40%, khối lượng nhỏ hơn nến sập → bán. SL trên đỉnh thấp hơn vừa tạo, TP ở nơi cú tăng ban đầu bắt đầu
(đáy thấp nhất 30 nến trước nến hưng phấn); bỏ nếu lãi < 1R. Hộp tích lũy sau cú giảm: ngược lại → mua.
Bộ `11-Hop-phan-phoi-H1-THU-NGHIEM.set` (`InpStrategy = 12`, H1). Dùng khối lượng tick của Exness, không cần dữ liệu ngoài.
Kiểm tra nhanh bằng Python trên nến M10 6 năm (chỉ đếm tín hiệu, không đo lãi lỗ): mẫu hình đủ 5 nhịp chỉ xuất hiện khoảng 2 lần
trên H1 và 2 lần trên M30. Các ngưỡng đã nới so với bản đầu (ban đầu 0 lần). Đây là mẫu hình hiếm; đã thêm vào xếp hạng (`XH-PhanPhoi-H1`),
nhiều khả năng không đủ 20 đợt để đủ điều kiện.

## v5.16: chiến lược 13 – đánh lưới trong vùng đi ngang (16/11/2026) – CHƯA KIỂM THỬ
Kiến thức: giăng lưới trong ao, giá lên xuống trong một vùng, rơi xuống một nấc thì mua, lên lại nấc trên thì bán, ăn phần chênh lệch.
Rủi ro là cá bơi ra khỏi ao: giá thủng đáy và rơi tiếp thì lưới mua ở mọi nấc trên đường xuống. Bộ `12-Danh-luoi-H1-THU-NGHIEM.set`
(`InpStrategy = 13`, `TrendBot/Grid.mqh`, lưới mua: mua ở nấc dưới, chốt lời ở nấc ngay trên). 4 luật:
1. **Chỉ giăng khi thật sự đi ngang** (khung chính, `InpGridBars` nến): vùng cao `InpGridMinATR`–`InpGridMaxATR` ATR, ADX < `InpGridMaxADX`,
   đã chạm đỉnh và đáy vùng mỗi phía ≥ 2 lần, giá đang ở giữa vùng.
2. **Không giăng quá dày:** mỗi mắt lưới ≥ `InpGridMinStepCost` × spread; không đủ thì giảm số nấc, dưới 3 nấc thì không giăng.
3. **Điểm dừng ngoài lưới:** mọi lệnh có SL đặt sẵn ở server tại đáy vùng − `InpGridStopATR` ATR. Nến đóng cửa thủng đáy vùng:
   tắt lưới, đóng hết, cắt lỗ. Giá phá lên trên đỉnh vùng: tắt lưới (hủy lệnh chờ), lệnh còn lại giữ chốt lời.
4. **Không dùng đòn bẩy cao:** khối lượng mỗi nấc tính sao cho nếu mọi nấc đều khớp rồi chạm SL thì tổng lỗ = `InpRiskPercent` vốn bot;
   ký quỹ cả lưới ≤ 50% ký quỹ tự do. **Tạm tắt** (hủy lệnh chờ, giữ lệnh đang mở) trước tin Mỹ (`InpAvoidUSNews`), khi chạm lỗ ngày,
   ngoài giờ giao dịch, spread rộng.
Sau khi tắt lưới, nghỉ `InpGridBars`/2 nến rồi mới tìm vùng mới. Trạng thái lưới lưu Global Variable (khởi động lại MT5 vẫn nhớ).
Gỡ bot khỏi chart: hủy lệnh chờ (lệnh đang mở vẫn có SL / TP). Chỉ lưới mua (giống bot lưới giao ngay); giá phá lên thì đứng ngoài con sóng.
Đã thêm vào xếp hạng (`XH-Luoi-H1`). Lệnh của lưới không đi qua khóa rủi ro nhóm BTC/ETH (InpMaxGroupRiskPct).

## v5.17: Scalp hay Swing – chọn theo con người (16/11/2026) – CHƯA KIỂM THỬ
Kiến thức: câu hỏi đúng không phải kiểu nào lời hơn mà bạn là người như thế nào; chọn sai kiểu đánh thì phương pháp tốt mấy cũng thua.
Ba tính năng mới (mặc định tắt) + hai bộ cài đặt:
- `InpSessionStartH` / `InpSessionEndH`: chỉ vào lệnh trong giờ cao điểm (giờ server = UTC). Lệnh đang mở vẫn quản lý bình thường.
- `InpStallBars` / `InpStallMinATR`: lệnh giữ ≥ N nến mà giá chưa đi theo chiều lệnh được x ATR thì thoát (lệnh đứng yên quá lâu).
- `InpSLStructBars` / `InpSLStructMinATR`: SL dưới đáy thấp nhất (mua) / trên đỉnh cao nhất (bán) N nến gần nhất + 0,25 ATR,
  không sát hơn x ATR (dừng lỗ dưới cấu trúc, không quá sát). Chỉ khi chiến lược không tự đặt SL.
- **`13-Phong-cach-Scalp-M5-THU-NGHIEM`** (người có nhiều thời gian, phản xạ nhanh, chịu áp lực, không ôm lệnh qua đêm):
  Donchian M5, chỉ 13–17 giờ UTC, theo hướng H1, SL cứng 1,5 ATR (bot không bao giờ nới SL), lệnh đứng yên 30 phút chưa đi 0,5 ATR thì thoát,
  tối đa 5 lệnh / ngày, TP 1,5R. **Chưa đạt:** mọi khung M1–M30 của Donchian đều lỗ ở 2020–2023 khi backtest – đúng nhược điểm "phí ăn mòn".
- **`14-Phong-cach-Swing-H4-THU-NGHIEM`** (người bận rộn, kiên nhẫn, chịu được giá lên xuống vài ngày): xu hướng D1, vào khi giá hồi về
  EMA20 H4 (vùng giá rẻ), SL dưới đáy 20 nến H4 (≥ 2 ATR), chốt 1/3 ở 2R, trailing 3 ATR từ 1R. Rủi ro vẫn 1% / lệnh nên SL rộng thì
  khối lượng tự nhỏ lại. Chưa backtest tổ hợp này; cấu hình swing đã kiểm thử vẫn là mặc định của bot (Donchian H4 + ADX).
Với BTC trên Exness (spread ~24 USD / BTC), dữ liệu backtest đến nay nghiêng hẳn về Swing: chỉ khung H4 qua được cả hai giai đoạn.

## v5.18: Khóa lệnh (hedging) và đánh theo giờ cao điểm (16/11/2026) – CHƯA KIỂM THỬ
**Khóa – mở khóa – nhồi** (`TrendBot/Hedge.mqh`, mặc định tắt, tài khoản phải ở chế độ phòng hộ):
- Khóa: bot giữ đúng 1 lệnh, lệnh đó lỗ `InpHedgeLockLossR` R (khóa lỗ, < 1 để khóa trước khi chạm SL) hoặc lời
  `InpHedgeLockProfitR` R khi sắp có tin Mỹ / từ `InpHedgeFriHour` giờ thứ Sáu (khóa lời) → mở lệnh ngược chiều cùng khối lượng,
  bỏ SL / TP lệnh gốc, ghi lại vùng đỉnh / đáy `InpHedgeZoneBars` nến. Mỗi lệnh chỉ khóa 1 lần.
- Mở khóa: không theo một cây nến. Nến đóng cửa hẳn ra ngoài vùng → nến sau hồi về test lại (≤ `InpHedgeRetestATR` ATR quanh mép)
  mà vẫn đóng cửa ngoài vùng → đóng lệnh ngược xu hướng, giữ lệnh cùng xu hướng. Đóng lại vào trong vùng = phá vỡ giả, chờ tiếp.
  Khóa lời chỉ mở khóa khi tin / cuối tuần đã qua.
- Lệnh còn lại: SL dưới đáy nến test − 0,25 ATR (đang lời thì ít nhất hòa vốn), rồi quản lý như thường (hòa vốn, trailing, nhồi).
  Không đặt được SL thì bot đóng luôn, không để lệnh trần. Một lệnh bị đóng ngoài ý muốn: lệnh kia đặt SL ở mép vùng bên kia.
- Không khóa quá lâu: quá `InpHedgeMaxBars` nến chưa xác nhận thì đóng cả hai (= cắt lỗ). Giữ 2 lệnh tốn phí (spread, swap) gấp đôi.
- Lúc đang khóa: không hòa vốn / trailing / nhồi / vào lệnh mới; 2 lệnh không có SL nên mọi kiểm tra rủi ro nhóm coi như hết hạn mức.
  Báo cáo backtest gộp lệnh khóa vào cùng đợt với lệnh gốc (R tính theo SL ban đầu của lệnh gốc).

**Nhồi đúng bài** (dùng cho cả lệnh còn lại sau mở khóa và đánh theo giờ): `InpPyramidRetest` chỉ nhồi khi giá hồi về ≥ 0,5 ATR
từ đỉnh 5 nến rồi đóng cửa bật lên; `InpPyramidSLBars` dời SL chung của mọi lớp lên dưới đáy N nến gần nhất. Vẫn giữ các luật cũ:
chỉ nhồi khi đang lời, lớp sau nhỏ hơn (`InpPyramidLotFactor`), lớp cũ về hòa vốn trước khi nhồi.

**Giờ cao điểm** (giờ server Exness = UTC; Việt Nam = UTC + 7):
- `InpSession2StartH` / `InpSession2EndH`: khung cao điểm thứ hai. Vào lệnh và nhồi chỉ trong một trong hai khung.
  London mở 14–15 giờ VN = 7–8 UTC; New York 19:30–23 giờ VN = 12:30–16 UTC; phiên Á buổi sáng và đêm khuya là giờ vắng.
- `InpSessPartialR`: vừa ra khỏi giờ cao điểm, lệnh đang lời ≥ x R thì chốt một nửa và dời SL về hòa vốn (mỗi lệnh 1 lần).
- Bộ cài đặt: **`15-Khoa-lenh-Hedging-H4-THU-NGHIEM`**, **`16-Gio-cao-diem-London-NewYork-H1-THU-NGHIEM`**.
- Cột báo cáo mới `Khoa_MoKhoa_HetGio_DungYen_CuoiPhien` = số lần khóa / mở khóa / hết hạn khóa / thoát lệnh đứng yên / chốt cuối phiên.

## v5.19: Không bắt dao rơi (chiến lược 14) và nhồi lệnh khi thắng đủ 4 quy tắc (16/11/2026) – CHƯA KIỂM THỬ
**Chiến lược 14 – Dao rơi: nhỏ, lớn, giữ** (`InpStrategy = 14`, bộ `17-Dao-roi-nho-lon-giu-H1-THU-NGHIEM`):
- Dao rơi: giá giảm ≥ `InpKnifeDropATR` ATR từ đỉnh xuống đáy trong ≤ `InpKnifeBars` nến (đáy = thấp nhất `InpKnifeLookback` nến).
  Không chỉ báo nào biết trước đâu là đáy; người kiếm nhiều nhất mua *sau* đáy.
- NHỎ: 1–2 nến sau đáy có nến tăng đóng cửa vượt đỉnh nến trước → lệnh thử `InpKnifeProbePct` % rủi ro chuẩn, SL dưới đáy.
- LỚN: giá đóng cửa vượt đỉnh gần nhất của cú giảm (đỉnh thấp hơn cuối cùng trước đáy), rồi có nến hồi về test lại
  (≤ `InpKnifeRetestATR` ATR) mà vẫn đóng cửa trên và là nến tăng → lệnh lớn, SL dưới đáy cao hơn vừa tạo. Mua đắt hơn đáy một chút
  nhưng có bằng chứng. Phá lên rồi đóng lại dưới mức đó = thất bại, không vào. Tổng rủi ro lệnh thử + lệnh lớn ≤ 1 lệnh chuẩn.
- GIỮ: không đặt TP. Chốt `InpPartialPct` % ở đỉnh cũ của cú giảm (mức chốt theo giá, lưu `PX_` cho từng lệnh), phần còn lại
  dời SL lên dưới mỗi đáy mới cao hơn (`InpTrailSwingBars`). Giá tăng dựng đứng rồi gãy: bán, ngược lại.
- Đã thêm vào đợt xếp hạng (`XH-DaoRoi-H1`, nay là 15 chiến lược).

**Nhồi lệnh khi thắng – 4 quy tắc** (bộ `18-Nhoi-khi-thang-kim-tu-thap-H4-THU-NGHIEM`):
1. Lớp đầu có lời và SL về hòa vốn mới được thêm lớp (có từ trước: bot dời SL lớp cũ về hòa vốn, đọc lại, chưa được thì không nhồi).
2. `InpPyramidRetest` (viết lại): chỉ thêm khi giá đã đóng cửa trên đỉnh cũ (cao nhất nến 6–25), rồi nến vừa đóng hồi về chạm vùng
   vừa phá (trong 0,3 ATR), vẫn đóng cửa trên và là nến tăng. Không mua đuổi cây nến đang tăng.
3. Kim tự tháp: `InpPyramidLotFactor = 0.5` → 1 phần, 1/2, 1/4 (có từ trước, không bao giờ làm tròn lên).
4. `InpPyramidSLBars`: mỗi lần thêm, SL chung dời lên dưới đáy mới nhất. Tổng rủi ro mở không vượt 1 lệnh chuẩn (có từ trước, CalcLots).
- Biết lúc dừng: `InpPyramidStopPct` – giá đã đi x% quãng đường từ lớp đầu tới mục tiêu lớn (TP lớp đầu, hoặc mức `PX_`) thì ngừng
  thêm lớp, chuyển sang chốt từng phần. Bot không có chế độ nhồi khi đang lỗ (trung bình giá) và sẽ không có.

## v5.20: Order block – 5 kiểu phản ứng (chiến lược 15, 16/11/2026) – CHƯA KIỂM THỬ
Quy tắc chung: chạm order block chưa phải tín hiệu, cách giá phản ứng tại đó mới là tín hiệu (`InpStrategy = 15`,
bộ `19-Order-block-5-phan-ung-H1-THU-NGHIEM`).
- Order block tăng = nến giảm cuối cùng ngay trước cú đẩy lên (trong 3 nến, giá đóng cửa cao hơn đỉnh nến đó ≥ `InpOBImpulseATR` ATR).
  Vùng = đỉnh..đáy nến đó, rộng ≤ `InpOBMaxATR` ATR. Tìm trong `InpOBLookback` nến, lấy vùng gần nhất giá đang về. Mỗi vùng vào 1 lần.
- Kiểu 1 – chạm mép trên rồi bật mạnh: **không đuổi**, chờ nhịp hồi sau.
- Kiểu 2 – vào tới giữa vùng rồi nến tăng đóng cửa trên giữa vùng: **Buy**, SL dưới đáy vùng − 0,25 ATR (phản ứng chuẩn nhất).
- Kiểu 3 – râu quét thủng đáy rồi nến tăng đóng cửa quay lại: **Buy**, SL dưới đáy râu − 0,1 ATR (thường mạnh nhất).
- Kiểu 4 – lình xình trong vùng ≥ `InpOBStallBars` nến: **đứng ngoài**.
- Kiểu 5 – nến đóng cửa thủng hẳn đáy vùng: **đứng ngoài**. `InpOBBreaker`: giá hồi lên lại, chạm đáy vùng và nến giảm đóng cửa dưới
  → **Sell** (vùng thành kháng cự), SL trên nến đó + 0,25 ATR.
- TP: đỉnh con sóng sau cú đẩy nếu xa hơn 1R, không thì theo `InpRR`. Order block giảm: làm ngược lại.
- Đã thêm vào đợt xếp hạng (`XH-OrderBlock-H1`, nay là 16 chiến lược).

## v5.21: 6 kiểu phá vỡ giả – phá vỡ thật phải đủ 3 điều (16/11/2026) – CHƯA KIỂM THỬ
Áp dụng cho Donchian (chiến lược 1, cấu hình mặc định). Bộ `20-Pha-vo-that-du-3-dieu-H4-THU-NGHIEM`.
| Kiểu phá vỡ giả | Bot tránh bằng |
|---|---|
| 1. Phá bằng râu | Có sẵn: Donchian chỉ tính giá đóng cửa, không tính râu |
| 2. Đóng cửa qua rồi quay vào | Có sẵn `InpBreakConfirm`; mới `InpFakeoutFade`: đánh chiều ngược lại, SL ngoài 2 nến |
| 3. Không có volume | Có sẵn `InpBreakMinVol` (số tick, Exness không có khối lượng thật) |
| 4. Lúc ra tin | Có sẵn `InpAvoidUSNews` (± `InpNewsHours` giờ quanh tin Mỹ, mọi chiến lược) |
| 5. Đầu phiên | Mới `InpBreakSkipOpenMin`: bỏ phá vỡ trong x phút đầu phiên 0 / 7 / 13 giờ UTC |
| 6. Phá rồi không giữ được | Mới `InpBreakRetest`: chờ test lại mép kênh (≤ `InpBreakRetestATR` ATR, ≤ `InpBreakRetestBars` nến) và đóng cửa vẫn ngoài kênh; đóng cửa quay vào trước đó = bỏ |
Phá vỡ thật = thân nến đóng cửa hẳn ngoài vùng (`InpBreakMinBody`) + volume tăng mạnh (`InpBreakMinVol`) + test lại giữ được
(`InpBreakRetest`). Đánh đổi: vào khi test lại sẽ bỏ lỡ các cú phá chạy thẳng không hồi; cấu hình C đã kiểm thử không có các lọc này.

## v5.22: FVG – chờ nến xác nhận (16/11/2026) – CHƯA KIỂM THỬ
Chạm FVG mới chỉ là đến đúng chỗ; cây nến xuất hiện ở đó mới cho biết có nên vào hay không. `InpFvgCandle = true` (chiến lược 5,
bộ `21-FVG-nen-xac-nhan-H1-THU-NGHIEM`, xếp hạng `XH-FVGNen-H1`):
| FVG tăng – mua | FVG giảm – bán | Vào khi |
|---|---|---|
| Nhấn chìm tăng (mạnh nhất) | Nhấn chìm giảm | Nến nuốt trọn thân nến trước đóng cửa |
| Sao mai | Sao hôm | Nến thứ 3 đóng cửa qua giữa thân nến đầu (nến đầu ≥ 0,5 ATR, nến giữa ≤ 30% thân nến đầu) |
| Nến búa | Nến râu trên dài | Râu ≥ 2 lần thân và ≥ 1/2 biên độ, đóng cửa ở 40% phía đầu nến |
| Harami tăng | Harami giảm | Tín hiệu yếu: chờ thêm 1 nến cùng chiều đóng cửa vượt đỉnh (đáy) nến harami |
| Ba lính trắng | Ba con quạ đen | Giá đã chạy xa: chỉ vào ở nến hồi nhẹ (lùi ≥ 1/4 quãng 3 nến, vẫn ngoài vùng) |
- Ít nhất một nến của mẫu phải chạm vào FVG. Lần về đầu tiên: không nến nào cũ hơn 6 nến chạm vùng trước đó.
- Không có nến xác nhận thì không vào. Có nến đóng cửa thủng hẳn qua FVG (dưới đáy FVG tăng / trên đỉnh FVG giảm): vùng hỏng, bỏ.
- SL dưới đáy mẫu nến hoặc đáy FVG (lấy mức thấp hơn) − 0,25 ATR, tối thiểu 0,5 ATR.

## v5.23: Lý thuyết Dow – thủy triều, giai đoạn, volume, cấu trúc (16/11/2026) – CHƯA KIỂM THỬ
SMC, Wyckoff, BOS, CHOCH đều mọc ra từ lý thuyết Dow (`TrendBot/Dow.mqh`):
1. 3 xu hướng cùng lúc: thủy triều (chính, khung `InpDowTF`, mặc định D1), con sóng (phụ, khung chính), gợn sóng (bỏ qua bằng
   `InpDowPivot`: đỉnh / đáy phải cao / thấp nhất trong ± N nến).
2. 3 giai đoạn: bot đếm số lần phá đỉnh (BOS) từ khi đổi chiều; từ lần `InpDowLateLegs` = giai đoạn cuối, không vào lệnh mới.
3. Volume xác nhận (`InpDowVolume`): khối lượng TB nến cùng chiều thủy triều ≥ nến ngược chiều (20 nến khung Dow, số tick).
4. Xu hướng còn đó cho tới khi giá **đóng cửa** thủng đáy gần nhất **và** tạo đỉnh thấp hơn (hoặc đóng cửa thủng lần nữa)
   – nền móng của CHOCH. Đóng cửa qua đỉnh gần nhất trong xu hướng tăng = BOS.
- **Bộ lọc Dow** (`InpDowFilter`, mọi chiến lược): chỉ mua khi thủy triều tăng, chỉ bán khi giảm. Cột báo cáo `ChanDow`.
- **Chiến lược 16 – Thủy triều + con sóng** (bộ `22-Dow-thuy-trieu-con-song-H4-THU-NGHIEM`, xếp hạng `XH-Dow-H4`):
  thủy triều D1 tăng, con sóng H4 đang giảm, nến H4 đóng cửa vượt đỉnh gần nhất của con sóng → Buy; SL dưới đáy con sóng − 0,25 ATR.

## v5.24: VWAP trong ngày + 3 cặp dải (chiến lược 17, 16/11/2026) – CHƯA KIỂM THỬ
Đường giữa cho biết phe nào đang thắng; các đường bao quanh cho biết giá đã chạy quá xa hay chưa (bộ `23-VWAP-3-cap-dai-M15-THU-NGHIEM`,
xếp hạng `XH-VWAP-M15`).
- VWAP = Σ(giá điển hình × khối lượng) / Σ khối lượng từ 0 giờ server (UTC) – giá vốn trung bình của thị trường hôm nay. Khối lượng là
  số tick Exness. Dải = VWAP ± k × độ lệch chuẩn có trọng số khối lượng (`InpVwapBand1/2/3` = 1 / 2 / 3).
- Cách 1 – theo xu hướng (`InpVwapMode` 0 hoặc 1): nến trước đóng cửa trên VWAP, nến vừa đóng chạm VWAP (± 0,1 ATR) rồi là nến tăng
  đóng cửa trên VWAP → Buy, SL dưới nến đó − 0,1 ATR, TP = đường +2. Dưới VWAP: ngược lại.
- Cách 2 – bắt nhịp kéo về (`InpVwapMode` 0 hoặc 2): nến chạm đường +3, là nến giảm có râu trên ≥ 40% biên độ và đóng cửa lại dưới
  đường +3 → Sell, SL trên râu, TP = VWAP. Ngày xu hướng mạnh giá bám đường xa rất lâu: không bao giờ bán chỉ vì chạm.
- Bỏ lệnh nếu lời tới mục tiêu < `InpVwapMinRR` × SL. Cần ≥ 4 nến trong ngày mới tính.

## v5.25: Vùng Key Volume (chiến lược 18, 16/11/2026) – CHƯA KIỂM THỬ
Đừng đoán giá dừng ở đâu, hãy tìm nơi thị trường đã để lại nhiều tiền nhất (bộ `24-Vung-Key-Volume-H1-THU-NGHIEM`, xếp hạng `XH-KeyVol-H1`).
- Volume Profile `InpKVLookback` nến, `InpKVBins` ô giá; số tick của mỗi nến rải đều lên các ô nến đó đi qua. Các ô ≥ `InpKVHighMult` ×
  trung bình liền nhau = 1 vùng (rộng hơn `InpKVMaxATR` ATR thì giữ phần quanh ô lớn nhất).
- Vùng hợp lệ khi đủ 3 dấu hiệu: (1) ≥ `InpKVMinBars` nến đóng cửa trong vùng và có nến đóng cửa cách vùng ≥ 2 ATR (đi ngang rồi chạy
  mạnh ra); (2) volume cao (bước trên); (3) đã quay về phản ứng ≥ `InpKVMinReact` lần (từ xa ≥ 1 ATR về chạm, rồi rời ≥ 1 ATR trong 5 nến).
- Đổi vai: nến trước đóng cửa trên vùng → hỗ trợ; dưới → kháng cự. Nến vừa đóng chạm vùng và phản ứng rõ (đóng cửa lại ngoài vùng cùng
  chiều, râu ≥ 40% biên độ hoặc vượt đỉnh / đáy nến trước) → vào lệnh, SL bên kia vùng − 0,25 ATR.

## v5.26: 3 câu hỏi – nhìn ít mà rõ (chiến lược 19, 16/11/2026) – CHƯA KIỂM THỬ
Không phải biết quá ít, mà là nhìn quá nhiều (bộ `25-Ba-cau-hoi-don-gian-H4-THU-NGHIEM`, xếp hạng `XH-3CauHoi-H4`):
1. Đang là mùa gì? Cấu trúc đỉnh / đáy khung chính (cùng thuật toán với Dow, `InpDowPivot`). Đang cảnh báo đổi chiều hoặc chưa rõ = đứng ngoài.
2. Cá tụ ở đâu? `InpSimpleLevels` đường ngang ở chỗ giá từng quay đầu rõ nhất: đỉnh / đáy ± `InpSimplePivot` nến trong
   `InpSimpleLookback` nến, gộp những chỗ cách nhau < 0,5 ATR, xếp theo tổng độ dài cú quay đầu. Giá ở giữa các đường: không làm gì.
3. Phao đã động chưa? Nến trước ở phía trên đường, nến vừa đóng chạm đường (± 0,25 ATR) và là nến tăng mạnh (thân ≥ 60% biên độ)
   đóng cửa trên đường → Buy, SL dưới đường / đáy nến − 0,25 ATR. Mùa giảm: ngược lại.

**Ghi chú thẳng thắn về chính bot này:** từ 15/11 tới nay bot đã có thêm 11 chiến lược và rất nhiều bộ lọc, tất cả chưa kiểm thử.
Đó đúng là cái bẫy bài này nói: bật hết lên thì mỗi cái nói một kiểu. Cách dùng đúng: chạy xếp hạng, chọn **một** chiến lược đứng đầu
(cộng tối đa **một** bộ lọc hỗ trợ), chạy demo đủ lâu cho thật thành thạo, rồi mới tính cái khác. Đừng bật nhiều bộ lọc cùng lúc
chỉ vì chúng có sẵn – mỗi bộ lọc thêm vào là một lần "chọn cái nói đúng điều mình muốn nghe" trong backtest.

## v5.27: Ngày có tin lớn – hỏi cú quét xong chưa (16/11/2026) – CHƯA KIỂM THỬ
Kịch bản: cả ngày đi ngang sát đỉnh / đáy (người lớn đứng ngoài chờ), lệnh chờ và dừng lỗ dồn về 2 đầu; tin ra, sổ lệnh mỏng, giá vọt
quét một đầu rồi quay đầu đi theo hướng thật. Tin mạnh nhất: CPI (19:30 / 20:30 giờ VN), Fed (1–2 giờ sáng), NFP (tối thứ Sáu đầu tháng).
1. `InpNewsWeekly`: sáng thứ Hai bot gửi lịch tin Mỹ quan trọng 7 ngày tới (giờ VN). Chỉ chạy thật (lịch kinh tế MT5).
2. `InpNewsPreMin` (vd. 30): trước giờ tin x phút không mở lệnh mới, không nhồi (mọi chiến lược trừ 20). `InpNewsProtect`: lệnh đang lời
   → 1 = SL về hòa vốn, 2 = chốt một nửa + hòa vốn (mỗi lệnh 1 lần, lệnh đang lỗ giữ SL). Cột báo cáo `BaoVeTruocTin`.
3. **Chiến lược 20 – Quét rồi mới đi** (bộ `26-Quet-tin-lon-M15-THU-NGHIEM`, xếp hạng `XH-QuetTin-M15`): vùng = đỉnh / đáy
   `InpNewsRangeMin` phút trước tin (cao ≤ `InpNewsRangeMaxATR` ATR). Cú quét = nến đầu tiên sau tin vượt ra ngoài vùng. Không đu cây nến tin:
   chờ hết lập cực trị mới, nến đóng cửa lại trong vùng, ngược chiều cú quét, thủng đáy (đỉnh) cây nến tạo cực trị → vào, SL ngoài cực trị.
- NFP: chạy thật lấy từ lịch kinh tế MT5. Backtest: `du-lieu/tin_my_nfp.csv` (2020–2026, thứ Sáu đầu tháng 8:30 New York, ƯỚC LƯỢNG theo
  quy tắc, chưa đối chiếu BLS) chỉ nạp khi bật `InpNewsNFP`. `tin_my.csv` giữ nguyên CPI / FOMC đã kiểm chứng để cấu hình C so sánh được.
- Lịch tin cho backtest nay được nạp khi dùng bất kỳ tính năng nào cần giờ tin (trước đây chỉ khi bật tránh tin – khóa lời trước tin
  trong backtest đã không có dữ liệu).

## v5.28: 4 kỹ thuật đánh – phương pháp cho biết vào ở đâu, kỹ thuật quyết định mang về bao nhiêu (16/11/2026) – CHƯA KIỂM THỬ
Bộ `27-Bon-ky-thuat-danh-H4-THU-NGHIEM` ghép đủ 4 kỹ thuật trên Donchian H4:
1. **Giải vốn** (mới, `InpScaleParts` 2–3): phần đầu vào ngay với 1/n rủi ro; phần sau là lệnh chờ Limit sâu hơn `InpScaleStepATR` ATR mỗi
   nấc, chung SL và TP, khối lượng tính để mỗi phần cũng 1/n rủi ro → tổng rủi ro vẫn đúng `InpRiskPercent`. Kế hoạch cố định lúc vào lệnh,
   không phải nhồi khi lỗ. Hủy phần chưa khớp sau `InpScaleBars` nến hoặc khi lệnh đầu đã đóng. Báo cáo cộng rủi ro các phần vào 1R của đợt.
2. **Hòa vốn không quá sớm**: có sẵn `InpBreakevenR` (mặc định 1R); mới `InpBESwingBars`: hoặc khi nến đóng cửa vượt đỉnh gần nhất trước lệnh.
3. **Rời SL theo giá**: có sẵn từ v5.19 (`InpTrailSwingBars`, dưới mỗi đáy mới cao hơn).
4. **Chốt từng phần**: có sẵn (`InpUsePartial`, `InpPartialR`, `InpPartialPct`).
Lưu ý: mỗi phần giải vốn là một lệnh riêng nên 1R (để hòa vốn / chốt phần) của phần sau tính theo khoảng cách tới SL chung, nhỏ hơn phần đầu.

## v5.29: Wyckoff Spring đầy đủ – giá có quay lại không? (16/11/2026) – CHƯA KIỂM THỬ
Chiến lược 6 trước đây vào ngay ở cây nến spring (thủng đáy rồi đóng cửa lại trong vùng). `InpSpringFull = true` chờ đủ chuỗi
(bộ `28-Wyckoff-Spring-day-du-H1-THU-NGHIEM`, xếp hạng `XH-SpringDu-H1`):
1. Cú giảm mạnh (≥ `InpSpringDropATR` ATR từ đỉnh 40 nến trước hộp) rồi hộp đi ngang `InpRangeBars` nến (≤ `InpRangeMaxATR` ATR, chạm đỉnh / đáy ≥ 2 lần).
2. Spring: thủng đáy hộp ≤ `InpSpringDepthATR` ATR và đóng cửa quay lại trong hộp trong 3 nến. Thủng rồi nằm luôn bên dưới = không phải spring.
3. Test: về gần đáy (≤ 0,5 ATR) với nến nhỏ (≤ 70% biên độ TB trong hộp) và volume thấp (< TB hộp), không thủng đáy spring.
4. Nến tăng mạnh (thân ≥ 60%) đóng cửa trên nắp hộp; lần đầu giá hồi về chạm nắp (≤ 0,3 ATR) mà vẫn đóng cửa trên → Buy.
5. SL dưới đáy spring − 0,25 ATR; TP ở nơi cú giảm bắt đầu (nếu ≥ 1R, không thì `InpRR`). Upthrust ở đỉnh: ngược lại.

## v5.30: Premium / discount – khung ngày cho biết đắt hay rẻ, H4 cho biết khi nào ra tay (chiến lược 21, 16/11/2026) – CHƯA KIỂM THỬ
Bộ `29-Premium-Discount-D1-H4-THU-NGHIEM`, xếp hạng `XH-PremDisc-H4`:
- Hộp = cao nhất / thấp nhất `InpPDDays` nến D1 (60 ≈ 2 tháng). Nửa dưới discount (chỉ mua), nửa trên premium (chỉ bán). Giá vào lệnh
  phải còn ở đúng nửa; quanh đường giữa thì không có lợi thế.
- Khung chính (H4), trong `InpPDLookback` nến: (1) cú quét – nến thủng đáy gần nhất (pivot ± 2 nến, trong vùng rẻ) rồi đóng cửa lại trên
  đáy đó trong 2 nến; (2) xác nhận – nến đóng cửa vượt đỉnh gần nhất trước cú quét, chưa có đáy thấp hơn; (3) FVG tăng trong cú bật, lần
  đầu giá hồi về + nến tăng đóng cửa trên đáy FVG → Buy.
- SL dưới đáy cú quét − 0,25 ATR. Chốt `InpPartialPct` % ở đường giữa (mức chốt theo giá), phần còn lại TP ở cạnh trên hộp. Bỏ nếu < 1R.
  Mỗi cú quét chỉ vào 1 lần. Premium: ngược lại.

## v5.31: Chuỗi phân tích – lồng ghép các chiến lược trên 1 khung (chiến lược 22, 16/11/2026) – CHƯA KIỂM THỬ
Một chart, một khung (bộ `30-Chuoi-phan-tich-H1-THU-NGHIEM`, xếp hạng `XH-Chuoi-H1`). Mỗi nến mới chạy đúng thứ tự:
| Bước | Câu hỏi | Lấy từ | Không đạt thì |
|---|---|---|---|
| B1 Thủy triều | Mùa gì, giai đoạn nào? | Dow khung `InpDowTF` (v5.23) | chưa rõ / giai đoạn cuối → đứng ngoài |
| B2 Vị trí | Giá rẻ hay đắt? | Hộp D1 premium / discount (v5.30), `InpChainPD` | sai nửa hộp → đứng ngoài |
| B3 Setup | Phao đã động chưa? | Các chiến lược trong `InpChainList` soi cùng nến vừa đóng | không có setup cùng chiều, hoặc có setup ngược chiều → đứng ngoài |
| B4 Bộ lọc | Đúng giờ, không có tin, spread ổn? | Bộ lọc chung (giờ, tin, spread, khối lượng...) | bỏ lệnh |
| B5 Khối lượng | Bao nhiêu công cụ đồng ý? | 1 setup = `InpChainOneRisk` × rủi ro; ≥ `InpChainFullCount` = đủ | – |
- Trong chuỗi, FVG luôn chờ nến xác nhận, Spring luôn chờ đủ chuỗi, Donchian luôn chờ test lại (bản an toàn của từng chiến lược).
- Không đưa vào chuỗi: lưới (13), quét tin (20), các chiến lược cần chỉ báo riêng hoặc phiên riêng (2, 3, 4, 7, 8, 10).
- SL / TP / mức chốt theo giá lấy từ setup đứng trước trong `InpChainList`. Nhật ký in ra từng bước, ví dụ
  `B1 thuy trieu TANG (lan pha 2) | B2 vung re | B3 2 setup: Order block + Key Volume | B5 rui ro x1.00`.
- Cột báo cáo `Chuoi_TinHieu_TraiChieu` = số lần vào lệnh / số lần đứng ngoài vì setup trái chiều.
- Đây là CÁCH LỒNG GHÉP, không phải bằng chứng có lợi thế: từng thành phần đều chưa kiểm thử. Xếp hạng sẽ cho biết chuỗi có hơn
  từng chiến lược riêng lẻ và hơn cấu hình C hay không.

## v5.32: Giao diện – "Quyết định của bot" và "Nhật ký quá trình" (16/11/2026)
Tab **Điều khiển** có thêm 2 khung (cần mở lại `GiaoDien.cmd` sau khi cập nhật, và bot bản 5.32 trở lên đang chạy thật / demo):
- **Quyết định của bot**: mỗi chart một thẻ – tài khoản, mã, chiến lược, quyết định hiện tại. Với chuỗi phân tích (chiến lược 22), hiện từng
  bước ✓ / ✕ (B1 thủy triều → B2 vị trí → B3 setup → B5 rủi ro) để thấy bot dừng ở bước nào. Dưới cùng là lý do của lệnh gần nhất.
- **Nhật ký quá trình**: các dòng mới nhất trước, lọc theo Vào / thoát lệnh, Phân tích (mỗi lần bot đổi quyết định), Quản lý lệnh
  (sửa SL, chốt phần, khóa / mở khóa), Lỗi. Giờ theo máy tính chạy MT5.
- Bot ghi `Common\Files\TrendBot_quyetdinh_<chart>.txt` (200 dòng gần nhất, mỗi 10 giây); giao diện đọc 150 dòng cuối. Backtest không ghi.

## v5.33: Bằng chứng của mỗi quyết định (16/11/2026)
Mỗi nến mới bot gom các **con số cụ thể** dẫn tới quyết định (`g_ev`, ngăn bằng " ; "), ghi vào file trạng thái (`bangchung=`) và vào nhật ký
sau dấu " || ". Giao diện: thẻ "Quyết định của bot" có mục **Dựa trên bằng chứng nào** (mở sẵn) và **Bằng chứng lúc vào lệnh**; mỗi dòng
nhật ký có nút mở bằng chứng. Nội dung:
- Bộ lọc chung khi đã có tín hiệu gốc: ADX so với ngưỡng, giá khung lớn so với EMA (hoặc MACD), mẫu nến, đa khung. Tín hiệu bị bộ lọc
  loại thì trạng thái ghi rõ "Bỏ tín hiệu MUA: ADX thấp; ngược xu hướng khung lớn;" (trước đây chỉ là "Chờ tín hiệu").
- Từng chiến lược: Donchian (đỉnh / đáy kênh, giá đóng cửa, thân nến %, khối lượng × TB), phá vỡ thật (mức đã phá, nến test lại),
  FVG (vùng, nến lớn, tên mẫu nến xác nhận), order block (vùng, kiểu phản ứng), Key Volume (vùng, số nến trong vùng, số lần phản ứng),
  3 câu hỏi (mùa, đỉnh / đáy, đường kẻ và điểm), premium / discount (hộp D1, đáy quét, đỉnh bị vượt, FVG), Spring đủ, sóng Dow, VWAP (VWAP,
  độ lệch chuẩn, các dải). Chuỗi phân tích: B1 cấu trúc D1 và số lần phá, B2 hộp D1 và giá ở nửa nào, B3 bằng chứng từng setup, B5 hệ số rủi ro.
- Lúc vào lệnh: SL cách bao xa (và bằng bao nhiêu ATR), TP, khối lượng, số tiền rủi ro và % vốn, số phần giải vốn.

## v5.34: Chế độ Tự động – 1 chart tự đổi chiến lược + MT5 riêng cho mô phỏng (16/11/2026) – THỬ NGHIỆM
Mọi chiến lược vẫn nằm chung một bot (`BTC_EMA_Pullback_v2.mq5` + `TrendBot/`); `InpStrategy` là công tắc. **`InpStrategy = 23`
(Tự động)** cho bot tự bật công tắc đó trong lúc chạy (bộ `31-Tu-dong-1-chart-THU-NGHIEM`):
- Mỗi 10 phút đọc `TrendBot_xephang.csv` (thứ hạng) và `TrendBot_xephang_cauhinh.csv` (thông số từng cấu hình, mới – nút 1 > Xếp hạng ghi).
  Lấy cấu hình đứng đầu **đủ điều kiện**, áp dụng thông số tín hiệu / quản lý lệnh của nó (chiến lược, khung, SL / TP, trailing, chốt phần,
  thông số riêng từng chiến lược), tạo lại chỉ báo, đánh từ nến tiếp theo.
- Giữ nguyên thông số bạn đặt trên chart: vốn, % rủi ro, giới hạn lỗ ngày / sụt giảm, giờ nghỉ, tránh tin, spread, bảo vệ lệnh tay.
  (Cấu hình xếp hạng tắt giới hạn sụt giảm để so công bằng – chế độ Tự động KHÔNG lấy dòng đó.)
- Chỉ đổi khi đang đứng ngoài (không lệnh, không lệnh chờ, không khóa lệnh): lệnh đang mở được quản lý trọn vẹn theo chiến lược đã mở nó.
  Magic cố định theo lúc gắn bot. Bảng thiếu / cũ hơn `InpSelectMaxAgeDays` ngày → Donchian H4 + ADX (đã kiểm thử); "KHONG" → đứng ngoài.
- Giao diện: ô chiến lược hiện `Tu dong -> <cấu hình>: <chiến lược> <khung>`; nhật ký ghi mỗi lần chuyển.
- Khác `InpAutoSelect` (v5.11, mỗi chiến lược 1 chart, chỉ bật / tắt vào lệnh theo mã `S<chiến lược>-<phút>`): mã đó trùng nhau khi cùng
  chiến lược + khung (vd. FVG và FVG + nến đều là S5-60); chế độ Tự động chọn theo TÊN cấu hình nên không bị trùng.

**MT5 riêng cho mô phỏng** (`mt5-mophong.txt`): cài thêm một bản MT5 vào thư mục khác (vd. `C:\MT5-MoPhong`), mở 1 lần, đăng nhập demo
Exness, rồi ghi đường dẫn thư mục đó vào `mt5-mophong.txt` (bỏ dấu #). Từ đó mô phỏng / xếp hạng compile và chạy trên bản này, chỉ đóng
bản này; bản MT5 đang giao dịch không bị đụng tới. Hai bản dùng chung `Common\Files`, nên bot Tự động đọc ngay bảng xếp hạng mới.

## v5.35: Theo tình huống – nhận diện thị trường rồi dùng đúng kiến thức (chiến lược 24, 16/11/2026) – CHƯA KIỂM THỬ
Mỗi nến mới bot **chẩn đoán** thị trường, rồi chỉ dùng bộ chiến lược mà các bài học dành cho tình huống đó
(bộ `32-Theo-tinh-huong-H1-THU-NGHIEM`, xếp hạng `XH-TinhHuong-H1`):
| Tình huống | Nhận ra bằng | Bộ chiến lược (bài học) |
|---|---|---|
| Sắp có tin | lịch tin, `InpSmartNewsMin` phút | đứng ngoài (ngày có tin lớn) |
| Vừa ra tin | tin < 4 giờ trước | 20 quét rồi mới đi |
| Vừa sập / tăng dựng đứng | ≥ `InpKnifeDropATR` ATR trong `InpKnifeBars` nến, cực trị trong 10 nến | 14 nhỏ – lớn – giữ |
| Xu hướng mạnh | thủy triều Dow `InpDowTF` rõ + ADX ≥ `InpSmartTrendADX` | 1 phá vỡ thật, 16 sóng Dow, 5 FVG + nến, 15 order block, 21 premium / discount – chỉ theo xu hướng |
| Giai đoạn cuối | ≥ `InpDowLateLegs` lần phá | 12 phân phối / tích lũy, 6 spring / upthrust – không đu theo |
| Đi ngang | ADX < `InpSmartRangeADX` và hộp `InpSmartRangeBars` nến ≤ `InpSmartRangeATR` ATR | 6 spring đủ, 18 Key Volume, 17 VWAP kéo về, 19 ba câu hỏi |
| Không rõ | còn lại | có thủy triều: 15, 5, 18 theo thủy triều; không: đứng ngoài |
- Thứ tự xét đúng như bảng (tin trước, rồi cú sập, rồi giai đoạn cuối, xu hướng, đi ngang).
- Setup trái chiều nhau = đứng ngoài; 1 setup = `InpChainOneRisk` × rủi ro, ≥ `InpChainFullCount` = đủ. Bản an toàn của từng chiến lược
  (FVG chờ nến, Spring chờ đủ chuỗi, phá vỡ chờ test lại).
- Giao diện: `Tinh huong: XU HUONG MANH | Dung: ... | MUA: Order block + FVG + nen | rui ro x1.00`; bằng chứng ghi rõ vì sao bot coi là
  tình huống đó (ADX, chiều cao hộp, Dow D1, biên độ cú sập).
- Khác Tự động (23): Tự động chọn theo điểm backtest (tuần một lần); Theo tình huống chọn theo trạng thái thị trường ngay lúc đó. Có thể
  để Tự động chọn chiến lược 24 nếu nó đứng đầu bảng xếp hạng.

## v5.36: Học từ thực chiến – lưu kết quả của chính bot và dùng cho quyết định sau (16/11/2026)
Áp dụng cho chế độ **Theo tình huống** (chiến lược 24), mặc định bật (`InpLearn`). Không dùng dữ liệu backtest (`TrendBot/Learn.mqh`):
- **Lệnh giấy:** mọi setup bot thấy trong mỗi tình huống (kể cả không vào lệnh vì trái chiều, bị bộ lọc chặn, hay đang có lệnh) được theo
  dõi từ giá đóng cửa nến tín hiệu: chạm SL = −1R, chạm TP của setup (không có thì 2R) = +R, quá `InpLearnMaxBars` nến = R tạm tính;
  cùng nến chạm cả hai thì tính SL. Lệnh thật quá ít để học nhanh, nên lệnh giấy là dữ liệu chính.
- **Lệnh thật:** R thực tế (sau phí, hòa vốn, chốt phần) được ghi riêng theo tình huống + chiến lược đã mở lệnh, để đối chiếu.
- **Dùng để quyết định** (mỗi cặp tình huống × chiến lược): chưa đủ `InpLearnMinN` lệnh giấy → *đang thử* (vẫn dùng kiến thức, rủi ro ×
  `InpLearnTryRisk`); R TB ≤ 0 → *loại* (không dùng trong tình huống đó, vẫn theo dõi giấy để tự phục hồi); cận dưới 90% > 0 → *tin dùng*
  (rủi ro đủ); còn lại → *chưa chắc* (rủi ro × 0,75). Bằng chứng của mỗi quyết định ghi đánh giá này.
- **Lưu:** `Common\Files\TrendBot_hoc_<tài khoản>_<mã>.csv`, đọc lại khi khởi động (tắt / bật MT5 không mất). Lệnh giấy đang mở thì mất
  khi khởi động lại. Backtest học trong bộ nhớ (không đọc / ghi file) để kiểm tra chính cơ chế học.
- **Giao diện:** khung "Bot đã học được gì từ thực chiến" – bảng tình huống × chiến lược: số lệnh giấy, R TB, % thắng, đánh giá, lệnh thật.
- Học cần thời gian: với H1, mỗi cặp cần vài tuần tới vài tháng để đủ 20 lệnh giấy. Chạy demo trước.
