//+------------------------------------------------------------------+
//| TrendBot/Signals.mqh: tin hieu goc (Donchian breakout / EMA pullback)
//| Chua xet bo loc. Tra false khi nen nay phai bo qua han (thieu du lieu, nen qua dai).
//+------------------------------------------------------------------+
//--- Gio mo cua New York (9:30) tinh bang phut UTC: 13:30 khi My dang gio mua he (DST), 14:30 khi khong.
// DST My: tu Chu nhat thu 2 thang 3 toi Chu nhat dau tien thang 11. Gia dinh gio server = UTC (Exness GMT+0).
int NthSunday(const int y, const int mon, const int n)
{
   MqlDateTime d; d.year = y; d.mon = mon; d.day = 1; d.hour = 0; d.min = 0; d.sec = 0;
   datetime t = StructToTime(d); TimeToStruct(t, d);
   return 1 + (7 - d.day_of_week) % 7 + 7 * (n - 1);
}
int NYOpenUTCMin(const datetime day)
{
   MqlDateTime d; TimeToStruct(day, d);
   bool dst = (d.mon > 3 && d.mon < 11) || (d.mon == 3 && d.day >= NthSunday(d.year, 3, 2)) ||
              (d.mon == 11 && d.day < NthSunday(d.year, 11, 1));
   return dst ? 810 : 870;
}

// Doi gio New York (phut tu 00:00) sang thoi diem server (gia dinh server = UTC) cho ngay 'day' (00:00 UTC)
datetime NYTime(const datetime day, const int nyMin)
{
   int off = NYOpenUTCMin(day) == 810 ? 240 : 300;      // 4 gio (mua he) hoac 5 gio
   return day + (nyMin + off) * 60;
}
double CloseAt(const datetime t)                         // gia dong cua nen ket thuc dung luc t
{
   int sh = iBarShift(_Symbol, P_TF, t - PeriodSeconds(P_TF), true);
   return sh < 0 ? 0 : iClose(_Symbol, P_TF, sh);
}

// Big Trades: co dinh cu (low = false) / day cu (low = true) truoc chi so j, cach muc 'price' trong 'zone' khong.
// Dinh / day cu = cao / thap hon 3 nen moi ben. Mang theo thu tu thoi gian (chi so lon = moi hon).
bool BigNearSwing(const double &hi[], const double &lo[], const int j, const double price, const bool low, const double zone)
{
   for(int q = j - 4; q >= 3; q--)
   {
      bool piv = true;
      for(int m = q - 3; m <= q + 3 && piv; m++)
      {
         if(m == q) continue;
         if(low ? lo[m] <= lo[q] : hi[m] >= hi[q]) piv = false;
      }
      if(piv && MathAbs((low ? lo[q] : hi[q]) - price) <= zone) return true;
   }
   return false;
}

// Phan phoi (v5.15): tim 5 nhip tren mang theo thu tu thoi gian (chi so lon = moi hon), chieu BAN.
// Chieu MUA (tich luy) goi cung ham voi gia doi dau (hi' = -lo, lo' = -hi): moi so sanh tu dao nguoc.
// Tra ve true khi nen 'last' (nen 1) la lan test lai day hop bi tu choi. slDist = khoang cach SL, tpPx = gia TP
// (cung he toa do mang dua vao), climaxT = thoi diem nen hung phan (moi cau truc chi vao 1 lan).
bool DistPattern(const double &hi[], const double &lo[], const double &op[], const double &cl[], const double &tv[],
                 const datetime &tm[], const int last, const double atr, const datetime usedT,
                 double &slDist, double &tpPx, datetime &climaxT)
{
   int boxMin = P_DistBoxMin < 4 ? 4 : P_DistBoxMin;
   for(int c = last - boxMin - 3; c >= 31; c--)
   {
      if(tm[c] <= usedT) return false;                                  // cu hon cau truc da vao lenh: dung
      // 1) Nen hung phan: tang dai, khoi luong lon nhat 20 nen truoc, rau tren >= 20% bien do; sau nhip tang >= 2 ATR
      double rg = hi[c] - lo[c];
      if(cl[c] <= op[c] || rg < P_DistClimaxATR * atr || hi[c] - cl[c] < 0.2 * rg) continue;
      bool maxVol = true;
      double tLow = lo[c];
      for(int q = c - 30; q < c; q++) { if(q >= c - 20 && tv[q] >= tv[c]) maxVol = false; if(lo[q] < tLow) tLow = lo[q]; }
      if(!maxVol || hi[c] - tLow < 2.0 * atr) continue;
      double top = hi[c];
      // 2) Hop di ngang sau nen hung phan (khong tao dinh moi), toi khi co nen sap
      double bot = DBL_MAX;
      int d = -1, touches = 0;
      bool ut = false, broke = false;
      for(int m = c + 1; m <= last - 1; m++)
      {
         double avg = 0;
         for(int q = m - 20; q < m; q++) avg += tv[q];
         avg /= 20.0;
         // 5) Nen sap: dong duoi day hop, dai >= 1 ATR, khoi luong >= 1,2 x TB, sau it nhat boxMin nen di ngang
         if(m - c - 1 >= boxMin && bot < DBL_MAX && cl[m] < bot && hi[m] - lo[m] >= atr && tv[m] >= 1.2 * avg) { d = m; break; }
         if(hi[m] > top + 0.5 * atr && cl[m] > top) { broke = true; break; }  // dong han tren nap: con tang, khong phai hop
         if(hi[m] >= top - 0.5 * atr) touches++;                           // cham nap hop
         if(hi[m] > top && cl[m] < top) ut = true;                         // 3) pha dinh gia: vot qua nap, dong lai trong hop
         if(lo[m] < bot) bot = lo[m];
      }
      if(broke || d < 0 || top - bot > P_DistBoxMaxATR * atr || touches < 1 || (P_DistNeedUT && !ut)) continue;
      // 4) Dinh thap hon: dinh gan nhat trong hop (cao hon 2 nen moi ben) thap hon nap >= 0,3 ATR
      double lh = 0;
      for(int p = d - 3; p >= c + 3 && lh == 0; p--)
      {
         bool piv = true;
         for(int j = p - 2; j <= p + 2 && piv; j++) if(j != p && hi[j] >= hi[p]) piv = false;
         if(piv) lh = hi[p];
      }
      if(lh <= 0 || lh > top - 0.3 * atr) continue;
      // Test lai day hop (nay la khang cu): lan cham dau tien sau nen sap, khoi luong nho, nen yeu, dong lai duoi day hop
      for(int m = d + 1; m <= last - 1; m++) if(hi[m] >= bot - 0.25 * atr) return false;   // da test truoc do
      double avg1 = 0;
      for(int q = last - 20; q < last; q++) avg1 += tv[q];
      avg1 /= 20.0;
      bool test = hi[last] >= bot - 0.25 * atr && hi[last] <= bot + 0.5 * atr;
      // Nen yeu bi tu choi: dong lai duoi day hop, nen giam hoac rau tren >= 40% bien do; khoi luong nho hon nen sap
      // va nho hon trung binh 20 nen (TB chi de doi chieu khi nen sap qua lon)
      double rgl = hi[last] - lo[last];
      bool rej = cl[last] < op[last] || (rgl > 0 && hi[last] - MathMax(op[last], cl[last]) >= 0.4 * rgl);
      bool weak = cl[last] < bot && rej && tv[last] < tv[d] && tv[last] < 1.5 * avg1;
      if(!test || !weak) return false;
      double slPx = MathMax(lh, hi[last]) + 0.25 * atr;                 // SL tren dinh thap hon vua tao
      slDist = MathMax(slPx - cl[last], 0.5 * atr);
      tpPx = tLow;                                                       // TP: noi cu tang ban dau bat dau
      if(cl[last] - tpPx < slDist) return false;                         // lai < 1R: bo
      climaxT = tm[c];
      return true;
   }
   return false;
}

// Dao roi (v5.19, CHUA KIEM THU): dung bat con dao dang roi. Khong chi bao nao noi truoc duoc dau la day; nhung cu bat
// trong luc roi la bay de tay to co cho ban them. Nguoi kiem nhieu nhat mua SAU day. 3 chu: NHO, LON, GIU.
//  - Dao roi: gia giam >= InpKnifeDropATR ATR tu dinh xuong day trong toi da InpKnifeBars nen (day = thap nhat InpKnifeLookback nen).
//  - NHO (mode 1): nen ngay sau day dong cua tang vuot dinh nen truoc -> lenh thu InpKnifeProbePct % rui ro chuan, SL duoi day.
//  - LON (mode 2): gia dong cua vuot dinh gan nhat cua cu giam (dinh thap hon cuoi cung truoc day), roi co nen hoi ve test lai
//    (cham trong InpKnifeRetestATR ATR) ma van dong cua tren va la nen tang -> vao lenh day du. SL duoi day cao hon vua tao.
//    Pha len roi dong lai duoi muc do: that bai, khong vao. Tong rui ro lenh thu + lenh lon khong vuot 1 lenh chuan (CalcLots).
//  - GIU: chot mot phan (InpPartialPct) o dinh cu cua cu giam, phan con lai doi SL len duoi moi day cao hon (InpTrailSwingBars).
// Ban nguoc lai (gia tang dung thang roi gay) doi dau gia.
bool KnifePattern(const double &hi[], const double &lo[], const double &op[], const double &cl[],
                  const int last, const double atr, int &mode, double &slDist, double &target, int &iLow0)
{
   mode = 0; slDist = 0; target = 0; iLow0 = -1;
   int iLo = 0;
   for(int i = 1; i <= last; i++) if(lo[i] <= lo[iLo]) iLo = i;
   if(iLo < 5 || iLo > last - 1) return false;                         // day phai la nen da qua (khong phai nen vua dong)
   int from = MathMax(0, iLo - P_KnifeBars), iTop = from;
   for(int i = from; i <= iLo; i++) if(hi[i] > hi[iTop]) iTop = i;
   if(hi[iTop] - lo[iLo] < P_KnifeDropATR * atr) return false;          // khong phai cu giam manh
   iLow0 = iLo; target = hi[iTop];
   // Dinh gan nhat cua cu giam: pivot high (2 nen moi ben) gan day nhat; roi thang khong co nhip hoi thi lay dinh 3 nen truoc day
   double lvl = 0;
   for(int k = iLo - 1; k >= iTop + 2 && lvl == 0; k--)
      if(k + 2 <= last && hi[k] > hi[k - 1] && hi[k] > hi[k - 2] && hi[k] >= hi[k + 1] && hi[k] >= hi[k + 2]) lvl = hi[k];
   if(lvl == 0) for(int k = MathMax(0, iLo - 3); k <= iLo; k++) lvl = MathMax(lvl, hi[k]);
   int jb = -1;
   for(int j = iLo + 1; j <= last - 1 && jb < 0; j++) if(cl[j] > lvl) jb = j;
   if(jb > 0)
   {
      for(int m = jb + 1; m < last; m++) if(cl[m] < lvl) return false;   // pha len roi dong lai duoi: that bai
      if(lo[last] <= lvl + P_KnifeRetestATR * atr && cl[last] > lvl && cl[last] > op[last])
      {
         double hl = lo[last];
         for(int m = jb; m <= last; m++) hl = MathMin(hl, lo[m]);        // day cao hon vua tao
         slDist = MathMax(cl[last] - (hl - 0.25 * atr), 0.5 * atr);
         if(target <= cl[last] + 0.5 * atr) target = 0;                  // dinh cu qua gan: chot theo R
         mode = 2;
         return true;
      }
      return false;
   }
   // Lenh thu nho: 1-2 nen sau day, nen vua dong tang va vuot dinh nen truoc
   if(iLo >= last - 2 && cl[last] > op[last] && cl[last] > hi[last - 1])
   {
      slDist = MathMax(cl[last] - (lo[iLo] - 0.25 * atr), 0.5 * atr);
      mode = 1;
      return true;
   }
   return false;
}
// Order block (v5.20, CHUA KIEM THU). OB tang = nen giam CUOI CUNG ngay truoc mot cu day len manh (trong 3 nen gia dong cua
// cao hon dinh nen do >= InpOBImpulseATR ATR). Vung = dinh..day cay nen do (rong <= InpOBMaxATR ATR). Cham OB chua phai tin hieu,
// CACH GIA PHAN UNG tai do moi la tin hieu. Xet nen vua dong khi gia quay ve vung:
//  1) Cham mep tren roi bat manh (khong vao toi nua vung): phe mua rat manh - lo roi thi KHONG duoi, cho nhip hoi sau.
//  2) Vao toi giua vung roi nen tang dong cua tren giua vung: phan ung chuan -> Buy, SL duoi day OB.
//  3) Quet thung day (rau duoi day OB) roi dong cua quay lai ben trong, nen tang: thuong la manh nhat -> Buy, SL duoi day cay rau.
//  4) Di ngang linh xinh trong vung >= InpOBStallBars nen: phe mua do du -> khong vao (o trong vung cang lau cang de thung).
//  5) Nen dong cua thung han duoi day OB: vung hong, dung ngoai. Gia hoi len lai vung do (InpOBBreaker): vung thanh khang cu,
//     nen giam bi tu choi o day vung -> Sell, SL tren nen do.
// TP = dinh con song sau cu day neu xa hon 1R, khong thi theo InpRR. OB giam: doi dau gia.
bool OBPattern(const double &hi[], const double &lo[], const double &op[], const double &cl[], const datetime &tm[],
               const int last, const double atr, int &mode, double &slDist, double &tp, datetime &key)
{
   mode = 0; slDist = 0; tp = 0; key = 0;
   int k0 = MathMax(1, last - P_OBLookback);
   for(int k = last - 4; k >= k0; k--)
   {
      if(cl[k] >= op[k] || cl[k + 1] <= op[k + 1]) continue;           // nen giam cuoi cung, ngay sau la nen tang
      double H = hi[k], Lw = lo[k], mid = (H + Lw) / 2.0;
      if(H - Lw > P_OBMaxATR * atr || H - Lw < 0.1 * atr) continue;
      int ie = -1;
      for(int i = k + 1; i <= MathMin(k + 3, last - 1) && ie < 0; i++) if(cl[i] >= H + P_OBImpulseATR * atr) ie = i;
      if(ie < 0) continue;
      double swingHi = hi[ie];
      for(int m = ie; m < last; m++) swingHi = MathMax(swingHi, hi[m]);
      int brk = -1;
      for(int m = ie + 1; m < last && brk < 0; m++) if(cl[m] < Lw) brk = m;
      if(brk >= 0)
      {
         // 5) vung da hong: chi con co the thanh khang cu khi gia hoi len lai
         if(!P_OBBreaker || tm[k] == g_obFlipUsed) continue;
         bool reclaimed = false;
         for(int m = brk + 1; m < last && !reclaimed; m++) if(cl[m] > H) reclaimed = true;
         if(reclaimed) continue;
         if(hi[last] >= Lw - 0.3 * atr && hi[last] <= H + 0.25 * atr && cl[last] < Lw && cl[last] < op[last])
         {
            mode = 4; key = tm[k];
            slDist = MathMax(hi[last] + 0.25 * atr - cl[last], 0.5 * atr);
            return true;
         }
         continue;
      }
      if(lo[last] > H) continue;                                       // gia chua ve vung nay
      if(tm[k] == g_obUsed) return false;                              // OB nay da vao lenh
      if(cl[last] < Lw) return false;                                  // 5) vua dong cua thung han: dung ngoai
      int stall = 0;
      for(int m = last - 1; m > ie && lo[m] <= H && cl[m] >= Lw && cl[m] <= H; m--) stall++;
      if(stall >= P_OBStallBars) return false;                         // 4) linh xinh trong vung: dung ngoai
      bool bull = cl[last] > op[last];
      if(lo[last] < Lw && cl[last] >= Lw && bull)                      // 3) quet thung day roi quay lai
      { mode = 3; slDist = MathMax(cl[last] - (lo[last] - 0.1 * atr), 0.3 * atr); }
      else if(lo[last] <= mid && lo[last] >= Lw && bull && cl[last] > mid) // 2) vao toi giua roi bat
      { mode = 2; slDist = MathMax(cl[last] - (Lw - 0.25 * atr), 0.3 * atr); }
      else return false;                                               // 1) chi cham mep / chua xac nhan: khong duoi
      key = tm[k];
      tp = swingHi - cl[last] >= slDist ? swingHi : 0;
      return true;
   }
   return false;
}
bool OBScan(const double atr, bool &buy, int &mode, double &slDist, double &tp, datetime &key)
{
   int L = (P_OBLookback < 20 ? 20 : P_OBLookback) + 6;
   double hi[], lo[], op[], cl[], nh[], nl[], no[], nc[];
   datetime tm[];
   ArrayResize(hi, L); ArrayResize(lo, L); ArrayResize(op, L); ArrayResize(cl, L); ArrayResize(tm, L);
   ArrayResize(nh, L); ArrayResize(nl, L); ArrayResize(no, L); ArrayResize(nc, L);
   for(int i = 0; i < L; i++)
   {
      int sh = L - i;
      hi[i] = iHigh(_Symbol, P_TF, sh); lo[i] = iLow(_Symbol, P_TF, sh);
      op[i] = iOpen(_Symbol, P_TF, sh); cl[i] = iClose(_Symbol, P_TF, sh); tm[i] = iTime(_Symbol, P_TF, sh);
      if(hi[i] <= 0 || lo[i] <= 0) return false;
      nh[i] = -lo[i]; nl[i] = -hi[i]; no[i] = -op[i]; nc[i] = -cl[i];
   }
   // OB tang: mode 2/3 = Buy, 4 = Sell (khang cu). OB giam (doi dau): nguoc lai
   if(OBPattern(hi, lo, op, cl, tm, L - 1, atr, mode, slDist, tp, key)) { buy = mode != 4; return true; }
   if(OBPattern(nh, nl, no, nc, tm, L - 1, atr, mode, slDist, tp, key)) { buy = mode == 4; tp = -tp; return true; }
   return false;
}
// Quet ca 2 chieu: dao roi -> mua; gia tang dung thang roi gay -> ban (doi dau gia). key = thoi diem nen day / dinh.
bool KnifeScan(const double atr, bool &buy, int &mode, double &slDist, double &target, datetime &key)
{
   int L = P_KnifeLookback < 20 ? 20 : P_KnifeLookback;
   double hi[], lo[], op[], cl[], nh[], nl[], no[], nc[];
   datetime tm[];
   ArrayResize(hi, L); ArrayResize(lo, L); ArrayResize(op, L); ArrayResize(cl, L); ArrayResize(tm, L);
   ArrayResize(nh, L); ArrayResize(nl, L); ArrayResize(no, L); ArrayResize(nc, L);
   for(int i = 0; i < L; i++)
   {
      int sh = L - i;
      hi[i] = iHigh(_Symbol, P_TF, sh); lo[i] = iLow(_Symbol, P_TF, sh);
      op[i] = iOpen(_Symbol, P_TF, sh); cl[i] = iClose(_Symbol, P_TF, sh); tm[i] = iTime(_Symbol, P_TF, sh);
      if(hi[i] <= 0 || lo[i] <= 0) return false;
      nh[i] = -lo[i]; nl[i] = -hi[i]; no[i] = -op[i]; nc[i] = -cl[i];
   }
   int ix = -1;
   if(KnifePattern(hi, lo, op, cl, L - 1, atr, mode, slDist, target, ix)) { buy = true; key = tm[ix]; return true; }
   if(KnifePattern(nh, nl, no, nc, L - 1, atr, mode, slDist, target, ix)) { buy = false; target = -target; key = tm[ix]; return true; }
   return false;
}
// Goi o nen moi khi dang giu lenh (lenh thu): xac nhan sau day thi vao lenh lon cung chieu, qua cac bo loc rui ro co ban
void KnifeAdd()
{
   double atr = 0;
   if(!GetValue(hATR, 0, 1, atr) || atr <= 0) return;
   bool buy; int mode; double sd, tg; datetime key;
   if(!KnifeScan(atr, buy, mode, sd, tg, key) || mode != 2 || key == g_knifeUsed || key != g_knifeProbeUsed) return;
   int cnt = 0; bool same = true;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetTicket(i) == 0 || !IsOwnSelected()) continue;
      cnt++;
      if((PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) != buy) same = false;
   }
   if(cnt != 1 || !same) return;                                       // chi them vao dung lenh thu cung chieu
   if(IsHalted() || GuardHalted() || DailyLossHit() || HedgeActive()) return;
   if(buy ? !P_AllowBuy : !P_AllowSell) return;
   if(P_MaxSpreadPoints > 0 && SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) > P_MaxSpreadPoints) return;
   string w = "", nm = "";
   if(!TimeAllowed(w) || (P_AvoidUSNews && USNewsNear(nm))) return;
   g_knifeUsed = key;
   g_sigSL = sd; g_sigTP = 0; g_sigRiskMult = 1; g_sigPartialPx = tg;
   SendEntry(buy, atr, false);
}

// Nen xac nhan tai vung (v5.22, FVG InpFvgCandle). Cham vung moi chi la den dung cho; cay nen xuat hien o do moi cho biet
// co nen vao hay khong. Mang theo shift (o[1] = nen vua dong). Chieu mua; chieu ban goi voi gia doi dau.
// edge = mep vung phia gia di toi (dinh FVG tang), maxSh = nen cu nhat duoc dung (phai sau khi FVG hinh thanh).
// Tra ve: 3 nhan chim, 4 sao mai, 1 nen bua, 2 harami + 1 nen tang xac nhan, 5 ba linh trang roi hoi nhe; 0 = chua co.
int ZoneCandle(const double &o[], const double &h[], const double &l[], const double &c[], const int maxSh,
               const double edge, const double inval, const double atr, double &patLow)
{
   double b1 = MathAbs(c[1] - o[1]), r1 = h[1] - l[1];
   // 3) Nhan chim tang: nen tang lon nuot tron than nen giam truoc - manh nhat, mua khi nen dong cua
   if(maxSh >= 2 && c[2] < o[2] && c[1] > o[1] && o[1] <= c[2] && c[1] >= o[2] && b1 > MathAbs(o[2] - c[2]) &&
      MathMin(l[1], l[2]) <= edge)
   { patLow = MathMin(l[1], l[2]); return 3; }
   // 4) Sao mai: nen giam, nen rat nho, nen tang manh dong cua qua giua than nen giam - mua khi nen thu 3 dong cua
   if(maxSh >= 3)
   {
      double b3 = o[3] - c[3], b2 = MathAbs(c[2] - o[2]);
      if(b3 >= 0.5 * atr && b2 <= 0.3 * b3 && c[1] > o[1] && c[1] >= (o[3] + c[3]) / 2.0 && MathMin(l[1], MathMin(l[2], l[3])) <= edge)
      { patLow = MathMin(l[1], MathMin(l[2], l[3])); return 4; }
   }
   // 1) Nen bua: dam sau vao vung nhung bi mua nguoc len, rau duoi dai (>= 2 than, >= 1/2 bien do), dong cua o nua tren
   if(r1 > 0 && l[1] <= edge && MathMin(o[1], c[1]) - l[1] >= MathMax(2.0 * b1, 0.5 * r1) && c[1] >= l[1] + 0.6 * r1)
   { patLow = l[1]; return 1; }
   // 2) Harami tang + xac nhan: nen tang nho nam gon trong than nen giam truoc (luc ban chung lai, con yeu), nen sau tang tiep
   if(maxSh >= 3 && c[3] < o[3] && c[2] > o[2] && o[2] >= c[3] && c[2] <= o[3] && c[1] > o[1] && c[1] > h[2] &&
      MathMin(l[2], l[3]) <= edge)
   { patLow = MathMin(l[1], MathMin(l[2], l[3])); return 2; }
   // 5) Ba linh trang tu vung roi hoi nhe: gia da chay xa, chi mua o nen hoi (giam, lui >= 1/4 quang 3 nen, van tren vung)
   if(maxSh >= 4 && c[4] > o[4] && c[3] > o[3] && c[2] > o[2] && c[3] > c[4] && c[2] > c[3] && l[4] <= edge &&
      c[1] < o[1] && l[1] <= c[2] - 0.25 * (c[2] - l[4]) && l[1] > inval && c[1] > edge)
   { patLow = MathMin(l[1], l[4]); return 5; }
   return 0;
}

// Pha vo gia (v5.21). Pha vo THAT can du 3 dieu: than nen dong cua han ngoai vung (InpBreakMinBody), khoi luong tang manh
// (InpBreakMinVol) va khi gia hoi ve test lai, vung vua pha giu duoc (InpBreakRetest). Thieu 1 dieu la dang doan.
// 6 kieu pha vo gia va cach bot tranh: 1) pha bang rau - Donchian chi tin gia dong cua; 2) dong cua qua roi quay vao -
// InpBreakConfirm (va InpFakeoutFade danh nguoc chieu); 3) khong co volume - InpBreakMinVol; 4) luc ra tin - InpAvoidUSNews;
// 5) dau phien - InpBreakSkipOpenMin; 6) pha roi khong giu duoc - InpBreakRetest (dong cua lai trong vung truoc khi test = huy).
// Nen shift j co phai nen pha vo kenh Donchian (than, khoi luong, do dai, gio dau phien) khong; lvl = mep kenh da pha.
bool DonchBreakAt(const int j, const bool buy, const double atr, double &lvl)
{
   int ix = buy ? iHighest(_Symbol, P_TF, MODE_HIGH, P_DonchianPeriod, j + 1) : iLowest(_Symbol, P_TF, MODE_LOW, P_DonchianPeriod, j + 1);
   if(ix < 0) return false;
   lvl = buy ? iHigh(_Symbol, P_TF, ix) : iLow(_Symbol, P_TF, ix);
   double cb = iClose(_Symbol, P_TF, j), ob = iOpen(_Symbol, P_TF, j), hb = iHigh(_Symbol, P_TF, j), lb = iLow(_Symbol, P_TF, j);
   double margin = P_BreakMinATR * atr, range = hb - lb, body = MathAbs(cb - ob);
   if(buy ? cb <= lvl + margin : cb >= lvl - margin) return false;
   if(P_BreakMaxATR > 0 && range > P_BreakMaxATR * atr) return false;
   if(P_BreakMinBody > 0 && !((buy ? cb > ob : cb < ob) && range > 0 && body >= range * P_BreakMinBody / 100.0)) return false;
   if(P_BreakMinVol > 0)
   {
      double vs = 0; int vn = 0;
      for(int q = j + 1; q <= j + 20; q++) { long v = iTickVolume(_Symbol, P_TF, q); if(v > 0) { vs += (double)v; vn++; } }
      if(vn < 10 || (double)iTickVolume(_Symbol, P_TF, j) < P_BreakMinVol * vs / vn) return false;
   }
   if(BreakAtSessionOpen(iTime(_Symbol, P_TF, j))) return false;
   return true;
}
// Pha vo dau phien (kieu 5): nen pha vo mo cua trong InpBreakSkipOpenMin phut dau cua phien A (0 gio), London (7 gio),
// New York (13 gio) - gio server Exness = UTC. Cu pha dau tien trong phien rat hay la cai bay.
bool BreakAtSessionOpen(const datetime t)
{
   if(P_BreakSkipOpenMin <= 0) return false;
   MqlDateTime d; TimeToStruct(t, d);
   int mins = d.hour * 60 + d.min;
   int opens[] = {0, 7 * 60, 13 * 60};
   for(int i = 0; i < 3; i++) if(mins >= opens[i] && mins < opens[i] + P_BreakSkipOpenMin) return true;
   return false;
}

bool BaseSignals(const double atr, const double trend, const double fast,
                 const double c1, const double h1, const double l1,
                 bool &buyBase, bool &sellBase)
{
   buyBase = false; sellBase = false;
   g_sigSL = 0; g_sigTP = 0; g_sigRiskMult = 1; g_sigPartialPx = 0;
   if(P_Strategy == STRAT_DONCHIAN)
   {
      // Pha vo: nen "b" dong vuot dinh/day cao nhat/thap nhat cua N nen truoc no.
      // b = 1 (nen vua dong); neu InpBreakConfirm thi b = 2 va nen 1 phai van dong ngoai kenh.
      int b = P_BreakConfirm ? 2 : 1;
      int hiIdx = iHighest(_Symbol, P_TF, MODE_HIGH, P_DonchianPeriod, b + 1);
      int loIdx = iLowest(_Symbol,  P_TF, MODE_LOW,  P_DonchianPeriod, b + 1);
      if(hiIdx < 0 || loIdx < 0) return false;
      double chHigh = iHigh(_Symbol, P_TF, hiIdx);
      double chLow  = iLow(_Symbol,  P_TF, loIdx);
      double cb = iClose(_Symbol, P_TF, b), ob = iOpen(_Symbol, P_TF, b);
      double hb = iHigh(_Symbol, P_TF, b),  lb = iLow(_Symbol, P_TF, b);
      double margin = P_BreakMinATR * atr;                         // vuot kenh bao xa
      double range  = hb - lb;
      // Nen qua dai thuong la thanh ly day chuyen (lenh bi ep dong tren so lenh mong): vao theo la duoi gia
      bool   tooLong = P_BreakMaxATR > 0 && range > P_BreakMaxATR * atr;
      double body   = MathAbs(cb - ob);
      // Than nen: nen pha vo phai la nen cung chieu, than chiem it nhat X% bien do (khong phai chi rau dai)
      bool   bodyBuy  = P_BreakMinBody <= 0 || (cb > ob && range > 0 && body >= range * P_BreakMinBody / 100.0);
      bool   bodySell = P_BreakMinBody <= 0 || (cb < ob && range > 0 && body >= range * P_BreakMinBody / 100.0);
      // Khoi luong: MT5 cua Exness chi co so tick (khong co khoi luong that). Pha vo co nhieu tick hon
      // binh thuong = nhieu nguoi tham gia, it kha nang la pha vo gia tren so lenh mong.
      bool volOk = true;
      if(P_BreakMinVol > 0)
      {
         double vs = 0; int vn = 0;
         for(int q = b + 1; q <= b + 20; q++) { long v = iTickVolume(_Symbol, P_TF, q); if(v > 0) { vs += (double)v; vn++; } }
         volOk = vn >= 10 && (double)iTickVolume(_Symbol, P_TF, b) >= P_BreakMinVol * vs / vn;
      }
      buyBase  = volOk && cb > chHigh + margin && bodyBuy  && c1 > trend && (b == 1 || c1 > chHigh);
      sellBase = volOk && cb < chLow  - margin && bodySell && c1 < trend && (b == 1 || c1 < chLow);
      if(tooLong && (buyBase || sellBase)) { g_status = "Nen pha vo qua dai, bo qua"; return false; }
      if((buyBase || sellBase) && BreakAtSessionOpen(iTime(_Symbol, P_TF, b))) { g_status = "Pha vo dau phien, bo qua"; return false; }
      // Kieu 6: khong vao ngay khi vua pha. Cho gia hoi ve test lai mep kenh (trong InpBreakRetestATR ATR) va dong cua van
      // ngoai kenh, trong InpBreakRetestBars nen. Co nen dong cua quay lai trong kenh truoc khi test = pha vo that bai, bo.
      if(P_BreakRetest)
      {
         buyBase = false; sellBase = false;
         double tol = P_BreakRetestATR * atr;
         for(int j = 2; j <= 1 + P_BreakRetestBars && !buyBase && !sellBase; j++)
            for(int d = 0; d < 2 && !buyBase && !sellBase; d++)
            {
               bool buy = d == 0;
               double lvl = 0;
               if(!DonchBreakAt(j, buy, atr, lvl)) continue;
               bool ok = true;
               for(int m = j - 1; m >= 2 && ok; m--)
               {
                  double cm = iClose(_Symbol, P_TF, m);
                  if(buy ? (cm <= lvl || iLow(_Symbol, P_TF, m) <= lvl + tol) : (cm >= lvl || iHigh(_Symbol, P_TF, m) >= lvl - tol)) ok = false;
               }
               if(!ok) continue;                                          // da that bai, hoac da test (lan dau da xet)
               if(buy  && l1 <= lvl + tol && c1 > lvl && c1 > trend) buyBase = true;
               if(!buy && h1 >= lvl - tol && c1 < lvl && c1 < trend) sellBase = true;
            }
      }
      // Kieu 2 danh nguoc (InpFakeoutFade): nen 2 dong cua pha kenh, nen 1 dong cua quay nguoc vao trong -> nguoi vua mua pha vo
      // dang bi ket: vao chieu nguoc lai, SL ngoai dinh / day cua 2 nen + 0,25 ATR
      if(P_FakeoutFade && !buyBase && !sellBase)
      {
         double lv = 0, o1 = iOpen(_Symbol, P_TF, 1), h2 = iHigh(_Symbol, P_TF, 2), l2 = iLow(_Symbol, P_TF, 2);
         if(DonchBreakAt(2, true, atr, lv) && c1 < lv && c1 < o1)
         { sellBase = true; g_sigSL = MathMax(MathMax(h1, h2) + 0.25 * atr - c1, 0.5 * atr); }
         else if(DonchBreakAt(2, false, atr, lv) && c1 > lv && c1 > o1)
         { buyBase = true; g_sigSL = MathMax(c1 - (MathMin(l1, l2) - 0.25 * atr), 0.5 * atr); }
      }
   }
   else if(P_Strategy == STRAT_RSI_REVERT)
   {
      // Gia tren EMA xu huong (xu huong len) nhung vua giam manh ngan han (RSI rat thap) -> mua hoi; nguoc lai voi Sell
      buyBase  = c1 > trend && g_rsi < P_RsiLow;
      sellBase = c1 < trend && g_rsi > P_RsiHigh;
   }
   else if(P_Strategy == STRAT_ORB)
   {
      // Vung gia [bat dau, bat dau + N phut] moi ngay (gio server). Trong 4 gio sau do, nen dau tien dong
      // ngoai vung thi vao theo huong pha vo. Nen gioi han 1 lenh/ngay bang InpMaxTradesPerDay.
      datetime t1 = iTime(_Symbol, P_TF, 1);
      MqlDateTime d; TimeToStruct(t1, d);
      datetime day = t1 - (d.hour * 3600 + d.min * 60 + d.sec);
      datetime rs = day + (P_OrbNewYork ? NYOpenUTCMin(day) : P_OrbStartMin) * 60, re = rs + P_OrbMinutes * 60;
      if(t1 < re || t1 >= re + 4 * 3600) return true;
      if(d.day_of_week == 0 || d.day_of_week == 6) return true;   // thu Bay / Chu nhat: chung khoan My nghi
      int sIdx = iBarShift(_Symbol, P_TF, rs, false), eIdx = iBarShift(_Symbol, P_TF, re - 1, false);
      if(sIdx < 0 || eIdx < 1 || sIdx < eIdx || iTime(_Symbol, P_TF, sIdx) < rs - PeriodSeconds(P_TF)) return true;
      int cnt = sIdx - eIdx + 1;
      double rh = iHigh(_Symbol, P_TF, iHighest(_Symbol, P_TF, MODE_HIGH, cnt, eIdx));
      double rl = iLow(_Symbol,  P_TF, iLowest(_Symbol,  P_TF, MODE_LOW,  cnt, eIdx));
      double c2 = iClose(_Symbol, P_TF, 2);
      buyBase  = c1 > rh && (c2 <= rh || eIdx == 2);
      sellBase = c1 < rl && (c2 >= rl || eIdx == 2);
   }
   else if(P_Strategy == STRAT_MACD)
   {
      // Dong MACD vua cat len duong tin hieu o nen vua dong -> Buy; cat xuong -> Sell
      double m[2], g[2];
      if(CopyBuffer(hMACD, 0, 1, 2, m) != 2 || CopyBuffer(hMACD, 1, 1, 2, g) != 2) return false;
      // m[0] = nen 2, m[1] = nen 1 (CopyBuffer tra theo thu tu thoi gian)
      buyBase  = m[1] > g[1] && m[0] <= g[0];
      sellBase = m[1] < g[1] && m[0] >= g[0];
   }
   else if(P_Strategy == STRAT_IMOM)
   {
      // Shen, Urquhart & Wang (2022): "ngay" BTC tinh tu 17:00 hom truoc toi 17:00 gio New York (luc CME nghi),
      // mo cua 9:00. Nua gio dau = tu 17:00 hom truoc toi 9:30; nua gio ke cuoi = 16:00-16:30.
      // Vao lenh luc 16:30, dong luc 17:00 (lam o PyramidStep).
      datetime t0 = iTime(_Symbol, P_TF, 0);
      MqlDateTime d; TimeToStruct(t0, d);
      datetime day = t0 - (d.hour * 3600 + d.min * 60 + d.sec);
      datetime tEntry = NYTime(day, 16 * 60 + 30);
      if(t0 != tEntry) return true;
      double pPrevClose = CloseAt(NYTime(day - 86400, 17 * 60));
      double pFirst     = CloseAt(NYTime(day, 9 * 60 + 30));
      double p1600      = CloseAt(NYTime(day, 16 * 60));
      double p1630      = CloseAt(tEntry);
      if(pPrevClose <= 0 || pFirst <= 0 || p1600 <= 0 || p1630 <= 0) return true;
      double rFirst = pFirst / pPrevClose - 1, rSLH = p1630 / p1600 - 1;
      if(P_ImomMode == 1)      { buyBase = rFirst > 0;  sellBase = !buyBase; }
      else if(P_ImomMode == 2) { buyBase = rSLH < 0;    sellBase = !buyBase; }
      else                     { buyBase = rFirst > 0 && rSLH < 0; sellBase = rFirst <= 0 && rSLH >= 0; }
   }
   else if(P_Strategy == STRAT_EXHAUST)
   {
      // Gia da chay mot chieu trong ngay >= x ATR(20) D1, dinh/day vua lap trong 6 nen gan day,
      // va nen vua dong bat dau quay dau (dong qua day/dinh cua nen truoc). Vao nguoc lai, TP o dai Bollinger ben kia.
      double ad[], up[], lo[];
      if(CopyBuffer(hATRD1, 0, 1, 1, ad) != 1 || CopyBuffer(hBB, 1, 1, 1, up) != 1 || CopyBuffer(hBB, 2, 1, 1, lo) != 1) return false;
      double dOpen = iOpen(_Symbol, PERIOD_D1, 0), dHigh = iHigh(_Symbol, PERIOD_D1, 0), dLow = iLow(_Symbol, PERIOD_D1, 0);
      if(dOpen <= 0 || ad[0] <= 0) return false;
      int hiI = iHighest(_Symbol, P_TF, MODE_HIGH, 6, 1), loI = iLowest(_Symbol, P_TF, MODE_LOW, 6, 1);
      double recentHi = iHigh(_Symbol, P_TF, hiI), recentLo = iLow(_Symbol, P_TF, loI);
      double h2 = iHigh(_Symbol, P_TF, 2), l2 = iLow(_Symbol, P_TF, 2);
      bool upRun = dHigh - dOpen >= P_ExhaustATR * ad[0] && recentHi >= dHigh;   // cu tang manh, dinh moi gan day
      bool dnRun = dOpen - dLow  >= P_ExhaustATR * ad[0] && recentLo <= dLow;
      sellBase = upRun && c1 < l2 && lo[0] < c1;      // bat dau hoi xuong, TP = dai duoi
      buyBase  = dnRun && c1 > h2 && up[0] > c1;      // bat dau hoi len, TP = dai tren
      if(sellBase) { g_sigSL = recentHi + 0.3 * atr - c1; g_sigTP = lo[0]; }
      if(buyBase)  { g_sigSL = c1 - (recentLo - 0.3 * atr); g_sigTP = up[0]; }
   }
   else if(P_Strategy == STRAT_FVG)
   {
      // FVG tang: nen giua (k) dai >= x ATR, tick >= 1,5 lan TB, va day nen k-1 > dinh nen k+1 (khoang trong).
      // Lan dau gia quay lai cham khoang trong (nen 1 cham, dong van tren day khoang trong) -> Buy. Giam thi nguoc lai.
      // InpFvgCandle (v5.22): khong vao ngay khi cham. Cho 1 trong 5 mau nen xac nhan tai FVG (ZoneCandle); co nen dong cua
      // thung han qua FVG (duoi day FVG tang / tren dinh FVG giam) thi vung da hong, bo qua.
      if(P_FvgCandle)
      {
         double o[7], h[7], l[7], c[7], no[7], nh[7], nl[7], nc[7];
         for(int q = 1; q <= 6; q++)
         {
            o[q] = iOpen(_Symbol, P_TF, q); h[q] = iHigh(_Symbol, P_TF, q); l[q] = iLow(_Symbol, P_TF, q); c[q] = iClose(_Symbol, P_TF, q);
            no[q] = -o[q]; nh[q] = -l[q]; nl[q] = -h[q]; nc[q] = -c[q];
         }
         o[0] = h[0] = l[0] = c[0] = no[0] = nh[0] = nl[0] = nc[0] = 0;
         for(int k = 4; k <= P_FvgLookback + 2 && !buyBase && !sellBase; k++)
         {
            datetime tk = iTime(_Symbol, P_TF, k);
            if(tk <= g_fvgUsed) break;
            double hk = iHigh(_Symbol, P_TF, k), lk = iLow(_Symbol, P_TF, k);
            if(hk - lk < P_FvgBigATR * atr) continue;
            double vs = 0; int vn = 0;
            for(int q = k + 1; q <= k + 20; q++) { long v = iTickVolume(_Symbol, P_TF, q); if(v > 0) { vs += (double)v; vn++; } }
            if(vn < 10 || (double)iTickVolume(_Symbol, P_TF, k) < 1.5 * vs / vn) continue;
            double gbU = iHigh(_Symbol, P_TF, k + 1), gtU = iLow(_Symbol, P_TF, k - 1);     // FVG tang: day / dinh
            double gtD = iLow(_Symbol, P_TF, k + 1),  gbD = iHigh(_Symbol, P_TF, k - 1);    // FVG giam: dinh / day
            bool isUp = iClose(_Symbol, P_TF, k) > iOpen(_Symbol, P_TF, k) && gtU > gbU;
            bool isDn = iClose(_Symbol, P_TF, k) < iOpen(_Symbol, P_TF, k) && gbD < gtD;
            if(!isUp && !isDn) continue;
            // Lan ve dau tien: khong nen nao cu hon cua so mau nen (shift >= 7) cham vung; khong nen nao dong cua thung vung
            bool old = false, broken = false;
            for(int q = k - 2; q >= 1; q--)
            {
               if(q >= 7 && (isUp ? iLow(_Symbol, P_TF, q) <= gtU : iHigh(_Symbol, P_TF, q) >= gbD)) old = true;
               double cq = iClose(_Symbol, P_TF, q);
               if(isUp ? cq < gbU : cq > gtD) broken = true;
            }
            if(old || broken) continue;
            int maxSh = MathMin(5, k - 2);
            double pl = 0;
            if(isUp)
            {
               int pat = ZoneCandle(o, h, l, c, maxSh, gtU, gbU, atr, pl);
               if(pat > 0) { buyBase = true; g_sigSL = MathMax(c1 - (MathMin(pl, gbU) - 0.25 * atr), 0.5 * atr); g_fvgUsed = tk; g_fvgPat = pat; }
            }
            else
            {
               int pat = ZoneCandle(no, nh, nl, nc, maxSh, -gbD, -gtD, atr, pl);
               if(pat > 0) { sellBase = true; g_sigSL = MathMax((MathMax(-pl, gtD) + 0.25 * atr) - c1, 0.5 * atr); g_fvgUsed = tk; g_fvgPat = pat; }
            }
         }
      }
      for(int k = 3; k <= P_FvgLookback + 2 && !buyBase && !sellBase && !P_FvgCandle; k++)
      {
         datetime tk = iTime(_Symbol, P_TF, k);
         if(tk <= g_fvgUsed) break;
         double hk = iHigh(_Symbol, P_TF, k), lk = iLow(_Symbol, P_TF, k);
         if(hk - lk < P_FvgBigATR * atr) continue;
         double vs = 0; int vn = 0;
         for(int q = k + 1; q <= k + 20; q++) { long v = iTickVolume(_Symbol, P_TF, q); if(v > 0) { vs += (double)v; vn++; } }
         if(vn < 10 || (double)iTickVolume(_Symbol, P_TF, k) < 1.5 * vs / vn) continue;
         double gapBotUp = iHigh(_Symbol, P_TF, k + 1), gapTopUp = iLow(_Symbol, P_TF, k - 1);   // FVG tang
         double gapTopDn = iLow(_Symbol, P_TF, k + 1),  gapBotDn = iHigh(_Symbol, P_TF, k - 1);  // FVG giam
         bool isUp = iClose(_Symbol, P_TF, k) > iOpen(_Symbol, P_TF, k) && gapTopUp > gapBotUp;
         bool isDn = iClose(_Symbol, P_TF, k) < iOpen(_Symbol, P_TF, k) && gapBotDn < gapTopDn;
         if(!isUp && !isDn) continue;
         // Chua bi cham lai tu khi hinh thanh (cac nen k-2 .. 2)
         bool touched = false;
         for(int q = k - 2; q >= 2; q--)
            if(isUp ? iLow(_Symbol, P_TF, q) <= gapTopUp : iHigh(_Symbol, P_TF, q) >= gapBotDn) { touched = true; break; }
         if(touched) continue;
         if(isUp && l1 <= gapTopUp && c1 > gapBotUp)
         { buyBase = true;  g_sigSL = c1 - (gapBotUp - 0.5 * atr); g_fvgUsed = tk; }
         if(isDn && h1 >= gapBotDn && c1 < gapTopDn)
         { sellBase = true; g_sigSL = (gapTopDn + 0.5 * atr) - c1; g_fvgUsed = tk; }
      }
   }
   else if(P_Strategy == STRAT_SPRING)
   {
      // Vung di ngang = N nen truoc nen 1, rong <= x ATR, dinh va day moi phia duoc cham it nhat 2 lan (trong 0,25 ATR).
      // Spring: nen 1 thung day vung roi dong lai ben trong -> Buy, TP = dinh vung. Upthrust: nguoc lai.
      int hiI = iHighest(_Symbol, P_TF, MODE_HIGH, P_RangeBars, 2), loI = iLowest(_Symbol, P_TF, MODE_LOW, P_RangeBars, 2);
      if(hiI < 0 || loI < 0) return false;
      double rh = iHigh(_Symbol, P_TF, hiI), rl = iLow(_Symbol, P_TF, loI);
      if(rh - rl > P_RangeMaxATR * atr || rh - rl < atr) return true;
      int tH = 0, tL = 0;
      for(int q = 2; q < 2 + P_RangeBars; q++)
      {
         if(iHigh(_Symbol, P_TF, q) >= rh - 0.25 * atr && (q == 2 || iHigh(_Symbol, P_TF, q - 1) < rh - 0.25 * atr)) tH++;
         if(iLow(_Symbol, P_TF, q)  <= rl + 0.25 * atr && (q == 2 || iLow(_Symbol, P_TF, q - 1)  > rl + 0.25 * atr)) tL++;
      }
      if(tH < 2 || tL < 2) return true;
      buyBase  = l1 < rl && c1 > rl;
      sellBase = h1 > rh && c1 < rh;
      if(buyBase && sellBase) { buyBase = false; sellBase = false; }
      if(buyBase)  { g_sigSL = c1 - (l1 - 0.2 * atr); g_sigTP = rh; }
      if(sellBase) { g_sigSL = (h1 + 0.2 * atr) - c1; g_sigTP = rl; }
   }
   else if(P_Strategy == STRAT_FIBVP)
   {
      // Fibonacci + Volume Profile (v5.11). Fibonacci cho biet gia CO THE dung o dau, Volume Profile cho biet o do co
      // giao dich that hay khong: chi cho mua/ban o muc Fibonacci nam trong vung giao dich day.
      // 1) Con song gan nhat trong InpFibLookback nen (bo nen 1): song tang = day thap nhat xuat hien TRUOC dinh cao nhat,
      //    bien do >= InpFibMinSwingATR x ATR. Song giam nguoc lai. Moi con song chi vao lenh 1 lan.
      // 2) Volume Profile cua con song: chia [day, dinh] thanh InpVPBins o, rai so tick cua tung nen (khung InpVPTFmin)
      //    deu len cac o ma nen do di qua. O "day" = so tick >= InpVPHighMult x trung binh cac o.
      //    Exness chi co so tick (so lan bao gia), khong co khoi luong that: day la uoc luong cua "dau chan tien".
      // 3) Xet cac muc 0,382 / 0,5 / 0,618 / 0,786 tu nong toi sau. Muc roi vao o mong: bo qua. Muc trong o day:
      //    vung = cac o day lien nhau quanh muc do.
      // 4) Xac nhan (song tang): nen 1 la nen tang, rau duoi cham vung, khong xuyen qua day vung qua 0,5 ATR, dong tren muc.
      //    SL = duoi day vung (hoac rau nen) 0,25 ATR, toi thieu 0,5 ATR. TP = dinh con song; bo neu TP < InpFibMinRR x SL.
      int lb = P_FibLookback < 10 ? 10 : P_FibLookback;
      int hiI = iHighest(_Symbol, P_TF, MODE_HIGH, lb, 2), loI = iLowest(_Symbol, P_TF, MODE_LOW, lb, 2);
      if(hiI < 0 || loI < 0 || atr <= 0) return false;
      double sH = iHigh(_Symbol, P_TF, hiI), sL = iLow(_Symbol, P_TF, loI), swing = sH - sL;
      if(hiI == loI || swing < P_FibMinSwingATR * atr) return true;
      bool up = loI > hiI;                                   // shift lon hon = cu hon: day truoc dinh -> song tang
      int iOld = hiI > loI ? hiI : loI, iNew = hiI < loI ? hiI : loI;
      datetime tExt = iTime(_Symbol, P_TF, iNew);            // thoi diem dinh (song tang) / day (song giam)
      if(tExt <= g_fibUsed) return true;
      if(up ? h1 > sH : l1 < sL) return true;                // nen 1 da vuot qua dinh/day: khong con la nhip hoi
      ENUM_TIMEFRAMES vtf = P_VPTFmin > 0 ? TFFromMin(P_VPTFmin) : P_TF;
      if(vtf == PERIOD_CURRENT) vtf = P_TF;
      datetime tFrom = iTime(_Symbol, P_TF, iOld), tTo = iTime(_Symbol, P_TF, iNew) + PeriodSeconds(P_TF) - 1;
      MqlRates vr[];
      int nv = CopyRates(_Symbol, vtf, tFrom, tTo, vr);
      if(nv < 10) return false;                              // chua du du lieu khung dem tick
      int nb = P_VPBins < 10 ? 10 : (P_VPBins > 200 ? 200 : P_VPBins);
      double bin = swing / nb;
      double vp[];
      ArrayResize(vp, nb); ArrayInitialize(vp, 0.0);
      double tot = 0;
      for(int i = 0; i < nv; i++)
      {
         double lo = MathMax(vr[i].low, sL), hi = MathMin(vr[i].high, sH);
         if(hi < lo || vr[i].tick_volume <= 0) continue;
         int ka = (int)MathFloor((lo - sL) / bin), kb = (int)MathFloor((hi - sL) / bin);
         if(ka < 0) ka = 0; if(ka > nb - 1) ka = nb - 1; if(kb < 0) kb = 0; if(kb > nb - 1) kb = nb - 1;
         double per = (double)vr[i].tick_volume / (kb - ka + 1);
         for(int k = ka; k <= kb; k++) vp[k] += per;
         tot += (double)vr[i].tick_volume;
      }
      if(tot <= 0) return false;
      double thr = P_VPHighMult * tot / nb;
      double o1 = iOpen(_Symbol, P_TF, 1);
      double fib[4] = { 0.382, 0.5, 0.618, 0.786 };
      for(int f = 0; f < 4 && !buyBase && !sellBase; f++)
      {
         double lvl = up ? sH - fib[f] * swing : sL + fib[f] * swing;
         int k = (int)MathFloor((lvl - sL) / bin);
         if(k < 0) k = 0; if(k > nb - 1) k = nb - 1;
         if(vp[k] < thr) continue;                           // muc Fibonacci nam trong vung mong: gia de truot qua
         int za = k, zb = k;
         while(za > 0 && vp[za - 1] >= thr) za--;
         while(zb < nb - 1 && vp[zb + 1] >= thr) zb++;
         double zLo = sL + za * bin, zHi = sL + (zb + 1) * bin;
         if(up && c1 > o1 && l1 <= zHi && l1 >= zLo - 0.5 * atr && c1 > lvl)
         {
            double sl = MathMax(c1 - (MathMin(l1, zLo) - 0.25 * atr), 0.5 * atr);
            if(sH - c1 < P_FibMinRR * sl) continue;
            buyBase = true; g_sigSL = sl; g_sigTP = sH; g_fibUsed = tExt;
         }
         if(!up && c1 < o1 && h1 >= zLo && h1 <= zHi + 0.5 * atr && c1 < lvl)
         {
            double sl = MathMax((MathMax(h1, zHi) + 0.25 * atr) - c1, 0.5 * atr);
            if(c1 - sL < P_FibMinRR * sl) continue;
            sellBase = true; g_sigSL = sl; g_sigTP = sL; g_fibUsed = tExt;
         }
      }
   }
   else if(P_Strategy == STRAT_DIVCVD)
   {
      // Phan ky RSI xac nhan bang CVD (v5.13, CHUA KIEM THU). RSI tinh tu gia dong cua: chi thay gia MAT DA (canh bao).
      // CVD = tong don (mua chu dong - ban chu dong): thay AI DANG BAM NUT (bang chung). Co canh bao ma chua co bang chung
      // thi cho; co ca hai moi vao lenh.
      // (a) Phan ky o dinh: 2 dinh gan nhat (dinh = cao hon InpDivPivot nen moi ben), dinh sau cao hon dinh truoc,
      //     RSI dinh sau THAP hon (canh bao) VA CVD dinh sau KHONG cao hon (nguoi mua chu dong da rut) -> Sell khi
      //     dinh sau vua duoc xac nhan va gia dong duoi gia dong cua nen dinh. RSI phan ky ma CVD van lap dinh moi =
      //     nguoi mua van do tien vao: KHONG ban (chinh la luc nguoi chi nhin RSI bi quet). Day: nguoc lai.
      // (b) Hap thu o day: RSI qua ban (canh bao) + trong InpAbsorbBars nen gan nhat CVD do manh (ban chu dong >=
      //     InpAbsorbDelta x tong khoi luong) MA gia khong giam them (dong cua giam < 0,25 ATR), gia dang o 1/4 duoi
      //     cua vung InpDivLookback nen: co nguoi hap thu het hang ban -> Buy. Dinh: nguoc lai.
      // SL: qua dinh / day + 0,25 ATR (toi thieu 0,5 ATR). TP theo InpRR (bo 09 dat 2R).
      // CVD lay tu nen Binance Futures cung khung (OrderFlow.mqh): Exness khong co chieu mua / ban chu dong.
      // Thieu du lieu Binance: khong vao lenh.
      int L = P_DivLookback < 15 ? 15 : P_DivLookback, k = P_DivPivot < 1 ? 1 : P_DivPivot;
      double rv[];
      if(CopyBuffer(hRSI, 0, 1, L, rv) != L) return false;            // rv[0] = nen L, rv[L-1] = nen 1
      double fv[], fb[];
      datetime t1 = iTime(_Symbol, P_TF, 1);
      bool got = MQLInfoInteger(MQL_TESTER) ? FlowFromFile(t1, L - 1, fv, fb) : FlowFromBinance(t1, L - 1, fv, fb);
      if(!got || ArraySize(fv) != L) { g_flowNoData++; g_status = "RSI + CVD: chua co du lieu Binance, khong vao lenh"; return true; }
      double cvd[], hi[], lo[];
      ArrayResize(cvd, L); ArrayResize(hi, L); ArrayResize(lo, L);
      double run = 0, rHi = 0, rLo = DBL_MAX;
      for(int i = 0; i < L; i++)
      {
         run += 2.0 * fb[i] - fv[i];
         cvd[i] = run;
         hi[i] = iHigh(_Symbol, P_TF, L - i); lo[i] = iLow(_Symbol, P_TF, L - i);
         if(hi[i] > rHi) rHi = hi[i];
         if(lo[i] < rLo) rLo = lo[i];
      }
      // (a) dinh / day vua duoc xac nhan: chi so p = nen k + 1
      int p = L - 1 - k;
      datetime tp = iTime(_Symbol, P_TF, k + 1);
      double cp = iClose(_Symbol, P_TF, k + 1);
      if(tp > g_divUsed)
      {
         bool ph = true, pl = true;
         for(int j = p - k; j <= p + k; j++)
         {
            if(j == p) continue;
            if(hi[j] >= hi[p]) ph = false;
            if(lo[j] <= lo[p]) pl = false;
         }
         for(int q = p - k - 1; q >= k && (ph || pl); q--)
         {
            bool qh = ph, ql = pl;
            for(int j = q - k; j <= q + k; j++)
            {
               if(j == q) continue;
               if(hi[j] >= hi[q]) qh = false;
               if(lo[j] <= lo[q]) ql = false;
            }
            if(qh && hi[p] > hi[q] && rv[p] < rv[q])                    // RSI canh bao o dinh
            {
               if(cvd[p] <= cvd[q] && c1 < cp)
               { sellBase = true; g_sigSL = MathMax((hi[p] + 0.25 * atr) - c1, 0.5 * atr); g_divUsed = tp; }
               else g_status = "RSI phan ky o dinh nhung CVD van lap dinh moi: nguoi mua con o day, cho";
            }
            if(ql && lo[p] < lo[q] && rv[p] > rv[q])                    // RSI canh bao o day
            {
               if(cvd[p] >= cvd[q] && c1 > cp)
               { buyBase = true; g_sigSL = MathMax(c1 - (lo[p] - 0.25 * atr), 0.5 * atr); g_divUsed = tp; }
               else g_status = "RSI phan ky o day nhung CVD van lap day moi: nguoi ban con o day, cho";
            }
            if(qh || ql) break;                                          // chi so voi dinh / day lien truoc
         }
      }
      // (b) Hap thu
      int M = P_AbsorbBars < 2 ? 2 : (P_AbsorbBars > L - 2 ? L - 2 : P_AbsorbBars);
      if(!buyBase && !sellBase && t1 - g_absUsed >= (long)M * PeriodSeconds(P_TF) && rHi > rLo)
      {
         double dv = 0, vv = 0, mLo = DBL_MAX, mHi = 0;
         for(int i = L - M; i < L; i++)
         {
            dv += 2.0 * fb[i] - fv[i]; vv += fv[i];
            if(lo[i] < mLo) mLo = lo[i];
            if(hi[i] > mHi) mHi = hi[i];
         }
         double chg = c1 - iClose(_Symbol, P_TF, M + 1);
         double pos = (c1 - rLo) / (rHi - rLo);
         double rsiNow = rv[L - 1];
         if(vv > 0 && dv <= -P_AbsorbDelta * vv && chg >= -0.25 * atr && pos <= 0.25 && rsiNow <= P_DivRsiLow)
         { buyBase = true; g_sigSL = MathMax(c1 - (mLo - 0.25 * atr), 0.5 * atr); g_absUsed = t1; }
         else if(vv > 0 && dv >= P_AbsorbDelta * vv && chg <= 0.25 * atr && pos >= 0.75 && rsiNow >= 100.0 - P_DivRsiLow)
         { sellBase = true; g_sigSL = MathMax((mHi + 0.25 * atr) - c1, 0.5 * atr); g_absUsed = t1; }
      }
   }
   else if(P_Strategy == STRAT_BIGTRADE)
   {
      // Big Trades (v5.14, CHUA KIEM THU): lenh lon de lai dau chan tren bieu do. Bong bong chi cho biet CO lenh lon,
      // khong cho biet lenh do THANG hay THUA: phai nhin gia lam gi ngay sau do. Chi xet o vung quan trong (dinh / day cu).
      // "Bong bong" = nen co khoi luong >= InpBigMult x TB 20 nen truoc tren Binance Futures, phe chu dong ap dao
      // (delta >= InpBigMinDelta: xanh = mua chu dong, do = ban chu dong). Exness khong co kich thuoc tung lenh nen
      // day la xap xi theo CA cay nen, khong phai tung lenh khop.
      // Uu tien:
      //  1) HAP THU (manh nhat): bong bong do to sat day cu ma gia khong giam them roi bat len -> nguoi ban lon bi nuot,
      //     thuong la day -> Buy. Bong bong xanh to sat dinh cu ma gia khong len noi -> nguoi mua bi ket -> Sell.
      //  2) CHUOI THANH LY: >= InpBigClusterMin bong bong do trong InpBigClusterBars nen, gia roi >= 3 ATR. Thuong la
      //     cat lo / thanh ly hang loat, khong phai tay to ban. Chuoi ket thuc ma gia ngung roi -> nguoi ban da can -> Buy.
      //  3) GIA DI THEO: bong bong xanh to roi gia tang manh (dong cua vuot dinh nen bong bong >= 0,5 ATR trong 3 nen).
      //     Vung bong bong thanh ho tro (nguoi dat lenh lon bao ve gia von): lan dau gia quay lai cham vung va dong nen
      //     tang -> Buy. Bong bong do + gia giam: nguoc lai.
      // SL ngoai vung / day / dinh 0,25 ATR (toi thieu 0,5 ATR). TP theo InpRR. Moi bong bong / chuoi chi vao 1 lan.
      int L = P_BigLookback < 30 ? 30 : P_BigLookback;
      double fv[], fb[];
      datetime t1 = iTime(_Symbol, P_TF, 1);
      bool got = MQLInfoInteger(MQL_TESTER) ? FlowFromFile(t1, L - 1, fv, fb) : FlowFromBinance(t1, L - 1, fv, fb);
      if(!got || ArraySize(fv) != L) { g_flowNoData++; g_status = "Big Trades: chua co du lieu Binance, khong vao lenh"; return true; }
      double hi[], lo[], cl[];
      int bub[];
      datetime tm[];
      ArrayResize(hi, L); ArrayResize(lo, L); ArrayResize(cl, L); ArrayResize(bub, L); ArrayResize(tm, L);
      for(int i = 0; i < L; i++)
      {
         int sh = L - i;
         hi[i] = iHigh(_Symbol, P_TF, sh); lo[i] = iLow(_Symbol, P_TF, sh); cl[i] = iClose(_Symbol, P_TF, sh);
         tm[i] = iTime(_Symbol, P_TF, sh);
         bub[i] = 0;
         if(i < 20 || fv[i] <= 0) continue;
         double avg = 0;
         for(int q = i - 20; q < i; q++) avg += fv[q];
         avg /= 20.0;
         if(avg <= 0 || fv[i] < P_BigMult * avg) continue;
         double d = (2.0 * fb[i] - fv[i]) / fv[i];
         bub[i] = d >= P_BigMinDelta ? 1 : (d <= -P_BigMinDelta ? -1 : 0);
      }
      int last = L - 1;
      double zone = P_BigZoneATR * atr, o1 = iOpen(_Symbol, P_TF, 1);
      // 1) Hap thu: bong bong o nen 1 hoac nen 2
      for(int j = last; j >= last - 1 && !buyBase && !sellBase; j--)
      {
         if(bub[j] == 0 || tm[j] <= g_bigUsed) continue;
         double mn = lo[j], mx = hi[j];
         for(int m = j + 1; m <= last; m++) { if(lo[m] < mn) mn = lo[m]; if(hi[m] > mx) mx = hi[m]; }
         double rj = hi[j] - lo[j];
         if(bub[j] < 0 && BigNearSwing(hi, lo, j, lo[j], true, zone) && mn >= lo[j] - 0.1 * atr)
         {
            bool react = j == last ? (rj > 0 && (c1 - lo[j]) / rj >= 0.6) : (c1 > o1 && c1 > cl[j]);
            if(react) { buyBase = true; g_sigSL = MathMax(c1 - (mn - 0.25 * atr), 0.5 * atr); g_bigUsed = tm[j]; }
         }
         if(!buyBase && bub[j] > 0 && BigNearSwing(hi, lo, j, hi[j], false, zone) && mx <= hi[j] + 0.1 * atr)
         {
            bool react = j == last ? (rj > 0 && (hi[j] - c1) / rj >= 0.6) : (c1 < o1 && c1 < cl[j]);
            if(react) { sellBase = true; g_sigSL = MathMax((mx + 0.25 * atr) - c1, 0.5 * atr); g_bigUsed = tm[j]; }
         }
      }
      // 2) Chuoi thanh ly vua ket thuc (nen 1 khong con la bong bong cung mau)
      int CB = P_BigClusterBars < 3 ? 3 : (P_BigClusterBars > L - 21 ? L - 21 : P_BigClusterBars);
      if(!buyBase && !sellBase && tm[last - 1] > g_bigUsed)
      {
         int nRed = 0, nGreen = 0;
         double cMx = 0, cMn = DBL_MAX;
         for(int m = last - CB; m <= last - 1; m++)
         {
            if(bub[m] < 0) nRed++;
            if(bub[m] > 0) nGreen++;
            if(hi[m] > cMx) cMx = hi[m];
            if(lo[m] < cMn) cMn = lo[m];
         }
         bool fell = cMx - cMn >= 3.0 * atr;
         if(nRed >= P_BigClusterMin && fell && bub[last] >= 0 && l1 >= cMn - 0.1 * atr && c1 > o1)
         { buyBase = true; g_sigSL = MathMax(c1 - (cMn - 0.25 * atr), 0.5 * atr); g_bigUsed = tm[last - 1]; }
         else if(nGreen >= P_BigClusterMin && fell && bub[last] <= 0 && h1 <= cMx + 0.1 * atr && c1 < o1)
         { sellBase = true; g_sigSL = MathMax((cMx + 0.25 * atr) - c1, 0.5 * atr); g_bigUsed = tm[last - 1]; }
      }
      // 3) Gia di theo bong bong -> vung bong bong thanh ho tro / khang cu, vao o lan cham lai dau tien
      for(int j = last - 4; j >= 20 && !buyBase && !sellBase; j--)
      {
         if(bub[j] == 0 || tm[j] <= g_bigUsed) continue;
         double bestC = cl[j + 1], worstC = cl[j + 1];
         for(int m = j + 1; m <= j + 3; m++) { if(cl[m] > bestC) bestC = cl[m]; if(cl[m] < worstC) worstC = cl[m]; }
         bool touched = false;
         if(bub[j] > 0 && bestC >= hi[j] + 0.5 * atr)                   // xanh, gia tang manh sau do
         {
            for(int m = j + 4; m < last && !touched; m++) if(lo[m] <= hi[j]) touched = true;
            if(!touched && l1 <= hi[j] && l1 >= lo[j] - 0.25 * atr && c1 > o1 && c1 > (hi[j] + lo[j]) / 2.0)
            { buyBase = true; g_sigSL = MathMax(c1 - (lo[j] - 0.25 * atr), 0.5 * atr); g_bigUsed = tm[j]; }
            break;                                                         // chi xet bong bong gan nhat co gia di theo
         }
         if(bub[j] < 0 && worstC <= lo[j] - 0.5 * atr)                   // do, gia giam manh sau do
         {
            for(int m = j + 4; m < last && !touched; m++) if(hi[m] >= lo[j]) touched = true;
            if(!touched && h1 >= lo[j] && h1 <= hi[j] + 0.25 * atr && c1 < o1 && c1 < (hi[j] + lo[j]) / 2.0)
            { sellBase = true; g_sigSL = MathMax((hi[j] + 0.25 * atr) - c1, 0.5 * atr); g_bigUsed = tm[j]; }
            break;
         }
      }
   }
   else if(P_Strategy == STRAT_KNIFE)
   {
      bool kb; int km; double ks, kt; datetime kk;
      if(KnifeScan(atr, kb, km, ks, kt, kk))
      {
         bool take = km == 2 ? kk != g_knifeUsed : (P_KnifeProbePct > 0 && kk != g_knifeProbeUsed && kk != g_knifeUsed);
         if(take)
         {
            if(kb) buyBase = true; else sellBase = true;
            g_sigSL = ks; g_sigPartialPx = kt;
            g_sigRiskMult = km == 1 ? MathMin(1.0, P_KnifeProbePct / 100.0) : 1.0;
            if(km == 1) g_knifeProbeUsed = kk; else g_knifeUsed = kk;
         }
      }
   }
   else if(P_Strategy == STRAT_DOW)
   {
      // Thuy trieu + con song (v5.23): chi giao dich theo chieu thuy trieu (DowOk, khung InpDowTF), dung con song nguoc chieu
      // lam cho vao lenh. Con song = cau truc khung chinh: dang giam (song hoi trong thuy trieu tang) va nen vua dong cua vuot
      // dinh gan nhat cua con song -> con song da het, Buy. SL duoi day con song - 0,25 ATR. Thuy trieu giam: nguoc lai.
      DowState w;
      if(!DowCalc(P_TF, 300, P_DowPivot, w)) return false;
      if(w.brk == 1 && w.prev == -1 && w.pl > 0)  { buyBase = true;  g_sigSL = MathMax(c1 - (w.pl - 0.25 * atr), 0.5 * atr); }
      if(w.brk == -1 && w.prev == 1 && w.ph > 0)  { sellBase = true; g_sigSL = MathMax((w.ph + 0.25 * atr) - c1, 0.5 * atr); }
   }
   else if(P_Strategy == STRAT_OB)
   {
      bool ob; int om; double os, ot; datetime okey;
      if(OBScan(atr, ob, om, os, ot, okey))
      {
         if(ob) buyBase = true; else sellBase = true;
         g_sigSL = os; g_sigTP = ot;
         if(om == 4) g_obFlipUsed = okey; else g_obUsed = okey;
      }
   }
   else if(P_Strategy == STRAT_DISTRIB)
   {
      // Hop phan phoi / tich luy (v5.15, CHUA KIEM THU). Cu sap nao cung de lai dau vet tren bieu do truoc khi xay ra,
      // 5 nhip lap lai o hau het cac cu sap:
      //  1) nen hung phan: tang rat dai, khoi luong lon nhat ca doan, de rau tren (dam dong mua duoi, tay to bat dau ban)
      //  2) gia khong con tao dinh moi: di ngang trong hop, moi lan cham nap bi dap xuong (co nguoi ban chan o tren)
      //  3) pha dinh gia: vot qua nap roi dong lai trong hop (cu du cuoi cung; InpDistNeedUT = bat buoc)
      //  4) dinh thap hon: lan hoi sau khong cham noi nap hop, cau truc tang bat dau gay
      //  5) nen sap: giam dai, khoi luong lon, thung day hop.
      // KHONG ban duoi nen sap: cho gia hoi len test lai day hop (nay la khang cu), khoi luong nho, nen yeu, bi tu choi -> Sell.
      // SL tren dinh thap hon vua tao, TP o noi cu tang ban dau bat dau. Day hop tich luy (sau cu giam): nguoc lai -> Buy.
      // Khoi luong = so tick cua Exness (so lan bao gia), khong can du lieu ngoai.
      int L = P_DistLookback < 80 ? 80 : P_DistLookback;
      double hi[], lo[], op[], cl[], tv[];
      double nh[], nl2[], no[], nc[];
      datetime tm[];
      ArrayResize(hi, L); ArrayResize(lo, L); ArrayResize(op, L); ArrayResize(cl, L); ArrayResize(tv, L); ArrayResize(tm, L);
      ArrayResize(nh, L); ArrayResize(nl2, L); ArrayResize(no, L); ArrayResize(nc, L);
      for(int i = 0; i < L; i++)
      {
         int sh = L - i;
         hi[i] = iHigh(_Symbol, P_TF, sh); lo[i] = iLow(_Symbol, P_TF, sh);
         op[i] = iOpen(_Symbol, P_TF, sh); cl[i] = iClose(_Symbol, P_TF, sh);
         tv[i] = (double)iTickVolume(_Symbol, P_TF, sh); tm[i] = iTime(_Symbol, P_TF, sh);
         if(hi[i] <= 0 || lo[i] <= 0) return false;                       // thieu du lieu nen
         nh[i] = -lo[i]; nl2[i] = -hi[i]; no[i] = -op[i]; nc[i] = -cl[i];  // doi dau: tich luy thanh phan phoi
      }
      double sl = 0, tp = 0;
      datetime ct = 0;
      if(DistPattern(hi, lo, op, cl, tv, tm, L - 1, atr, g_distUsed, sl, tp, ct))
      { sellBase = true; g_sigSL = sl; g_sigTP = tp; g_distUsed = ct; }
      else if(DistPattern(nh, nl2, no, nc, tv, tm, L - 1, atr, g_distUsed, sl, tp, ct))
      { buyBase = true; g_sigSL = sl; g_sigTP = -tp; g_distUsed = ct; }
   }
   else
   {
      buyBase  = c1 > trend && fast > trend && l1 <= fast && c1 > fast;
      sellBase = c1 < trend && fast < trend && h1 >= fast && c1 < fast;
   }
   return true;
}
