# -*- coding: utf-8 -*-
"""Tao cac bo cai dat san trong cai-dat/*.set tu gia tri mac dinh cua bot + phan khac biet cua tung bo.
Moi file ghi DU moi thong so: khi bam Load trong MT5, thong so khong co trong file se GIU gia tri dang co
(khong ve mac dinh), nen file thieu thong so de lai cai dat cua bo nap truoc do.
Chay lai sau khi them / doi thong so cua bot:  python cong-cu/tao_cai_dat.py"""
import glob, os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
from nhan_thong_so import GROUPS  # noqa: E402

SRC = os.path.join(ROOT, "BTC_EMA_Pullback_v2.mq5")
OUT = os.path.join(ROOT, "cai-dat")
ENUMS = {"PERIOD_M1": 1, "PERIOD_M5": 5, "PERIOD_M15": 15, "PERIOD_M30": 30, "PERIOD_H1": 16385, "PERIOD_H4": 16388,
         "PERIOD_D1": 16408, "PERIOD_W1": 32769}
BACKTEST_ONLY = {"InpPreset", "InpTestLabel", "InpExportTFmin"}
# Cai dat rieng cua nguoi dung: KHONG ghi vao bo cai dat san, de Load khong xoa token Telegram, von chia cho bot, ...
PERSONAL_GROUPS = {"12. Nhật ký và kỷ luật giao dịch", "13. Hiển thị và thông báo"}
PERSONAL = {"InpCapital", "InpMagic", "InpManageEverySec"}

# (ten file, [dong ghi chu dau file], {thong so khac mac dinh})
PRESETS = [
    ("01-Chuan-Donchian-H4.set", [
        "01. Cấu hình chuẩn: phá vỡ kênh Donchian H4 (cấu hình C)",
        "Trạng thái: ĐÃ KIỂM THỬ. PF 1,93 (2023–2026) và 2,59 (2020–2023), sụt giảm dưới 5%.",
        "Backtest giá tick thật, vốn 3.000 USD, đã trừ trượt giá 0,05% mỗi lệnh.",
        "Lãi dồn vào ít lệnh lớn: bỏ 5 lệnh tốt nhất thì lợi nhuận giảm mạnh. Cần chạy demo 2–3 tháng trước khi dùng tiền thật.",
        "Vốn khuyến nghị: từ 3.000 USD. 0,01 lot với SL khoảng 3.000 USD/BTC đã rủi ro ~30 USD mỗi lệnh;",
        "vốn nhỏ hơn thì bot bỏ qua tín hiệu (không làm tròn lên lot tối thiểu).",
    ], {}),
    ("02-Tu-bam-lenh-H4.set", [
        "02. Tự bấm lệnh, bot quản lý (khung H4)",
        "Trạng thái: CÔNG CỤ HỖ TRỢ, không phải chiến lược đã kiểm thử.",
        "Bot KHÔNG tự vào lệnh. Bạn bấm BUY / SELL trên chart (bấm 2 lần để xác nhận); bot tính lot theo rủi ro 1%,",
        "đặt SL 2,5 ATR H4, dời SL về hòa vốn, nhồi tối đa 3 lớp khi giá đi thêm 1 ATR, trailing 3 ATR.",
        "Góc phải chart có bảng xu hướng M1 → D1.",
    ], {"InpManualEntry": "true", "InpPyramidMax": "3"}),
    ("03-Bao-ve-lenh-tay.set", [
        "03. Bảo vệ lệnh vào tay",
        "Trạng thái: CÔNG CỤ HỖ TRỢ. Bot không tự vào lệnh, chỉ canh các lệnh bạn vào tay trên mã của chart:",
        "tự đặt SL 1,5% nếu lệnh chưa có SL, giảm lot khi rủi ro trên 3% vốn, đóng lệnh nhồi vào lệnh đang lỗ,",
        "đóng lệnh lỗ giữ quá 24 giờ, lỗ tay quá 5% trong ngày thì đóng hết và khóa lệnh tay tới hết ngày.",
        "Lệnh chờ (Limit / Stop) được sửa ngay khi còn chờ: tự đặt SL, lot quá lớn thì hủy và đặt lại nhỏ hơn,",
        "hủy lệnh chờ nhồi vào lệnh cùng chiều đang lỗ ở giá tệ hơn.",
        "Chốt lời: lời bằng mức rủi ro ban đầu (1R) thì dời SL về hòa vốn, sau đó kéo SL theo giá cách 2 × ATR M15.",
        "Gắn vào một chart bất kỳ của mã đó (khung M1). Chạy được cùng lúc với bot 01 (mã nhận diện khác nhau).",
    ], {"InpTF": "1", "InpAllowBuy": "false", "InpAllowSell": "false", "InpGuardManual": "true"}),
    ("04-Bao-ve-lenh-tay-von-1-trieu.set", [
        "04. Bảo vệ lệnh vào tay cho vốn khoảng 1 triệu VND (38 USD)",
        "Trạng thái: CÔNG CỤ HỖ TRỢ. Như bộ 03 nhưng nới cho vốn nhỏ, vì 0,01 lot BTC là lot nhỏ nhất:",
        "SL 1,5% (~1.100 USD giá) với 0,01 lot đã mất ~29% vốn, nên bộ 03 sẽ đóng mọi lệnh.",
        "Bộ này: lệnh chưa có SL thì đặt SL cách giá vào 0,25% (~180 USD giá, ~5% vốn với 0,01 lot);",
        "chấp nhận tối đa 6% vốn mỗi lệnh, nên SL bạn tự đặt phải cách giá vào không quá ~220 USD với 0,01 lot;",
        "lỗ tay quá 10% trong ngày (khoảng 2 lệnh thua) thì đóng hết và khóa tới hết ngày.",
        "Vẫn chặn nhồi vào lệnh đang lỗ, đóng lệnh lỗ giữ quá 24 giờ, sửa cả lệnh chờ.",
        "Chốt lời: lời 1R thì dời SL về hòa vốn, sau đó kéo SL theo giá cách 2 × ATR M15.",
        "Tự nhồi theo xu hướng: tối đa 3 lớp 0,01 lot; lớp mới khi mọi lớp đã hòa vốn, giá đi thêm 1R và ≥ 5/9 khung cùng chiều.",
        "Gắn vào một chart BTCUSDm bất kỳ. Rủi ro 5–6% mỗi lệnh là cao: 5 lệnh thua liên tiếp mất ~25% vốn.",
    ], {"InpTF": "1", "InpAllowBuy": "false", "InpAllowSell": "false", "InpGuardManual": "true",
        "InpGuardSLPct": "0.25", "InpGuardMaxRiskPct": "6.0", "InpGuardDayLossPct": "10.0", "InpGuardPyramidMax": "3"}),
    ("TN1-Donchian-H4-nhoi-3-lop.set", [
        "TN1. Thử nghiệm: Donchian H4, nhồi tối đa 3 lớp",
        "Trạng thái: CHƯA ĐẠT. Vốn 3.000 USD: +1.740 / +1.926 USD (2023–2026 / 2020–2023), sụt giảm 12% / 9%.",
        "Ở cùng mức sụt giảm không hơn cấu hình 01; tính theo từng đợt xu hướng, t chỉ 1,7. Chỉ chạy demo.",
    ], {"InpPyramidMax": "3"}),
    ("TN2-Donchian-M30-khoi-luong.set", [
        "TN2. Thử nghiệm: Donchian M30, lọc khối lượng nến phá vỡ",
        "Trạng thái: CHƯA ĐẠT. PF 1,51 (2023–2026) nhưng 0,74 (2020–2023). Chỉ chạy demo.",
    ], {"InpTF": "30", "InpUseHTF": "false", "InpBreakMinVol": "1.5", "InpMaxSpreadPoints": "1500"}),
    ("TN3-RSI-M15.set", [
        "TN3. Thử nghiệm: RSI(2) quá mua / quá bán, khung M15",
        "Trạng thái: CHƯA ĐẠT. PF 0,90 (2023–2026), 0,75 (2020–2023). Chỉ chạy demo.",
    ], {"InpStrategy": "2", "InpTF": "15", "InpUseADX": "false", "InpUseTrailing": "false", "InpATRMult": "1.5",
        "InpRR": "1", "InpMaxSpreadPoints": "1500"}),
    ("TN4-ORB-M5-phien-My.set", [
        "TN4. Thử nghiệm: phá vỡ vùng giá 30 phút đầu phiên Mỹ, khung M5",
        "Trạng thái: CHƯA ĐẠT. PF 0,98 (2023–2026), 0,89 (2020–2023). Chỉ chạy demo.",
    ], {"InpStrategy": "3", "InpTF": "5", "InpUseADX": "false", "InpUseHTF": "false", "InpUseTrailing": "false",
        "InpATRMult": "1.0", "InpRR": "2", "InpMaxTradesPerDay": "1", "InpMaxSpreadPoints": "1500"}),
    ("TN5-Wyckoff-M15-von-nho.set", [
        "TN5. Thử nghiệm: Wyckoff spring / upthrust M15 cho vốn nhỏ",
        "Trạng thái: CHƯA ĐẠT. Vốn lớn: PF 0,92 / 0,66. Vốn 1 triệu, rủi ro tới 5%/lệnh: 3 năm +10 USD, sụt giảm 27%.",
        "Với 5%/lệnh, 3 lệnh thua liên tiếp là chạm mức dừng hẳn 15%. Chỉ chạy demo.",
    ], {"InpStrategy": "6", "InpTF": "15", "InpUseADX": "false", "InpUseHTF": "false", "InpUseTrailing": "false",
        "InpMaxRiskRoundUp": "5", "InpMaxSpreadPoints": "1500"}),
    ("TN6-Demo-1-trieu-M5.set", [
        "TN6. Thử nghiệm cho tài khoản demo 1 triệu VND: Donchian M5 (tín hiệu, SL và trailing đều theo M5)",
        "Trạng thái: CHƯA ĐẠT. Donchian M5 lỗ ở cả hai giai đoạn backtest. Chỉ để làm quen cách bot vận hành.",
        "0,01 lot thua khoảng 80–150 nghìn (8–15% tài khoản). Khóa lỗ ngày 20%, dừng hẳn khi sụt 50%",
        "(mức mặc định 3% / 15% sẽ dừng bot sau 1–2 lệnh thua).",
    ], {"InpTF": "5", "InpMaxSpreadPoints": "1500", "InpMaxRiskRoundUp": "20", "InpMaxDailyLossPct": "20",
        "InpMaxDrawdownPct": "50"}),
    ("TN7-Demo-1-trieu-H4-SL-M5.set", [
        "TN7. Thử nghiệm cho tài khoản demo 1 triệu VND: tín hiệu H4 như cấu hình 01, SL và trailing theo ATR M5",
        "Trạng thái: CHƯA CÓ KẾT QUẢ BACKTEST (đợt SLnho-*). SL M5 ~150 USD/BTC, spread ~24 USD/BTC chiếm khoảng 16% mỗi lệnh.",
        "0,01 lot thua khoảng 80–150 nghìn (8–15% tài khoản). Khóa lỗ ngày 20%, dừng hẳn khi sụt 50%.",
    ], {"InpSLTFmin": "5", "InpMaxRiskRoundUp": "20", "InpMaxDailyLossPct": "20", "InpMaxDrawdownPct": "50"}),
]


def defaults():
    pat = re.compile(r'^\s*input\s+(?!group\b)(\w+)\s+(\w+)\s*=\s*(.+?);')
    strat = {}
    d = {}
    for l in open(SRC, encoding="utf-8-sig"):
        m = re.match(r'^\s*(STRAT_\w+)\s*=\s*(\d+)', l)
        if m:
            strat[m.group(1)] = int(m.group(2))
        m = pat.match(l)
        if m:
            typ, name, v = m.group(1), m.group(2), m.group(3).strip()
            if typ == "string":
                v = v.strip('"')
            elif v in ENUMS:
                v = str(ENUMS[v])
            elif v in strat:
                v = str(strat[v])
            elif re.fullmatch(r'[A-Z][A-Z0-9_]*', v):
                sys.exit("Chua biet gia tri so cua %s (%s)" % (v, name))
            d[name] = v
    return d


def main():
    d = defaults()
    version = re.search(r'#define\s+BOT_VERSION\s+"([^"]+)"', open(SRC, encoding="utf-8-sig").read()).group(1)
    keep = set()
    for fname, notes, over in PRESETS:
        bad = [k for k in over if k not in d or k in PERSONAL or k in BACKTEST_ONLY]
        if bad:
            sys.exit("%s: thong so khong co trong bot: %s" % (fname, bad))
        lines = ["; TrendBot – " + notes[0]] + ["; " + n for n in notes[1:]]
        lines.append("; Tạo cho bot %s. Khác mặc định: %s" % (version, ", ".join("%s=%s" % kv for kv in over.items()) or "không có"))
        lines.append("; File ghi đủ thông số giao dịch, để khi Load trong MT5 không còn sót giá trị của bộ nạp trước.")
        lines.append("; Không ghi cài đặt riêng (thông báo, Telegram, nhật ký, vốn dành cho bot, mã nhận diện): Load giữ nguyên.")
        for group, items in GROUPS:
            if group in PERSONAL_GROUPS:
                continue
            names = [n for n, _, _ in items if n not in BACKTEST_ONLY and n not in PERSONAL]
            if not names:
                continue
            lines.append(";")
            lines.append("; --- " + group)
            for name in names:
                lines.append("%s=%s" % (name, over.get(name, d[name])))
        path = os.path.join(OUT, fname)
        with open(path, "wb") as f:   # UTF-16 LE co BOM, xuong dong CRLF: dung dinh dang MT5 tu ghi
            f.write(("\r\n".join(lines) + "\r\n").encode("utf-16"))
        keep.add(fname)
    for f in glob.glob(os.path.join(OUT, "*.set")):
        if os.path.basename(f) not in keep:
            os.remove(f)
            print("Da xoa bo cu:", os.path.basename(f))
    print("Da tao %d bo cai dat." % len(keep))


if __name__ == "__main__":
    main()
