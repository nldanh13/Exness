# Hướng dẫn bot BTC v2.2 (MT5)

> v2.2 có 2 chiến lược, chọn bằng `InpStrategy`:
> - **EMA pullback** (mặc định): vào lệnh khi giá hồi về EMA20 theo xu hướng.
> - **Donchian breakout**: vào lệnh khi giá phá đỉnh/đáy của N nến gần nhất (`InpDonchianPeriod`), SL rộng, không đặt TP, thoát bằng trailing ATR. Đặt `InpRR = 0` để bỏ TP.

## Dùng hằng ngày với VS Code (khuyên dùng)
Mở thư mục bot bằng VS Code. Các lệnh nằm ở **Terminal → Run Task…**:

| Lệnh | Làm gì |
|---|---|
| **Bot: tu dong cap nhat khi luu** | Tự bật khi mở thư mục. Sửa `.mq5` rồi Ctrl+S là bot trên MT5 được cập nhật. |
| **Bot: cap nhat ngay** (Ctrl+Shift+B) | Chép và compile ngay. |
| **Bot: chay backtest** | Mở MT5 và chạy 1 lần backtest với cài đặt mặc định. |
| **Bot: so sanh cac cau hinh** | Tự chạy lần lượt 6 cấu hình (khoảng 25–30 phút), rồi tạo file `ket-qua-backtest-....zip`. **Gửi file zip này cho Claude** để phân tích. |

Muốn thử cấu hình khác, sửa danh sách `$Runs` ở đầu file `ChayThuNghiem.ps1`.

---


> Bot chỉ để thử nghiệm. Không có gì đảm bảo có lãi. Luôn backtest rồi chạy demo trước khi dùng tiền thật.

File bot: `BTC_EMA_Pullback_v2.mq5`.

## Bản 2 làm gì

**Vào lệnh (khung H1):** giá và EMA20 cùng nằm một phía so với EMA200. Nến vừa đóng đã chạm EMA20 rồi đóng cửa trở lại đúng phía xu hướng. Lệnh phải qua thêm các bộ lọc:
- **Khung H4:** giá đóng cửa H4 cũng phải nằm đúng phía so với EMA200 H4.
- **ADX ≥ 20:** bỏ qua khi thị trường đi ngang.
- **Mẫu nến (mặc định tắt):** chỉ vào lệnh khi có pin bar hoặc engulfing.

**SL / TP / lot:** SL = 1,5 × ATR, TP = 2R, lot tự tính để mỗi lệnh chỉ rủi ro 1% vốn.

**Quản lý lệnh đang mở:**
1. Lãi đạt 1R thì **chốt 50%** khối lượng.
2. Dời SL về **hòa vốn**.
3. **Trailing stop**: SL tự đi theo giá, cách 2 × ATR, chỉ dời theo hướng có lợi.

**Bộ lọc thời gian:** không vào lệnh mới vào Thứ 7, Chủ nhật và hai khung giờ hay có tin Mỹ (12–14h và 18–20h **giờ server**). Lệnh đang mở vẫn được quản lý bình thường.

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
- Nạp hoặc rút tiền sẽ làm lệch "đỉnh vốn". Sau khi nạp/rút, nên reset bằng `InpResetHalt = true`.
- BTC có thể trượt giá qua SL khi có tin. Swap crypto qua đêm có thể cao.
- Nên xem lại kết quả mỗi tuần, dù đã có thông báo.

## Giới hạn vào lệnh (mới ở v2.1)
- `InpAllowBuy` / `InpAllowSell`: bật/tắt từng chiều.
- `InpMaxTradesPerDay`: số lệnh tối đa mỗi ngày (0 = tắt).
- `InpCooldownBars`: nghỉ N nến sau một lệnh thua (0 = tắt).
