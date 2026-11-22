# Nhật ký can thiệp

## Phần bot tự ghi (từ v5.50.0)

Bot tự ghi mọi việc bạn và bot đã làm với lệnh vào `Common\Files\TrendBot_cantiep_<số tài khoản>.csv` (từ v5.51 mỗi tài khoản một file) (trong MT5: File → Open Data Folder, lùi lên thư mục `Terminal\Common\Files`). Mỗi dòng có:

- **Ai:** `BAN (web / dien thoai / MT5 may tinh)`, `BAN` (sửa SL / TP), `BOT`, `BOT (that bai)`, `SAN (cham SL / TP / stop out)`, `HE THONG` (bot bật / tắt).
- **Hành động:** MO lenh, DONG lenh, DONG MOT PHAN, DAT SL, DOI SL sat gia hon, NOI SL xa hon (tang rui ro), XOA SL, DAT / DOI / XOA TP, DAT / SUA / HUY lenh cho, KHOA lenh tay het ngay...
- **Giờ server, giờ máy, mã, số ticket, lệnh của ai, chiều, lot, giá, SL cũ → mới, TP cũ → mới, lãi / lỗ, giá thị trường, lý do.**

Khi lệnh chạm SL, cột lý do cho biết SL đó do bạn hay bot đặt lần cuối.

Xem chi tiết: [HUONG-DAN.md, mục v5.50.0](HUONG-DAN.md#v5500-nhật-ký-can-thiệp-giữa-bạn-và-bot).

## Phần bạn tự ghi

Bot biết bạn **đã làm gì**, nhưng không biết **vì sao**. Mỗi lần muốn tắt bot, đổi thông số, vào lệnh tay, dời SL hay nạp thêm tiền: ghi một dòng **trước khi làm** (kể cả khi cuối cùng không làm). Chủ nhật mở file `TrendBot_cantiep_<số tài khoản>.csv`, đối chiếu từng dòng `BAN` với bảng này.

| Ngày giờ | Muốn làm gì | Lý do / cảm xúc lúc đó | Bot đang lãi hay lỗ (hôm nay, tuần này) | Có làm không | Xem lại cuối tuần: đúng hay sai |
|---|---|---|---|---|---|
| | | | | | |
