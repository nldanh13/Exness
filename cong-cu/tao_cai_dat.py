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
BACKTEST_ONLY = {"InpPreset", "InpTestLabel", "InpExportTFmin", "InpTrials"}
# Cai dat rieng cua nguoi dung: KHONG ghi vao bo cai dat san, de Load khong xoa token Telegram, von chia cho bot, ...
PERSONAL_GROUPS = {"12. Nhật ký và kỷ luật giao dịch", "13. Hiển thị và thông báo"}
PERSONAL = {"InpCapital", "InpMagic", "InpManageEverySec"}

# (ten file, [dong ghi chu dau file], {thong so khac mac dinh})
PRESETS = [
    ("01-TrendBot-tat-ca-trong-1-M15.set", [
        "01. TẤT CẢ TRONG 1: bot tự giao dịch theo tình huống + bảo vệ lệnh bạn vào tay + nhật ký. Gắn 1 chart BTCUSDm M15.",
        "Vốn khoảng 770 nghìn – 1 triệu VND (~29–38 USD). THỬ NGHIỆM, RỦI RO CAO. Chạy demo trước khi dùng tiền thật.",
        "1) Tự giao dịch (chiến lược 24 Theo tình huống, M15): mỗi nến bot xem thị trường đang ở tình huống nào rồi dùng đúng bộ kiến thức.",
        "   Sắp có tin → đứng ngoài. Xu hướng mạnh → phá vỡ thật, sóng Dow, FVG, order block, premium/discount. Đi ngang → spring, Key Volume, VWAP.",
        "   Chỉ vào 0,01 lot khi lệnh dính SL mất ≤ 6% vốn; setup có SL xa hơn thì BỎ, không tăng rủi ro. Dời hòa vốn ở 1R.",
        "   Lỗ ngày 6% thì khóa tới hết ngày; sụt 15% từ đỉnh thì bot dừng hẳn.",
        "2) Bảo vệ lệnh tay (như bộ 04 cũ): lệnh chưa có SL thì đặt SL cách giá vào 0,25%; lệnh tay rủi ro quá 6% vốn thì giảm lot;",
        "   chặn nhồi vào lệnh đang lỗ; đóng lệnh lỗ giữ quá 24 giờ; lời 1R dời SL hòa vốn rồi kéo SL 2 × ATR M15; sửa cả lệnh chờ.",
        "   Bucket lệnh tay 1%/ngày, thuật toán 2%/ngày, tổng magic 0 khóa ở 10%. Với 0,01 lot, một lệnh thua có thể vượt bucket.",
        "3) Nhật ký (bật sẵn): TrendBot_nhatky.csv (mọi giao dịch) và TrendBot_cantiep.csv (bạn hay bot đã làm gì với từng lệnh).",
    ], {"InpStrategy": "24", "InpTF": "15", "InpUseADX": "false", "InpUseHTF": "false", "InpRR": "2", "InpDowTF": "16408",
        "InpDowLateLegs": "4", "InpChainFullCount": "2", "InpChainOneRisk": "0.5", "InpNewsNFP": "true",
        "InpRiskPercent": "1.0", "InpMaxRiskRoundUp": "6.0", "InpMaxDailyLossPct": "6.0", "InpMaxGroupRiskPct": "6.0", "InpMaxDrawdownPct": "15.0",
        "InpUseBreakeven": "true", "InpBreakevenR": "1.0", "InpUsePartial": "false", "InpTrailSwingBars": "10",
        "InpMaxSpreadPoints": "1500", "InpNewsPreMin": "30",
        "InpGuardManual": "true", "InpGuardSLPct": "0.25", "InpGuardMaxRiskPct": "6.0", "InpGuardDayLossPct": "10.0",
        "InpGuardPyramidMax": "3", "InpGuardPyramidLotFactor": "0.5", "InpGuardHumanDayPct": "1.0", "InpGuardAlgoDayPct": "2.0"}),
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
