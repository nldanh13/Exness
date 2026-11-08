# -*- coding: utf-8 -*-
"""Ghi lai chu thich (nhan hien trong MT5) va thu tu nhom cua cac input trong BTC_EMA_Pullback_v2.mq5
theo bang cong-cu/nhan_thong_so.py, va xuat giai thich ra giao-dien/giai-thich-thong-so.json.
Chi doi chu thich, nhom va thu tu: KHONG doi kieu, ten, gia tri mac dinh (file .set va backtest cu van dung).
Chay:  python cong-cu/viet_lai_nhan.py   (them input moi vao bot thi phai them vao bang, neu khong script bao loi)"""
import json, os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
from nhan_thong_so import GROUPS, STRATEGY_LABELS  # noqa: E402

SRC = os.path.join(ROOT, "BTC_EMA_Pullback_v2.mq5")
INPUT_RE = re.compile(r'^\s*input\s+(?!group\b)(\w+)\s+(\w+)\s*=\s*(.+?);')

raw = open(SRC, "rb").read()
text = raw.decode("utf-8-sig")
nl = "\r\n" if "\r\n" in text else "\n"
lines = text.split(nl)

idx = [i for i, l in enumerate(lines) if re.match(r'^\s*input\b', l)]
first, last = idx[0], idx[-1]
inputs = {}
for i in range(first, last + 1):
    l = lines[i]
    if not l.strip() or re.match(r'^\s*input\s+group\b', l):
        continue
    m = INPUT_RE.match(l)
    if not m:
        sys.exit("Dong %d nam giua cac input nhung khong phai input: %r" % (i + 1, l))
    typ, name, val = m.group(1), m.group(2), m.group(3).strip()
    if name in inputs:
        sys.exit("Input trung ten: " + name)
    inputs[name] = (typ, val)

table = [(g, items) for g, items in GROUPS]
names = [n for _, items in table for n, _, _ in items]
missing = [n for n in inputs if n not in names]
extra = [n for n in names if n not in inputs]
dup = sorted({n for n in names if names.count(n) > 1})
if missing or extra or dup:
    sys.exit("Bang nhan khong khop voi bot.\n  Chua co nhan: %s\n  Khong con trong bot: %s\n  Trung: %s" % (missing, extra, dup))

out = []
for gi, (group, items) in enumerate(table):
    if gi:
        out.append("")
    out.append('input group "%s"' % group)
    for name, label, _ in items:
        typ, val = inputs[name]
        decl = "input %-15s %-19s = %s;" % (typ, name, val)
        out.append("%-55s // %s" % (decl, label))
lines[first:last + 1] = out

# Nhan cua tung chien luoc (hien trong danh sach chon cua MT5)
for i, l in enumerate(lines):
    m = re.match(r'^(\s*)(STRAT_\w+)(\s*=\s*\d+)(\s*,?)\s*(//.*)?$', l)
    if m and m.group(2) in STRATEGY_LABELS:
        head = "%s%-18s = %s%s" % (m.group(1), m.group(2), m.group(3).split("=")[1].strip(), m.group(4).strip())
        lines[i] = "%-28s // %s" % (head, STRATEGY_LABELS[m.group(2)])

new = nl.join(lines)
# UTF-8 co BOM: MetaEditor doc dung tieng Viet co dau; PowerShell 5.1 (Get-Content) cung nhan dung.
open(SRC, "wb").write(b"\xef\xbb\xbf" + new.encode("utf-8"))

help_map = {n: h for _, items in table for n, _, h in items if h}
with open(os.path.join(ROOT, "giao-dien", "giai-thich-thong-so.json"), "w", encoding="utf-8") as f:
    json.dump(help_map, f, ensure_ascii=False, indent=1)
print("Da ghi %d thong so trong %d nhom; %d giai thich." % (len(names), len(table), len(help_map)))
