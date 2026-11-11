# Rà soát an toàn v5.10.22

## Thay đổi

1. **LiveR có hai nguồn giao dịch tách biệt.** `P_Magic` được so với benchmark `InpLiveExpR`/`InpLiveSdR` (mặc định là thống kê Donchian), còn các lệnh magic 0 được EA gắn dấu `TB tu vao`/`TB nhoi tay` có `g_lrAutoSum/g_lrAutoN` riêng và **không** bị đánh giá bằng ngưỡng Donchian. Phân loại từ deal *mở*, tổng phí/swap và P&L theo `DEAL_POSITION_ID`, chỉ tính khi không còn `POSITION_IDENTIFIER` mở. Các lần khớp một phần được gộp và tính đủ khối lượng SL ban đầu từng lần khớp. Trường hợp thiếu giá SL không có R tin cậy và sẽ không được đưa vào mẫu.
2. **Netting/Exchange:** EA sẽ `INIT_FAILED` hoặc `ExpertRemove()` nếu tài khoản chưa hỗ trợ Hedging. Đây là giới hạn có chủ đích vì một vị thế Netting có thể chứa giao dịch của nhiều nguồn/magic; tính rủi ro/chốt riêng là không an toàn. Kiểm tra lại sau khi VPS đăng nhập.
3. **BTC/ETH và magic 0:** chế độ `GuardAutoEntry()` và `GuardPyramid()` cùng sử dụng `GroupLock()` + `GroupGuardRiskAllowed()` + reservation riêng cho magic 0, từ trước khi kiểm tra rủi ro nhóm tới khi server phản hồi. Tổng rủi ro tính cả magic 0 và các vị thế `P_Magic` của nhóm cùng terminal MT5. Reservation được giữ tạm tối đa 120 giây sau lệnh khớp để bảo vệ khoảng trễ cập nhật vị thế; có thể làm **bỏ bớt** tín hiệu nhưng không tăng giới hạn. Giới hạn nhóm `InpMaxGroupRiskPct` là trần bổ sung, có thể chặt hơn bucket thuật toán 2%.
4. **Bucket 1% và 2%:** nhồi lệnh tự động không bị khóa chỉ vì bucket của người nhập lệnh 1%; chỉ từ chối nhồi thêm lên vị thế *do người nhập* khi bucket người nhập đã khóa. Bucket 2% vẫn kiểm soát mọi lệnh bot mới.
5. **Rút/nạp tiền:** trong `GuardCheckAcctDD()`, bot chỉ bù trừ các deal `DEAL_TYPE_BALANCE` đã xác nhận ở lịch sử, dùng mutex CAS giữa chart cùng account và watermark ticket/thời gian lưu ở Global Variables và file Common. Không dùng P&L hoặc commission như nạp/rút, không tự mở khóa `halt`. Lần đầu nâng cấp không xử lý lại lịch sử trước watermark; nếu khoản rút diễn ra trước lúc nâng cấp mà peak đã lệch, dùng `InpResetHalt` một lần sau khi kiểm tra. Cảnh báo: sàn có thể dùng deal Balance cho những loại điều chỉnh khác; đối chiếu tab History trước khi tin tuyệt đối vào mốc này.
6. **Thiếu dữ liệu:** khi bật funding, Fear & Greed, Wikipedia/Nasdaq hoặc tránh tin Mỹ, dữ liệu thiếu/lỗi dẫn đến **không gửi lệnh mới** thay vì bỏ qua bộ lọc. Trong Strategy Tester, muốn bật tránh tin Mỹ phải cung cấp `tin_my.csv`; nếu không nên tắt bộ lọc đó trong lần thử có chủ đích và ghi nhận sự khác biệt. Khi đang có vị thế, các chức năng quản lý thoát lệnh vẫn hoạt động.

## Kiểm thử trước khi chạy tiền thật

- GitHub Actions chạy Python, sinh lại Inputs/preset và **test tĩnh cấu trúc MQL5** (`tests/test_safety.py`). **Không** có trình biên dịch MetaEditor trong CI; CI xanh không bảo đảm mã MQL5 biên dịch.
- Bắt buộc compile `BTC_EMA_Pullback_v2.mq5` và toàn bộ `TrendBot/*.mqh` trên MetaEditor, kiểm tra Errors/Warnings.
- Demo Hedging với BTCUSDm và ETHUSDm: cố mở hai tín hiệu cùng lúc, chạm trần nhóm, khóa human nhưng algo vẫn được nhồi đúng nguồn; chạy với và không có file tin/funding/F&G để xác nhận fail-closed.
- Thử gửi vào/đóng một phần, server đổi POSITION_TICKET, đóng vị thế bằng tay, khởi động lại và kiểm tra R chỉ tổng kết **sau khi vị thế hết**.
- Demo rút/nạp tiền giả (nếu tài khoản demo cho phép): kiểm tra peak trước/sau một deal `DEAL_TYPE_BALANCE`, chạy hai chart guard đồng thời, crash và restart. Không thử tiền thật.
- Với vốn khoảng 1 triệu VND và BTC tối thiểu 0,01 lot, không thay đổi logic bỏ lệnh khi SL vượt ngân sách; **0 giao dịch có thể là kết quả đúng**. Không tăng `InpMaxRiskRoundUp` để cưỡng ép giao dịch.
- Cần thử tick thật và demo vài tuần trước khi dùng thực; CPCV/PBO và DSR trong dự án là kết quả nghiên cứu, **không** xác nhận lợi thế live.

**Giới hạn không thể xóa bằng thay đổi MQL5 hiện tại:** không có đồng bộ rủi ro qua các terminal/VPS khác nhau; gap/stop slippage có thể vượt giới hạn; số lượng thử thực tế (`InpTrials`) phải được khai báo trung thực. Các nhóm rủi ro hiện đồng bộ theo cấu hình `InpCorrSymbols` trong cùng terminal.
