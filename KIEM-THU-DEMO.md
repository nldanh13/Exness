# Kiểm thử bot trên demo (v5.10.18)

Chạy trên tài khoản **demo** Exness, chart BTCUSDm M5, bộ cài đặt 05 hoặc 06. Mỗi bài ghi lại: ngày giờ, ảnh bảng điều khiển,
dòng trong tab **Experts** (Ctrl+T → Experts), và file liên quan. Các file nằm ở `File → Open Data Folder → ..\Common\Files`.

Mẹo chung:
- **F3** mở cửa sổ Global Variables: xem trạng thái bot lưu lại (khóa ngày, mốc vốn, R, bộ đếm...). Tên của bảo vệ lệnh tay bắt đầu bằng `TBG_`, khóa chart bằng `TBO_`.
- Để bài thử diễn ra nhanh, **tạm hạ** ngưỡng (ví dụ sụt giảm 1% thay vì 15%), thử xong đặt lại như cũ.

| # | Bài thử | Cách làm trên demo | Đạt khi |
|---|---|---|---|
| 1 | Sụt giảm tài khoản khi có cả lệnh tay / tự vào (magic 0) và lệnh chiến lược chính | Bật cả chiến lược chính (`InpAllowBuy/Sell = true`) và bảo vệ lệnh tay. Đặt `InpGuardMaxDDPct = 1`. Mở 1 lệnh tay 0,01 lot cho lỗ khoảng 1% vốn. | Thông báo "DUNG HAN". Lệnh tay bị đóng, lệnh chờ tay bị hủy. Bảng hiện "DỪNG HẲN". Bấm BUY / SELL bị từ chối. Chiến lược chính không vào lệnh mới (trạng thái "DUNG HAN: von tai khoan..."). Lệnh của chiến lược chính đang mở giữ nguyên SL / TP. Xong: bật `InpResetHalt = true` một lần rồi đổi về false. |
| 2 | Chạm giới hạn lỗ ngày | Đặt `InpGuardDayLossPct = 1`. Đặt sẵn 1 lệnh chờ tay xa giá. Mở 1 lệnh tay cho lỗ quá 1%. | Lệnh tay (cả lệnh mở trước khi gắn bot) bị đóng, lệnh chờ bị hủy, bảng hiện "ĐÃ KHÓA". Không có lệnh tự vào / nhồi nào tới 0:00 giờ server. Mở tay lệnh mới thì bị đóng ngay. |
| 3 | Đóng lệnh khớp một phần | Khó tạo ra theo ý trên demo. Cách gần nhất: mở 3 lớp rồi để bot chốt gộp lúc thị trường chạy nhanh. Xem tab Experts. | Nếu có dòng "chi khop mot phan": bot báo "dong not phan con lai" và vị thế hết hẳn; chỉ báo "CHOT LOI" khi vị thế đã hết. Global Variable `..._closing` mất sau khi đóng xong. |
| 4 | Hai chart cùng mã khởi động cùng lúc | Mở 2 chart BTCUSDm, gắn bot cả hai. Đóng MT5 rồi mở lại (hai chart khởi động cùng lúc). | Đúng **một** chart làm việc, chart kia hiện "CHART KHÁC đang bảo vệ". Đóng chart đang làm việc thì chart kia tự nhận quyền trong vài giây. Không bao giờ cả hai cùng hiện "CHART KHÁC". |
| 5 | Sàn đổi ticket / ghi chú | Không tự tạo được trên demo. Kiểm gián tiếp: lệnh tự vào có ghi chú "TB tu vao"; bấm sửa lệnh không đổi ghi chú. Xem F3 có biến `bm<số>` trùng cột **ID** (không phải Ticket) trong lịch sử. | Bảng vẫn đếm đúng số lệnh tự vào; chốt gộp vẫn tính lệnh đó là "bot mở". |
| 6 | Mất mạng / khởi động lại MT5 | Lúc đang có lệnh tự vào: (a) ngắt mạng 2 phút rồi bật lại; (b) đóng MT5 bằng Task Manager (giả mất điện) rồi mở lại. | Sau khi mở lại: mốc vốn (`peak`), R ban đầu (`r<ID>`), bộ đếm lệnh tự vào trong ngày (`acnt...`), khóa ngày / dừng hẳn còn nguyên trong F3. Bảng hiện đúng "lệnh thứ N hôm nay". Bot ghi Global Variable xuống đĩa mỗi 30 giây, nên tắt đột ngột chỉ mất tối đa 30 giây gần nhất. |
| 7 | Spread tăng mạnh khi có tin Mỹ | Chờ ngày có tin lớn (CPI, NFP, FOMC – xem lịch kinh tế trong MT5). Bộ 05 / 06 đã bật `InpAvoidUSNews`. | Trong khoảng `InpNewsHours` quanh tin: không có lệnh tự vào, không nhồi. Spread vượt `InpMaxSpreadPoints` hoặc vượt 20% khoảng SL: không vào, không nhồi. |
| 8 | Chạy demo nhiều tuần | Để chạy liên tục (nên dùng VPS). Mỗi tuần mở 3 file trong `Common\Files`. | Đối chiếu được: **giá yêu cầu / giá khớp / trượt giá / spread** trong `TrendBot_truotgia.csv` (Magic 0 = tự vào, nhồi); **lãi lỗ, phí, số dư** trong `TrendBot_nhatky.csv`; **equity cuối ngày** trong `TrendBot_tongket.csv` để tính mức sụt giảm lớn nhất. |

Sau mỗi bài: nhớ trả các thông số đã hạ về giá trị của bộ 05 / 06 (nạp lại file .set là nhanh nhất).
