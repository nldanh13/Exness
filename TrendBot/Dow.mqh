//+------------------------------------------------------------------+
//| TrendBot/Dow.mqh: Ly thuyet Dow - thuy trieu, giai doan, volume xac nhan, cau truc dinh / day (v5.23, THU NGHIEM)
//+------------------------------------------------------------------+
// Goc re cua SMC, Wyckoff, BOS, CHOCH. 4 dieu cua Charles Dow:
//  1) 3 xu huong chay cung luc: chinh (thuy trieu, nhieu thang), phu (con song hoi nguoc, vai tuan), gon song hang ngay.
//     Bot: thuy trieu = cau truc dinh / day tren khung InpDowTF (mac dinh D1); con song = cau truc tren khung chinh.
//  2) Xu huong chinh co 3 giai doan: dau (nguoi hieu biet mua khi tin con xau), giua (ro rang, tang manh nhat), cuoi (dam dong
//     lao vao, tin toan tot - luc nguoi mua som ban ra). Bot dem so lan pha dinh (BOS) tu khi doi chieu: 1 = dau, >= InpDowLateLegs
//     = cuoi -> khong vao lenh moi.
//  3) Volume phai xac nhan: tang khoe thi nen tang khoi luong lon, nen hoi khoi luong nho (InpDowVolume, so tick 20 nen khung Dow).
//  4) Xu huong con do cho toi khi co tin hieu dao chieu ro rang: tang = dinh sau cao hon, day sau cao hon. Chi khi gia DONG CUA thung
//     day gan nhat VA tao dinh thap hon (hoac dong cua thung lan nua) xu huong moi doi chieu. Chua bi pha thi dung doan dinh.
struct DowState
{
   int    trend;    // +1 tang, -1 giam, 0 chua ro
   int    legs;     // so lan pha dinh (tang) / pha day (giam) tu khi doi chieu: giai doan cua xu huong
   int    pend;     // canh bao: -1 xu huong tang vua thung day gan nhat (cho dinh thap hon), +1 nguoc lai
   double ph, pl;   // dinh / day (pivot) gan nhat
   int    brk;      // nen cuoi cung: +1 dong cua vuot dinh gan nhat, -1 thung day gan nhat, 0 khong
   int    prev;     // xu huong truoc nen cuoi cung
};

// Tinh cau truc tren 'bars' nen da dong cua khung tf. Pivot = dinh / day cao / thap nhat trong +-P nen.
bool DowCalc(const ENUM_TIMEFRAMES tf, const int bars, const int P, DowState &st)
{
   double hi[], lo[], cl[];
   ArraySetAsSeries(hi, false); ArraySetAsSeries(lo, false); ArraySetAsSeries(cl, false);
   int n = MathMin(CopyHigh(_Symbol, tf, 1, bars, hi), MathMin(CopyLow(_Symbol, tf, 1, bars, lo), CopyClose(_Symbol, tf, 1, bars, cl)));
   ZeroMemory(st);
   if(n < 3 * P + 20) return false;
   int trend = 0, legs = 0, pend = 0;
   double ph = 0, pl = 0, refHigh = 0, refLow = 0;
   bool phLive = false, plLive = false;
   for(int i = 0; i < n; i++)
   {
      int p = i - P;
      if(p >= P)
      {
         bool isH = true, isL = true;
         for(int q = p - P; q <= p + P; q++)
         {
            if(q == p) continue;
            if(hi[q] >= hi[p]) isH = false;
            if(lo[q] <= lo[p]) isL = false;
         }
         // Dinh thap hon sau khi xu huong tang thung day = doi chieu giam (va nguoc lai)
         if(isH) { if(pend == -1 && hi[p] < refHigh) { trend = -1; legs = 1; pend = 0; } ph = hi[p]; phLive = true; }
         if(isL) { if(pend == 1 && lo[p] > refLow)   { trend = 1;  legs = 1; pend = 0; } pl = lo[p]; plLive = true; }
      }
      int before = trend, b = 0;
      if(phLive && cl[i] > ph)
      {
         phLive = false; b = 1;
         if(trend == 0)       { trend = 1; legs = 1; }
         else if(trend == 1)  { legs++; pend = 0; }                     // BOS: xu huong tang tiep dien
         else if(pend == 1)   { trend = 1; legs = 1; pend = 0; }        // thung lan 2: doi chieu
         else                 { pend = 1; refLow = pl; }                // canh bao: cho day cao hon
      }
      else if(plLive && cl[i] < pl)
      {
         plLive = false; b = -1;
         if(trend == 0)       { trend = -1; legs = 1; }
         else if(trend == -1) { legs++; pend = 0; }
         else if(pend == -1)  { trend = -1; legs = 1; pend = 0; }
         else                 { pend = -1; refHigh = ph; }
      }
      if(i == n - 1) { st.brk = b; st.prev = before; }
   }
   st.trend = trend; st.legs = legs; st.pend = pend; st.ph = ph; st.pl = pl;
   return true;
}

int g_dowBlocked = 0;
DowState g_tide;
datetime g_tideBar = 0;
bool     g_tideOk = false;
// Thuy trieu (khung InpDowTF), tinh lai moi nen moi cua khung do
bool DowTide(DowState &st)
{
   datetime t = iTime(_Symbol, P_DowTF, 0);
   if(t != g_tideBar || !g_tideOk) { g_tideBar = t; g_tideOk = DowCalc(P_DowTF, 400, P_DowPivot, g_tide); }
   st = g_tide;
   return g_tideOk;
}
// Volume xac nhan: 20 nen khung Dow, khoi luong TB nen cung chieu thuy trieu >= nen nguoc chieu
bool DowVolumeOk(const bool buy)
{
   double up = 0, dn = 0; int nu = 0, nd = 0;
   for(int i = 1; i <= 20; i++)
   {
      double o = iOpen(_Symbol, P_DowTF, i), c = iClose(_Symbol, P_DowTF, i);
      double v = (double)iTickVolume(_Symbol, P_DowTF, i);
      if(o <= 0 || v <= 0) continue;
      if(c > o) { up += v; nu++; } else if(c < o) { dn += v; nd++; }
   }
   if(nu < 3 || nd < 3) return true;                                   // qua it nen de so sanh: khong chan
   return buy ? up / nu >= dn / nd : dn / nd >= up / nu;
}
// Truoc moi lenh: thuy trieu dang len hay xuong, dang o giai doan nao. Chi giao dich theo chieu thuy trieu.
bool DowOk(const bool buy)
{
   if(!P_DowFilter && P_Strategy != STRAT_DOW) return true;
   DowState t;
   string why = "";
   if(!DowTide(t)) why = "chua du nen de xac dinh thuy trieu";
   else if(t.trend != (buy ? 1 : -1)) why = buy ? "thuy trieu dang xuong" : "thuy trieu dang len";
   else if(P_DowLateLegs > 0 && t.legs >= P_DowLateLegs) why = StringFormat("thuy trieu o giai doan cuoi (%d lan pha)", t.legs);
   else if(P_DowVolume && !DowVolumeOk(buy)) why = "volume khong xac nhan thuy trieu";
   if(why == "") return true;
   g_dowBlocked++;
   g_status = "Bo tin hieu (Dow): " + why;
   return false;
}
