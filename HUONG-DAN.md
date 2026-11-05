# Hướng dẫn bot BTC v3.1 (MT5)

> **v3.1:** `LaiTheoNam` tính cả phí lúc vào lệnh nên tổng các năm khớp với `LoiNhuan`; thêm cột `LenhDau` (ngày của lệnh đầu tiên). Với lần chạy "trước 3 năm", nếu `LenhDau` muộn hơn nhiều so với ngày bắt đầu hoặc `SoLenh` quá ít, nghĩa là MT5 thiếu dữ liệu cũ và kết quả ngoài mẫu chưa đủ để tin. Mã lỗi được xóa trước mỗi lần gửi lệnh nên thông báo lỗi đúng với lần gửi đó.

> **v3.0:** bảng kết quả có thêm cột `BoQuaLot` (số tín hiệu bị bỏ vì lot tính ra nhỏ hơn 0,01) và `LaiTheoNam` (lãi/lỗ từng năm). Lượt so sánh mới kiểm tra độ bền của Donchian H4: vốn 30.000, cặp ETHUSDm, và giai đoạn 3 năm trước đó (dữ liệu chưa dùng để chọn). Khi mở VS Code, bot chỉ compile code đang có trên máy, **không tự kéo code từ GitHub** nữa.
>
> **Quan trọng khi đổi cài đặt mặc định:** EA đang gắn trên chart vẫn giữ tham số cũ. Muốn dùng mặc định mới, gỡ EA khỏi chart rồi gắn lại, hoặc mở tab *Inputs* và bấm *Reset*.

> **v2.9:** cài đặt mặc định chuyển sang cấu hình tốt nhất của lần so sánh 3 năm (11/2026): **Donchian 20, khung H4, lọc ADX + EMA200 D1**, SL 2,5 ATR, không TP, trailing 3 ATR, không chốt một phần / hòa vốn, không nghỉ cuối tuần hay giờ tin. Kết quả backtest nhanh: +962 USD trên vốn 3.000 (+32%), PF 2,09, sụt giảm tối đa 4,6%, 86 lệnh. Con số này được chọn trên chính dữ liệu đã dùng để so sánh và mẫu dưới 100 lệnh, nên chưa đáng tin cho tới khi qua lượt kiểm tra độ bền của v3.0.

> **v2.8:** bot đối soát định kỳ để biết lệnh đã đóng hết (không phụ thuộc thứ tự sự kiện), nên cooldown và dọn trạng thái không bị sót; chốt một phần trên tài khoản Netting dùng lệnh ngược chiều; script backtest đóng MT5 rồi mới compile. **Lưu ý:** đóng MT5 để backtest sẽ dừng mọi bot đang chạy trên MT5 đó. Nếu chạy bot trên tài khoản thật, hãy backtest bằng một bản MT5 cài riêng. Lưu file `.mq5` khi đang bật "tự cập nhật" cũng làm bot trên chart nạp lại (trạng thái vẫn giữ nhờ Global Variables).

> **v2.7:** đổi `InpCapital` thì bot tự đặt lại mốc vốn, đỉnh vốn và mốc đầu ngày (không còn bị hiểu nhầm là sụt giảm rồi dừng hẳn).

> **v2.6:** lỗ ngày tính theo phần thay đổi kể từ 00:00 (lệnh giữ qua đêm không bị tính lỗ cũ); chạm lỗ ngày là khóa đến hết ngày; trạng thái gắn với POSITION_IDENTIFIER; chỉ coi lệnh khớp khi server trả DONE; rủi ro mỗi lệnh tính trên vốn của bot (sau khi nạp/rút, đặt `InpResetHalt = true` một lần). Bot thiết kế cho tài khoản **Hedging** (Exness mặc định); tài khoản Netting sẽ có cảnh báo.
>
> **v2.5:** chờ đăng nhập xong mới khởi tạo trạng thái; thêm `InpCapital` (vốn dành cho bot); thông báo lỗi bị gộp, tối đa 1 lần / 5 phút mỗi loại.
>
> **v2.4:** giới hạn lỗ ngày và sụt giảm chỉ tính **lãi/lỗ đã đóng + phần lỗ đang chạy của chính bot** (lệnh đang lãi trả bớt lãi không bị tính là lỗ) (theo magic + symbol), nên không bị lệch khi nạp/rút tiền hoặc khi chạy EA khác. Chạm lỗ ngày thì có thể đóng luôn lệnh đang mở (`InpCloseOnDailyLoss`). Mức hòa vốn đã cộng phí + swap + buffer theo R (`InpBEBufferR`). Trạng thái được lưu theo tài khoản + symbol + magic và giữ lại khi khởi động lại.

> v2.2 có 2 chiến lược, chọn bằng `InpStrategy`:
> - **EMA pullback** (mặc định): vào lệnh khi giá hồi về EMA20 theo xu hướng.
> - **Donchian breakout**: vào lệnh khi giá phá đỉnh/đáy của N nến gần nhất (`InpDonchianPeriod`), SL rộng, không đặt TP, thoát bằng trailing ATR. Đặt `InpRR = 0` để bỏ TP.

## Dùng hằng ngày với VS Code (khuyên dùng)
Mở thư mục bot bằng VS Code. Không cần bấm Sync: mỗi nút dưới đây **tự lấy code mới nhất từ GitHub** rồi mới chạy. Khi mở VS Code, code đang có trên máy được compile vào MT5 (không tự kéo code mới). Các nút nằm ở **Terminal → Run Task…**:

| Nút | Khi nào dùng |
|---|---|
| **1. So sanh cau hinh (nhanh)** | Việc chính lúc này. Chạy 9 cấu hình trên 3 năm, xong tạo file `ket-qua-backtest-....zip`. **Gửi file zip này cho Claude.** |
| **2. Cap nhat bot vao MT5** (Ctrl+Shift+B) | Khi bot đang chạy trên chart và muốn nạp bản mới ngay. |

**Khi chuyển sang tiền thật:** mọi nút ở trên đều kéo code mới từ GitHub và compile thẳng vào MT5, nên bot trên chart sẽ nạp code bạn chưa kịp xem. Hãy chạy bot thật trên **một bản MT5 cài riêng** (không dùng để backtest), và chỉ cập nhật bản đó bằng tay khi đã đọc thay đổi. Muốn tắt hẳn việc tự compile khi mở VS Code, xóa khối `"runOptions"` trong `.vscode/tasks.json`.
| **3. So sanh cau hinh (chinh xac, cham)** | Chỉ khi Claude bảo, để kiểm tra lại cấu hình tốt nhất bằng tick thật. |

Muốn thử cấu hình khác, sửa danh sách `$Runs` ở đầu file `ChayThuNghiem.ps1`.

---


> Bot chỉ để thử nghiệm. Không có gì đảm bảo có lãi. Luôn backtest rồi chạy demo trước khi dùng tiền thật.

File bot: `BTC_EMA_Pullback_v2.mq5`.

## Bot làm gì (cài đặt mặc định)

**Vào lệnh (khung H4, chiến lược Donchian breakout):** nến H4 vừa đóng cửa vượt lên trên đỉnh cao nhất của 20 nến trước đó thì Buy, xuống dưới đáy thấp nhất thì Sell. Lệnh phải qua thêm các bộ lọc:
- **Xu hướng:** giá ở đúng phía EMA200 H4, và giá đóng cửa D1 ở đúng phía EMA200 D1.
- **ADX ≥ 20:** bỏ qua khi thị trường đi ngang.

**SL / TP / lot:** SL = 2,5 × ATR, **không đặt TP**. Lot tự tính để mỗi lệnh chỉ rủi ro 1% vốn. Nếu lot tính ra nhỏ hơn 0,01 thì bot **bỏ qua tín hiệu** chứ không vào lệnh vượt rủi ro, nên với vốn nhỏ bot có thể vào ít lệnh hơn (xem cột `BoQuaLot`).

**Quản lý lệnh đang mở:** trailing stop cách 3 × ATR, bật ngay từ đầu, chỉ dời theo hướng có lợi. Lệnh thoát khi chạm SL hoặc trailing. Chốt một phần và hòa vốn mặc định tắt (bật lại bằng `InpUsePartial`, `InpUseBreakeven`).

**Bộ lọc thời gian:** mặc định tắt (BTC giao dịch 24/7). Có thể bật nghỉ cuối tuần (`InpSkipWeekend`) và hai khung giờ tin (`InpBlock1Start`, `InpBlock2Start`).

Chiến lược cũ (EMA pullback H1) vẫn còn: đặt `InpStrategy = STRAT_EMA_PULLBACK`.

**Bảo vệ tài khoản:**
- Lỗ 3% trong ngày thì ngừng vào lệnh tới hôm sau.
- Sụt giảm 15% so với đỉnh vốn thì **dừng hẳn** và đóng hết lệnh. Muốn chạy lại, đặt `InpResetHalt = true` một lần rồi đổi về `false`.

**Thông báo:** báo khi bot khởi động, vào lệnh, thoát lệnh (kèm lãi/lỗ), gặp lỗi, chạm giới hạn lỗ.

**Bảng thông tin** ở góc biểu đồ: trạng thái bot, equity, lãi/lỗ hôm nay, số lệnh, mức sụt giảm, spread.

## Cài đặt
1. MT5 (tài khoản **demo** Exness) → *File → Open Data Folder* → `MQL5/Experts` → chép file `.mq5` vào.
2. Mở MetaEditor (F4), mở file và nhấn **Compile** (F7). Nếu báo lỗi, chụp màn hình gửi lại.
3. Mở biểu đồ BTCUSD (tài khoản Standard có thể tên `BTCUSDm`), kéo EA vào, bật **Algo Trading**.
4. Treo trên VPS để bot chạy 24/7.

## Bật thông báo
**Push về app MT5 (dễ nhất):**
1. Cài app MetaTrader 5 trên điện thoại → *Settings → Messages* → chép **MetaQuotes ID**.
2. Trên máy tính: *Tools → Options → Notifications* → tích *Enable Push Notifications*, dán ID → bấm *Test*.

**Telegram (tùy chọn):**
1. Chat với `@BotFather` → `/newbot` → lấy **token**.
2. Nhắn một tin bất kỳ cho bot vừa tạo, rồi mở `https://api.telegram.org/bot<TOKEN>/getUpdates` để lấy **chat id**.
3. MT5: *Tools → Options → Expert Advisors* → tích *Allow WebRequest for listed URL* → thêm `https://api.telegram.org`.
4. Trong cài đặt EA: `InpTelegram = true`, điền `InpTgToken` và `InpTgChatId`.

Bot không gửi thông báo khi đang backtest.

## Giờ server
Các khung giờ nghỉ tính theo **giờ server** (cột thời gian trong Market Watch). Server Exness thường là GMT+0, tức chậm 7 tiếng so với giờ Việt Nam. Ví dụ tin CPI Mỹ ra lúc 19:30 giờ Việt Nam (mùa hè) là 12:30 giờ server. Hãy kiểm tra lại giờ server của bạn và chỉnh `InpBlock1Start/End`, `InpBlock2Start/End` cho phù hợp. Đặt giá trị `-1` để tắt.

## Backtest và so sánh
- *View → Strategy Tester* → EA v2, BTCUSD, H1, chế độ **Every tick based on real ticks**, kiểm tra 1–2 năm dữ liệu.
- **Bật/tắt từng bộ lọc** (`InpUseHTF`, `InpUseADX`, `InpUseCandle`, `InpUsePartial`, `InpUseTrailing`…) để xem bộ lọc nào thật sự giúp ích. Đừng bật hết chỉ vì nghe hay: quá nhiều bộ lọc có thể làm số lệnh còn rất ít.
- Các chỉ số cần xem: số lệnh (≥100), Profit Factor, Max Drawdown, chuỗi thua dài nhất.

## Lưu ý
- Các mốc lỗ ngày/sụt giảm tính trên "vốn của bot" = balance lúc bắt đầu theo dõi + lãi/lỗ của bot. Muốn đặt lại mốc (ví dụ sau khi đổi số vốn), đặt `InpResetHalt = true` một lần.
- BTC có thể trượt giá qua SL khi có tin. Swap crypto qua đêm có thể cao.
- Nên xem lại kết quả mỗi tuần, dù đã có thông báo.

## Giới hạn vào lệnh (mới ở v2.1)
- `InpAllowBuy` / `InpAllowSell`: bật/tắt từng chiều.
- `InpMaxTradesPerDay`: số lệnh tối đa mỗi ngày (0 = tắt).
- `InpCooldownBars`: nghỉ N nến sau một lệnh thua (0 = tắt).

## Nâng cấp bot khi đang có lệnh mở
Nên cập nhật bot khi **không có lệnh mở**. Nếu buộc phải cập nhật lúc có lệnh, bot sẽ cố nhận lại trạng thái cũ; nếu không được và SL đã ở mức hòa vốn, bot ước lượng 1R = ATR × `InpATRMult` và bỏ qua bước chốt một phần cho lệnh đó.
