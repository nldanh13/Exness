# TrendBot v5.45.0 — DirectionEngine tập trung (SHADOW / chỉ quan sát)

## Vì sao không ép các chỉ báo vào cùng một kết luận?

Phiên bản **v5.44.0** bảo vệ lệnh thật bằng cách yêu cầu: **bảng 9 EMA**, **bốn nguồn dự đoán** và **Dow D1** đều đồng hướng. Cơ chế này vẫn **giữ nguyên** khi bổ sung v5.45.0.

Mục tiêu của v5.45 là khảo sát xem một bộ não hướng tập trung, không cộng trùng các chỉ báo cùng nguồn, có phát hiện được hướng hợp lý hơn hay không. **Nó KHÔNG mở lệnh, đổi chiến thuật, sửa SL, lot, risk, cho phép làm tròn min lot, hay thay thế `SyncEntryAllowed`.**

## Một Engine — ba nhóm thông tin, 100 điểm tối đa

| Nhóm | Trọng số tối đa | Nguồn đầu vào, gộp trùng |
|---|---:|---|
| **Cấu trúc xu hướng** | **40** | Dow D1 và cấu trúc đỉnh/đáy H4 cùng **một nhóm**. Dow phải có chiều; nếu cấu trúc H4 đưa phiếu ngược thì nhóm đứng ngoài. Không cộng Dow hai lần |
| **EMA đa khung** | **35** | Bảng 9 EMA20/50 + EMA50 H4/D1 cùng **một nhóm**. Bảng 9 có ít nhất 5/9 cùng chiều **và H4,D1 cùng chiều** mới là một phiếu; nếu EMA50 H4/D1 phản đối thì nhóm đứng ngoài. Không cộng 9 EMA thành 9 điểm độc lập |
| **Động lượng** | **25** | MACD H4 dựa trên nến đã đóng, một phiếu chiều |
| **ADX** | Không bỏ phiếu | Nhãn **đang có xu hướng / đi ngang / chuyển tiếp**. ADX là độ mạnh, không phải dấu tăng/giảm |
| **FVG, Order Block, Sóng Dow, VWAP, Key Volume…** | Không bỏ phiếu | **Bộ tìm điểm vào** sau khi có hướng; không được nhân số phiếu hướng |

Cộng **điểm ủng hộ MUA** và **điểm ủng hộ BÁN** riêng; nguồn không rõ = 0, nguồn bất đồng được thể hiện minh bạch. Kết luận MUA nếu điểm MUA ít nhất **70/100 và lớn hơn điểm BÁN**, ngược lại tương tự BÁN. Nếu không thì **CHỜ**. Ví dụ: cấu trúc MUA + EMA MUA, MACD BÁN → MUA 75 / BÁN 25; v5.44 có thể CHỜ, đây chính là khác biệt muốn **kiểm chứng trên dữ liệu**, không cho phép áp dụng vào lệnh thật.

**Lưu ý:** 40/35/25, quy tắc ≥70 điểm và 5/9 chỉ là **giả thuyết thử nghiệm**, không dựa trên lợi nhuận đã kiểm chứng. “75 điểm” **không phải xác suất thắng 75%**.

## Hai kết luận có nhiệm vụ khác nhau

- **LỆNH THẬT — v5.44:** `HƯỚNG LỆNH THỐNG NHẤT`; vẫn là bộ duy nhất quyết định lệnh tự động của chiến lược **Theo tình huống**.
- **DỰ ĐOÁN THỬ NGHIỆM — v5.45:** `Engine v5.45 [THỬ, KHÔNG VÀO LỆNH]`; chỉ ghi xu hướng, điểm MUA/BÁN, so với v5.44.

Không được lấy “Engine v5.45 có tín hiệu” làm lý do bật Algo Trading hoặc tăng mức `InpMaxRiskRoundUp` trên tài khoản thật. Khi các bộ khác nhau, **đây là bất đồng cần đo lường, không phải hai lệnh trái chiều**.

## Nguồn dữ liệu và đánh giá

- Mỗi **nến M15 đã đóng**: chụp cùng thời điểm `g_dirLastBar == g_syncBar == g_tbSnapshotBar`. Bản v5.45 sử dụng dữ liệu đã tính của v5.44, không tự đọc nến đang hình thành.
- Ghi dòng **F** (forecast) gồm điểm, chiều của từng nhóm, chiều Engine, chiều thực tế được v5.44 cho phép, giá đóng cửa, spread và ATR.
- Sau đúng **4, 8, 16 nến M15 đã đóng**: ghi dòng **R** và phân loại UP/DOWN/FLAT với vùng nhiễu `max(2 × spread, 0,1 × ATR14 M15)`, đồng nhất với bộ đo hướng cũ.
- Dự đoán và thời hạn chưa hoàn tất được lưu trong file pending riêng qua lần khởi động lại. Không tạo ngược dự đoán cho các nến bị bỏ lỡ.
- File mới **độc lập** với `TrendBot_huong_..._M15.csv` phiên bản 5.43/5.44, tránh phá dữ liệu cũ.

Trong MT5 vào **File → Open Data Folder**, tìm thư mục `Terminal\Common\Files`:

- `TrendBot_direction_engine_<account>_<symbol>_<magic>_M15.csv`: nhật ký F/R
- `TrendBot_direction_engine_pending_<account>_<symbol>_<magic>_M15.txt`: các dự đoán còn chờ đủ hạn

Sau khi có dữ liệu từ demo/chế độ theo dõi, từ thư mục repo chạy:

```powershell
python cong-cu/so_sanh_direction_engine.py "C:\duong-dan\TrendBot_direction_engine_<account>_BTCUSDm_<magic>_M15.csv"
```

Báo cáo so sánh **Engine v5.45**, **hướng được phép giao dịch v5.44**, và hai đối chứng **luôn mua / luôn bán**, trên từng mốc 4/8/16. Có tỷ lệ bỏ phiếu, đúng/sai/đi ngang và khoảng Wilson 95% *chưa điều chỉnh phụ thuộc*.

## Kiểm thử trước khi nghĩ đến việc thay v5.44

1. GitHub Actions: static MQL invariants, unit test Python 27 trường hợp biểu quyết, dữ liệu F/R bất biến, kiểm tra no-lookahead và bộ bảo vệ lệnh v5.44 không bị thay đổi. **CI không biên dịch MQL5 bằng MetaEditor thật.**
2. Trên máy ACER: tắt **Algo Trading** nếu kết nối tài khoản thật, cập nhật repo, bấm **F7 MetaEditor** kiểm tra 0 errors. Quan sát chart trên **demo**.
3. Trên demo: sau khi ít nhất 16 nến M15 đóng liên tục (4 giờ), kiểm tra một lô dự đoán đủ hạn. Gửi CSV nếu muốn đánh giá.
4. Không chỉ xét một phiên giảm: lấy nhiều pha thị trường, chia dữ liệu trước/sau theo thời gian, dùng các đoạn **không chồng lấn**, so sánh coverage và accuracy ngoài mẫu. Một mô hình có accuracy cao nhưng rất ít phiếu chưa chắc tốt hơn mô hình cũ.
5. Chỉ sau Strategy Tester với real ticks, phí giao dịch, SL và quản trị vốn mới cân nhắc sửa bộ lọc giao dịch thật trong PR riêng.

**Không có bảo đảm lợi nhuận** từ bất kỳ điểm đồng thuận hay chỉ báo nào. Nếu tài khoản vốn rất nhỏ không đủ lot tối thiểu tại SL hợp lý, tiếp tục từ chối lệnh thay vì tăng rủi ro cho vừa lot.
