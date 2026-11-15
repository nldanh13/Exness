//+------------------------------------------------------------------+
//| TrendBot/Learn.mqh: Hoc tu thuc chien (v5.36)
//+------------------------------------------------------------------+
// Bot ap dung kien thuc vao thuc chien, LUU LAI ket qua cua chinh no, roi dung du lieu do cho cac quyet dinh sau - khong dua vao
// backtest du lieu cu. Don vi hoc = cap (tinh huong, chien luoc) cua che do Theo tinh huong (chien luoc 24).
//  - Lenh giay: MOI setup bot thay (ca setup khong vao lenh, setup bi bo loc chan, setup trai chieu) duoc theo doi tren khung chinh
//    tu gia dong cua nen tin hieu: cham SL = -1R, cham TP (TP cua setup, khong co thi 2R) = +R, qua InpLearnMaxBars nen = R tam tinh.
//    Cung nen cham ca SL va TP: tinh SL (bi quan). Lenh that qua it de hoc nhanh nen dung lenh giay lam du lieu chinh.
//  - Lenh that: R thuc te (sau phi, hoa von, chot phan...) cua lenh bot vao, ghi rieng de doi chieu voi lenh giay.
//  - Danh gia moi cap khi da du InpLearnMinN lenh giay (R trung binh m, can duoi 90% LB = m - 1,28 sd / can n):
//      chua du du lieu -> "dang thu":  van dung kien thuc, rui ro x InpLearnTryRisk
//      LB > 0          -> "tin dung":  rui ro du
//      m > 0, LB <= 0  -> "chua chac": rui ro x 0,75
//      m <= 0          -> "loai":      khong dung chien luoc nay trong tinh huong nay (van theo doi lenh giay de tu phuc hoi)
//  - Luu: Common\Files\TrendBot_hoc_<tai khoan>_<ma>.csv (thoi gian,tinh huong,chien luoc,chieu,R,loai) - doc lai khi khoi dong.
//    Backtest: hoc trong bo nho (khong doc / ghi file), de kiem tra chinh co che hoc.
#define LRN_SIT 8
#define LRN_STR 32
struct LVT { datetime t; int sit; int strat; int dir; double entry; double sl; double tp; double risk; int bars; };
LVT      g_lvt[];
int      g_ln[LRN_SIT][LRN_STR], g_lw[LRN_SIT][LRN_STR], g_rn[LRN_SIT][LRN_STR];
double   g_ls[LRN_SIT][LRN_STR], g_ls2[LRN_SIT][LRN_STR], g_rs[LRN_SIT][LRN_STR];
bool     g_lrnLoaded = false;
datetime g_lrnBar = 0;
int      g_sigMember = -1;                 // chien luoc thanh vien dung dau cua lenh vua vao (de gan ket qua lenh that)

string LearnFile() { return StringFormat("TrendBot_hoc_%I64d_%s.csv", AccountInfoInteger(ACCOUNT_LOGIN), _Symbol); }
bool LearnKeyOk(const int sit, const int st) { return sit >= 0 && sit < LRN_SIT && st >= 0 && st < LRN_STR; }
void LearnStat(const int sit, const int st, const double r, const bool real)
{
   if(!LearnKeyOk(sit, st)) return;
   if(real) { g_rn[sit][st]++; g_rs[sit][st] += r; return; }
   g_ln[sit][st]++; g_ls[sit][st] += r; g_ls2[sit][st] += r * r;
   if(r > 0) g_lw[sit][st]++;
}
void LearnLoad()
{
   if(g_lrnLoaded) return;
   g_lrnLoaded = true;
   ArrayInitialize(g_ln, 0); ArrayInitialize(g_lw, 0); ArrayInitialize(g_rn, 0);
   ArrayInitialize(g_ls, 0); ArrayInitialize(g_ls2, 0); ArrayInitialize(g_rs, 0);
   if(MQLInfoInteger(MQL_TESTER) || !FileIsExist(LearnFile(), FILE_COMMON)) return;
   int h = FileOpen(LearnFile(), FILE_READ | FILE_TXT | FILE_ANSI | FILE_COMMON | FILE_SHARE_READ | FILE_SHARE_WRITE);
   if(h == INVALID_HANDLE) return;
   int rows = 0;
   while(!FileIsEnding(h))
   {
      string p[];
      if(StringSplit(FileReadString(h), ',', p) < 6 || p[0] == "ThoiGian") continue;
      LearnStat((int)StringToInteger(p[1]), (int)StringToInteger(p[2]), StringToDouble(p[4]), p[5] == "that");
      rows++;
   }
   FileClose(h);
   if(rows > 0) PrintFormat("Hoc tu thuc chien: nap %d ket qua tu %s", rows, LearnFile());
}
void LearnSave(const int sit, const int st, const int dir, const double r, const bool real)
{
   if(MQLInfoInteger(MQL_TESTER)) return;
   bool isNew = !FileIsExist(LearnFile(), FILE_COMMON);
   int h = FileOpen(LearnFile(), FILE_READ | FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_COMMON | FILE_SHARE_READ);
   if(h == INVALID_HANDLE) return;
   FileSeek(h, 0, SEEK_END);
   if(isNew) FileWriteString(h, "ThoiGian,TinhHuong,ChienLuoc,Chieu,R,Loai\r\n");
   FileWriteString(h, StringFormat("%s,%d,%d,%d,%.3f,%s\r\n", TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES), sit, st, dir, r, real ? "that" : "giay"));
   FileClose(h);
}
// Dang ky 1 lenh giay cho setup vua thay (moi cap tinh huong / chien luoc / chieu chi 1 lenh giay mo moi nen)
void LearnRegister(const int sit, const int st, const int dir, const double entry, const double slDist, const double tpPx)
{
   if(!P_Learn || slDist <= 0 || entry <= 0 || !LearnKeyOk(sit, st)) return;
   LearnLoad();
   datetime t = iTime(_Symbol, P_TF, 0);
   int n = ArraySize(g_lvt);
   for(int i = 0; i < n; i++) if(g_lvt[i].t == t && g_lvt[i].sit == sit && g_lvt[i].strat == st && g_lvt[i].dir == dir) return;
   if(n >= 300) return;
   ArrayResize(g_lvt, n + 1);
   g_lvt[n].t = t; g_lvt[n].sit = sit; g_lvt[n].strat = st; g_lvt[n].dir = dir; g_lvt[n].entry = entry;
   g_lvt[n].risk = slDist; g_lvt[n].sl = entry - dir * slDist;
   g_lvt[n].tp = (dir > 0 ? tpPx > entry : (tpPx > 0 && tpPx < entry)) ? tpPx : entry + dir * 2.0 * slDist;
   g_lvt[n].bars = 0;
}
// Cham lenh giay: goi moi tick, chi lam viec khi co nen moi tren khung chinh
void LearnUpdate()
{
   if(!P_Learn) return;
   LearnLoad();
   datetime b = iTime(_Symbol, P_TF, 0);
   if(b == 0 || b == g_lrnBar) return;
   g_lrnBar = b;
   datetime t1 = iTime(_Symbol, P_TF, 1);
   double h = iHigh(_Symbol, P_TF, 1), l = iLow(_Symbol, P_TF, 1), c = iClose(_Symbol, P_TF, 1);
   for(int i = ArraySize(g_lvt) - 1; i >= 0; i--)
   {
      if(t1 < g_lvt[i].t) continue;                                   // chua co nen nao dong sau nen tin hieu
      g_lvt[i].bars++;
      int d = g_lvt[i].dir;
      double r = 0; bool done = false;
      if(d > 0 ? l <= g_lvt[i].sl : h >= g_lvt[i].sl) { r = -1; done = true; }
      else if(d > 0 ? h >= g_lvt[i].tp : l <= g_lvt[i].tp) { r = (g_lvt[i].tp - g_lvt[i].entry) * d / g_lvt[i].risk; done = true; }
      else if(g_lvt[i].bars >= P_LearnMaxBars) { r = (c - g_lvt[i].entry) * d / g_lvt[i].risk; done = true; }
      if(!done) continue;
      LearnStat(g_lvt[i].sit, g_lvt[i].strat, r, false);
      LearnSave(g_lvt[i].sit, g_lvt[i].strat, d, r, false);
      int last = ArraySize(g_lvt) - 1;
      if(i != last) g_lvt[i] = g_lvt[last];
      ArrayResize(g_lvt, last);
   }
}
// Danh gia cap (tinh huong, chien luoc): 0 dang thu, 1 tin dung, 2 chua chac, 3 loai. factor = he so rui ro.
int LearnVerdict(const int sit, const int st, double &factor, string &txt)
{
   LearnLoad();
   factor = P_LearnTryRisk; txt = "";
   if(!P_Learn) { factor = 1; return 1; }
   if(!LearnKeyOk(sit, st)) return 0;
   int n = g_ln[sit][st];
   double m = n > 0 ? g_ls[sit][st] / n : 0;
   double var = n > 1 ? (g_ls2[sit][st] - n * m * m) / (n - 1) : 0;
   double lb = n > 1 ? m - 1.28 * MathSqrt(MathMax(var, 0)) / MathSqrt(n) : m;
   string real = g_rn[sit][st] > 0 ? StringFormat("; lenh that %d lan TB %+.2fR", g_rn[sit][st], g_rs[sit][st] / g_rn[sit][st]) : "";
   if(n < P_LearnMinN)
   { txt = StringFormat("%d/%d lenh giay%s -> dang thu (rui ro x%.2f)", n, P_LearnMinN, n > 0 ? StringFormat(", TB %+.2fR", m) : "", factor); txt += real; return 0; }
   int v = m <= 0 ? 3 : lb > 0 ? 1 : 2;
   factor = v == 1 ? 1.0 : v == 2 ? 0.75 : 0;
   txt = StringFormat("%d lenh giay, TB %+.2fR, thang %.0f%%, can duoi %+.2fR -> %s", n, m, 100.0 * g_lw[sit][st] / n, lb,
                      v == 1 ? "TIN DUNG" : v == 2 ? "chua chac (rui ro x0.75)" : "LOAI") + real;
   return v;
}
// Ket qua lenh that (FinalizeClosed): khoa LS_<vi the> = tinh huong x 100 + chien luoc, gan luc vao lenh
void LearnRealClose(const ulong posId, const double r)
{
   string k = GVName("LS_" + (string)posId);
   if(!GlobalVariableCheck(k)) return;
   int key = (int)GlobalVariableGet(k);
   GlobalVariableDel(k);
   LearnLoad();
   LearnStat(key / 100, key % 100, r, true);
   LearnSave(key / 100, key % 100, 0, r, true);
}
// Tom tat cho giao dien: sit:strat:n:TB:thang%:danh gia:n that:TB that ; ...
string LearnSummary()
{
   LearnLoad();
   string s = "";
   for(int a = 0; a < LRN_SIT; a++)
      for(int b = 0; b < LRN_STR; b++)
      {
         if(g_ln[a][b] == 0 && g_rn[a][b] == 0) continue;
         double f; string tx;
         int v = LearnVerdict(a, b, f, tx);
         int n = g_ln[a][b];
         s += StringFormat("%s%d:%d:%d:%.3f:%.0f:%d:%d:%.3f", s == "" ? "" : ";", a, b, n, n > 0 ? g_ls[a][b] / n : 0,
                           n > 0 ? 100.0 * g_lw[a][b] / n : 0, v, g_rn[a][b], g_rn[a][b] > 0 ? g_rs[a][b] / g_rn[a][b] : 0);
      }
   return s + StringFormat("|mo:%d", ArraySize(g_lvt));
}
