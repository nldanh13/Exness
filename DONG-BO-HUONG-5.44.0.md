# V5.44.0 — Đồng bộ hướng khi "Theo tình huống"

## Vấn đề cần giải quyết

Ở v5.43.0, **bảng 9 khung EMA20/50**, **bộ dự đoán 4 nguồn (Dow, EMA H4+D1, MACD H4, cấu trúc H4)** và **bộ chọn bối cảnh thị trường "Theo tình huống" (Dow D1 + ADX + mẫu hình)** đo **các khía cạnh khác nhau**. Ví dụ, 9 khung có thể 6/9 GIẢM, 4 nguồn lại có 2 phiếu GIẢM, 1 phiếu TĂNG, 1 trung tính; khi đó v5.43 đúng khi báo **chưa đủ đồng thuận**, nhưng ba kết quả khiến giao diện khó hiểu và chưa ngăn mọi đường tự mở lệnh ngược.

## Nguyên tắc thống nhất — 3 điều kiện đều cần thỏa

Chỉ với `InpStrategy = STRAT_SMART` (chiến lược 24), mọi lệnh **tự động mở mới** chỉ được phép theo một chiều khi **cả ba nhóm cùng chiều**:

1. **Bảng 9 khung EMA20/50** có ít nhất 6/9 khung nghiêng cùng chiều và **H1, H4, D1 đều cùng chiều**. Các dao động ngắn M1/M3 có thể ngược xu hướng lớn mà không tự đảo chiều chính.
2. **Bốn nguồn độc lập ghi số liệu** có ít nhất 3 phiếu đồng thuận, **không có phiếu trái chiều** (giữ nguyên thuật toán v5.43).
3. **Thủy triều Dow D1** xác nhận cùng chiều và không đang chờ xác nhận đảo chiều.

Nếu một nguồn chưa rõ hoặc phản đối, **hướng cho phép giao dịch = DỪNG NGOÀI / CHỜ ĐỒNG THUẬN**. Không đổi 0 thành BUY/SELL; không cố làm cho 9 biểu đồ luôn cùng màu. **Bối cảnh thị trường** (xu hướng mạnh / đi ngang / không rõ) vẫn giữ nguyên nhãn vì đây là phân loại trạng thái, không phải chiều giá.

### Cùng một nến M15 đã đóng

- Cả 9 dòng trên bảng phải dùng **các nến hoàn tất tại cùng thời điểm đóng M15**, không dùng nến M1 mới hơn hoặc nến H4/D1 chưa đóng. 9 phiếu này được chụp một lần và cố định đến lần đóng M15 tiếp theo.
- Bốn phiếu dự đoán vẫn giữ bất biến trong file CSV, so sánh với giá sau 4, 8, 16 nến M15. Khi MT5 khởi động lại, nạp lại phiếu chưa đến hạn cho nến hiện tại thay vì giả làm không có phiếu.
- **Hướng vào lệnh thống nhất là một quyết định bổ sung**, không thay đổi dữ liệu kiểm chứng ban đầu.

### Đường mở lệnh được bảo vệ

Bộ lọc cuối cùng (`SyncEntryAllowed`) kiểm tra lại **đúng nến M15 mới nhất** trước khi thêm rủi ro:

- Setup tự động mới của `Theo tình huống`, kể cả khi tín hiệu tìm được trước khi các bộ đồng thuận.
- Lệnh chờ **giá hồi** và cơ chế **vào lại sau thua**, nếu đồng thuận mất đi thì hủy dự định.
- Các lệnh **tự nhồi** của chiến lược chính.
- Những **lệnh SCALE BUY LIMIT/SELL LIMIT** do EA đặt từ tín hiệu đã đồng thuận trước đó nhưng còn chưa khớp: nếu hướng thay đổi/mất đồng thuận thì chủ động hủy các lệnh SCALE thuộc Magic của EA để tránh khớp ngược khi đang chờ.
- Chế độ tự mở lệnh và tự nhồi từ phần bảo vệ lệnh tay (`InpGuardAutoEntry`, `InpGuardPyramidMax`) **khi EA đang dùng `STRAT_SMART`**.

**Không chặn** thao tác thoát lệnh, dời SL, chốt lời, bảo vệ tài khoản hoặc các vị thế đang mở. Lệnh **bấm BUY/SELL thủ công** vẫn do người dùng quyết định (các quy tắc rủi ro hiện hữu vẫn áp dụng). Các chiến lược khác ngoài `STRAT_SMART` giữ nguyên điều kiện của chúng.

### Ví dụ cụ thể trong ảnh MT5

| Dữ liệu | Kết luận |
|---|---|
| 9 khung: 6 GIẢM, 1 TĂNG, 2 NGANG; H1/H4/D1 cùng GIẢM | Chỉ báo nghiêng GIẢM |
| 4 nguồn: chỉ 2/4 đồng ý, có 1 phiếu trái | **Chưa đủ đồng thuận** |
| Hướng giao dịch thống nhất | **CHỜ ĐỒNG THUẬN — chưa mở lệnh tự động mới** |

Nhờ vậy, bảng vẫn thể hiện **sự thật của các chỉ báo** nhưng chỉ còn **một kết luận được phép dùng để vào lệnh**.

## Quan sát trên chart và trong file trạng thái

- Bên trái: `HƯỚNG LỆNH THỐNG NHẤT (M15): CHỜ ĐỒNG THUẬN / CHỈ MUA / CHỈ BÁN`.
- Bảng bên phải: 9 khung đã đóng theo cùng thời điểm M15 và dòng `KẾT LUẬN: ...`.
- File `Common\Files\TrendBot_trangthai_<chart>.txt`: `huongdongbo=` cho phép đọc lý do; `huonglenh=` và `huong9=` cho ứng dụng browser biết chiều cuối cùng, các số đếm `tang9/giam9` và `huong4` vẫn giữ dấu vết từng bộ.
- File thống kê `TrendBot_huong_..._M15.csv` vẫn đo các dự đoán như trước; đây không phải bằng chứng có lợi nhuận sau spread.

## Trước khi sử dụng trên MT5

1. Kiểm tra GitHub CI, cập nhật mã về máy, nhấn F7 trong MetaEditor. **GitHub CI không thay thế native MetaEditor**.
2. Chạy thử trong Strategy Tester ở chế độ Every tick based on real ticks hoặc trên **MT5 demo**. Đảm bảo các lệnh bị chặn khi 9/4/Dow bất đồng và được phép *xét các bộ lọc còn lại* chỉ khi cả ba cùng chiều.
3. Xem `Experts`, bảng trạng thái, và tài khoản có **0 lệnh ngoài kế hoạch**.
4. Trên tài khoản thật vốn nhỏ BTCUSDm, **không tự nới `InpMaxRiskRoundUp` hay SL/lot** chỉ để ép bot vào lệnh. Bộ lọc đồng bộ chỉ có thể giảm số lần vào lệnh, không đảm bảo tăng lợi nhuận.

## Giới hạn

Điều kiện ≥3/4 không có phiếu ngược và 6/9 kèm H1/H4/D1 rất chặt, có thể khiến bot ít vào lệnh hoặc hoàn toàn đứng ngoài nhiều ngày. Điều đó là **chủ đích an toàn** của bản này và cần đánh giá tỷ lệ bỏ lỡ tín hiệu bằng dữ liệu ngoài mẫu. Không suy diễn rằng 9 khung và 4 nhóm chỉ báo là nguồn hoàn toàn độc lập.
