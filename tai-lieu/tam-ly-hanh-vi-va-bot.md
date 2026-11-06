# Tâm lý học hành vi và bot BTC

Nov 6, 2026 · Duy Anh

Nghiên cứu hành vi giải thích được vì sao bot Donchian có lãi: đám đông phản ứng chậm, đuổi theo xu hướng, và hay chốt lời sớm. Bot đang kiếm lời từ chính các thói quen đó.

- **Momentum và sự chú ý có thật:** BTC có quán tính giá theo tuần, và lượng tìm kiếm Google đi trước lợi nhuận.
- **Chỉ số tâm lý là quan hệ hai chiều:** hữu ích để lọc bối cảnh, không đủ mạnh để làm tín hiệu vào lệnh.
- **Rủi ro hành vi lớn nhất là của người vận hành:** tắt bot giữa chuỗi thua, hoặc tăng rủi ro sau chuỗi thắng.
- **Áp dụng được ngay:** funding rate đã có trong bot. Lượt xem Wikipedia và Fear & Greed là hai phép thử tiếp theo.

## Momentum, bầy đàn và sự chú ý của nhà đầu tư

Nghiên cứu lớn nhất về lợi nhuận crypto cho thấy BTC có **quán tính giá** (momentum) rõ, và mức chú ý của công chúng đi trước giá. Đây là cơ sở hành vi cho chiến lược Donchian đang dùng.

- **Momentum:** theo [Liu & Tsyvinski](https://cepr.org/voxeu/columns/risks-and-returns-cryptocurrencies), tuần nào BTC tăng mạnh hơn bình thường một độ lệch chuẩn thì tuần sau lợi nhuận cao hơn khoảng 3,16%. Giá đi theo đà vì người mua đến muộn và đuổi theo.
- **Sự chú ý:** lượng tìm kiếm Google về Bitcoin tăng một độ lệch chuẩn thì lợi nhuận tuần sau cao hơn khoảng 1,84% (cùng nguồn).
- **Bầy đàn ở cấp giao dịch:** [Gemayel & Preda (2024)](https://scholars.ln.edu.hk/en/publications/herding-in-the-cryptocurrency-market-a-transaction-level-analysis/) phân tích từng lệnh và thấy hiện tượng bầy đàn mạnh hơn khi thị trường giảm. Phần lớn là người giao dịch lặp lại hành vi của chính mình, không chỉ sao chép người khác. Bầy đàn trong crypto cũng kéo dài ngắn hơn thị trường truyền thống.

Ý nghĩa cho bot: lợi thế của breakout đến từ việc đám đông phản ứng chậm rồi dồn theo. Bầy đàn mạnh hơn lúc giảm giải thích vì sao lệnh Sell của bot vẫn có lãi trong năm 2022.

## Đo tâm lý đám đông

Các chỉ số tâm lý có liên hệ với giá, nhưng phần lớn là quan hệ hai chiều: giá tăng làm tâm lý hưng phấn, và ngược lại. Vì vậy chúng hữu ích để nhận biết bối cảnh hơn là làm tín hiệu vào lệnh.

| Chỉ số | Kết quả nghiên cứu | Hạn chế |
| --- | --- | --- |
| Google Trends, lượt xem Wikipedia | Tương quan với giá BTC khoảng 0,88 và 0,83. Khi giá trên xu hướng ngắn hạn, chú ý tăng đẩy giá lên; khi giá dưới xu hướng, chú ý tăng lại đẩy giá xuống ([Kristoufek 2013](https://www.nature.com/doifinder/10.1038/srep03415)) | Dữ liệu 2011–2013, khi thị trường còn rất nhỏ |
| Fear & Greed Index | Dự báo được lợi nhuận BTC và ETH, nhưng có vòng phản hồi: lợi nhuận cũng tác động ngược lại chỉ số ([Cavalheiro, Vieira & Thue 2024](https://ideas.repec.org/a/eme/rbfpps/rbf-08-2023-0224.html)) | Chỉ 1 năm dữ liệu tuần (7/2022–6/2023) |
| Funding rate (đã thêm vào bot) | Đo trực tiếp đám đông dùng đòn bẩy đang nghiêng về phía nào | Chỉ của Binance, chưa kiểm thử trên bot |

Phát hiện đáng chú ý nhất là tính bất đối xứng của Kristoufek: cùng một mức "gây chú ý" nhưng tác động ngược nhau tùy giá đang ở trên hay dưới xu hướng. Điều này khớp với cách bot chỉ vào lệnh theo hướng EMA200.

## Thiên kiến cá nhân và tâm lý người vận hành bot

Người nắm BTC cũng có xu hướng **chốt lời sớm, gồng lỗ lâu** (disposition effect), rõ nhất từ năm 2017 trở đi ([Bitcoin Trading is Irrational!, arXiv 2020](https://arxiv.org/abs/2010.12415)). Mức độ thay đổi theo thời gian chứ không cố định.

- **Bot đang làm ngược lại thiên kiến này:** cắt lỗ cố định ở 2,5 ATR và để lãi chạy bằng trailing, không đặt TP. Tỷ lệ thắng chỉ khoảng 40% nhưng lệnh thắng trung bình gấp khoảng 2,7 lần lệnh thua.
- **Rủi ro tâm lý lớn nhất nằm ở người vận hành:** với tỷ lệ thắng 40%, chuỗi 5–8 lệnh thua liên tiếp là bình thường. Sợ lỗ khiến người ta tắt bot đúng lúc đó, rồi bỏ lỡ lệnh thắng lớn bù lại cả chuỗi.
- **Quá tự tin sau vài lệnh thắng:** dễ dẫn đến tăng `InpRiskPercent` hoặc vốn. Nên giữ nguyên rủi ro 1% trong ít nhất 50 lệnh đầu trên demo.
- **Đuổi theo kết quả gần nhất:** sửa cấu hình sau mỗi tuần thua là một dạng thiên kiến. Mọi thay đổi phải qua quy trình 3 bộ dữ liệu như hiện tại.

Một quy tắc nên đặt trước khi chạy tiền thật: chỉ dừng bot khi sụt giảm vượt mức Monte Carlo 95% trong bảng kết quả, không dừng vì cảm giác.

## Ra quyết định khi có rủi ro

Người ta đánh giá lại/lỗ so với một mốc tham chiếu, đau vì lỗ nhiều hơn vui vì lãi cùng mức, và đánh giá quá cao cơ hội nhỏ nhưng lợi lớn. Đây là lý thuyết triển vọng (prospect theory) của Kahneman và Tversky (1979), nền tảng của cuốn *Thinking, Fast and Slow*.

- **Ưa thích "vé số":** trong crypto, nhà đầu tư chạy theo các đồng có khả năng tăng vọt, và mức độ này thay đổi theo thời gian và theo từng loại coin ([Zhao, Wang & Liu 2024](https://ideas.repec.org/a/eee/intfin/v91y2024ics1042443124000234.html)).
- **Mốc tham chiếu:** đỉnh cũ, giá tròn (100.000 USD) và giá mua vào trở thành nơi nhiều người đặt lệnh. Breakout qua đỉnh 20 nến cũng là một mốc như vậy, nên dễ kích hoạt lệnh dừng lỗ và lệnh đuổi theo.
- **Cho chính bạn:** vì sợ lỗ mạnh hơn ham lãi, nên quyết định trước các quy tắc (rủi ro 1%, khi nào dừng bot), rồi để bot làm theo, thay vì quyết định lúc đang thua.

## Phong tục, lịch và hành vi tiêu dùng

Các hiệu ứng theo lịch và văn hóa trên BTC có xuất hiện, nhưng không ổn định đủ để bot giao dịch theo. Ngoại lệ duy nhất đáng kiểm thử là thanh khoản cuối tuần.

| Hiệu ứng | Bằng chứng | Kết luận cho bot |
| --- | --- | --- |
| Giờ trong ngày | Giao dịch sôi động hơn khi sàn chứng khoán Mỹ mở cửa, thấp nhất từ nửa đêm đến sáng sớm ([Baur, Cahill, Godfrey & Liu 2017](https://research-repository.uwa.edu.au/en/publications/bitcoin-time-of-day-day-of-week-and-month-of-year-effects-in-retu/)) | Bot khung H4 ít bị ảnh hưởng. Không thêm bộ lọc giờ |
| Ngày trong tuần | Khối lượng cuối tuần thấp hơn, lợi nhuận thứ Hai cao hơn, nhưng "không có mẫu hình nhất quán" qua thời gian ([Quantpedia tóm tắt](https://quantpedia.com/are-there-any-simple-calendar-effects-in-bitcoin-market/)) | Đã có phép thử "nghỉ cuối tuần" trong lượt so sánh |
| Tết Âm lịch | Giả thuyết người châu Á bán BTC lấy tiền tiêu Tết, nhưng chỉ dựa trên khoảng 5 năm quan sát và chưa được kiểm định thống kê ([Decrypt](https://decrypt.co/17439/does-the-chinese-new-year-really-affect-bitcoins-price)) | Quá ít mẫu, không đưa vào bot |
| Tháng trong năm, mùa thuế | Nghiên cứu trên không tìm thấy mẫu hình bền vững | Không đưa vào bot |

Về hành vi tiêu dùng: mình chưa tìm được nghiên cứu có dữ liệu nào liên kết chi tiêu, ngày lương hay mùa mua sắm với giá BTC. Với một hiệu ứng chỉ xảy ra vài lần mỗi năm, backtest 6 năm chỉ có vài chục điểm dữ liệu, dễ thấy mẫu hình do ngẫu nhiên.

## Thao túng thị trường

Thao túng trên BTC đã được ghi nhận trong các tạp chí tài chính hàng đầu. Bot không chống lại được, nhưng có thể tránh dựa vào những dữ liệu dễ bị làm giả.

| Hình thức | Bằng chứng | Bot tự bảo vệ thế nào |
| --- | --- | --- |
| Giao dịch ảo (wash trading) | Khảo sát 29 sàn năm 2019: trung bình 77,5% khối lượng trên sàn không được quản lý là giả, sàn có quản lý thì rất ít ([Cong, Li, Tang & Yang, NBER](https://www.kitco.com/news/article/2022-12-29/wash-trading-rampant-unregulated-crypto-exchanges-nber-study)) | Bot không dùng khối lượng để ra quyết định. Không nên thêm chỉ báo dựa trên volume |
| Bot giao dịch giả trên sàn | Mt. Gox 2013: hai bot "Markus" và "Willy" mua bằng BTC không có thật. Ngày có giao dịch đáng ngờ giá tăng khoảng 4%, có thể đã đẩy BTC từ 150 lên hơn 1.000 USD ([Gandal, Hamrick, Moore & Oberman](https://techcrunch.com/2018/01/15/researchers-finds-that-one-person-likely-drove-bitcoin-from-150-to-1000)) | Thị trường nay lớn hơn nhiều nên khó lặp lại ở quy mô đó. Giới hạn sụt giảm 15% và lỗ ngày 3% vẫn là lớp bảo vệ cuối |
| Đẩy giá bằng stablecoin | 2017–2018: khoảng 87 giờ (dưới 1% thời gian) đóng góp khoảng 50% mức tăng của BTC, gắn với dòng Tether sau các đợt giảm ([Griffin & Shams, Journal of Finance 2020](https://quantpedia.com/a-very-influential-paper-about-tether-bitcoin-relationship-manipulation/)). Tác giả nói đây là "phù hợp với" thao túng, không phải bằng chứng chắc chắn | Bot đi theo xu hướng nên có thể ăn theo đợt đẩy giá, nhưng cũng chịu khi nó đảo chiều. Trailing 3 ATR giới hạn phần lãi bị trả lại |
| Quét stop (đẩy giá qua mốc rồi quay đầu) | Hay được nhắc trong giới giao dịch, nhưng mình chưa tìm được nghiên cứu đo lường trên BTC | Bot chỉ xét giá **đóng cửa** nến H4 nên râu nến quét qua đỉnh không kích hoạt lệnh. SL 2,5 ATR cũng xa các mốc tròn dễ bị nhắm. Phép thử "xác nhận thêm 1 nến" và "bỏ nến quá dài" đang chờ kết quả |

Lưu ý riêng cho Exness: giá BTCUSDm là giá CFD do Exness lấy từ các nguồn thanh khoản, không phải sổ lệnh mở. Một đợt thao túng trên sàn lớn vẫn truyền sang giá này, kèm spread giãn rộng.

## Tương quan với các tài sản khác

BTC có ảnh hưởng qua lại với chứng khoán Mỹ và đồng đô la, nhưng mức độ thay đổi mạnh theo từng giai đoạn. Vì vậy tương quan hữu ích để quản lý rủi ro hơn là để ra tín hiệu.

| Tài sản | Tương quan với BTC | Độ ổn định |
| --- | --- | --- |
| Chứng khoán Mỹ (S&P 500) | Gần 0 (0,01) giai đoạn 2017–2019, tăng lên 0,36 giai đoạn 2020–2021. BTC giải thích khoảng 1/10 biến động lợi nhuận S&P 500 ([IMF 2022](https://www.imf.org/en/blogs/articles/2022/01/11/crypto-prices-move-more-in-sync-with-stocks-posing-new-risks/index.md)) | Tăng từ khi tổ chức lớn tham gia, nhưng thay đổi theo giai đoạn |
| Đồng đô la (DXY) | Ngược chiều khoảng −0,45 trong 30 ngày (cuối 2025), có lúc về gần 0 chỉ trong vài tuần ([CryptoSlate](https://cryptoslate.com/does-a-weaker-dollar-drive-bitcoin-price-now/)). Trên khung dài hơn 180 ngày, liên hệ gần như biến mất ([Al-Mansouri 2025](https://mdpi.com/1911-8074/18/5/259)) | Không ổn định, yếu hơn vàng và cổ phiếu |
| Lãi suất thực Mỹ 10 năm | Ngược chiều khoảng −0,38 trong 30 ngày (cùng nguồn CryptoSlate) | Thay đổi theo giai đoạn, hay đổi quanh các kỳ họp Fed |
| Vàng | Vàng ngược chiều đô la rất ổn định, BTC thì không (Al-Mansouri 2025) | BTC chưa đóng vai "vàng kỹ thuật số" một cách nhất quán |
| ETH | Bot cùng tham số có lãi trên cả BTC và ETH trong backtest, nghĩa là hai đồng thường cùng xu hướng | Cao, nhưng mình chưa đọc nguồn đo con số cụ thể |

**Áp dụng cho bot:**

- **Không chạy BTC và ETH cùng lúc với rủi ro 1% mỗi bên.** Hai đồng thường cùng xu hướng nên thực chất là gần 2% rủi ro cho cùng một đợt biến động. Nếu chạy cả hai, hãy giảm mỗi bên còn 0,5%.
- **Có thể kiểm thử trong MT5:** Exness có sẵn chỉ số Nasdaq (`USTEC`) và vàng (`XAUUSD`), nên một bộ lọc kiểu "chỉ Buy BTC khi Nasdaq cũng trên EMA200" backtest được, khác với funding hay on-chain. Mình chưa làm vì tương quan quá thay đổi: có giai đoạn gần 0, nên bộ lọc dễ chỉ đẹp trên một đoạn dữ liệu.
- **Tin vĩ mô của Mỹ** (kỳ họp Fed, CPI) là lúc tương quan với đô la và lãi suất thay đổi nhiều nhất. Bot đã có sẵn các khung giờ nghỉ tin (`InpBlock1Start`, `InpBlock2Start`) nếu bạn muốn tránh.

## Áp dụng vào bot

Ba giả thuyết có cơ sở từ tài liệu và kiểm thử được bằng dữ liệu miễn phí. Mỗi cái chỉ được bật nếu tốt hơn cấu hình C ở cả 3 nơi: 3 năm gần đây, 3 năm trước đó và ETH.

| Giả thuyết | Cơ sở | Dữ liệu | Trạng thái |
| --- | --- | --- | --- |
| Bỏ Buy khi đám đông dùng đòn bẩy quá nghiêng về Long | Bầy đàn, thanh lý dây chuyền | Funding rate Binance | Đã có trong bot (v3.6), đang chờ chạy thử |
| Breakout đáng tin hơn khi sự chú ý của công chúng đang tăng | Liu & Tsyvinski, Kristoufek | Lượt xem Wikipedia "Bitcoin" theo ngày | Chưa làm |
| Không mua khi tham lam cực độ, không bán khi sợ hãi cực độ | Vòng phản hồi tâm lý – giá | Fear & Greed Index theo ngày, từ 2018 | Chưa làm |

**Điều không nên làm:**

- Không dùng chỉ số tâm lý làm tín hiệu vào lệnh riêng. Bằng chứng dự báo còn yếu và hai chiều, chỉ nên dùng để lọc bớt.
- Không chọn ngưỡng sau khi xem kết quả (ví dụ thử Fear & Greed 70, 75, 80 rồi giữ cái đẹp nhất). Đặt một ngưỡng theo lý do trước, rồi thử.
- Không dựa vào dữ liệu chỉ có 1–2 năm. Nghiên cứu Fear & Greed ở trên chỉ dùng 1 năm dữ liệu.

## Nguồn tham khảo

- [Liu & Tsyvinski, Risks and Returns of Cryptocurrency (tóm tắt trên VoxEU)](https://cepr.org/voxeu/columns/risks-and-returns-cryptocurrencies)
- [Kristoufek (2013), BitCoin meets Google Trends and Wikipedia, Scientific Reports](https://www.nature.com/doifinder/10.1038/srep03415)
- [Cavalheiro, Vieira & Thue (2024), Fear & Greed Index và lợi nhuận BTC/ETH, Review of Behavioral Finance](https://ideas.repec.org/a/eme/rbfpps/rbf-08-2023-0224.html)
- [Gemayel & Preda (2024), Herding in the cryptocurrency market: a transaction-level analysis](https://scholars.ln.edu.hk/en/publications/herding-in-the-cryptocurrency-market-a-transaction-level-analysis/)
- [Bitcoin Trading is Irrational! An Analysis of the Disposition Effect in Bitcoin (arXiv 2020)](https://arxiv.org/abs/2010.12415)

* [Baur, Cahill, Godfrey & Liu (2017), Bitcoin time-of-day, day-of-week and month-of-year effects](https://research-repository.uwa.edu.au/en/publications/bitcoin-time-of-day-day-of-week-and-month-of-year-effects-in-retu/)
* [Quantpedia, Are There Any Simple Calendar Effects in Bitcoin Market?](https://quantpedia.com/are-there-any-simple-calendar-effects-in-bitcoin-market/)
* [Decrypt, Does the Chinese New Year really affect Bitcoin's price?](https://decrypt.co/17439/does-the-chinese-new-year-really-affect-bitcoins-price)
* [Zhao, Wang & Liu (2024), Lottery-like preference in the cryptocurrency market](https://ideas.repec.org/a/eee/intfin/v91y2024ics1042443124000234.html)

- [Cong, Li, Tang & Yang, Crypto Wash Trading (NBER, tóm tắt trên Kitco)](https://www.kitco.com/news/article/2022-12-29/wash-trading-rampant-unregulated-crypto-exchanges-nber-study)
- [Gandal, Hamrick, Moore & Oberman, Price Manipulation in the Bitcoin Ecosystem (tóm tắt trên TechCrunch)](https://techcrunch.com/2018/01/15/researchers-finds-that-one-person-likely-drove-bitcoin-from-150-to-1000)
- [Griffin & Shams, Is Bitcoin Really Un-Tethered? (tóm tắt trên Quantpedia)](https://quantpedia.com/a-very-influential-paper-about-tether-bitcoin-relationship-manipulation/)

* [IMF (2022), Crypto Prices Move More in Sync With Stocks, Posing New Risks](https://www.imf.org/en/blogs/articles/2022/01/11/crypto-prices-move-more-in-sync-with-stocks-posing-new-risks/index.md)
* [CryptoSlate, Does a weaker dollar drive Bitcoin price now?](https://cryptoslate.com/does-a-weaker-dollar-drive-bitcoin-price-now/)
* [Al-Mansouri (2025), Bitcoin vs. the US Dollar: wavelet analysis, JRFM](https://mdpi.com/1911-8074/18/5/259)

Một số nguồn chỉ đọc được phần tóm tắt, không phải toàn văn.
