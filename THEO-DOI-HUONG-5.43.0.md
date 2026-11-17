# Theo dõi hướng 4 nguồn — TrendBot v5.43.0

**Trạng thái: thử nghiệm, chỉ quan sát.** Không dùng phiếu hướng mới để vào lệnh, đổi hướng, tăng lot, nới mức làm tròn lot hay nới SL. Phiên bản này vẫn chạy chiến lược **Theo tình huống** như trước và bảo toàn `InpRiskPercent`, `InpMaxRiskRoundUp`, bucket lỗ, margin check.

## Mục tiêu

Kiểm tra xem bộ nhận định hướng mới có **thực sự dự đoán tốt hơn** Dow D1 một nguồn hoặc thị trường tăng/giảm cơ bản hay không, trước khi cho nó tác động đến bất kỳ giao dịch nào.

Trên chart dùng `InpStrategy = STRAT_SMART` (24), mỗi khi một **nến M15 đóng**, EA quan sát 4 nhóm chỉ báo:

| Nguồn | Hướng tăng / giảm khi nào | Không dự đoán nếu |
|---|---|---|
| **Dow D1** | Xu hướng chính theo cấu trúc Dow của `DowTide()` | Không đủ lịch sử, xu hướng chưa rõ hoặc đang chờ xác nhận đổi chiều |
| **EMA H4 + D1** | Giá đóng cửa H4 và D1 đều cao hơn/thấp hơn EMA50 riêng của khung đó | Hai khung không cùng chiều hoặc thiếu dữ liệu |
| **MACD H4** | MACD(12,26,9) trên H4 nằm trên/dưới Signal **và** cùng tăng/giảm so với nến H4 trước | Xung đột giữa độ dốc và vị trí so với Signal |
| **Cấu trúc giá H4** | Đỉnh và đáy của 8 nến H4 đã đóng gần nhất đều cao/thấp hơn của 8 nến ngay trước đó | Đỉnh và đáy không cùng xác nhận hướng |

**Đây là bốn nhóm chỉ báo, không phải bốn mẫu độc lập về mặt thống kê**: tất cả dựa trên giá BTC. Bộ đồng thuận chỉ đưa ra TĂNG hoặc GIẢM nếu **≥3/4 nhóm cùng chiều và không có phiếu phản đối**; còn lại là DỪNG NGOÀI (abstain). Không biến điểm số thành “xác suất giá tăng” vì chưa có hiệu chuẩn theo dữ liệu ngoài mẫu.

### Đánh giá sau 4, 8, 16 nến M15

Mỗi quan sát được ghi thời điểm **nến tín hiệu đã đóng** và giá đóng cửa của nến đó. Chỉ sau khi có đủ 4, 8 hoặc 16 **nến M15 đã đóng tiếp theo** mới ghi giá đóng cửa tương lai của đúng nến hạn. Định vị lại nến gốc bằng `iBarShift(..., true)` để tránh sai khi MT5 không chạy liên tục và **không dùng nến 0**.

Giá thay đổi có độ lớn không vượt `max(2 × spread lúc dự đoán, 0,1 × ATR14 M15)` được phân loại **FLAT**, không tự nhận là thắng hoặc thua. Đây là quy tắc lọc nhiễu phục vụ **độ chính xác hướng**, **không phải mô phỏng giá khớp thực**. Mọi phiếu của từng nguồn, gồm cả phiếu 0, được lưu bất biến theo nến gốc.

Các dự đoán chưa đủ hạn được lưu trong file riêng và nạp lại sau khi khởi động terminal. Chạy backtest không ghi file Common; chạy trên demo hoặc chart thật chỉ **quan sát**, nhưng nếu terminal không mở/không có M15 thì không thể tạo dự đoán cho những nến đó. Khi trở lại, các kết quả đang chờ được đối chiếu từ lịch sử đã có; không điền dự đoán ngược quá khứ.

## Xem dữ liệu trên máy

1. Trong MT5 bật chart **demo** chiến lược `InpStrategy = STRAT_SMART`. Tắt Algo Trading nếu chỉ muốn xem; EA vẫn cần được terminal chạy và nhận tick để quan sát.
2. Trên bảng chart hoặc dòng `huong=` của `TrendBot_trangthai_<chart>.txt` sẽ thấy hướng tổng hợp, số nhóm đồng thuận và từng phiếu. Một dòng `huongso=` cho biết số dự đoán/nhãn trong phiên hiện tại.
3. Mở **File → Open Data Folder**, đi lên thư mục `Terminal`, rồi tới `Common\Files` (hoặc tìm theo đường `TERMINAL_COMMONDATA_PATH\Files`). Tìm:
   - `TrendBot_huong_<account>_<symbol>_<magic>_M15.csv`: dòng `F` là dự đoán, `R` là kết quả sau 4/8/16 nến.
   - `TrendBot_huong_mo_<account>_<symbol>_<magic>_M15.txt`: dự đoán còn mở và nến cuối đã xét, không xóa khi đang theo dõi.

Ví dụ trong PowerShell, từ thư mục repo:

```powershell
python cong-cu/danh_gia_huong.py "C:\Users\<ten-ban>\AppData\Roaming\MetaQuotes\Terminal\Common\Files\TrendBot_huong_<account>_BTCUSDm_<magic>_M15.csv"
```

Báo cáo cho từng mốc H+4/H+8/H+16 gồm tỷ lệ bỏ phiếu, tỷ lệ đúng/sai/đi ngang của mỗi nguồn, khoảng Wilson 95% (tham khảo), và tần suất giá thực tế tăng/giảm/đi ngang. Chỉ dùng `F` có `R` tương ứng. Báo cáo sẽ từ chối nếu phiếu nguồn bị thay đổi sau khi dự đoán hoặc dữ liệu giá không nhất quán.

**Cảnh báo phương pháp:** Dự đoán ở các nến liên tiếp và nhiều mốc thời gian chồng lấn lớn, khoảng Wilson hiện **không điều chỉnh phụ thuộc theo thời gian**, không chứng minh edge. Cần đánh giá theo giai đoạn ngoài mẫu, chặn theo cụm thời gian và kiểm tra chi phí thực trong MT5 Strategy Tester trước khi thay đổi lệnh.

## Các tiêu chí trước khi cân nhắc chuyển khỏi chế độ quan sát

- Tối thiểu hàng trăm quan sát **không chồng lấn**, bao gồm nhiều trạng thái giá và ít nhất một giai đoạn giữ riêng chưa dùng hiệu chỉnh.
- Mỗi mốc H+4/8/16 phải được so sánh với baseline “luôn theo Dow D1”, “luôn bán” và “luôn mua” cùng một điều kiện nhiễu; độ phủ tín hiệu phải được báo cùng tỷ lệ đúng.
- Không được nhìn kết quả để thay đổi quy tắc trên chính tập kiểm thử; khi chỉnh quy tắc phải đánh giá tập ngoài mẫu mới.
- Nếu không có chứng cứ tốt hơn baseline sau chi phí, **không** dùng lớp đánh giá này để sửa hướng hoặc size giao dịch thật.

## Kiểm thử bắt buộc

CI GitHub chạy kiểm tra Python và các bất biến tĩnh; **không có MetaEditor hoặc MT5 real ticks chạy trên GitHub Actions này**. Cần bấm F7 trong MetaEditor và chạy Strategy Tester/demo trên tài khoản Hedging; kiểm tra CSV đủ F và R, nến gốc + horizon, khả năng khôi phục sau restart, nguyên tắc một dự đoán mỗi nến.

**Đặc biệt:** Vốn BTCUSDm tài khoản thật nhỏ và `InpMaxRiskRoundUp = 6%` vẫn có thể khiến lệnh tối thiểu chịu rủi ro cao; lớp dự đoán mới **không sửa** chính sách vốn đó. Nếu muốn kiểm thử mà không vào lệnh thật: tắt Algo Trading và không gắn preset bật auto vào tài khoản thật.
