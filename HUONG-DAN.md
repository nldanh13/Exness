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

**Dọn file:** mỗi lần chạy, sau khi đóng gói xong, script xóa báo cáo HTML/PNG của MT5 (đã nằm trong zip) và chỉ giữ file zip mới nhất trong thư mục bot. Thư mục `ket-qua/` chỉ giữ lần chạy mới nhất của mỗi chế độ (`nhanh`, `chinhxac`); file cũ bị xóa trong cùng commit đẩy kết quả mới, nên vẫn xem lại được trong lịch sử git.

**Khi đang backtest:**
- Script sẽ hỏi đóng MT5. Đóng MT5 là **dừng mọi bot đang chạy trên MT5 đó**.
- Tắt terminal VS Code hay tắt máy giữa chừng thì lượt chạy dừng và không có file zip. Không hỏng gì cả, chỉ cần chạy lại. Dữ liệu giá đã tải vẫn được giữ.

## Giao diện trên trình duyệt (không cần VS Code)
Bấm đúp **`GiaoDien.cmd`** trong thư mục bot. Trình duyệt mở `http://localhost:8765` với hai trang:

- **Bảng điều khiển**:
  - *Tình trạng hiện tại* nói bằng một câu: MT5 đang mở hay tắt, bot đang chạy tài khoản **thật hay demo**, bot đang **giữ bao nhiêu lệnh**, có phiên bản bot mới không. Bot từ v5.4 mới báo được tài khoản và số lệnh (ghi file `TrendBot_trangthai_*.txt` trong Common\Files mỗi 10 giây, không ghi số tài khoản).
  - *Chiến lược đã vượt qua kiểm thử chưa?* tóm tắt lần thử mới nhất: mấy chiến lược đạt, chiến lược nào chắc chắn nhất, bước tiếp theo.
  - *Bạn muốn làm gì?*: Thử các chiến lược (nút 1), Kiểm tra kỹ (nút 3), Xem kết quả, Cập nhật phiên bản bot (nút 2), Gửi nhật ký tài khoản (nút 4), Tự thử 1 lần trong MT5. Các câu hỏi y/n trước đây thành ô tích. Nếu tài khoản thật đang có lệnh mở, giao diện cảnh báo trước khi đóng MT5.
- **Kết quả thử nghiệm**: mỗi chiến lược có kết luận *Đạt tiêu chí kiểm thử*, *Kết quả chưa đạt yêu cầu*, hoặc *Chưa đủ dữ liệu để kết luận*. Bấm một dòng để xem giải thích bằng lời, tiền lời cộng dồn, lời/lỗ theo năm và theo giờ. Bấm "Chỉ số kỹ thuật" để hiện PF, Recovery, t-stat…

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

**Chọn chiến thuật khi gắn bot lên chart:** mỗi lần compile, các file cài đặt sẵn trong `cai-dat/` được chép vào MT5. Khi gắn bot, mở tab *Inputs*, bấm **Load** và chọn một file:
- `1-Donchian-H4-khuyen-dung.set`: chiến lược chính (đã qua kiểm thử).
- `2-Donchian-M30-khoiLuong.set`, `3-RSI-M15.set`, `4-ORB-M5-phien-My.set`: lướt sóng, **chưa đạt** kiểm thử, chỉ chạy demo.
Vốn 1 triệu VNĐ: sau khi Load, đặt thêm `InpMaxRiskRoundUp = 5`. Mỗi chiến thuật tự có Magic riêng, nên gắn nhiều chiến thuật trên cùng `BTCUSDm` (mỗi cái một chart) không lẫn lệnh.

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
