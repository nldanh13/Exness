# Kiểm toán và chỉnh sửa rủi ro v5.10.20 (chưa xác minh trên MetaEditor)

## 1. Vốn tối thiểu là một đại lượng tính theo SL, tick value và volume min

Không áp dụng số vốn cố định cho mọi broker. Công thức thực tế tại thời điểm vào lệnh:

- `R_min = |OrderCalcProfit(direction, symbol, volume_min, price_entry, stop_loss)|`
- `V_min(risk%) = R_min / (risk% / 100)`
- Lệnh chỉ được gửi khi rủi ro của khối lượng làm tròn xuống hợp lệ. Không tăng lot chỉ để có giao dịch.

Ví dụ *chỉ khi* hợp đồng BTC là 1 BTC/lot và min lot 0,01:
- BTC thay đổi 100 USD -> 0,01 lot thay đổi xấp xỉ 1 USD, chưa gồm spread/phí.
- Với SL cách giá vào 1.000 USD: 0,01 lot rủi ro khoảng 10 USD; vốn tối thiểu cho 1% là 1.000 USD, cho 2% là 500 USD.
- Với SL cách 3.000 USD (có thể xảy ra ở H4): rủi ro khoảng 30 USD; cần 3.000 USD cho 1%, 1.500 USD cho 2%.
- Với vốn 1 triệu VND, giá trị chính xác còn phụ thuộc tỷ giá tài khoản, loại hợp đồng và thông số sàn. Dùng `Specification` trong MT5 / `OrderCalcProfit`, không dựa vào ước lượng cố định.

`InpMinSLATRMult = 1.0` đặt sàn khoảng cách SL theo ATR của khung SL cho chiến lược chính; mặc định chiến lược Donchian 2,5 ATR không đổi. `CalcLots()` đã từ chối lot nhỏ hơn min và nay thông báo vốn yêu cầu ở mức 1% và 2%. Chế độ tự vào M5 dùng `OrderCalcProfit` và giới hạn bucket thuật toán trước khi gửi. **Các preset 05/06 có thể không giao dịch BTC với vốn 1 triệu VND** — đó là cơ chế từ chối an toàn, không phải hỏng tín hiệu. Không được tăng rủi ro để ép lệnh chạy. Tài khoản Cent chỉ là khả năng cần kiểm tra: không giả định BTCUSDm có sẵn trên loại tài khoản đó.

## 2. Phân phối lợi nhuận: không áp đặt win rate lý thuyết

Dữ liệu có sẵn `ket-qua/20261107-1924-chinhxac-lenh.csv` cho cấu hình `C-Donchian20-H4-ADX`: 85 giao dịch, win rate khoảng 41,2%, lệnh thắng trung bình 1,92R, lệnh thua trung bình -0,64R, net +35,08R. 10% lệnh thắng tốt nhất đóng góp khoảng 37% **tổng R dương**, không phải bằng chứng cho kết luận “80% lãi năm đến từ tail” hay tỷ lệ thắng cố định cho mọi điều kiện thị trường. Đây là dữ liệu quá khứ, chưa xác thực out-of-sample.

`InpBreakoutUseSentiment = false`: Donchian mặc định *không* chặn tín hiệu vì Fear & Greed/funding cực đoan (nếu các bộ lọc đó được bật); có thể bật lại để so sánh. EMA pullback và auto-entry M5 vẫn áp dụng các bộ lọc khi người dùng bật. Tin Mỹ, EMA/ADX, Nasdaq là các bộ lọc riêng, không tự động bị tắt. Thử A/B có/không lọc, đối chiếu số lượng lệnh, tổng R, MDD và đuôi phải; kiểm tra trên dữ liệu ngoài mẫu.

Công cụ: `python cong-cu/phan_phoi_loi_nhuan.py ket-qua/20261107-1924-chinhxac-lenh.csv --lan C-Donchian20-H4-ADX`. Tùy chọn `--cot FundingPhanVi --toi-da 80` chỉ dùng để khảo sát dữ liệu, không thể thay cho backtest thực tế của thay đổi điều kiện vào lệnh.

## 3. Nhồi lệnh giảm khối lượng, không giả vờ có 0,005 lot

`InpPyramidLotFactor = 0.5` áp dụng giới hạn giảm hình học cho nhồi của chiến lược chính; `InpGuardPyramidLotFactor = 0.5` áp dụng trong `GuardPyramid()` (module `ManualEntry.mqh`). Nếu lot chuẩn là 0,04, lớp sau tối đa 0,02, tiếp 0,01; nếu khởi đầu 0,01, lớp sau cần 0,005 nên **bỏ nhồi**. Không làm tròn 0,005 lên 0,01 vì phá vỡ giới hạn rủi ro. Luôn kiểm tra lại tổng rủi ro từ SL các lớp.

Chốt giỏ **giữ đồng bộ** và xác minh khối lượng còn lại. `PositionCloseBy` chỉ dùng khi có vị thế đối ứng trên tài khoản hedging, không phải giải pháp đóng đồng loạt các lớp cùng chiều. `SetAsyncMode(true)` chỉ gửi yêu cầu mà không đợi xác nhận, **không có tính nguyên tử** và dễ tạo trạng thái “đã đóng” giả nếu không có hệ thống đối soát riêng. V5.10.20 ưu tiên đóng khẩn cấp từ `OnTimer` và thử lại dựa trên `GetTickCount64` (2 giây khi halt); không cam kết khớp trong cùng mili-giây hay không trượt giá.

## 4. Đồng bộ, lưu trạng thái, backtest

- `GroupLock()` đã dùng CAS và timestamp với TTL 60 giây. Nay `GroupUnlock()` chỉ giải phóng khóa còn thuộc token mình đã lấy. Không dùng `GlobalVariableTime()` làm TTL, vì đọc biến cũng thay đổi thời điểm truy cập.
- Trạng thái sụt giảm toàn tài khoản có snapshot `TrendBot_dd_<account>.txt` trong Common Files, kết hợp với Terminal Global Variables. Dừng hẳn và reset ghi ngay; mốc đỉnh được lưu tối đa khoảng mỗi 30 giây. Snapshot không thay thế sao lưu VPS hoặc khóa phía máy chủ.
- `InpGuardBacktest` mặc định tắt; preset 05/06 bật để chạy logic guard, tự vào, nhồi và chốt trong Strategy Tester. Đồng hồ kiểm tra trong tester dựa thời gian mô phỏng; không xuất nhật ký/đồ họa hay flush Global Variable trong tối ưu hóa không trực quan. Mỗi pass dọn trạng thái `TBG_` thử nghiệm trước khi khởi động. Đây là **khả năng chạy backtest**, chưa phải kết quả backtest có lãi.
- Các script/nhãn và ba preset MT5 được tạo lại bằng cùng bộ sinh để tránh thiếu Input và nhiễm cấu hình từ lần Load trước.

## 5. Hai bucket lỗ ngày tách biệt (tùy chọn)

`InpGuardHumanDayPct = 1.0`: lệnh `magic=0` do người vào, trên **mã chart** đang bảo vệ. `InpGuardAlgoDayPct = 2.0`: lệnh bot tự mở/nhồi `magic=0` và `P_Magic` trên **mã chart** đó. Khi bucket chạm ngưỡng, khóa đến 0:00 giờ server. Mọi đường vào lệnh do EA thực hiện đều kiểm tra khóa thuật toán; lệnh tay mở trực tiếp ở terminal không thể bị ngăn trước khi khớp, mà sẽ được xử lý sau đó. Lệnh auto được so rủi ro tiền của SL với ngân sách bucket còn lại trước khi gửi.

`InpGuardDayLossPct` tổng cho toàn bộ `magic=0` trên mã và `InpGuardMaxDDPct` cho equity toàn tài khoản vẫn giữ. **Đây chưa phải hệ thống chia ngân sách rủi ro chính xác trên mọi mã và mọi MT5 terminal**: các bucket theo mã/chart và nhận diện lịch sử vẫn phụ thuộc dữ liệu đóng lệnh/Global Variable. Ngưỡng 1%/2% không bảo đảm mức lỗ cuối cùng không vượt ngưỡng trong gap, spread hay trượt giá.

Đặc biệt: với 0,01 lot BTC và vốn 1 triệu VND, việc bật bucket thuật toán 2% có thể loại tất cả tín hiệu của bộ 05/06. Đừng vô hiệu khóa để tạo ra giao dịch; hãy tăng vốn phù hợp, giảm giá trị tick/ATR bằng một sản phẩm khác, hoặc sử dụng demo.

## 6. Kiểm thử bắt buộc trước khi merge/vào tiền thật

1. Biên dịch `BTC_EMA_Pullback_v2.mq5` trong MetaEditor; không chấp nhận lỗi hoặc warning đáng ngờ.
2. Chạy bộ 05 và 06 trong MT5 Strategy Tester **Every tick based on real ticks**, với cùng khoảng dữ liệu out-of-sample, và so sánh có/không nhồi, có/không lọc tâm lý. Nếu 0 giao dịch, kiểm tra thông báo “min lot/bucket” thay vì tự giảm giới hạn rủi ro.
3. Kiểm tra tắt/mở MT5, chart trùng mã, rút tiền, lệnh dở dang và partial fills; verify Global Variables và snapshot.
4. Test demo nhiều tuần có dữ liệu spread/trượt giá phí, xem `KIEM-THU-DEMO.md`. Không suy hiệu quả tương lai từ kết quả quá khứ.

**Giới hạn:** chưa thể compile MQL5 hoặc chạy MT5 trên môi trường tạo PR. Nhánh này là bản sửa để kiểm tra, không nên triển khai thẳng tiền thật.
