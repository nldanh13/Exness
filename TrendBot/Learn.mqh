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
struct LVT { datetime t; int sit; int strat; int dir; double entry; double sl; double tp; double risk; int bars; double cost; datetime lastT;
             double mfe; double mae; string feat; };
LVT      g_lvt[];
int      g_ln[LRN_SIT][LRN_STR], g_lw[LRN_SIT][LRN_STR], g_rn[LRN_SIT][LRN_STR];
double   g_ls[LRN_SIT][LRN_STR], g_ls2[LRN_SIT][LRN_STR], g_rs[LRN_SIT][LRN_STR];
bool     g_lrnLoaded = false;
datetime g_lrnBar = 0;
int      g_sigMember = -1;                 // chien luoc thanh vien dung dau cua lenh vua vao (de gan ket qua lenh that)

string LearnFile() { return StringFormat("TrendBot_hoc_%I64d_%s.csv", AccountInfoInteger(ACCOUNT_LOGIN), _Symbol); }
// Lenh giay dang mo (v5.37): luu ra file de tat may khong mat; mo may lai thi cham bu cac nen da bo lo (gia trong luc tat may
// co san trong lich su MT5). Danh cho nguoi chi mo may vai gio moi ngay.
string LearnOpenFile() { return StringFormat("TrendBot_hoc_mo_%I64d_%s.csv", AccountInfoInteger(ACCOUNT_LOGIN), _Symbol); }
void LearnSaveOpen()
{
   if(MQLInfoInteger(MQL_TESTER)) return;
   int h = FileOpen(LearnOpenFile(), FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_COMMON | FILE_SHARE_READ);
   if(h == INVALID_HANDLE) return;
   for(int i = 0; i < ArraySize(g_lvt); i++)
      FileWriteString(h, StringFormat("%I64d,%d,%d,%d,%.8f,%.8f,%.8f,%.8f,%d,%.8f,%I64d,%.3f,%.3f,%s\r\n", (long)g_lvt[i].t, g_lvt[i].sit, g_lvt[i].strat,
                      g_lvt[i].dir, g_lvt[i].entry, g_lvt[i].sl, g_lvt[i].tp, g_lvt[i].risk, g_lvt[i].bars, g_lvt[i].cost, (long)g_lvt[i].lastT,
                      g_lvt[i].mfe, g_lvt[i].mae, g_lvt[i].feat));
   FileClose(h);
}
void LearnLoadOpen()
{
   ArrayResize(g_lvt, 0);
   if(MQLInfoInteger(MQL_TESTER) || !FileIsExist(LearnOpenFile(), FILE_COMMON)) return;
   int h = FileOpen(LearnOpenFile(), FILE_READ | FILE_TXT | FILE_ANSI | FILE_COMMON | FILE_SHARE_READ | FILE_SHARE_WRITE);
   if(h == INVALID_HANDLE) return;
   while(!FileIsEnding(h))
   {
      string p[];
      if(StringSplit(FileReadString(h), ',', p) < 11) continue;
      int n = ArraySize(g_lvt);
      ArrayResize(g_lvt, n + 1);
      g_lvt[n].t = (datetime)StringToInteger(p[0]); g_lvt[n].sit = (int)StringToInteger(p[1]); g_lvt[n].strat = (int)StringToInteger(p[2]);
      g_lvt[n].dir = (int)StringToInteger(p[3]); g_lvt[n].entry = StringToDouble(p[4]); g_lvt[n].sl = StringToDouble(p[5]);
      g_lvt[n].tp = StringToDouble(p[6]); g_lvt[n].risk = StringToDouble(p[7]); g_lvt[n].bars = (int)StringToInteger(p[8]);
      g_lvt[n].cost = StringToDouble(p[9]); g_lvt[n].lastT = (datetime)StringToInteger(p[10]);
      g_lvt[n].mfe = ArraySize(p) > 11 ? StringToDouble(p[11]) : 0; g_lvt[n].mae = ArraySize(p) > 12 ? StringToDouble(p[12]) : 0;
      g_lvt[n].feat = ArraySize(p) > 13 ? p[13] : "";
   }
   FileClose(h);
   if(ArraySize(g_lvt) > 0) PrintFormat("Hoc tu thuc chien: nap lai %d lenh giay dang mo, cham bu cac nen luc tat may", ArraySize(g_lvt));
}
// v5.46: lenh giay bi bo loc dong bo huong chan (dbh=0) van ghi file de doi chieu rieng, nhung KHONG tinh vao thong ke "Hoc":
// thong ke chi phan anh setup ma bot that su duoc phep vao
bool LearnCounts(const string feat) { return StringFind(feat, "dbh=0") < 0; }
// Danh dau cac lenh giay vua dang ky o nen nay (cung tinh huong, cung chieu) sau khi biet ket qua bo loc dong bo huong
void LearnTagBar(const int sit, const int dir, const string tag)
{
   datetime t = iTime(_Symbol, P_TF, 0);
   bool ch = false;
   for(int i = 0; i < ArraySize(g_lvt); i++)
      if(g_lvt[i].t == t && g_lvt[i].sit == sit && g_lvt[i].dir == dir && StringFind(g_lvt[i].feat, "dbh=") < 0)
      { g_lvt[i].feat += ";" + tag; ch = true; }
   if(ch) LearnSaveOpen();
}
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
   LearnLoadOpen();
   if(MQLInfoInteger(MQL_TESTER) || !FileIsExist(LearnFile(), FILE_COMMON)) return;
   int h = FileOpen(LearnFile(), FILE_READ | FILE_TXT | FILE_ANSI | FILE_COMMON | FILE_SHARE_READ | FILE_SHARE_WRITE);
   if(h == INVALID_HANDLE) return;
   int rows = 0;
   while(!FileIsEnding(h))
   {
      string p[];
      if(StringSplit(FileReadString(h), ',', p) < 6 || p[0] == "ThoiGian") continue;
      if(p[5] == "that" || ArraySize(p) < 11 || LearnCounts(p[10]))
         LearnStat((int)StringToInteger(p[1]), (int)StringToInteger(p[2]), StringToDouble(p[4]), p[5] == "that");
      rows++;
   }
   FileClose(h);
   if(rows > 0) PrintFormat("Hoc tu thuc chien: nap %d ket qua tu %s", rows, LearnFile());
}
// Dong ket qua: ThoiGian,TinhHuong,ChienLuoc,Chieu,R,Loai,MFE,MAE,SoNen,Diem,DacTrung,VaoLuc
//  MFE / MAE = gia di thuan xa nhat / nguoc sau nhat (R); Diem = thang diem A-F (LearnGrade); DacTrung = boi canh luc vao (k=v;...)
void LearnSave(const int sit, const int st, const int dir, const double r, const bool real,
               const double mfe = 0, const double mae = 0, const int bars = 0, const string grade = "", const string feat = "", const datetime tin = 0)
{
   if(MQLInfoInteger(MQL_TESTER)) return;
   bool isNew = !FileIsExist(LearnFile(), FILE_COMMON);
   int h = FileOpen(LearnFile(), FILE_READ | FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_COMMON | FILE_SHARE_READ);
   if(h == INVALID_HANDLE) return;
   FileSeek(h, 0, SEEK_END);
   if(isNew) FileWriteString(h, "ThoiGian,TinhHuong,ChienLuoc,Chieu,R,Loai,MFE,MAE,SoNen,Diem,DacTrung,VaoLuc\r\n");
   FileWriteString(h, StringFormat("%s,%d,%d,%d,%.3f,%s,%.3f,%.3f,%d,%s,%s,%s\r\n", TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES), sit, st, dir, r,
                                   real ? "that" : "giay", mfe, mae, bars, grade, feat, tin > 0 ? TimeToString(tin, TIME_DATE | TIME_MINUTES) : ""));
   FileClose(h);
}
// Thang diem moi lan ap dung kien thuc:
//  A (4) cham TP va chua bao gio nguoc qua 0,5R - dung, vao dung diem
//  B (3) co loi (> +0,3R)                         - dung
//  C (2) hoa (-0,3R .. +0,3R)                     - chua ro dung sai
//  D (1) thua nhung da tung di dung huong >= 0,5R - dung huong, QUAN LY LENH chua tot
//  F (0) thua va chua bao gio di dung huong 0,5R  - DIEU KIEN VAO co van de
string LearnGrade(const double r, const double mfe, const double mae, const bool hitTP)
{
   if(hitTP && mae < 0.5) return "A";
   if(r > 0.3) return "B";
   if(r >= -0.3) return "C";
   return mfe >= 0.5 ? "D" : "F";
}
// Dang ky 1 lenh giay cho setup vua thay (moi cap tinh huong / chien luoc / chieu chi 1 lenh giay mo moi nen)
void LearnRegister(const int sit, const int st, const int dir, const double entry, const double slDist, const double tpPx, const string feat = "")
{
   if(!P_Learn || slDist <= 0 || entry <= 0 || !LearnKeyOk(sit, st)) return;
   LearnLoad();
   datetime t = iTime(_Symbol, P_TF, 0);
   int n = ArraySize(g_lvt);
   // v5.46: moi bo (tinh huong, chien luoc, chieu) chi 1 lenh giay dang mo. Truoc chi chan trung trong cung 1 nen nen cung 1 setup
   // (vd. Quet tin sau khi khoi dong lai) bi ghi 2 lenh giay cach nhau vai nen, dem trung ket qua.
   for(int i = 0; i < n; i++) if(g_lvt[i].sit == sit && g_lvt[i].strat == st && g_lvt[i].dir == dir) return;
   if(n >= 300) return;
   // v5.46: gia vao = gia Bid hien tai (cung loai gia voi nen MT5), khong dung gia dong cua nen 1: sau khi mat ket noi / khoi dong lai,
   // nen 1 co the chua tai du lich su nen gia dong cua la gia cu. Spread van tru rieng o duoi (cost).
   double bidNow = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double px = !MQLInfoInteger(MQL_TESTER) && bidNow > 0 ? bidNow : entry;
   ArrayResize(g_lvt, n + 1);
   g_lvt[n].t = t; g_lvt[n].sit = sit; g_lvt[n].strat = st; g_lvt[n].dir = dir; g_lvt[n].entry = px;
   g_lvt[n].risk = slDist; g_lvt[n].sl = px - dir * slDist;
   g_lvt[n].tp = (dir > 0 ? tpPx > px : (tpPx > 0 && tpPx < px)) ? tpPx : px + dir * 2.0 * slDist;
   g_lvt[n].bars = 0; g_lvt[n].lastT = 0; g_lvt[n].mfe = 0; g_lvt[n].mae = 0; g_lvt[n].feat = feat;
   // Phi: R cua lenh giay tru spread luc thay setup (quy ra R), de bot khong hoc tu con so dep hon thuc te
   g_lvt[n].cost = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * _Point;
   LearnSaveOpen();
}
// Cham lenh giay: goi moi tick, chi lam viec khi co nen moi tren khung chinh
void LearnUpdate()
{
   if(!P_Learn) return;
   LearnLoad();
   datetime b = iTime(_Symbol, P_TF, 0);
   if(b == 0 || b == g_lrnBar) return;
   g_lrnBar = b;
   bool changed = false;
   for(int i = ArraySize(g_lvt) - 1; i >= 0; i--)
   {
      // Cham tung nen da dong tu sau nen tin hieu (ke ca cac nen trong luc tat may), theo thu tu thoi gian
      int d = g_lvt[i].dir, sh0 = iBarShift(_Symbol, P_TF, g_lvt[i].t, false);
      double r = 0; bool done = false, hitTP = false;
      for(int sh = MathMax(sh0, 1); sh >= 1 && !done; sh--)
      {
         datetime tb = iTime(_Symbol, P_TF, sh);
         if(tb < g_lvt[i].t || tb <= g_lvt[i].lastT) continue;
         double h = iHigh(_Symbol, P_TF, sh), l = iLow(_Symbol, P_TF, sh), c = iClose(_Symbol, P_TF, sh);
         if(h <= 0 || l <= 0) break;                                  // chua tai du lich su: thu lai o nen sau
         g_lvt[i].lastT = tb; g_lvt[i].bars++; changed = true;
         double fav = (d > 0 ? h - g_lvt[i].entry : g_lvt[i].entry - l) / g_lvt[i].risk, adv = (d > 0 ? g_lvt[i].entry - l : h - g_lvt[i].entry) / g_lvt[i].risk;
         if(d > 0 ? l <= g_lvt[i].sl : h >= g_lvt[i].sl) { r = -1; done = true; g_lvt[i].mae = MathMax(g_lvt[i].mae, 1.0); }
         else if(d > 0 ? h >= g_lvt[i].tp : l <= g_lvt[i].tp) { r = (g_lvt[i].tp - g_lvt[i].entry) * d / g_lvt[i].risk; done = true; hitTP = true; }
         if(!done || hitTP) { g_lvt[i].mfe = MathMax(g_lvt[i].mfe, MathMin(fav, hitTP ? r : fav)); g_lvt[i].mae = MathMax(g_lvt[i].mae, MathMin(adv, 1.0)); }
         if(done) break;
         else if(g_lvt[i].bars >= P_LearnMaxBars) { r = (c - g_lvt[i].entry) * d / g_lvt[i].risk; done = true; }
      }
      if(!done) continue;
      r -= g_lvt[i].risk > 0 ? g_lvt[i].cost / g_lvt[i].risk : 0;     // tru phi spread
      if(LearnCounts(g_lvt[i].feat)) LearnStat(g_lvt[i].sit, g_lvt[i].strat, r, false);
      LearnSave(g_lvt[i].sit, g_lvt[i].strat, d, r, false, g_lvt[i].mfe, g_lvt[i].mae, g_lvt[i].bars,
                LearnGrade(r, g_lvt[i].mfe, g_lvt[i].mae, hitTP), g_lvt[i].feat, g_lvt[i].t);
      int last = ArraySize(g_lvt) - 1;
      if(i != last) g_lvt[i] = g_lvt[last];
      ArrayResize(g_lvt, last);
   }
   if(changed) LearnSaveOpen();
}
// So setup dong y / trai chieu cua nen nay: ghi vao dac trung cac lenh giay vua dang ky (dong = cung chieu, trai = nguoc chieu)
void LearnSetAgree(const int sit, const int nb, const int ns)
{
   datetime t = iTime(_Symbol, P_TF, 0);
   bool ch = false;
   for(int i = 0; i < ArraySize(g_lvt); i++)
      if(g_lvt[i].t == t && g_lvt[i].sit == sit && StringFind(g_lvt[i].feat, "dong=") < 0)
      {
         int same = g_lvt[i].dir > 0 ? nb : ns, opp = g_lvt[i].dir > 0 ? ns : nb;
         g_lvt[i].feat += StringFormat(";dong=%d;trai=%d", same, opp > 0 ? 1 : 0);
         ch = true;
      }
   if(ch) LearnSaveOpen();
}

// ---- Kien thuc da dieu chinh (v5.39) ----
// Common\Files\TrendBot_dieuchinh_<tai khoan>_<ma>.csv (giao dien ghi khi ban bam "Ap dung"). Moi dong:
//   chien luoc|tinh huong (-1 = moi tinh huong)|dac trung|<= hoac >=|nguong|ngay duyet|ghi chu
// = dieu kien BO SUNG cho kien thuc: chien luoc chi duoc dung khi dac trung thoa dieu kien. Doc lai moi 10 phut.
string   g_krStrat[], g_krFeat[], g_krOp[], g_krNote[];
int      g_krSit[];
double   g_krVal[];
datetime g_krRead = 0;
string KnowFile() { return StringFormat("TrendBot_dieuchinh_%I64d_%s.csv", AccountInfoInteger(ACCOUNT_LOGIN), _Symbol); }
void KnowLoad()
{
   if(g_krRead != 0 && TimeCurrent() - g_krRead < 600) return;
   g_krRead = TimeCurrent();
   ArrayResize(g_krStrat, 0); ArrayResize(g_krFeat, 0); ArrayResize(g_krOp, 0); ArrayResize(g_krNote, 0); ArrayResize(g_krSit, 0); ArrayResize(g_krVal, 0);
   if(!FileIsExist(KnowFile(), FILE_COMMON)) return;
   int h = FileOpen(KnowFile(), FILE_READ | FILE_TXT | FILE_ANSI | FILE_COMMON | FILE_SHARE_READ | FILE_SHARE_WRITE);
   if(h == INVALID_HANDLE) return;
   while(!FileIsEnding(h))
   {
      string p[];
      if(StringSplit(FileReadString(h), '|', p) < 5 || StringSubstr(p[0], 0, 1) == "#") continue;
      if(p[3] != "<=" && p[3] != ">=") continue;
      int n = ArraySize(g_krVal);
      ArrayResize(g_krStrat, n + 1); ArrayResize(g_krFeat, n + 1); ArrayResize(g_krOp, n + 1); ArrayResize(g_krNote, n + 1);
      ArrayResize(g_krSit, n + 1); ArrayResize(g_krVal, n + 1);
      g_krStrat[n] = p[0]; g_krSit[n] = (int)StringToInteger(p[1]); g_krFeat[n] = p[2]; g_krOp[n] = p[3]; g_krVal[n] = StringToDouble(p[4]);
      g_krNote[n] = ArraySize(p) > 5 ? p[5] : "";
   }
   FileClose(h);
}
double FeatGet(const string feat, const string key, bool &found)
{
   found = false;
   string kv[];
   int n = StringSplit(feat, ';', kv);
   for(int i = 0; i < n; i++)
   {
      int e = StringFind(kv[i], "=");
      if(e > 0 && StringSubstr(kv[i], 0, e) == key) { found = true; return StringToDouble(StringSubstr(kv[i], e + 1)); }
   }
   return 0;
}
bool KnowRulesOk(const int strat, const int sit, const string feat, string &why)
{
   why = "";
   KnowLoad();
   for(int i = 0; i < ArraySize(g_krVal); i++)
   {
      if((int)StringToInteger(g_krStrat[i]) != strat || (g_krSit[i] >= 0 && g_krSit[i] != sit)) continue;
      bool f;
      double v = FeatGet(feat, g_krFeat[i], f);
      if(!f) continue;
      bool ok = g_krOp[i] == "<=" ? v <= g_krVal[i] + 1e-9 : v >= g_krVal[i] - 1e-9;
      if(!ok) { why = StringFormat("chi dung khi %s %s %s (dang la %s%s)", g_krFeat[i], g_krOp[i], DoubleToString(g_krVal[i], 2),
                                   DoubleToString(v, 2), g_krNote[i] != "" ? ", duyet " + g_krNote[i] : ""); return false; }
   }
   return true;
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
   { txt = StringFormat("%d/%d lenh giay%s -> dang thu%s", n, P_LearnMinN, n > 0 ? StringFormat(", TB %+.2fR", m) : "",
                        P_LearnApply ? StringFormat(" (rui ro x%.2f)", factor) : " (chua du du lieu)"); txt += real; return 0; }
   int v = m <= 0 ? 3 : lb > 0 ? 1 : 2;
   factor = v == 1 ? 1.0 : v == 2 ? 0.75 : 0;
   txt = StringFormat("%d lenh giay, TB %+.2fR, thang %.0f%%, can duoi %+.2fR -> %s", n, m, 100.0 * g_lw[sit][st] / n, lb,
                      v == 1 ? "TIN DUNG" : v == 2 ? (P_LearnApply ? "chua chac (rui ro x0.75)" : "chua chac") : "LOAI") + real;
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
