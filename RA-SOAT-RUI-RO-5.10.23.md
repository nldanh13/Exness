# Kiểm toán sửa lỗi định lượng và quản trị rủi ro — v5.10.23

**Trạng thái:** mã đã chỉnh trên nhánh kiểm toán. GitHub CI chỉ kiểm tra Python, lịch tin, định dạng Input và các bất biến tĩnh, **không biên dịch MQL5**. Phải biên dịch MetaEditor và chạy MT5 Strategy Tester + demo Hedging trước khi dùng tiền thật.

## 1. Kế toán theo vị thế mở đầu tiên (quan trọng nhất)

Trước đây `GuardManualDayPL()` cộng P&L theo `DEAL_MAGIC=0` của *deal đóng*. Nếu `CTrade` mang Magic của chiến lược khi đóng lệnh tay, lỗ có thể bị hạch toán nhầm. `RefreshClosedPL()` cũng có thể đếm nhầm khoản đóng đó cho chiến lược chính.

`TrendBot/Ledger.mqh` mới dùng `DEAL_POSITION_ID` để tìm deal **mở đầu tiên** (đúng `DEAL_ENTRY_IN`). Nguồn lệnh được cố định theo deal mở, không thay đổi theo Magic của người đóng. Ba nguồn: (1) người mở `magic=0`, (2) TrendBot tự vào/nhồi `magic=0` nhận diện bằng comment/tag, (3) EA `magic!=0`. Sổ cái cộng `DEAL_PROFIT`, swap, commission và fee, cả đóng một phần, và tách phần lãi/lỗ đã có trước 00:00 cho vị thế qua đêm. Khi không truy xuất được lịch sử mở vị thế, **không cho tăng rủi ro tự động**, thay vì ngầm coi lỗ bằng 0.

Bucket **1% human / 2% algo** dùng toàn bộ account và khóa Global Variable theo account, không còn tính riêng từng chart hay cộng chồng `DayPL()`. Cần kiểm thử với đóng bởi người, EA, SL/TP và partial fills. Nguồn magic0 từ EA khác không có comment nhận diện được coi là giao dịch người dùng; tài khoản riêng cho bot giúp giảm mơ hồ nguồn gốc.

## 2. Trần nhóm và lệnh không có SL

`CalcLots()` trước đây chỉ xét trần nhóm khi `corr != ""`, tức có thể bỏ qua ngay **lệnh đầu tiên** trong nhóm. Bây giờ kiểm tra `InGroup()` mỗi lần. Vị thế trong nhóm không có SL hoặc thiếu tick metadata sẽ chặn mở thêm thay vì giả định chỉ rủi ro bằng một lệnh chuẩn. `MathMin(BotEquity(),ACCOUNT_EQUITY)` giới hạn số tiền rủi ro không vượt equity thật, kể cả khi `InpCapital` cao hơn số dư.

## 3. Kiểm tra ký quỹ trước gửi lệnh

`EntryMarginOk()` mới gọi `OrderCalcMargin()` và `OrderCheck()` ngay trước khi gửi giao dịch chính, nhồi chiến lược, lệnh nút trên chart, tự vào `magic0` và nhồi `magic0`. Bộ giới hạn bảo thủ mặc định (chưa có input để tránh sinh ra preset không tương thích):

- Ký quỹ của một lệnh mới không quá **35% free margin**;
- Sau lệnh vẫn còn tối thiểu **10% equity** dưới dạng free margin;
- Margin level dự kiến phải **≥300%**.

Đây là *bộ lọc tiền giao dịch*, không bảo đảm server khớp giá, không vô hiệu HMR hoặc tránh được stop-out trong gap. `OrderCheck` có thể bảo thủ hơn `CTrade` với một số loại khớp; phải đo log lỗi/retcode trên tài khoản demo cụ thể.

## 4. BTCUSDc cho vốn 1 triệu VND

Theo tài liệu Exness: `BTCUSDc` trên MT5 Standard Cent có contract size 0,01 BTC/lot, `BTCUSD` chuẩn là 1 BTC/lot. Volume min được công bố 0,01 lot. Các mức số dư Cent dùng **USC**: 100 USC = 1 USD. Khi MT5 dùng `BTCUSDc`/`ETHUSDc` và nhóm vẫn mặc định `BTCUSDm,ETHUSDm`, bot tự đổi nhóm thành `BTCUSDc,ETHUSDc` (không ghi đè nhóm do người dùng tự cấu hình). Giá trị rủi ro dùng **đơn vị tiền mà broker trả trong `OrderCalcProfit()` và `ACCOUNT_EQUITY`**, không tự nhân 100 lần.

Không dùng preset BTCUSDm để quyết định vào BTCUSDc nếu chưa kiểm tra `SYMBOL_TRADE_TICK_VALUE_LOSS`, stops level, margin, spread, thời gian giao dịch, phí và Market Watch. Khả năng cung cấp BTCUSDc theo khu vực và tài khoản phải xác minh trong Exness Personal Area.

Nguồn: https://get.exness.help/hc/en-us/articles/17854191888540-Cryptocurrencies và https://get.exness.help/hc/vi/articles/17537782786588-T%C3%A0i-kho%E1%BA%A3n-Standard-Cent

## 5. Sụt giảm equity — hai thước đo

Giữ `BotEquityForLimits()` để khóa theo vốn đã thực hiện/lỗ thả nổi âm, tránh cắt xu hướng vì trả lại lãi chưa chốt. Song song tạo `mtmPeak` và `BotMtmDrawdownPct()` để **hiển thị riêng drawdown mark-to-market** (bao gồm lãi thả nổi). Snapshot lưu thêm `mtmPeak` trong Common Files; không đổi chính sách dừng hiện có.

## 6. Tin kinh tế và nghiên cứu

`du-lieu/tin_my.csv` bổ sung CPI Mỹ ngày **10/11/2026 13:30 UTC** và **10/12/2026 13:30 UTC** theo BLS (08:30 US Eastern) và giữ FOMC 09/12/2026. `cong-cu/kiem_tra_lich_tin.py` kiểm chứng 12/12 ngày CPI năm 2026, thứ tự sự kiện, UTC timestamp và các bản ghi trùng; CI sẽ từ chối dữ liệu lịch hỏng. MT5 Tester từ chối giao dịch khi yêu cầu tránh tin nhưng lịch không bao phủ thời đoạn, hoặc sự kiện gần nhất xa hơn 40 ngày. **File lịch lịch sử hiện có chỉ bao phủ CPI + FOMC, chưa gồm NFP đầy đủ cho 2020–2026; không được gọi bộ lọc này là lọc mọi tin Mỹ.** Nếu mở rộng sang NFP phải tạo lại toàn bộ lịch lịch sử nhất quán, tránh chỉ chặn vài tháng.

`cong-cu/bootstrap_khoi_thang.py` chạy bootstrap theo khối **ba tháng liên tiếp** trên R của lệnh (tháng vào gần đúng), nhằm đánh giá rủi ro phụ thuộc thời gian; `cong-cu/cpcv.py --bien-the` thêm benchmark buy-and-hold BTC ở độ biến động tháng tương đương. Không trộn R thật với log-return tương đương: số benchmark chỉ là phép chuẩn hóa rủi ro, không chứng minh alpha.

PBO 60% và các Sharpe ngoài mẫu chéo nhau chưa thể xem như thử nghiệm độc lập. `InpTrials` phải phản ánh **tổng số cấu hình thực tế đã thử**; đừng giữ mặc định 1 nếu đã dò tham số nhiều lần.

## 7. Giới hạn và kiểm thử bắt buộc

1. **MetaEditor**: compile EA và mọi include, xử lý lỗi/warning, thực hiện cùng terminal/broker phiên bản thực dùng.
2. **Sổ cái**: trên demo Hedging, mở manual BUY/SELL có phí, đóng bằng tay, SL, EA, partial; so sánh tổng P&L nguồn human/algo với lịch sử broker; thử lỗi thiếu history để bảo đảm không tăng rủi ro.
3. **Đơn vị Cent**: so `OrderCalcProfit()` của 0,01 lot BTCUSDc trên biến động ±$100 với `SYMBOL_TRADE_TICK_VALUE_LOSS`, `ACCOUNT_CURRENCY`, margin và equity thực; xác nhận nhóm BTCUSDc/ETHUSDc.
4. **Group/margin**: với rủi ro 2%/lệnh và trần nhóm 1,5%, lệnh đầu phải bị giảm lot/bỏ; nếu một vị thế trong nhóm không có SL, không mở thêm; kiểm tra OrderCheck khi HMR.
5. **Tin tức**: chạy `python cong-cu/kiem_tra_lich_tin.py`, thử xóa ngày CPI 10/11/2026 và chắc chắn CI đỏ; so kết quả Strategy Tester có/tắt `InpAvoidUSNews` và bao phủ lịch.
6. **Thống kê**: chạy `python cong-cu/bootstrap_khoi_thang.py ket-qua/20261107-1924-chinhxac-lenh.csv`; benchmark buy-and-hold và Donchian ở rủi ro tương đương; đóng băng cấu hình trước OOS.
7. **Demo** nhiều tuần và kiểm tra restart/đổi ticket, so equity mark-to-market và đỉnh giới hạn thực; không xác nhận tiền thật chỉ vì GitHub Actions xanh.

**Chưa giải quyết bằng công cụ hiện tại:** đồng bộ rủi ro qua các MT5 terminal/VPS độc lập; gap không bảo đảm SL; chất lượng lịch NFP giai đoạn 2020–2026; forward performance của chiến lược. Không cố định lợi nhuận kỳ vọng hoặc win rate tương lai từ kết quả quá khứ.
