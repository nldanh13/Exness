# ChayThuNghiem.ps1 - Chay lan luot nhieu cau hinh backtest va in bang so sanh
#   powershell -ExecutionPolicy Bypass -File .\ChayThuNghiem.ps1
# Sua danh sach $Runs ben duoi de thu cau hinh khac.

# Mac dinh chay che do NHANH (gia OHLC tung phut, Model=1): nhanh hon nhieu, du dung de loc cau hinh
# cho chien luoc khung H1/H4/D1. Them -ChinhXac de chay tick that (Model=4) cho cau hinh cuoi cung.
# Cac lan chay cung ma / cung khoang ngay / cung von duoc gom thanh 1 dot "Optimization" cua MT5,
# MT5 tu chia cho moi nhan CPU (nhanh gap nhieu lan). Them -TuanTu de chay lan luot tung lan nhu cu.
param([switch]$ChinhXac, [switch]$TuanTu, [string]$Nhom = "file")

$ErrorActionPreference = "Stop"
$Model = if ($ChinhXac) { 4 } else { 1 }
$ModeLabel = if ($ChinhXac) { "tick that (chinh xac)" } else { "OHLC 1 phut (nhanh)" }
$Symbol   = "BTCUSDm"
$Deposit  = 3000
$Leverage = "1:100"
$Years    = 3       # H4/D1 can nhieu nam de du so lenh; MT5 se bat dau tu ngay co du lieu som nhat
$FromDate = (Get-Date).AddYears(-$Years).ToString("yyyy.MM.dd")
$ToDate   = (Get-Date).AddDays(-1).ToString("yyyy.MM.dd")

# Moi lan chay: Ten + cac thong so muon doi (cac thong so khac giu mac dinh trong code)
# $Base: bo loc CHUNG cho moi cau hinh de so sanh cong bang (chi khac nhau o chien luoc / khung)
$Base = @{ InpMaxDrawdownPct = 0; InpUsePartial = "false"; InpUseBreakeven = "false"; InpUseTrailing = "true";
           InpUseADX = "false"; InpSkipWeekend = "false"; InpBlock1Start = -1; InpBlock2Start = -1;
           InpTF = 16388; InpHTF = 16408; InpUseHTF = "true" }
# EMA pullback: SL 2 ATR, TP 2R, trailing tu 1.5R
$Ema  = @{ InpStrategy = 0; InpATRMult = 2.0; InpRR = 2.0; InpTrailStartR = 1.5; InpTrailATRMult = 2.0 }
# Donchian breakout: SL 2.5 ATR, khong TP, trailing 3 ATR tu dau (chandelier)
$Brk  = @{ InpStrategy = 1; InpATRMult = 2.5; InpRR = 0; InpTrailStartR = 0; InpTrailATRMult = 3.0; InpDonchianPeriod = 20 }
# Bo loc cu cua EMA (ADX + bo cuoi tuan + nghi gio tin) de doi chieu
$OldFilters = @{ InpUseADX = "true"; InpSkipWeekend = "true"; InpBlock1Start = 12; InpBlock1End = 14; InpBlock2Start = 18; InpBlock2End = 20 }
function Cfg { $h = $Base.Clone(); foreach ($x in $args) { if ($x) { foreach ($k in $x.Keys) { $h[$k] = $x[$k] } } }; $h }
# Lan 3 (11/2026): kiem tra do ben cua Donchian H4. EMA, D1, H1 da loai o lan 2.
#  - Von 30000: xem lot toi thieu co dang bo bot lenh (so lenh, BoQuaLot, % lai) khong
#  - ETHUSDm: cung tham so tren cap khac (du lieu chua dung de chon)
#  - 2020-2023: giai doan truoc 3 nam da dung de chon (ngoai mau)
# Moi lan co the ghi de: Deposit, Symbol, From, To.
$Q = @{ InpUseADX = "true" }   # C = Donchian20 H4 + ADX
$OOSFrom = (Get-Date).AddYears(-6).ToString("yyyy.MM.dd")
$Runs = @(
    @{ Name = "B-Donchian20-H4";        Inputs = (Cfg $Brk) },
    @{ Name = "C-Donchian20-H4-ADX";    Inputs = (Cfg $Brk @{ InpUseADX = "true" }) },
    @{ Name = "D-Donchian55-H4";        Inputs = (Cfg $Brk @{ InpDonchianPeriod = 55 }) },
    @{ Name = "B-von30000";             Inputs = (Cfg $Brk);                          Deposit = 30000 },
    @{ Name = "C-lamTronLot1.5";        Inputs = (Cfg $Brk @{ InpUseADX = "true"; InpMaxRiskRoundUp = 1.5 }) },   # vao 0.01 lot neu rui ro that <= 1.5%
    @{ Name = "C-lamTronLot1.5-truoc";  Inputs = (Cfg $Brk @{ InpUseADX = "true"; InpMaxRiskRoundUp = 1.5 }); From = $OOSFrom; To = $FromDate },
    @{ Name = "C-lamTronLot1.5-ETH";    Inputs = (Cfg $Brk @{ InpUseADX = "true"; InpMaxRiskRoundUp = 1.5 }); Symbol = "ETHUSDm" },
    @{ Name = "C-von30000";             Inputs = (Cfg $Brk @{ InpUseADX = "true" });  Deposit = 30000 },
    @{ Name = "B-ETH";                  Inputs = (Cfg $Brk);                          Symbol = "ETHUSDm" },
    @{ Name = "C-ETH";                  Inputs = (Cfg $Brk @{ InpUseADX = "true" });  Symbol = "ETHUSDm" },
    @{ Name = "B-truoc-3nam";           Inputs = (Cfg $Brk);                          From = $OOSFrom; To = $FromDate },
    @{ Name = "C-truoc-3nam";           Inputs = (Cfg $Brk @{ InpUseADX = "true" });  From = $OOSFrom; To = $FromDate },
    # Chat luong breakout (them vao C): than nen >= 50%, vuot kenh >= 0.25 ATR, cho 1 nen xac nhan.
    # Chi giu bo loc nao tot hon C o CA 3 noi: 3 nam gan day, 3 nam truoc, ETH.
    @{ Name = "C+than50";               Inputs = (Cfg $Brk $Q @{ InpBreakMinBody = 50 }) },
    @{ Name = "C+than50-truoc";         Inputs = (Cfg $Brk $Q @{ InpBreakMinBody = 50 });  From = $OOSFrom; To = $FromDate },
    @{ Name = "C+than50-ETH";           Inputs = (Cfg $Brk $Q @{ InpBreakMinBody = 50 });  Symbol = "ETHUSDm" },
    @{ Name = "C+vuot0.25ATR";          Inputs = (Cfg $Brk $Q @{ InpBreakMinATR = 0.25 }) },
    @{ Name = "C+vuot0.25ATR-truoc";    Inputs = (Cfg $Brk $Q @{ InpBreakMinATR = 0.25 }); From = $OOSFrom; To = $FromDate },
    @{ Name = "C+vuot0.25ATR-ETH";      Inputs = (Cfg $Brk $Q @{ InpBreakMinATR = 0.25 }); Symbol = "ETHUSDm" },
    @{ Name = "C+xacnhan";              Inputs = (Cfg $Brk $Q @{ InpBreakConfirm = "true" }) },
    @{ Name = "C+xacnhan-truoc";        Inputs = (Cfg $Brk $Q @{ InpBreakConfirm = "true" }); From = $OOSFrom; To = $FromDate },
    @{ Name = "C+xacnhan-ETH";          Inputs = (Cfg $Brk $Q @{ InpBreakConfirm = "true" }); Symbol = "ETHUSDm" },
    # Tu tai lieu thanh khoan: cuoi tuan so lenh mong (khoi luong ~1/2 ngay thuong), de bi quet.
    @{ Name = "C+nghiCuoiTuan";         Inputs = (Cfg $Brk $Q @{ InpSkipWeekend = "true" }) },
    @{ Name = "C+nghiCuoiTuan-truoc";   Inputs = (Cfg $Brk $Q @{ InpSkipWeekend = "true" }); From = $OOSFrom; To = $FromDate },
    @{ Name = "C+nghiCuoiTuan-ETH";     Inputs = (Cfg $Brk $Q @{ InpSkipWeekend = "true" }); Symbol = "ETHUSDm" },
    # Tu tai lieu thanh ly: nen pha vo > 3 ATR thuong la thanh ly day chuyen, vao theo la duoi gia.
    @{ Name = "C+boNenDai3ATR";         Inputs = (Cfg $Brk $Q @{ InpBreakMaxATR = 3 }) },
    @{ Name = "C+boNenDai3ATR-truoc";   Inputs = (Cfg $Brk $Q @{ InpBreakMaxATR = 3 }); From = $OOSFrom; To = $FromDate },
    @{ Name = "C+boNenDai3ATR-ETH";     Inputs = (Cfg $Brk $Q @{ InpBreakMaxATR = 3 }); Symbol = "ETHUSDm" },
    # Funding rate Binance: bo Buy khi funding > 0.03%/8h (phe Long qua dong), bo Sell khi < -0.03%.
    @{ Name = "C+funding";              Inputs = (Cfg $Brk $Q @{ InpUseFunding = "true" }) },
    @{ Name = "C+funding-truoc";        Inputs = (Cfg $Brk $Q @{ InpUseFunding = "true" }); From = $OOSFrom; To = $FromDate },
    @{ Name = "C+funding-ETH";          Inputs = (Cfg $Brk $Q @{ InpUseFunding = "true" }); Symbol = "ETHUSDm" },
    # Tu tai lieu tam ly: bo Buy khi Fear & Greed hom qua >= 76 (tham lam cuc do), bo Sell khi <= 24.
    @{ Name = "C+fearGreed";            Inputs = (Cfg $Brk $Q @{ InpUseFearGreed = "true" }) },
    @{ Name = "C+fearGreed-truoc";      Inputs = (Cfg $Brk $Q @{ InpUseFearGreed = "true" }); From = $OOSFrom; To = $FromDate },
    @{ Name = "C+fearGreed-ETH";        Inputs = (Cfg $Brk $Q @{ InpUseFearGreed = "true" }); Symbol = "ETHUSDm" },
    # Su chu y (Kristoufek 2013): chi vao lenh khi luot xem Wikipedia TB 7 ngay > TB 30 ngay.
    @{ Name = "C+chuY";                 Inputs = (Cfg $Brk $Q @{ InpUseAttention = "true" }) },
    @{ Name = "C+chuY-truoc";           Inputs = (Cfg $Brk $Q @{ InpUseAttention = "true" }); From = $OOSFrom; To = $FromDate },
    @{ Name = "C+chuY-ETH";             Inputs = (Cfg $Brk $Q @{ InpUseAttention = "true" }); Symbol = "ETHUSDm" },
    # Tuong quan voi chung khoan My: Buy chi khi USTEC tren EMA200 D1, Sell chi khi duoi.
    @{ Name = "C+nasdaq";               Inputs = (Cfg $Brk $Q @{ InpUseMarketFilter = "true" }) },
    @{ Name = "C+nasdaq-truoc";         Inputs = (Cfg $Brk $Q @{ InpUseMarketFilter = "true" }); From = $OOSFrom; To = $FromDate },
    @{ Name = "C+nasdaq-ETH";           Inputs = (Cfg $Brk $Q @{ InpUseMarketFilter = "true" }); Symbol = "ETHUSDm" },
    # Tranh tin My co lich (FOMC, CPI): khong vao lenh trong 2 gio truoc/sau. Lich o du-lieu/tin_my.csv.
    @{ Name = "C+tranhTin";             Inputs = (Cfg $Brk $Q @{ InpAvoidUSNews = "true" }) },
    @{ Name = "C+tranhTin-truoc";       Inputs = (Cfg $Brk $Q @{ InpAvoidUSNews = "true" }); From = $OOSFrom; To = $FromDate },
    @{ Name = "C+tranhTin-ETH";         Inputs = (Cfg $Brk $Q @{ InpAvoidUSNews = "true" }); Symbol = "ETHUSDm" },
    # Giam co theo sut giam (tai lieu "Kien thuc nang cao"): khong phai bo loc, chi doi co lenh khi dang sut giam
    @{ Name = "C+giamTheoDD";           Inputs = (Cfg $Brk $Q @{ InpDDScale = "true" }) },
    @{ Name = "C+giamTheoDD-truoc";     Inputs = (Cfg $Brk $Q @{ InpDDScale = "true" }); From = $OOSFrom; To = $FromDate },
    @{ Name = "C+giamTheoDD-ETH";       Inputs = (Cfg $Brk $Q @{ InpDDScale = "true" }); Symbol = "ETHUSDm" },
    # Dung y mac dinh cua EA nhu se chay that (co dung han 15%, lo ngay 3%), khong ghi de gi
    @{ Name = "MacDinh-nhu-chay-that";  Inputs = @{} }
)
# Lan doi chieu: chi kiem tra lenh moi giay (nhanh hon) de do sai khac so voi moi tick (mac dinh)
$Runs += @{ Name = "C-moiGiay"; Inputs = (Cfg $Brk $Q @{ InpManageEverySec = 1 }) }
# Luot song ngan (khung M30, M15, M10, M5, M3, M1): cung cau truc C, von 30000 de lot toi thieu khong bo lenh, chi do xem co loi the sau phi khong.
# Lan 2 da loai H1 (kem H4). Tieu chi dat truoc: PF_Truot0.05% >= 1,3 o CA 3 nam gan day lan 3 nam truoc.
# Che do nhanh (M1 OHLC) khong chinh xac cho khung ngan: ma nao dat phai chay lai bang tick that.
foreach ($tf in @(@{ N = "M30"; V = 30 }, @{ N = "M15"; V = 15 }, @{ N = "M10"; V = 10 }, @{ N = "M5"; V = 5 }, @{ N = "M3"; V = 3 }, @{ N = "M1"; V = 1 })) {
    $Runs += @{ Name = "Ngan-$($tf.N)";       Inputs = (Cfg $Brk $Q @{ InpTF = $tf.V; InpMaxSpreadPoints = 1500 }); Deposit = 30000 }
    $Runs += @{ Name = "Ngan-$($tf.N)-truoc"; Inputs = (Cfg $Brk $Q @{ InpTF = $tf.V; InpMaxSpreadPoints = 1500 }); Deposit = 30000; From = $OOSFrom; To = $FromDate }
    # Them dieu kien khoi luong: nen pha vo co so tick >= 1,5 lan trung binh 20 nen truoc
    $Runs += @{ Name = "Ngan-$($tf.N)+khoiLuong";       Inputs = (Cfg $Brk $Q @{ InpTF = $tf.V; InpBreakMinVol = 1.5; InpMaxSpreadPoints = 1500 }); Deposit = 30000 }
    $Runs += @{ Name = "Ngan-$($tf.N)+khoiLuong-truoc"; Inputs = (Cfg $Brk $Q @{ InpTF = $tf.V; InpBreakMinVol = 1.5; InpMaxSpreadPoints = 1500 }); Deposit = 30000; From = $OOSFrom; To = $FromDate }
}
# Chien thuat luot song khac (tham so co dinh, khong do tim): co TP, khong trailing, vang 30000.
#  - RSI: gia tren EMA200 cua khung nhung RSI(2) < 10 thi mua hoi (nguoc lai voi Sell), SL 1,5 ATR, TP 1R. Thu M5, M15.
#  - ORB: 30 phut dau tu luc New York mo cua 9:30 (13:30 UTC mua he, 14:30 mua dong; server = UTC), pha vo thi vao, SL 1 ATR, TP 2R, 1 lenh/ngay. Thu M5.
# Tieu chi giong phan khung ngan: PF_Truot0.05% >= 1,3 o CA 2 giai doan.
# Luot song khong vao lenh khi spread > 1500 point (15 USD, khoang gap doi binh thuong cua BTCUSDm). Dat truoc, khong do tim.
$Scalp = @{ InpUseADX = "false"; InpUseHTF = "false"; InpUseTrailing = "false"; InpTrailStartR = 0; InpMaxSpreadPoints = 1500 }
$ScalpRuns = @(
    # RSI giu bo loc xu huong D1 (gia D1 dung phia EMA200 D1): EMA200 cua M5 chi ~17 gio du lieu
    @{ N = "RSI-M5";  I = @{ InpStrategy = 2; InpTF = 5;  InpATRMult = 1.5; InpRR = 1; InpUseHTF = "true" } },
    @{ N = "RSI-M15"; I = @{ InpStrategy = 2; InpTF = 15; InpATRMult = 1.5; InpRR = 1; InpUseHTF = "true" } },
    @{ N = "ORB-M5";  I = @{ InpStrategy = 3; InpTF = 5;  InpATRMult = 1.0; InpRR = 2; InpMaxTradesPerDay = 1 } },
    # Dao chieu sau cu chay >= 75% ATR(20) ngay, bat dau hoi thi vao nguoc lai; SL qua dinh/day + 0,3 ATR; TP = dai Bollinger(20) ben kia
    @{ N = "DaoChieu-M5"; I = @{ InpStrategy = 4; InpTF = 5; InpExhaustATR = 0.75 } },
    # FVG: nen lon (>= 2 ATR, tick >= 1,5 lan TB) de lai khoang trong; lan dau gia quay lai thi vao theo huong nen do; SL qua khoang trong 0,5 ATR; TP 2R
    @{ N = "FVG-M30"; I = @{ InpStrategy = 5; InpTF = 30;    InpRR = 2 } },
    @{ N = "FVG-H1";  I = @{ InpStrategy = 5; InpTF = 16385; InpRR = 2 } },
    # Wyckoff spring/upthrust: vung di ngang 20 nen (<= 4 ATR, moi bien cham >= 2 lan), pha ra roi dong lai ben trong; TP = bien ben kia
    @{ N = "Spring-M5";  I = @{ InpStrategy = 6; InpTF = 5 } },
    @{ N = "Spring-M15"; I = @{ InpStrategy = 6; InpTF = 15 } }
)
foreach ($sr in $ScalpRuns) {
    $Runs += @{ Name = "Ngan-$($sr.N)";       Inputs = (Cfg $Brk $Scalp $sr.I); Deposit = 30000 }
    $Runs += @{ Name = "Ngan-$($sr.N)-truoc"; Inputs = (Cfg $Brk $Scalp $sr.I); Deposit = 30000; From = $OOSFrom; To = $FromDate }
}
# Nhoi lenh theo da (y tuong cua ban 07/11): vao khi pha vo Donchian 20, gia di them 1 ATR thi vao them (toi da 3 lenh,
# lenh cu doi SL ve hoa von), nen dong cat EMA20 nguoc chieu thi dong het. Tham so dat truoc, khong do tim.
$Nhoi = @{ InpPyramidMax = 3; InpPyramidStepATR = 1.0; InpExitOnEMA = "true"; InpUseTrailing = "false" }
$Runs += @{ Name = "C+nhoi3";            Inputs = (Cfg $Brk $Q @{ InpPyramidMax = 3; InpPyramidStepATR = 1.0 }) }
$Runs += @{ Name = "C+nhoi3-truoc";      Inputs = (Cfg $Brk $Q @{ InpPyramidMax = 3; InpPyramidStepATR = 1.0 }); From = $OOSFrom; To = $FromDate }
$Runs += @{ Name = "C+nhoi3-ETH";        Inputs = (Cfg $Brk $Q @{ InpPyramidMax = 3; InpPyramidStepATR = 1.0 }); Symbol = "ETHUSDm" }
$Runs += @{ Name = "Nhoi3-H4";           Inputs = (Cfg $Brk $Q $Nhoi) }
$Runs += @{ Name = "Nhoi3-H4-truoc";     Inputs = (Cfg $Brk $Q $Nhoi); From = $OOSFrom; To = $FromDate }
$Runs += @{ Name = "Nhoi3-H4-ETH";       Inputs = (Cfg $Brk $Q $Nhoi); Symbol = "ETHUSDm" }
foreach ($tf in @(@{ N = "H1"; V = 16385 }, @{ N = "M30"; V = 30 }, @{ N = "M15"; V = 15 }, @{ N = "M5"; V = 5 })) {
    $i = Cfg $Brk $Q $Nhoi @{ InpTF = $tf.V; InpMaxSpreadPoints = 1500 }
    $Runs += @{ Name = "Ngan-Nhoi3-$($tf.N)";       Inputs = $i; Deposit = 30000 }
    $Runs += @{ Name = "Ngan-Nhoi3-$($tf.N)-truoc"; Inputs = $i.Clone(); Deposit = 30000; From = $OOSFrom; To = $FromDate }
}
# Da khung: khung lon quyet dinh huong, khung nho chi de vao lenh. Khung nho M30/M15/M5 chi danh theo huong cua
# khung lon (gia H1 hoac H4 dong cua tren/duoi EMA50 cua chinh khung do), thay vi EMA200 D1.
foreach ($c in @(@{ N = "M30"; V = 30; H = "H4"; HV = 16388 }, @{ N = "M15"; V = 15; H = "H4"; HV = 16388 },
                 @{ N = "M15"; V = 15; H = "H1"; HV = 16385 }, @{ N = "M5";  V = 5;  H = "H1"; HV = 16385 })) {
    $i = Cfg $Brk $Q $Nhoi @{ InpTF = $c.V; InpMaxSpreadPoints = 1500; InpUseHTF = "true"; InpHTF = $c.HV; InpHTFEMA = 50 }
    $Runs += @{ Name = "Ngan-Nhoi3-$($c.N)+huong$($c.H)";       Inputs = $i; Deposit = 30000 }
    $Runs += @{ Name = "Ngan-Nhoi3-$($c.N)+huong$($c.H)-truoc"; Inputs = $i.Clone(); Deposit = 30000; From = $OOSFrom; To = $FromDate }
}
# Nhoi lenh buoc 2R (theo nghien cuu Concretum: them 1 lop moi khi gia di them 2 lan khoang rui ro ban dau = 5 ATR)
$Runs += @{ Name = "C+nhoi3-buoc2R";       Inputs = (Cfg $Brk $Q @{ InpPyramidMax = 3; InpPyramidStepATR = 5.0 }) }
$Runs += @{ Name = "C+nhoi3-buoc2R-truoc"; Inputs = (Cfg $Brk $Q @{ InpPyramidMax = 3; InpPyramidStepATR = 5.0 }); From = $OOSFrom; To = $FromDate }
$Runs += @{ Name = "C+nhoi3-buoc2R-ETH";   Inputs = (Cfg $Brk $Q @{ InpPyramidMax = 3; InpPyramidStepATR = 5.0 }); Symbol = "ETHUSDm" }
# Da khung theo Quantpedia (BTC 2018-2025): MACD(12,26,9) H1 cat len thi mua, chi khi MACD D1 dang tang; chi mua (long-only);
# thoat o nen H1 dau tien dong do. Them SL 2,5 ATR de an toan. Ban "-haiChieu" cho ca Sell, ban "-khongLoc" bo loc D1.
$Qp = @{ InpStrategy = 7; InpTF = 16385; InpUseADX = "false"; InpUseHTF = "true"; InpHTF = 16408; InpHTFMacd = "true";
         InpAllowSell = "false"; InpExitOnBar = "true"; InpUseTrailing = "false"; InpTrailStartR = 0; InpRR = 0; InpMaxSpreadPoints = 1500 }
foreach ($v in @(@{ N = "Ngan-MACD-H1+D1"; X = @{} }, @{ N = "Ngan-MACD-H1+D1-haiChieu"; X = @{ InpAllowSell = "true" } },
                 @{ N = "Ngan-MACD-H1-khongLoc"; X = @{ InpUseHTF = "false" } })) {
    $i = Cfg $Brk $Qp $v.X
    $Runs += @{ Name = $v.N;            Inputs = $i;         Deposit = 30000 }
    $Runs += @{ Name = "$($v.N)-truoc"; Inputs = $i.Clone(); Deposit = 30000; From = $OOSFrom; To = $FromDate }
}
# Von that cua ban: 1 trieu VND ~ 38 USD (ty gia ~26.000). Chay lai cac cau hinh luot song uu tien voi von nay,
# 3 nam gan day, de thay BoQuaLot (tin hieu bi bo vi 0,01 lot da rui ro qua 1%) va ket qua that voi tai khoan nho.
# Dot 1756: voi rui ro 1%, gan nhu moi tin hieu bi bo (0 lenh). Ban "-von1tr-rr5": van vao 0,01 lot neu SL mat toi da 5% tai khoan.
$Von1tr = 38
foreach ($n in @("Ngan-RSI-M15", "Ngan-RSI-M5", "Ngan-M15", "Ngan-M30", "Ngan-ORB-M5", "Ngan-M5+khoiLuong", "Ngan-M10+khoiLuong", "Ngan-M15+khoiLuong", "Ngan-M30+khoiLuong",
               "Ngan-DaoChieu-M5", "Ngan-FVG-M30", "Ngan-FVG-H1", "Ngan-Spring-M5", "Ngan-Spring-M15",
               "Ngan-Nhoi3-M15", "Ngan-Nhoi3-M5", "Ngan-Nhoi3-M15+huongH4", "Ngan-Nhoi3-M15+huongH1", "Ngan-Nhoi3-M5+huongH1", "Ngan-MACD-H1+D1")) {
    $src = $Runs | Where-Object { $_.Name -eq $n } | Select-Object -First 1
    if ($src) {
        $Runs += @{ Name = "$n-von1tr"; Inputs = $src.Inputs.Clone(); Deposit = $Von1tr }
        $i5 = $src.Inputs.Clone(); $i5["InpMaxRiskRoundUp"] = 5
        $Runs += @{ Name = "$n-von1tr-rr5"; Inputs = $i5; Deposit = $Von1tr }
        # Luon vao 0,01 lot du rui ro bao nhieu (chi bo khi 1 lenh thua lon hon ca tai khoan): de thay ket qua that
        $i100 = $src.Inputs.Clone(); $i100["InpMaxRiskRoundUp"] = 100
        $Runs += @{ Name = "$n-von1tr-luonVao"; Inputs = $i100; Deposit = $Von1tr }
    }
}
# Chi chay mot phan: file chi-chay.txt (moi dong 1 mau ten, cho phep *), Claude cap nhat khi chi can vai cau hinh.
# Nhom chon tu menu cua nut 1: h4 / luotsong / von1tr / tatca / file (theo chi-chay.txt, mac dinh)
$nhomPats = switch ($Nhom) {
    'h4'       { @($Runs | Where-Object { -not $_.Name.StartsWith("Ngan-") } | ForEach-Object { $_.Name }) }
    'luotsong' { @("Ngan-*", "C-Donchian20-H4-ADX") | Where-Object { $_ } }
    'von1tr'   { @("*-von1tr", "*-von1tr-rr5", "C-Donchian20-H4-ADX") }
    default    { @() }
}
if (-not $ChinhXac -and $Nhom -eq 'luotsong') {
    $Runs = @($Runs | Where-Object { ($_.Name.StartsWith("Ngan-") -and $_.Name -notlike "*-von1tr*") -or $_.Name -eq "C-Donchian20-H4-ADX" })
} elseif (-not $ChinhXac -and $nhomPats.Count -gt 0) {
    $Runs = @($Runs | Where-Object { $n = $_.Name; @($nhomPats | Where-Object { $n -like $_ }).Count -gt 0 })
}
$onlyFile = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "chi-chay.txt"
if (-not $ChinhXac -and $Nhom -eq 'file' -and (Test-Path $onlyFile)) {
    $pats = @(Get-Content $onlyFile | ForEach-Object { $_.Trim() } | Where-Object { $_ -and -not $_.StartsWith("#") })
    if ($pats.Count -gt 0) {
        $Runs = @($Runs | Where-Object { $n = $_.Name; @($pats | Where-Object { $n -like $_ }).Count -gt 0 })
        Write-Host "Chi chay cac cau hinh khop chi-chay.txt." -ForegroundColor Yellow
    }
}
# Ma khung thoi gian: 16385 = H1, 16388 = H4, 16408 = D1, 32769 = W1

# Che do chinh xac: B va C tren 3 nam gan day, ETH va giai doan truoc do (bo von 30000 vi khong phu thuoc tick). Moi cai ~20 phut, tong ~2 gio.
# Che do chinh xac: tick that rat nang (moi agent nap ca trieu tick vao RAM). Tren may it RAM (vd. 8 GB)
# chay song song 12 agent se treo may, nen chi chay 5 cau hinh can thiet va chay LAN LUOT (1 agent).
if ($ChinhXac) {
    # Danh sach chay tick that: file chinh-xac.txt (moi dong 1 ten cau hinh, Claude cap nhat sau moi dot nhanh,
    # vd. cac cau hinh luot song vua dat tieu chi). Khong co file thi dung 5 cau hinh H4 chinh.
    $pick = @("C-Donchian20-H4-ADX", "C-moiGiay", "C-truoc-3nam", "C-ETH", "C-von30000")
    $pickFile = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "chinh-xac.txt"
    if (Test-Path $pickFile) {
        $fromFile = @(Get-Content $pickFile | ForEach-Object { $_.Trim() } | Where-Object { $_ -and -not $_.StartsWith("#") })
        if ($fromFile.Count -gt 0) { $pick = $fromFile }
    }
    $unknown = @($pick | Where-Object { $_ -notin @($Runs | ForEach-Object { $_.Name }) })
    if ($unknown.Count -gt 0) { Write-Host "Khong co cau hinh: $($unknown -join ', ')" -ForegroundColor Yellow }
    $Runs = @($Runs | Where-Object { $_.Name -in $pick })
    $TuanTu = $true
}
Write-Host "Se chay $($Runs.Count) cau hinh." -ForegroundColor Cyan

$ProjectDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $ProjectDir "MT5Common.ps1")

try {
    $mt5 = Find-MT5
    $src = Join-Path $ProjectDir "$BotName.mq5"
    if (-not (Test-Path $src)) { throw "Khong thay $src" }
    $Inputs = Get-BotInputs $src
    foreach ($run in $Runs) { foreach ($k in $run.Inputs.Keys) {
        if (-not $Inputs.Defaults.Contains($k)) { throw "Tham so '$k' trong lan '$($run.Name)' khong co trong bot." } } }
    Write-Host "Doc duoc $($Inputs.Defaults.Count) tham so mac dinh tu bot." -ForegroundColor Green
} catch { Write-Host "LOI: $_" -ForegroundColor Red; exit 1 }

# --- Dong MT5 TRUOC khi compile: compile khi MT5 dang mo se nap lai bot dang chay tren chart ---
if (-not (Stop-MT5 $mt5)) { exit 0 }
try {
    # Luon chep + compile ban moi nhat truoc khi chay
    $r = Invoke-BotCompile $mt5 $src
    if (-not $r.Ok) { $r.Errors | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }; throw "Compile that bai." }
    Write-Host "Da compile ban moi nhat cua bot. $($r.Summary)" -ForegroundColor Green
    Write-Host "Cap nhat du lieu funding rate tu Binance..." -ForegroundColor Cyan
    Update-FundingData $mt5 @("BTCUSDT", "ETHUSDT")
    Update-SentimentData $mt5
    Copy-Item (Join-Path $ProjectDir "du-lieu\tin_my.csv") (Join-Path $mt5.CommonFiles "tin_my.csv") -Force   # lich FOMC + CPI
} catch { Write-Host "LOI: $_" -ForegroundColor Red; exit 1 }
$dataDir    = $mt5.DataDir
$compileLog = $r.Log
$startTime  = Get-Date
# Don bao cao cu cua MT5 (htm/png/ini/xml cua cac lan truoc), de zip chi chua lan nay
Get-ChildItem $dataDir -File -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -like "$BotName-*" -and $_.Extension -in ".htm", ".html", ".png", ".ini", ".xml" } |
    Remove-Item -Force -ErrorAction SilentlyContinue

$resultFile = Join-Path $mt5.CommonFiles "BTC_EMA_results.csv"
if (Test-Path $resultFile) { Remove-Item $resultFile -Force }
$resDirMT5 = Join-Path $mt5.CommonFiles "TrendBotRes"
if (Test-Path $resDirMT5) { Remove-Item (Join-Path $resDirMT5 "*") -Force -ErrorAction SilentlyContinue }
else { New-Item -ItemType Directory -Path $resDirMT5 | Out-Null }
$tradeDirMT5 = Join-Path $mt5.CommonFiles "TrendBotTrades"      # dac diem tung lenh (vao dau / giua / muon xu huong)
if (Test-Path $tradeDirMT5) { Remove-Item (Join-Path $tradeDirMT5 "*") -Force -ErrorAction SilentlyContinue }
else { New-Item -ItemType Directory -Path $tradeDirMT5 | Out-Null }

# Gom cac lan chay theo (ma, tu ngay, den ngay, von): moi nhom 1 dot chay song song.
# So thu tu cau hinh (InpPreset) lien tiep trong moi nhom; bot doc cau hinh tu TrendBot_presets.csv.
$groups = [ordered]@{}
foreach ($run in $Runs) {
    $run.Sym = if ($run.Symbol)  { $run.Symbol }  else { $Symbol }
    $run.Dep = if ($run.Deposit) { $run.Deposit } else { $Deposit }
    $run.Frm = if ($run.From)    { $run.From }    else { $FromDate }
    $run.Tod = if ($run.To)      { $run.To }      else { $ToDate }
    $key = "$($run.Sym)|$($run.Frm)|$($run.Tod)|$($run.Dep)"
    if (-not $groups.Contains($key)) { $groups[$key] = New-Object System.Collections.ArrayList }
    [void]$groups[$key].Add($run)
}
$id = 0
$presetLines = foreach ($g in $groups.Values) { foreach ($run in $g) {
    $id++; $run.Id = $id
    (@("$id", $run.Name) + @($run.Inputs.Keys | Sort-Object | ForEach-Object { "$_=$($run.Inputs[$_])" })) -join ";"
} }
$presetLines | Set-Content -Path (Join-Path $mt5.CommonFiles "TrendBot_presets.csv") -Encoding ASCII
$cacheDir = Join-Path $dataDir "Tester\cache"

$cach = if ($TuanTu) { "lan luot tung lan" } else { "song song, $($groups.Count) dot" }
Write-Host "Chay $($Runs.Count) lan backtest ($cach), che do $ModeLabel. Dung tat MT5." -ForegroundColor Cyan
$j = 0
foreach ($g in $groups.Values) {
    $j++
    $first = $g[0]
    $jobs = New-Object System.Collections.ArrayList
    if ($TuanTu) { foreach ($r in $g) { [void]$jobs.Add(@($r)) } } else { [void]$jobs.Add(@($g)) }
    foreach ($job in $jobs) {
        $a = $job[0].Id; $b = $job[$job.Count - 1].Id
        $names = ($job | ForEach-Object { $_.Name }) -join ", "
        Write-Host "[dot $j/$($groups.Count)] $($first.Sym) $($first.Frm)->$($first.Tod) von $($first.Dep): $names ..." -NoNewline
        # Xoa cache toi uu cua MT5, neu khong MT5 lay ket qua cu va bot khong chay lai (khong ghi file ket qua)
        if (Test-Path $cacheDir) { Get-ChildItem $cacheDir -Filter *.opt -File -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue }
        $ini = Join-Path $dataDir "$BotName-dot$j-$a.ini"
        $opt = @{ Symbol = $first.Sym; From = $first.Frm; To = $first.Tod; Deposit = $first.Dep; Leverage = $Leverage;
                  Report = "$BotName-dot$j-$a"; Shutdown = $true; Model = $Model }
        if ($a -eq $b) { $ov = @{ InpPreset = $a } } else { $ov = @{}; $opt.OptKey = "InpPreset"; $opt.OptFrom = $a; $opt.OptTo = $b }
        New-TesterIni $mt5 $Inputs $ov $ini $opt
        $sw = [Diagnostics.Stopwatch]::StartNew()
        Start-Process -FilePath $mt5.Terminal -ArgumentList "/config:`"$ini`"" -Wait
        Write-Host " xong ($([int]$sw.Elapsed.TotalSeconds)s)" -ForegroundColor Green
    }
}

# Gom file ket qua tung lan (TrendBotRes\001.csv ...) theo dung thu tu trong $Runs
$rows = New-Object System.Collections.ArrayList
$missing = @()
foreach ($run in $Runs) {
    $f = Join-Path $resDirMT5 ("{0:D3}.csv" -f $run.Id)
    if (Test-Path $f) { foreach ($r in @(Import-Csv $f)) { [void]$rows.Add($r) } } else { $missing += $run.Name }
}
# Thieu bat ky cau hinh nao = dot chay CHUA HOAN THANH: van luu de xem, nhung khong day len GitHub, khong dung de chon.
$incomplete = $missing.Count -gt 0
if ($incomplete) {
    Write-Host "LOI: thieu ket qua cua $($missing.Count)/$($Runs.Count) cau hinh: $($missing -join ', ')" -ForegroundColor Red
    Write-Host "Dot chay nay CHUA HOAN THANH: khong day len GitHub. Hay chay lai, hoac gui file zip cho Claude de tim nguyen nhan." -ForegroundColor Red
}
if ($rows.Count -gt 0) { $rows | Export-Csv -Path $resultFile -NoTypeInformation -Encoding ASCII }
$tradeRows = New-Object System.Collections.ArrayList
foreach ($run in $Runs) {
    $f = Join-Path $tradeDirMT5 ("{0:D3}.csv" -f $run.Id)
    if (Test-Path $f) { foreach ($r in @(Import-Csv $f)) { [void]$tradeRows.Add($r) } }
}

Write-Host ""
$summary = Join-Path $ProjectDir "ket-qua-so-sanh.csv"
if (Test-Path $resultFile) {
    Import-Csv $resultFile | Format-Table -AutoSize | Out-String -Width 250 | Write-Host
    Copy-Item $resultFile $summary -Force
    Write-Host "Da luu bang so sanh: $summary" -ForegroundColor Cyan
} else {
    Write-Host "CANH BAO: Khong co file ket qua tong hop. Van gom bao cao + log de Claude chan doan." -ForegroundColor Yellow
    $summary = $null
}
# Gom tat ca ket qua vao 1 file zip de gui
$outDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$pack   = Join-Path $env:TEMP "BTC_EMA_ketqua"
if (Test-Path $pack) { Remove-Item $pack -Recurse -Force }
New-Item -ItemType Directory -Path $pack | Out-Null
if ($summary) { Copy-Item $summary $pack }
# Bao cao HTML/PNG cua cac lan chay
Get-ChildItem $dataDir -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -like "$BotName-*" -and $_.Extension -in ".htm", ".html", ".png", ".ini" } |
    Copy-Item -Destination $pack -ErrorAction SilentlyContinue
# Log chan doan: compile, nhat ky terminal/tester, nhat ky agent (chi phan moi)
$diag = Join-Path $pack "logs"
New-Item -ItemType Directory -Path $diag | Out-Null
if (Test-Path $compileLog) { Copy-Item $compileLog $diag }
$logDirs = @((Join-Path $dataDir "logs"), (Join-Path $dataDir "Tester\logs"), (Join-Path $env:APPDATA "MetaQuotes\Tester"))
$n = 0
foreach ($ld in $logDirs) {
    if (-not (Test-Path $ld)) { continue }
    Get-ChildItem $ld -Recurse -Filter *.log -File -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -ge $startTime.AddMinutes(-5) } |
        Sort-Object LastWriteTime -Descending | Select-Object -First 6 | ForEach-Object {
            $n++
            Get-Content $_.FullName -Tail 3000 | Set-Content (Join-Path $diag ("$n-" + $_.Directory.Name + "-" + $_.Name + ".txt"))
        }
}
$zip = Join-Path $outDir ("ket-qua-backtest-" + (Get-Date -Format "yyyyMMdd-HHmm") + ".zip")
Compress-Archive -Path (Join-Path $pack "*") -DestinationPath $zip -Force
# Chi giu file zip vua tao trong thu muc bot, xoa cac zip cu (ket qua da nam tren GitHub, thu muc ket-qua/)
if (Test-Path $zip) {
    Get-ChildItem $outDir -Filter "ket-qua-backtest-*.zip" -File | Where-Object { $_.FullName -ne $zip } |
        Remove-Item -Force -ErrorAction SilentlyContinue
    # Bao cao htm/png/ini/xml cua MT5 da nam trong zip: xoa luon, khong de lai trong thu muc du lieu MT5
    Get-ChildItem $dataDir -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -like "$BotName-*" -and $_.Extension -in ".htm", ".html", ".png", ".ini", ".xml" } |
        Remove-Item -Force -ErrorAction SilentlyContinue
}
Write-Host ""
Write-Host "==> GUI FILE NAY CHO CLAUDE: $zip" -ForegroundColor Yellow
# Luu bang ket qua vao thu muc ket-qua/ va day len GitHub, de Claude doc thang (khong can gui zip).
# Chi commit dung file nay; khong dung toi thay doi khac cua ban. Loi mang thi van con file zip de gui tay.
if ($summary) {
    $resDir = Join-Path $ProjectDir "ket-qua"
    if (-not (Test-Path $resDir)) { New-Item -ItemType Directory -Path $resDir | Out-Null }
    $tag     = if ($ChinhXac) { "chinhxac" } else { "nhanh" }
    if ($incomplete) { $tag += "-CHUADU" }
    $resName = (Get-Date -Format "yyyyMMdd-HHmm") + "-$tag.csv"
    Copy-Item $summary (Join-Path $resDir $resName) -Force
    $tradeName = $resName -replace '\.csv$', '-lenh.csv'
    if ($tradeRows.Count -gt 0) { $tradeRows | Export-Csv -Path (Join-Path $resDir $tradeName) -NoTypeInformation -Encoding ASCII }
    # Don ket qua cu cung che do (nhanh / chinhxac): chi giu lan moi nhat trong ket-qua/.
    # Ban cu van xem lai duoc trong lich su git. Lan chay CHUA DU chi xoa cac ban CHUA DU cu, khong dung toi ket qua day du.
    $modeTag  = if ($ChinhXac) { "chinhxac" } else { "nhanh" }
    $oldRegex = if ($incomplete) { "^\d{8}-\d{4}-$modeTag-CHUADU(-lenh)?\.csv$" } else { "^\d{8}-\d{4}-$modeTag(-CHUADU)?(-lenh)?\.csv$" }
    $oldFiles = @(Get-ChildItem $resDir -File -Filter "*.csv" -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match $oldRegex -and $_.Name -ne $resName -and $_.Name -ne $tradeName })
    if ($oldFiles.Count -gt 0) {
        $oldFiles | Remove-Item -Force -ErrorAction SilentlyContinue
        Write-Host ("Da xoa {0} file ket qua cu ({1}) trong ket-qua\" -f $oldFiles.Count, $modeTag) -ForegroundColor DarkGray
    }
    if ($incomplete) {
        Write-Host "Da luu ban CHUA DU o ket-qua\$resName (chi tren may, khong day len GitHub)." -ForegroundColor Yellow
    } elseif ((Get-Command git -ErrorAction SilentlyContinue) -and (Test-Path (Join-Path $ProjectDir ".git"))) {
        $rel = "ket-qua/$resName"
        $relT = "ket-qua/$tradeName"
        $paths = @($rel); if (Test-Path (Join-Path $ProjectDir $relT)) { $paths += $relT }
        # File cu da xoa o tren (ca file con sot tu lan truoc khong day duoc): dua viec xoa vao cung commit
        foreach ($t in @(& git -C $ProjectDir ls-files -- "ket-qua" 2>$null)) {
            $leaf = Split-Path $t -Leaf
            if ($leaf -match $oldRegex -and -not (Test-Path (Join-Path $ProjectDir $t))) { $paths += $t }
        }
        # Neu may ban dang co commit chua day len, KHONG day ho (git push day ca nhanh).
        & git -C $ProjectDir fetch -q 2>&1 | Out-Null
        $ahead = [int](& git -C $ProjectDir rev-list --count "@{u}..HEAD" 2>$null)
        if ($ahead -gt 0) {
            $gitOut = @("May ban co $ahead commit chua day len GitHub. De tranh day nham, script khong tu day ket qua.")
            $LASTEXITCODE = 1
        } else { $gitOut = & git -C $ProjectDir add -- $paths 2>&1 }
        if ($LASTEXITCODE -eq 0) { $gitOut = & git -C $ProjectDir commit -q -m "Ket qua backtest $resName" -- $paths 2>&1 }
        # Trong 35-45 phut chay co the da co commit moi tren GitHub: keo ve truoc roi moi day
        if ($LASTEXITCODE -eq 0) { $gitOut = & git -C $ProjectDir pull -q --rebase --autostash 2>&1 }
        if ($LASTEXITCODE -eq 0) { $gitOut = & git -C $ProjectDir push -q 2>&1 }
        # Kiem tra chac chan file da co tren GitHub (khong chi tin ma thoat cua push)
        $onRemote = $false
        if ($LASTEXITCODE -eq 0) {
            & git -C $ProjectDir fetch -q 2>&1 | Out-Null
            & git -C $ProjectDir cat-file -e "@{u}:$rel" 2>&1 | Out-Null
            $onRemote = ($LASTEXITCODE -eq 0)
        }
        if ($onRemote) {
            Write-Host "==> Da day ket qua len GitHub ($rel). Chi can nhan Claude 'xong roi', khong can gui zip." -ForegroundColor Green
        } else {
            Write-Host "Khong day duoc ket qua len GitHub, hay gui file zip:" -ForegroundColor Yellow
            $gitOut | ForEach-Object { Write-Host "    $_" -ForegroundColor Yellow }
        }
    }
}
Invoke-Item $outDir
