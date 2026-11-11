# TrendBot: bot BTC cho MetaTrader 5

> Bot chỉ để thử nghiệm và **không đảm bảo có lãi**. Luôn backtest, rồi chạy demo vài tuần trước khi dùng tiền thật.

Expert Advisor cho MT5 (sàn Exness, mã `BTCUSDm`), kèm bộ script PowerShell để backtest hàng loạt, giao diện trên trình duyệt và vài công cụ Python. Chiến lược chính là phá vỡ kênh Donchian 20 nến H4, lọc theo EMA200 H4/D1 và ADX, SL theo ATR, rủi ro 1% vốn mỗi lệnh. Bot còn có chế độ bảo vệ lệnh vào tay (đặt SL, giới hạn lỗ ngày, chặn nhồi lệnh lỗ).

**Tài liệu đầy đủ (cách dùng, ý nghĩa thông số, kết quả từng đợt backtest, lịch sử phiên bản): [HUONG-DAN.md](HUONG-DAN.md).**

**Rà soát riêng v5.10.20:** [vốn tối thiểu theo ATR, bộ lọc Donchian, nhồi giảm lot, risk buckets 1%/2% và kế hoạch kiểm thử](RA-SOAT-RUI-RO-5.10.20.md). Với BTC và vốn khoảng 1 triệu VND, mức lot nhỏ nhất có thể khiến EA bỏ hoàn toàn các tín hiệu; không nên nâng rủi ro chỉ để vào được lệnh. Phiên bản hiện tại ghi ở dòng đầu của file đó.

## Bắt đầu nhanh

1. Clone repo về máy Windows có MT5 (Exness) và VS Code.
2. Mở thư mục bằng VS Code, vào **Terminal → Run Task…** và chọn **2. Cap nhat bot vao MT5**. Script tự chép bot vào MT5 và compile.
3. Trong MT5, mở chart `BTCUSDm`, kéo `BTC_EMA_Pullback_v2` vào chart và bật **Algo Trading**. Có thể nạp sẵn bộ thông số trong `cai-dat/` qua nút *Load* ở tab Inputs.
4. Muốn dùng giao diện thay cho VS Code: bấm đúp `GiaoDien.cmd`, trình duyệt mở `http://localhost:8765`.

Chi tiết từng nút, cách đọc kết quả backtest và cách bật thông báo nằm trong [HUONG-DAN.md](HUONG-DAN.md#dùng-hằng-ngày-với-vs-code).

## Cấu trúc thư mục

| Đường dẫn | Nội dung |
|---|---|
| `BTC_EMA_Pullback_v2.mq5` | File bot: tham số (inputs) và thứ tự chạy |
| `TrendBot/*.mqh` | Logic của bot, mỗi file một việc (tín hiệu, bộ lọc, rủi ro, quản lý lệnh, bảo vệ, báo cáo…) |
| `cai-dat/*.set` | Bộ thông số dựng sẵn, sinh bằng `cong-cu/tao_cai_dat.py` |
| `*.ps1`, `GiaoDien.cmd` | Script cài bot, chạy backtest hàng loạt, đồng bộ GitHub, gửi nhật ký, giao diện |
| `giao-dien/` | Trang web của giao diện và file giải thích thông số |
| `cong-cu/` | Công cụ Python (xem bên dưới) |
| `ket-qua/` | Bảng kết quả backtest mới nhất của mỗi chế độ (`nhanh`, `chinhxac`) và dữ liệu giá nén |
| `du-lieu/` | Dữ liệu ngoài dùng cho bộ lọc và phân tích (tin Mỹ, open interest) |
| `tai-lieu/` | Ghi chú nghiên cứu |
| `chi-chay.txt`, `chinh-xac.txt` | Danh sách cấu hình chạy ở nút 1 và nút 3 |
| `nhat-ky-can-thiep.md` | Mẫu nhật ký mỗi lần muốn can thiệp vào bot |

## Công cụ Python

Cần Python 3.10 trở lên. Cài thư viện ngoài một lần:

```
pip install -r requirements.txt
```

| Script | Việc |
|---|---|
| `cong-cu/nhan_thong_so.py` | Bảng nhãn và giải thích của mọi thông số, là nguồn duy nhất cho nhãn trong MT5 và giao diện |
| `cong-cu/viet_lai_nhan.py` | Ghi lại nhãn và nhóm trong `.mq5` theo bảng trên, xuất `giao-dien/giai-thich-thong-so.json` |
| `cong-cu/tao_cai_dat.py` | Sinh lại các file `cai-dat/*.set` từ giá trị mặc định của bot |
| `cong-cu/thu_oi_C.py` | Thử open interest / bản đồ thanh lý với chiến lược C (cần `numpy`) |

**Khi thêm hoặc đổi một input của bot**, thêm dòng tương ứng vào `cong-cu/nhan_thong_so.py` rồi chạy:

```
python cong-cu/viet_lai_nhan.py
python cong-cu/tao_cai_dat.py
```

GitHub Actions (`.github/workflows/kiem-tra-nhan.yml`) chạy lại hai lệnh này ở mỗi lần push và pull request. Nếu bảng nhãn thiếu hoặc thừa thông số, hoặc file `.mq5`, file giải thích hay `cai-dat/*.set` chưa được sinh lại, bước kiểm tra báo đỏ và in ra phần chênh lệch.

## Kết quả và dữ liệu

`ket-qua/` chỉ giữ lần chạy mới nhất của mỗi chế độ (`nhanh`, `chinhxac`): script backtest xóa bảng cũ trong cùng commit đẩy bảng mới, nên bản cũ vẫn xem lại được trong lịch sử git. Giao diện đọc trực tiếp các file `-lenh.csv` để hiện kết quả cộng dồn. Dữ liệu giá (`ket-qua/gia-*.zip`) và open interest (`du-lieu/oi-*.zip`) là file nén để Claude phân tích; chỉ cập nhật khi thật cần, vì mỗi bản mới đều nằm lại trong lịch sử git.

**Bản sửa an toàn 5.10.22:** [LiveR, Hedging, khóa nhóm BTC/ETH, bucket và dòng tiền nạp/rút](RA-SOAT-RUI-RO-5.10.22.md). Cần compile MetaEditor và demo trước khi sử dụng vốn thật.

## An toàn

- Không đưa token Telegram, mật khẩu hay file `.env` lên GitHub (`.gitignore` đã chặn `*.secret`, `.env`, `cai-dat-rieng/`).
- Bot được thiết kế cho tài khoản **Hedging**. Đọc mục [Khi chuyển sang tiền thật](HUONG-DAN.md#khi-chuyển-sang-tiền-thật) trước khi dùng tài khoản thật.
