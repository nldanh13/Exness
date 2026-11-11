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
    ("04-Bao-ve-lenh-tay-von-1-trieu.set", [
        "04. Bảo vệ lệnh vào tay cho vốn khoảng 1 triệu VND (38 USD)",
        "Trạng thái: CÔNG CỤ HỖ TRỢ. Bot không tự vào lệnh, chỉ canh lệnh bạn vào tay (cả lệnh chờ) trên mã của chart.",
        "0,01 lot BTC là lot nhỏ nhất, nên các mức dưới đây đã nới cho vốn nhỏ.",
        "Bộ này: lệnh chưa có SL thì đặt SL cách giá vào 0,25% (~180 USD giá, ~5% vốn với 0,01 lot);",
        "chấp nhận tối đa 6% vốn mỗi lệnh, nên SL bạn tự đặt phải cách giá vào không quá ~220 USD với 0,01 lot;",
        "lỗ tay quá 10% trong ngày (khoảng 2 lệnh thua) thì đóng hết và khóa tới hết ngày.",
        "Vẫn chặn nhồi vào lệnh đang lỗ, đóng lệnh lỗ giữ quá 24 giờ, sửa cả lệnh chờ.",
        "Chốt lời: lời 1R thì dời SL về hòa vốn, sau đó kéo SL theo giá cách 2 × ATR M15.",
        "Tự nhồi theo xu hướng: tối đa 3 lớp 0,01 lot; lớp mới khi mọi lớp đã hòa vốn, giá đi thêm 1R và ≥ 5/9 khung cùng chiều.",
        "Gắn vào một chart BTCUSDm bất kỳ. Rủi ro 5–6% mỗi lệnh là cao: 5 lệnh thua liên tiếp mất ~25% vốn.",
    ], {"InpTF": "1", "InpAllowBuy": "false", "InpAllowSell": "false", "InpGuardManual": "true",
        "InpGuardSLPct": "0.25", "InpGuardMaxRiskPct": "6.0", "InpGuardDayLossPct": "10.0", "InpGuardPyramidMax": "3"}),
    ("05-Tu-vao-lenh-von-1-trieu-THU-NGHIEM.set", [
        "05. THỬ NGHIỆM: bot tự vào lệnh + bảo vệ, cho vốn khoảng 1 triệu VND",
        "CHẾ ĐỘ TỰ GIAO DỊCH BẬT (InpGuardAutoEntry=true): bot tự mở lệnh mà không cần bạn bấm BUY hoặc SELL.",
        "InpAllowBuy / InpAllowSell = false chỉ tắt chiến lược chính, KHÔNG tắt chế độ tự vào lệnh.",
        "Trạng thái: CHƯA BACKTEST. Chỉ chạy demo để xem kết quả trên số liệu hiện tại.",
        "Như bộ 04 (SL 0,25%, rủi ro tối đa 6%, khóa lỗ ngày 10%, nhồi tối đa 3 lớp),",
        "thêm: bot tự vào 0,01 lot khi ≥ 6/9 khung cùng chiều (bắt buộc có H1 và H4) và nến M5 vừa hồi về EMA20 rồi bật lại.",
        "Chế độ nhanh: không giới hạn số lệnh, không nghỉ sau lệnh thua. Chỉ dừng khi lỗ 10% trong ngày.",
        "Spread ~6 USD mỗi lệnh so với SL ~180 USD: càng nhiều lệnh, phí spread càng ăn vào lãi.",
        "Chốt lời theo khung vào lệnh (M5): hòa vốn ở 1R, kéo SL 2 × ATR M5, TP cố định 2R,",
        "lệnh chưa tới hòa vốn sau 12 nến M5 (1 giờ) thì đóng, không ôm lệnh.",
    ], {"InpTF": "1", "InpAllowBuy": "false", "InpAllowSell": "false", "InpGuardManual": "true",
        "InpGuardSLPct": "0.25", "InpGuardMaxRiskPct": "6.0", "InpGuardDayLossPct": "10.0", "InpGuardPyramidMax": "3",
        "InpGuardAutoEntry": "true", "InpGuardAutoTrend": "6", "InpGuardAutoTFmin": "5",
        "InpGuardAutoMaxDay": "0", "InpGuardAutoCooldownMin": "0",
        "InpGuardTrailTFmin": "0", "InpGuardTPR": "2.0", "InpGuardMaxBars": "12"}),
    ("06-Nhoi-chot-gop-von-1-trieu-THU-NGHIEM.set", [
        "06. THỬ NGHIỆM: như bộ 05 nhưng nhồi sớm hơn và chốt gộp mọi lớp một lượt",
        "CHẾ ĐỘ TỰ GIAO DỊCH BẬT: bot tự mở lệnh mà không cần bạn bấm BUY hoặc SELL. CHƯA BACKTEST, chỉ chạy demo.",
        "SL 0,15% (~110 USD giá, ~3% vốn với 0,01 lot). Lời 0,5R thì dời SL về hòa vốn và nhồi thêm lớp (tối đa 3 lớp).",
        "Chốt gộp: tổng lời mọi lớp đạt 2R thì đóng hết. Ví dụ đủ 3 lớp thì chốt khi giá đi khoảng 1,2R (~130 USD) từ lớp đầu;",
        "chỉ 1 lớp thì chốt khi đi 2R (~220 USD). Không đặt TP từng lớp. Kéo SL 2 × ATR M5 sau khi hòa vốn.",
        "SL gần hơn bộ 05 nên dễ bị quét hơn; spread ~6 USD chiếm khoảng 6% của R.",
    ], {"InpTF": "1", "InpAllowBuy": "false", "InpAllowSell": "false", "InpGuardManual": "true",
        "InpGuardSLPct": "0.15", "InpGuardMaxRiskPct": "6.0", "InpGuardDayLossPct": "10.0", "InpGuardPyramidMax": "3",
        "InpGuardBreakevenR": "0.5", "InpGuardPyramidStepR": "0.5", "InpGuardBasketR": "2.0",
        "InpGuardAutoEntry": "true", "InpGuardAutoTrend": "6", "InpGuardAutoTFmin": "5",
        "InpGuardAutoMaxDay": "0", "InpGuardAutoCooldownMin": "0",
        "InpGuardTrailTFmin": "0", "InpGuardTPR": "0.0", "InpGuardMaxBars": "12"}),
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
