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
            mode = 4; key = tm[k]; g_pzA = Lw; g_pzB = H;
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
      key = tm[k]; g_pzA = Lw; g_pzB = H; g_pzC = stall;
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
   string kind[] = {"", "", "kieu 2: vao toi giua vung roi nen xac nhan dong cua qua giua", "kieu 3: quet thung mep vung roi dong cua quay vao",
                    "kieu 5: vung da bi dong cua thung, gia hoi lai bi tu choi (vung doi vai)"};
   if(OBPattern(hi, lo, op, cl, tm, L - 1, atr, mode, slDist, tp, key))
   { buy = mode != 4; EvAdd(StringFormat("Order block tang %s - %s (nen %s): %s", Px(g_pzA), Px(g_pzB), TimeToString(key, TIME_DATE | TIME_MINUTES), kind[mode])); return true; }
   if(OBPattern(nh, nl, no, nc, tm, L - 1, atr, mode, slDist, tp, key))
   { buy = mode == 4; tp = -tp; EvAdd(StringFormat("Order block giam %s - %s (nen %s): %s", Px(-g_pzB), Px(-g_pzA), TimeToString(key, TIME_DATE | TIME_MINUTES), kind[mode])); return true; }
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
string CandleName(const int pat, const bool buy)
{
   switch(pat)
   {
      case 1: return buy ? "nen bua (rau duoi dai)" : "nen rau tren dai";
      case 2: return buy ? "harami tang + nen tang xac nhan" : "harami giam + nen giam xac nhan";
      case 3: return buy ? "nhan chim tang" : "nhan chim giam";
      case 4: return buy ? "sao mai" : "sao hom";
      case 5: return buy ? "ba linh trang roi hoi nhe" : "ba con qua den roi hoi nhe";
   }
   return "?";
}
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

// VWAP trong ngay + 3 cap dai do lech chuan (v5.24). VWAP = gia von trung binh ca thi truong hom nay, tinh theo khoi luong
// (so tick Exness), tinh lai tu 0 gio server (UTC) moi ngay. Gia tren VWAP: phan lon nguoi mua dang loi, phe mua kiem soat.
// Dai = VWAP +- k x do lech chuan co trong so khoi luong ("soi day thun" keo gia ve coc).
// Tinh cho nen 'shift' (gom cac nen tu dau ngay toi nen do). Tra ve false neu ngay moi co qua it nen.
bool VwapAt(const int shift, double &vwap, double &sd)
{
   datetime t = iTime(_Symbol, P_TF, shift);
   if(t == 0) return false;
   MqlDateTime d; TimeToStruct(t, d);
   datetime day = t - (d.hour * 3600 + d.min * 60 + d.sec);
   double sv = 0, spv = 0, sp2v = 0; int n = 0;
   for(int q = shift; q < shift + 1500; q++)
   {
      datetime tq = iTime(_Symbol, P_TF, q);
      if(tq == 0 || tq < day) break;
      double tp = (iHigh(_Symbol, P_TF, q) + iLow(_Symbol, P_TF, q) + iClose(_Symbol, P_TF, q)) / 3.0;
      double v = (double)iTickVolume(_Symbol, P_TF, q);
      if(v <= 0) continue;
      sv += v; spv += tp * v; sp2v += tp * tp * v; n++;
   }
   if(n < 4 || sv <= 0) return false;
   vwap = spv / sv;
   double var = sp2v / sv - vwap * vwap;
   sd = var > 0 ? MathSqrt(var) : 0;
   return sd > 0;
}

// Vung Key Volume (v5.25): vung gia thi truong da giao dich nhieu nhat - "ben xe". Rat nhieu nguoi co vi the o day (gia von cua ho):
// nguoi dang loi mua them bao ve lenh, nguoi dang lo ban ra thoat hoa von -> gia ve la phan ung manh. 3 dau hieu:
//  1) gia tung di ngang o do kha lau (>= InpKVMinBars nen dong cua trong vung) roi chay manh ra (dong cua cach vung >= 2 ATR);
//  2) volume cao hon han: Volume Profile InpKVLookback nen (so tick rai deu tren cac o nen di qua), o >= InpKVHighMult x TB;
//  3) gia da tung quay ve va phan ung ro (rot >= 1 ATR khoi vung trong 5 nen) it nhat InpKVMinReact lan.
// Doi vai: gia nam tren -> ho tro (cho Buy), nam duoi -> khang cu (cho Sell). Danh dau roi CHO: gia quay ve, co nen phan ung ro
// (dong cua lai ngoai vung, cung chieu, rau >= 40% bien do hoac vuot dinh nen truoc) moi vao. SL ben kia vung - 0,25 ATR.
int KVReactions(const double bot, const double top, const int L, const double atr)
{
   int react = 0; bool away = false;
   for(int q = L + 1; q >= 7; q--)
   {
      double hq = iHigh(_Symbol, P_TF, q), lq = iLow(_Symbol, P_TF, q), cq = iClose(_Symbol, P_TF, q);
      if(cq > top + atr || cq < bot - atr) { away = true; continue; }
      if(!away || lq > top || hq < bot) continue;
      for(int m = q - 1; m >= q - 5; m--)
      {
         double cm = iClose(_Symbol, P_TF, m);
         if(cm > top + atr || cm < bot - atr) { react++; break; }
      }
      away = false;
   }
   return react;
}
bool KeyVolSignal(const double atr, const double c1, const double h1, const double l1, bool &buy, double &slDist)
{
   int L = P_KVLookback < 50 ? 50 : P_KVLookback, nb = P_KVBins < 10 ? 10 : (P_KVBins > 200 ? 200 : P_KVBins);
   int iH = iHighest(_Symbol, P_TF, MODE_HIGH, L, 2), iL = iLowest(_Symbol, P_TF, MODE_LOW, L, 2);
   if(iH < 0 || iL < 0) return false;
   double pHi = iHigh(_Symbol, P_TF, iH), pLo = iLow(_Symbol, P_TF, iL), w = (pHi - pLo) / nb;
   if(w <= 0) return false;
   double vb[];
   ArrayResize(vb, nb); ArrayInitialize(vb, 0);
   double tot = 0;
   for(int q = 2; q <= L + 1; q++)
   {
      double hq = iHigh(_Symbol, P_TF, q), lq = iLow(_Symbol, P_TF, q), v = (double)iTickVolume(_Symbol, P_TF, q);
      if(v <= 0) continue;
      int a = (int)MathMax(0, MathFloor((lq - pLo) / w)), b = (int)MathMin(nb - 1, MathFloor((hq - pLo) / w));
      if(b < a) continue;
      for(int k = a; k <= b; k++) vb[k] += v / (b - a + 1);
      tot += v;
   }
   if(tot <= 0) return false;
   double thr = P_KVHighMult * tot / nb, o1 = iOpen(_Symbol, P_TF, 1), h2 = iHigh(_Symbol, P_TF, 2), l2 = iLow(_Symbol, P_TF, 2);
   double c2 = iClose(_Symbol, P_TF, 2), r1 = h1 - l1;
   int maxBins = (int)MathMax(1, MathFloor(P_KVMaxATR * atr / w));
   for(int k = 0; k < nb; k++)
   {
      if(vb[k] < thr) continue;
      int a = k, b = k;
      while(b + 1 < nb && vb[b + 1] >= thr) b++;
      k = b;                                                            // vung tiep theo bat dau sau doan nay
      // Doan qua rong: giu cua so quanh o dinh (volume lon nhat)
      if(b - a + 1 > maxBins)
      {
         int pk = a;
         for(int j = a; j <= b; j++) if(vb[j] > vb[pk]) pk = j;
         a = MathMax(a, pk - maxBins / 2); b = MathMin(b, a + maxBins - 1);
      }
      double bot = pLo + a * w, top = pLo + (b + 1) * w;
      if(l1 > top + 0.1 * atr || h1 < bot - 0.1 * atr) continue;       // nen vua dong khong ve vung nay
      // Dau hieu 1: di ngang trong vung lau roi chay manh ra
      int inside = 0; bool exitStrong = false;
      for(int q = 2; q <= L + 1; q++)
      {
         double cq = iClose(_Symbol, P_TF, q);
         if(cq >= bot && cq <= top) inside++;
         if(cq > top + 2.0 * atr || cq < bot - 2.0 * atr) exitStrong = true;
      }
      if(inside < P_KVMinBars || !exitStrong) continue;
      // Dau hieu 3: da tung phan ung
      int reacts = KVReactions(bot, top, L, atr);
      if(reacts < P_KVMinReact) continue;
      string kvEv = StringFormat("Key Volume %s - %s: volume o >= %.1f x TB, %d nen dong cua trong vung, da phan ung %d lan", Px(bot), Px(top),
                                 P_KVHighMult, inside, reacts);
      // Doi vai + nen phan ung ro
      bool fromAbove = c2 > top, fromBelow = c2 < bot;
      if(fromAbove && c1 > top && c1 > o1 && (MathMin(o1, c1) - l1 >= 0.4 * r1 || c1 > h2))
      { buy = true; slDist = MathMax(c1 - (bot - 0.25 * atr), 0.5 * atr); EvAdd(kvEv + "; gia tu tren ve (ho tro), nen tang dong cua " + Px(c1) + " tren vung"); return true; }
      if(fromBelow && c1 < bot && c1 < o1 && (h1 - MathMax(o1, c1) >= 0.4 * r1 || c1 < l2))
      { buy = false; slDist = MathMax((top + 0.25 * atr) - c1, 0.5 * atr); EvAdd(kvEv + "; gia tu duoi len (khang cu), nen giam dong cua " + Px(c1) + " duoi vung"); return true; }
   }
   return false;
}

// 3 cau hoi cua nguoi di cau (v5.26): bieu do gan nhu trong tron - nen, vai duong ke va 3 cau hoi.
//  1) Dang la mua gi? Cau truc dinh / day khung chinh (DowCalc): dinh sau cao hon = mua tang, chi tim mua; thap hon = mua giam,
//     chi tim ban. Dang canh bao doi chieu / chua ro = lon xon -> dung ngoai (khong phai mua nao cung nen di cau).
//  2) Ca tu o dau? Ke InpSimpleLevels duong ngang o nhung cho gia tung quay dau ro rang nhat: dinh / day lon (+-InpSimplePivot nen)
//     trong InpSimpleLookback nen, gom cac dinh / day cach nhau < 0,5 ATR; diem = tong do dai cu quay dau (ATR, 10 nen sau do).
//     Gia lo lung o giua cac duong: khong lam gi.
//  3) Phao da dong chua? Gia ve dung duong ke (nen truoc dong cua phia tren, nen vua dong cham trong 0,25 ATR) roi mot cay nen
//     tang bat len manh (than >= 60% bien do, dong cua tren duong) -> moi giat can. SL duoi duong / day nen - 0,25 ATR.
bool SimpleSignal(const double atr, const double c1, const double h1, const double l1, bool &buy, double &slDist)
{
   DowState s;
   if(!DowCalc(P_TF, 300, P_DowPivot, s) || s.trend == 0 || s.pend != 0) { g_status = "Mua lon xon: dung ngoai"; return false; }
   int L = P_SimpleLookback < 50 ? 50 : P_SimpleLookback, P = P_SimplePivot < 2 ? 2 : P_SimplePivot;
   double lv[], sc[]; int nl = 0;
   ArrayResize(lv, 0); ArrayResize(sc, 0);
   for(int q = P + 11; q <= L; q++)
   {
      double hq = iHigh(_Symbol, P_TF, q), lq = iLow(_Symbol, P_TF, q);
      bool isH = true, isL = true;
      for(int m = q - P; m <= q + P; m++)
      {
         if(m == q) continue;
         if(iHigh(_Symbol, P_TF, m) >= hq) isH = false;
         if(iLow(_Symbol, P_TF, m) <= lq) isL = false;
      }
      for(int side = 0; side < 2; side++)
      {
         if(side == 0 ? !isH : !isL) continue;
         double px = side == 0 ? hq : lq, mv = 0;
         for(int m = q - 1; m >= q - 10; m--)
            mv = MathMax(mv, side == 0 ? px - iLow(_Symbol, P_TF, m) : iHigh(_Symbol, P_TF, m) - px);
         double strength = mv / atr;
         int f = -1;
         for(int j = 0; j < nl && f < 0; j++) if(MathAbs(lv[j] - px) < 0.5 * atr) f = j;
         if(f < 0) { nl++; ArrayResize(lv, nl); ArrayResize(sc, nl); lv[nl - 1] = px; sc[nl - 1] = strength; }
         else { lv[f] = (lv[f] * sc[f] + px * strength) / MathMax(sc[f] + strength, 1e-9); sc[f] += strength; }
      }
   }
   // Chi giu InpSimpleLevels duong manh nhat
   int keep = MathMin(nl, P_SimpleLevels < 1 ? 1 : P_SimpleLevels);
   double c2 = iClose(_Symbol, P_TF, 2), o1 = iOpen(_Symbol, P_TF, 1), r1 = h1 - l1, body = MathAbs(c1 - o1);
   bool strong = r1 > 0 && body >= 0.6 * r1;
   for(int t = 0; t < keep; t++)
   {
      int best = t;
      for(int j = t + 1; j < nl; j++) if(sc[j] > sc[best]) best = j;
      double tl = lv[t], ts = sc[t]; lv[t] = lv[best]; sc[t] = sc[best]; lv[best] = tl; sc[best] = ts;
      double lvl = lv[t];
      string sEv = StringFormat("Mua %s (dinh gan nhat %s, day gan nhat %s); duong ke %s (manh thu %d, diem %.1f ATR quay dau); nen than %.0f%% bien do",
                                s.trend == 1 ? "TANG" : "GIAM", Px(s.ph), Px(s.pl), Px(lvl), t + 1, sc[t], r1 > 0 ? body / r1 * 100.0 : 0);
      if(s.trend == 1 && strong && c2 > lvl && l1 <= lvl + 0.25 * atr && l1 >= lvl - 1.0 * atr && c1 > o1 && c1 > lvl)
      { buy = true; slDist = MathMax(c1 - (MathMin(l1, lvl) - 0.25 * atr), 0.5 * atr); EvAdd(sEv); return true; }
      if(s.trend == -1 && strong && c2 < lvl && h1 >= lvl - 0.25 * atr && h1 <= lvl + 1.0 * atr && c1 < o1 && c1 < lvl)
      { buy = false; slDist = MathMax((MathMax(h1, lvl) + 0.25 * atr) - c1, 0.5 * atr); EvAdd(sEv); return true; }
   }
   return false;
}

// Wyckoff Spring day du (v5.29, InpSpringFull). Sau cu giam manh gia di ngang trong hop: nguoi gom mua moi lan gia roi, chua muon
// gia chay vi chua gom du. Phan hang con lai lay tu dung lo duoi day hop: gia bi day thung day (rung cay cho qua rung), dung lo kich
// hoat, nguoi hoang ban thao -> roi vao tay nguoi gom. Spring = lo xo bi nen thap nhat truoc khi bat len. Phan biet voi giam that:
//  1) thung day nhung KHONG di xa (<= InpSpringDepthATR ATR) va quay lai trong hop rat nhanh (dong cua tren day trong 3 nen);
//  2) sau do ve gan day them 1 lan (test): nen nho, volume thap, khong thung noi day spring -> nguoi ban da can hang.
//  Thung day roi nam luon ben duoi, khong quay lai = giam tiep (khong phai spring).
// Vao lenh: cho nen tang manh pha len khoi nap hop (than >= 60% bien do), roi mua khi gia hoi ve cham lai nap (<= 0,3 ATR) va dong cua
// van tren nap. SL duoi day cu spring - 0,25 ATR. TP dau tien o noi cu giam manh bat dau. Upthrust o dinh: nguoc lai (doi dau gia).
bool SpringFullPattern(const double &hi[], const double &lo[], const double &op[], const double &cl[], const double &tv[],
                       const int last, const double atr, double &slDist, double &tp)
{
   int R = P_RangeBars < 8 ? 8 : P_RangeBars;
   for(int s = last - 3; s >= R + 41; s--)                               // s = nen spring (thung day)
   {
      // Hop = R nen truoc spring: rong 1..InpRangeMaxATR ATR, cham dinh / day moi phia >= 2 lan
      double rh = hi[s - R], rl = lo[s - R], vAvg = 0, rAvg = 0;
      for(int q = s - R; q < s; q++) { rh = MathMax(rh, hi[q]); rl = MathMin(rl, lo[q]); vAvg += tv[q]; rAvg += hi[q] - lo[q]; }
      vAvg /= R; rAvg /= R;
      if(rh - rl > P_RangeMaxATR * atr || rh - rl < atr || lo[s] >= rl) continue;
      int tH = 0, tL = 0;
      for(int q = s - R; q < s; q++)
      {
         if(hi[q] >= rh - 0.25 * atr && (q == s - R || hi[q - 1] < rh - 0.25 * atr)) tH++;
         if(lo[q] <= rl + 0.25 * atr && (q == s - R || lo[q - 1] > rl + 0.25 * atr)) tL++;
      }
      if(tH < 2 || tL < 2) continue;
      // Cu giam manh truoc hop
      double top = 0;
      for(int q = s - R - 40; q < s - R; q++) top = MathMax(top, hi[q]);
      if(top - rl < P_SpringDropATR * atr) continue;
      // 1) Khong di xa, quay lai nhanh
      int ret = -1; double spLow = lo[s];
      for(int q = s; q <= MathMin(s + 2, last - 2) && ret < 0; q++) { spLow = MathMin(spLow, lo[q]); if(cl[q] > rl) ret = q; }
      if(ret < 0 || rl - spLow > P_SpringDepthATR * atr) continue;
      // 2) Test: ve gan day, nen nho, volume thap, khong thung day spring; 3) roi nen tang manh pha nap
      bool test = false; int brk = -1;
      for(int q = ret + 1; q < last && brk < 0; q++)
      {
         if(lo[q] < spLow || cl[q] < rl - P_SpringDepthATR * atr) { test = false; break; }   // thung lai: khong phai spring
         if(!test && lo[q] <= rl + 0.5 * atr && hi[q] - lo[q] <= 0.7 * rAvg && tv[q] < vAvg) test = true;
         double rq = hi[q] - lo[q];
         if(test && cl[q] > rh && cl[q] > op[q] && rq > 0 && cl[q] - op[q] >= 0.6 * rq) brk = q;
      }
      if(brk < 0) continue;
      // 4) Hoi ve cham lai nap va giu duoc (lan cham dau tien sau khi pha)
      bool ok = true;
      for(int q = brk + 1; q < last && ok; q++) if(cl[q] <= rh || lo[q] <= rh + 0.3 * atr) ok = false;
      if(!ok || !(lo[last] <= rh + 0.3 * atr && cl[last] > rh)) continue;
      slDist = MathMax(cl[last] - (spLow - 0.25 * atr), 0.5 * atr);
      tp = top - cl[last] >= slDist ? top : 0;
      g_pzA = rl; g_pzB = rh; g_pzC = spLow; g_pzD = top;
      return true;
   }
   return false;
}

// Premium / Discount 2 khung (v5.30). Khung ngay cho biet gia dat hay re, khung chinh (H4) cho biet khi nao ra tay.
// Hop = dinh cao nhat / day thap nhat InpPDDays nen D1 (~2 thang). Nua tren = premium (dat, chi ban), nua duoi = discount (re, chi mua),
// duong giua = can bang. Gia lo lung quanh giua: dung ngoai (chi vao khi gia vao lenh con o nua re / dat).
// Khung chinh, chieu mua (ban: doi dau gia):
//  1) Cu quet: nen dam thung day gan nhat (pivot +-2 nen, nam trong vung discount) roi dong cua lai tren day do trong 2 nen.
//  2) Xac nhan quay dau: sau cu quet, nen dong cua vuot dinh gan nhat (pivot truoc cu quet); khong co day thap hon day quet.
//  3) Diem vao: cu bat de lai FVG tang (day nen k+1 > dinh nen k-1). Lan dau gia hoi ve FVG, nen tang dong cua tren day FVG -> Buy.
// SL duoi day cu quet - 0,25 ATR. Chot phan dau o duong giua (InpPartialPct), phan con lai o canh tren premium (TP).
bool PDPattern(const double &hi[], const double &lo[], const double &op[], const double &cl[], const int last, const double atr,
               const double bxHi, const double bxLo, double &slDist, double &tp1, double &tp2, int &sweepIx)
{
   double mid = (bxHi + bxLo) / 2.0;
   if(cl[last] >= mid) return false;                                   // khong o vung re
   for(int s = last - 3; s >= 10; s--)
   {
      // day gan nhat truoc s (pivot +-2), trong vung discount
      double pl = 0; int ip = -1;
      for(int k = s - 3; k >= 2 && ip < 0; k--)
         if(lo[k] < lo[k - 1] && lo[k] < lo[k - 2] && lo[k] <= lo[k + 1] && lo[k] <= lo[k + 2]) { ip = k; pl = lo[k]; }
      if(ip < 0 || pl >= mid || lo[s] >= pl) continue;
      int ret = -1; double swLow = lo[s];
      for(int q = s; q <= MathMin(s + 2, last - 3) && ret < 0; q++) { swLow = MathMin(swLow, lo[q]); if(cl[q] > pl) ret = q; }
      if(ret < 0) continue;
      // dinh gan nhat truoc cu quet
      double ph = 0;
      for(int k = s - 1; k >= 2 && ph == 0; k--)
         if(k + 2 < s && hi[k] > hi[k - 1] && hi[k] > hi[k - 2] && hi[k] >= hi[k + 1] && hi[k] >= hi[k + 2]) ph = hi[k];
      if(ph == 0) continue;
      int b = -1;
      for(int q = ret; q < last && b < 0; q++)
      {
         if(lo[q] < swLow) break;                                      // co day thap hon: chua quay dau
         if(cl[q] > ph) b = q;
      }
      if(b < 0) continue;
      // FVG tang trong cu bat (nen giua k tu s+1 toi b), lay khoang trong gan nhat
      double gBot = 0, gTop = 0; int gk = -1;
      for(int k = MathMin(b, last - 2); k >= s + 1 && gk < 0; k--)
         if(lo[k + 1] > hi[k - 1] && cl[k] > op[k]) { gk = k; gBot = hi[k - 1]; gTop = lo[k + 1]; }
      if(gk < 0) continue;
      bool fresh = true;
      for(int q = gk + 2; q < last && fresh; q++) if(lo[q] <= gTop || cl[q] < gBot) fresh = false;
      if(!fresh) return false;                                         // da hoi ve truoc do / da thung: bo cau truc nay
      if(!(lo[last] <= gTop && cl[last] > gBot && cl[last] > op[last])) return false;
      slDist = MathMax(cl[last] - (swLow - 0.25 * atr), 0.5 * atr);
      tp1 = mid; tp2 = bxHi; sweepIx = s;
      g_pzA = swLow; g_pzB = ph; g_pzC = gBot; g_pzD = gTop;
      return tp2 - cl[last] >= slDist;                                  // lai toi canh tren < 1R: bo
   }
   return false;
}

// Chuoi phan tich (v5.31, chien luoc 22): long ghep cac chien luoc thanh MOT chuoi logic tren cung mot khung thoi gian.
//  Buoc 1 - Thuy trieu (Dow, khung InpDowTF): tang chi tim mua, giam chi tim ban, chua ro = dung ngoai; giai doan cuoi
//           (>= InpDowLateLegs lan pha dinh) = khong vao moi.
//  Buoc 2 - Vi tri (InpChainPD): hop gia D1 InpPDDays nen - mua chi o nua re (discount), ban chi o nua dat (premium).
//  Buoc 3 - Setup: cac chien luoc "vung + nen xac nhan" trong InpChainList cung soi nen vua dong (FVG luon cho nen xac nhan,
//           Spring luon cho du chuoi, Donchian luon cho test lai). Chi tinh setup cung chieu thuy trieu; co setup NGUOC chieu
//           = cac cong cu dang noi moi cai mot kieu -> dung ngoai.
//  Buoc 4 - Bo loc chung (gio, tin, spread, khoi luong...) chay nhu moi chien luoc khac sau buoc nay.
//  Buoc 5 - Khoi luong theo dong thuan: 1 setup = InpChainOneRisk x rui ro, >= InpChainFullCount setup = du rui ro.
//  SL / TP / muc chot theo gia lay tu setup dau tien trong danh sach (uu tien theo thu tu InpChainList).
string g_chainWhy = "";
bool   g_inChain = false;               // dang soi setup cua 1 chien luoc thanh vien trong chuoi
int    g_chainHits = 0, g_chainConflicts = 0;
string ChainName(const int m)
{
   switch(m)
   {
      case 0: return "EMA hoi"; case 1: return "Pha vo + test lai"; case 5: return "FVG + nen"; case 6: return "Spring du";
      case 9: return "Fib + VP"; case 12: return "Hop phan phoi"; case 14: return "Dao roi"; case 15: return "Order block";
      case 16: return "Song Dow"; case 17: return "VWAP"; case 18: return "Key Volume"; case 19: return "3 cau hoi"; case 21: return "Premium/discount";
      case 20: return "Quet tin";
   }
   return "S" + IntegerToString(m);
}
bool ChainSignals(const double atr, const double trend, const double fast, const double c1, const double h1, const double l1,
                  bool &buyBase, bool &sellBase)
{
   buyBase = false; sellBase = false;
   // Buoc 1
   DowState t;
   if(!DowTide(t) || t.trend == 0) { g_status = "Chuoi B1: thuy trieu chua ro, dung ngoai"; return true; }
   int dir = t.trend;
   if(P_DowLateLegs > 0 && t.legs >= P_DowLateLegs) { g_status = StringFormat("Chuoi B1: thuy trieu %s o giai doan cuoi (lan pha %d), dung ngoai", t.trend > 0 ? "TANG" : "GIAM", t.legs); return true; }
   string why = StringFormat("B1 thuy trieu %s (lan pha %d)", dir > 0 ? "TANG" : "GIAM", t.legs);
   EvAdd(StringFormat("B1: cau truc dinh / day %s %s, dinh gan nhat %s, day gan nhat %s, %d lan pha %s tu khi doi chieu%s",
                      EnumToString(P_DowTF), dir > 0 ? "TANG" : "GIAM", Px(t.ph), Px(t.pl), t.legs, dir > 0 ? "dinh" : "day",
                      P_DowLateLegs > 0 ? StringFormat(" (giai doan cuoi tu lan %d)", P_DowLateLegs) : ""));
   // Buoc 2
   if(P_ChainPD)
   {
      int dH = iHighest(_Symbol, PERIOD_D1, MODE_HIGH, P_PDDays, 1), dL = iLowest(_Symbol, PERIOD_D1, MODE_LOW, P_PDDays, 1);
      if(dH < 0 || dL < 0) return false;
      double mid = (iHigh(_Symbol, PERIOD_D1, dH) + iLow(_Symbol, PERIOD_D1, dL)) / 2.0;
      EvAdd(StringFormat("B2: hop D1 %d nen dinh %s / day %s / giua %s; gia %s nam nua %s", P_PDDays, Px(iHigh(_Symbol, PERIOD_D1, dH)),
                         Px(iLow(_Symbol, PERIOD_D1, dL)), Px(mid), Px(c1), c1 < mid ? "DUOI (re)" : "TREN (dat)"));
      if(dir > 0 ? c1 >= mid : c1 <= mid) { g_status = why + " | B2 gia khong o vung " + (dir > 0 ? "re" : "dat") + ", dung ngoai"; return true; }
      why += dir > 0 ? " | B2 vung re" : " | B2 vung dat";
   }
   // Buoc 3
   string list[];
   int n = StringSplit(P_ChainList, ',', list);
   ENUM_STRATEGY keep = P_Strategy;
   bool kFvg = P_FvgCandle, kSpr = P_SpringFull, kRet = P_BreakRetest;
   int agree = 0, against = 0;
   double pSL = 0, pTP = 0, pPX = 0, pMult = 1;
   string names = "";
   for(int i = 0; i < n; i++)
   {
      StringTrimLeft(list[i]); StringTrimRight(list[i]);
      int m = (int)StringToInteger(list[i]);
      if(list[i] == "" || m < 0 || m == STRAT_CHAIN || m == STRAT_GRID || m == STRAT_IMOM || m == STRAT_NEWS ||
         m == STRAT_RSI_REVERT || m == STRAT_DIVCVD || m == STRAT_MACD || m == STRAT_EXHAUST || m == STRAT_ORB || m > STRAT_PD) continue;
      P_Strategy = (ENUM_STRATEGY)m;
      P_FvgCandle = true; P_SpringFull = true; P_BreakRetest = true;
      bool b = false, s = false;
      g_inChain = true;
      bool ok = BaseSignals(atr, trend, fast, c1, h1, l1, b, s);
      g_inChain = false;
      P_Strategy = keep; P_FvgCandle = kFvg; P_SpringFull = kSpr; P_BreakRetest = kRet;
      if(!ok || (!b && !s)) continue;
      if((dir > 0 && b) || (dir < 0 && s))
      {
         if(agree == 0) { pSL = g_sigSL; pTP = g_sigTP; pPX = g_sigPartialPx; pMult = g_sigRiskMult; }
         agree++; names += (names == "" ? "" : " + ") + ChainName(m);
      }
      else { against++; names += (names == "" ? "" : " + ") + "nguoc: " + ChainName(m); }
   }
   g_sigSL = 0; g_sigTP = 0; g_sigPartialPx = 0; g_sigRiskMult = 1;
   if(agree == 0) { g_status = why + " | B3 chua co setup"; return true; }
   if(against > 0) { g_chainConflicts++; g_status = why + " | B3 setup trai chieu (" + names + "), dung ngoai"; return true; }
   // Buoc 5
   double mult = agree >= P_ChainFullCount ? 1.0 : MathMax(0.1, MathMin(1.0, P_ChainOneRisk));
   EvAdd(StringFormat("B5: %d setup cung chieu (du rui ro khi >= %d) -> rui ro x%.2f", agree, P_ChainFullCount, mult));
   if(pMult > 0 && pMult < 1) mult *= pMult;
   if(dir > 0) buyBase = true; else sellBase = true;
   g_sigSL = pSL; g_sigTP = pTP; g_sigPartialPx = pPX; g_sigRiskMult = mult;
   g_chainHits++;
   g_chainWhy = why + StringFormat(" | B3 %d setup: %s | B5 rui ro x%.2f", agree, names, mult);
   g_status = g_chainWhy;
   Print("CHUOI PHAN TICH: ", g_chainWhy);
   return true;
}

// Theo tinh huong (v5.35, chien luoc 24). Bot CHAN DOAN thi truong o nen vua dong roi dung DUNG bo kien thuc cho tinh huong do
// (moi tinh huong lay tu bai hoc tuong ung), thay vi chay moi chien luoc mot luc hay chon theo diem backtest:
//  1) Sap co tin lon (InpSmartNewsMin phut toi)        -> dung ngoai (bai "ngay co tin lon").
//  2) Vua ra tin (trong 4 gio)                           -> cho cu quet thanh khoan xong (chien luoc 20).
//  3) Vua co cu sap / tang dung dung (>= InpKnifeDropATR ATR trong InpKnifeBars nen, cuc tri trong 10 nen) -> nho, lon, giu (14).
//  4) Xu huong manh: thuy trieu Dow D1 ro + ADX >= InpSmartTrendADX, chua giai doan cuoi -> chi danh theo xu huong:
//     pha vo that (1), song Dow (16), FVG + nen (5), order block (15), premium / discount (21).
//  5) Xu huong giai doan cuoi (>= InpDowLateLegs lan pha) -> khong du theo; chi cho phan phoi / tich luy (12) va spring / upthrust (6).
//  6) Di ngang: ADX < InpSmartRangeADX va hop InpSmartRangeBars nen cao <= InpSmartRangeATR ATR -> danh trong hop:
//     Spring du (6), Key Volume (18), VWAP keo ve (17, chi cach 2), 3 cau hoi (19).
//  7) Con lai (khong ro) -> neu co thuy trieu: chi setup vung manh (15, 5, 18) theo thuy trieu; khong thi dung ngoai.
// Trong tinh huong: cac chien luoc cua bo cung soi nen vua dong; setup trai chieu nhau = dung ngoai; 1 setup = InpChainOneRisk rui ro,
// >= InpChainFullCount setup = du rui ro. Moi quyet dinh ghi tinh huong + bang chung (ADX, hop, Dow, bien do cu sap...).
string SmartSitName(const int s)
{
   switch(s)
   {
      case 1: return "SAP CO TIN"; case 2: return "VUA RA TIN"; case 3: return "VUA CO CU SAP / TANG DUNG DUNG";
      case 4: return "XU HUONG MANH"; case 5: return "XU HUONG GIAI DOAN CUOI"; case 6: return "DI NGANG"; case 7: return "KHONG RO";
   }
   return "?";
}
bool SmartSignals(const double atr, const double trend, const double fast, const double c1, const double h1, const double l1,
                  bool &buyBase, bool &sellBase)
{
   buyBase = false; sellBase = false;
   string nm = "", list = "", why = "";
   int dir = 0;                                                     // chieu cho phep: +1 mua, -1 ban, 0 ca hai (theo setup)
   g_smartSit = 0;
   DowState t;
   bool tideOk = DowTide(t);
   double adx = 0;
   GetValue(hADX, 0, 1, adx);
   // Bien do gan day (cu sap / tang dung dung) va hop di ngang
   int kb = P_KnifeBars < 5 ? 5 : P_KnifeBars;
   int iH = iHighest(_Symbol, P_TF, MODE_HIGH, kb, 1), iL = iLowest(_Symbol, P_TF, MODE_LOW, kb, 1);
   int rb = P_SmartRangeBars < 10 ? 10 : P_SmartRangeBars;
   int rH = iHighest(_Symbol, P_TF, MODE_HIGH, rb, 1), rL = iLowest(_Symbol, P_TF, MODE_LOW, rb, 1);
   if(iH < 0 || iL < 0 || rH < 0 || rL < 0) return false;
   double kHi = iHigh(_Symbol, P_TF, iH), kLo = iLow(_Symbol, P_TF, iL), boxH = iHigh(_Symbol, P_TF, rH) - iLow(_Symbol, P_TF, rL);
   bool crashDn = kHi - kLo >= P_KnifeDropATR * atr && iL <= 10 && iH > iL;
   bool spikeUp = kHi - kLo >= P_KnifeDropATR * atr && iH <= 10 && iL > iH;
   if(MinutesToNews(P_SmartNewsMin, nm) >= 0)
   { g_smartSit = 1; why = "sap ra tin " + nm + " trong " + IntegerToString(P_SmartNewsMin) + " phut"; }
   else if(LastNewsTime(240, nm) > 0)
   { g_smartSit = 2; why = "tin " + nm + " vua ra (< 4 gio)"; list = "20"; }
   else if(crashDn || spikeUp)
   { g_smartSit = 3; why = StringFormat("%s %.1f ATR trong %d nen", crashDn ? "giam" : "tang", (kHi - kLo) / atr, kb); list = "14"; }
   else if(tideOk && t.trend != 0 && P_DowLateLegs > 0 && t.legs >= P_DowLateLegs)
   { g_smartSit = 5; why = StringFormat("Dow %s %s, da pha %d lan", EnumToString(P_DowTF), t.trend > 0 ? "tang" : "giam", t.legs); list = "12,6"; }
   // Vung dem (v5.39.1): da o tinh huong nao thi giu cho toi khi chi so ra han khoi nguong (+-3 ADX), tranh doi bo kien thuc moi nen
   // khi ADX dao dong quanh nguong ("nhin gon song tuong thuy trieu"). Xu huong: giu khi ADX >= nguong - 3 va thuy trieu khong doi chieu.
   else if(tideOk && t.trend != 0 && (adx >= P_SmartTrendADX || (g_smartPrev == 4 && g_smartPrevDir == t.trend && adx >= P_SmartTrendADX - 3)))
   { g_smartSit = 4; dir = t.trend; why = StringFormat("Dow %s %s (lan pha %d), ADX %.1f >= %.0f", EnumToString(P_DowTF), t.trend > 0 ? "tang" : "giam", t.legs, adx, P_SmartTrendADX); list = "1,16,5,15,21"; }
   else if((adx < P_SmartRangeADX && boxH <= P_SmartRangeATR * atr) ||
           (g_smartPrev == 6 && adx < P_SmartRangeADX + 3 && boxH <= P_SmartRangeATR * 1.15 * atr))
   { g_smartSit = 6; why = StringFormat("ADX %.1f < %.0f, hop %d nen cao %.1f ATR", adx, P_SmartRangeADX, rb, boxH / atr); list = "6,18,17,19"; }
   else
   {
      g_smartSit = 7; why = StringFormat("ADX %.1f, hop %d nen cao %.1f ATR, thuy trieu %s", adx, rb, boxH / atr, !tideOk || t.trend == 0 ? "chua ro" : (t.trend > 0 ? "tang" : "giam"));
      if(tideOk && t.trend != 0) { dir = t.trend; list = "15,5,18"; }
   }
   if(g_smartSit != g_smartPrev && g_smartPrev != 0)
      why += StringFormat(" (doi tu %s)", SmartSitName(g_smartPrev));
   else if(g_smartSit == g_smartPrev && (g_smartSit == 4 || g_smartSit == 6))
      why += " (giu tinh huong: vung dem +-3 ADX)";
   g_smartPrev = g_smartSit; g_smartPrevDir = tideOk ? t.trend : 0;
   g_smartName = SmartSitName(g_smartSit);
   string head = "Tinh huong: " + g_smartName;
   EvAdd("Tinh huong " + g_smartName + ": " + why);
   if(list == "") { g_status = head + " | " + (g_smartSit == 1 ? "dung ngoai cho tin ra" : "khong co bo chien luoc phu hop, dung ngoai"); return true; }
   // Soi setup cua bo chien luoc tinh huong nay
   string ls[];
   int n = StringSplit(list, ',', ls);
   ENUM_STRATEGY keep = P_Strategy;
   bool kFvg = P_FvgCandle, kSpr = P_SpringFull, kRet = P_BreakRetest; int kVw = P_VwapMode;
   // Dac trung boi canh (v5.39): ghi kem moi lan ap dung kien thuc (lenh giay) de cham diem va dieu chinh kien thuc sau nay
   double o1b = iOpen(_Symbol, P_TF, 1), r1b = h1 - l1, vS = 0; int vN = 0;
   for(int q = 2; q <= 21; q++) { long v = iTickVolume(_Symbol, P_TF, q); if(v > 0) { vS += (double)v; vN++; } }
   double volR = vN > 0 && vS > 0 ? (double)iTickVolume(_Symbol, P_TF, 1) / (vS / vN) : 0;
   int dHi = iHighest(_Symbol, PERIOD_D1, MODE_HIGH, P_PDDays, 1), dLo = iLowest(_Symbol, PERIOD_D1, MODE_LOW, P_PDDays, 1);
   double bxH = dHi >= 0 ? iHigh(_Symbol, PERIOD_D1, dHi) : 0, bxL = dLo >= 0 ? iLow(_Symbol, PERIOD_D1, dLo) : 0;
   MqlDateTime fdt; TimeToStruct(TimeCurrent(), fdt);
   string nmF = "";
   double toNews = MinutesToNews(999, nmF);
   string featBase = StringFormat("adx=%.1f;than=%.0f;vol=%.2f;gio=%d;tin=%.0f", adx, r1b > 0 ? MathAbs(c1 - o1b) / r1b * 100.0 : 0, volR,
                                  fdt.hour, toNews < 0 ? 999 : toNews);
   int nb = 0, ns = 0, bMem = -1, sMem = -1;
   double bSL = 0, bTP = 0, bPX = 0, bM = 1, sSL = 0, sTP = 0, sPX = 0, sM = 1, bF = 0, sF = 0;
   string bN = "", sN = "", useN = "", outN = "";
   for(int i = 0; i < n; i++)
   {
      int m = (int)StringToInteger(ls[i]);
      useN += (useN == "" ? "" : ", ") + ChainName(m);
      P_Strategy = (ENUM_STRATEGY)m;
      P_FvgCandle = true; P_SpringFull = true; P_BreakRetest = true; P_VwapMode = g_smartSit == 6 ? 2 : 1;
      bool b = false, s = false;
      g_inChain = true;
      bool ok = BaseSignals(atr, trend, fast, c1, h1, l1, b, s);
      g_inChain = false;
      P_Strategy = keep; P_FvgCandle = kFvg; P_SpringFull = kSpr; P_BreakRetest = kRet; P_VwapMode = kVw;
      if(!ok || (!b && !s)) continue;
      // Hoc tu thuc chien (Learn.mqh): moi setup thay duoc la 1 lenh giay; ket qua da tich luy quyet dinh co dung chien luoc nay
      // trong tinh huong nay hay khong va voi bao nhieu rui ro
      double sd = g_sigSL > 0 ? g_sigSL : atr * P_ATRMult;
      int dm = b ? 1 : -1;
      double hop = bxH > bxL ? (dm > 0 ? (c1 - bxL) / (bxH - bxL) : (bxH - c1) / (bxH - bxL)) : 0.5;
      double tpr = g_sigTP > 0 ? MathAbs(g_sigTP - c1) / sd : 2.0;
      string feat = featBase + StringFormat(";slatr=%.2f;tpr=%.2f;hop=%.2f;xh=%d", sd / atr, tpr, hop,
                                            !tideOk || t.trend == 0 ? 0 : (t.trend == dm ? 1 : -1));
      // Kien thuc da dieu chinh (ban duyet tren giao dien): setup khong thoa dieu kien bo sung thi khong dung, van ghi lenh giay
      string ruleWhy = "";
      bool ruleOk = KnowRulesOk(m, g_smartSit, feat, ruleWhy);
      LearnRegister(g_smartSit, m, dm, c1, sd, g_sigTP, feat + (ruleOk ? "" : ";luat=1"));
      if(!ruleOk) { EvAdd("Kien thuc da dieu chinh - " + ChainName(m) + ": " + ruleWhy + " -> khong dung"); outN += (outN == "" ? "" : ", ") + ChainName(m) + " (dieu kien bo sung)"; continue; }
      double lf; string lt;
      int lv = LearnVerdict(g_smartSit, m, lf, lt);
      // Mac dinh (InpLearnApply = false) quyet dinh hoan toan theo KIEN THUC: ket qua thuc chien chi ghi vao bang chung de tham khao
      if(!P_LearnApply) { lf = 1.0; EvAdd("Thuc chien (tham khao) - " + ChainName(m) + ": " + lt); }
      else
      {
         EvAdd("Hoc - " + ChainName(m) + " (" + g_smartName + "): " + lt);
         if(lv == 3) { outN += (outN == "" ? "" : ", ") + ChainName(m); continue; }   // du lieu thuc chien cho thay khong hieu qua
      }
      if(b) { if(nb == 0) { bSL = g_sigSL; bTP = g_sigTP; bPX = g_sigPartialPx; bM = g_sigRiskMult; bMem = m; } nb++; bF = MathMax(bF, lf); bN += (bN == "" ? "" : " + ") + ChainName(m); }
      if(s) { if(ns == 0) { sSL = g_sigSL; sTP = g_sigTP; sPX = g_sigPartialPx; sM = g_sigRiskMult; sMem = m; } ns++; sF = MathMax(sF, lf); sN += (sN == "" ? "" : " + ") + ChainName(m); }
   }
   g_sigSL = 0; g_sigTP = 0; g_sigPartialPx = 0; g_sigRiskMult = 1;
   head += " | Dung: " + useN;
   if(outN != "") head += " | Khong dung: " + outN;
   LearnSetAgree(g_smartSit, nb, ns);                                // ghi so setup dong y / trai chieu vao lenh giay nen nay
   if(dir > 0) ns = 0; if(dir < 0) nb = 0;                          // xu huong: bo setup nguoc chieu thuy trieu (khong tinh la trai chieu)
   if(nb == 0 && ns == 0) { g_status = head + " | chua co setup"; return true; }
   if(nb > 0 && ns > 0) { g_chainConflicts++; g_status = head + " | setup trai chieu (mua: " + bN + " / ban: " + sN + "), dung ngoai"; return true; }
   int agree = nb > 0 ? nb : ns;
   double mult = agree >= P_ChainFullCount ? 1.0 : MathMax(0.1, MathMin(1.0, P_ChainOneRisk));
   double pM = nb > 0 ? bM : sM;
   if(pM > 0 && pM < 1) mult *= pM;
   double lF = nb > 0 ? bF : sF;                                     // he so tu du lieu thuc chien (dang thu / chua chac / tin dung)
   if(lF > 0 && lF < 1) mult *= lF;
   g_sigMember = nb > 0 ? bMem : sMem;
   if(nb > 0) { buyBase = true; g_sigSL = bSL; g_sigTP = bTP; g_sigPartialPx = bPX; }
   else       { sellBase = true; g_sigSL = sSL; g_sigTP = sTP; g_sigPartialPx = sPX; }
   g_sigRiskMult = mult;
   EvAdd(StringFormat("Kien thuc: %d setup %s dong y -> rui ro x%.2f (1 setup = x%.2f, tu %d setup = du)", agree, nb > 0 ? "MUA" : "BAN", mult,
                      P_ChainOneRisk, P_ChainFullCount));
   g_chainHits++;
   g_chainWhy = head + StringFormat(" | %s: %s | rui ro x%.2f", nb > 0 ? "MUA" : "BAN", nb > 0 ? bN : sN, mult);
   g_status = g_chainWhy;
   Print("THEO TINH HUONG: ", g_chainWhy);
   return true;
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
      if(!g_inChain)                                   // trong chuoi phan tich chi ghi khi co tin hieu (tranh nhieu)
      {
         double vs2 = 0; int vn2 = 0;
         for(int q = b + 1; q <= b + 20; q++) { long v = iTickVolume(_Symbol, P_TF, q); if(v > 0) { vs2 += (double)v; vn2++; } }
         EvAdd(StringFormat("Kenh Donchian %d nen: dinh %s / day %s; nen %d dong cua %s (than %.0f%% bien do, khoi luong x%.1f TB 20 nen); EMA%d %s",
                            P_DonchianPeriod, Px(chHigh), Px(chLow), b, Px(cb), range > 0 ? body / range * 100.0 : 0,
                            vn2 > 0 && vs2 > 0 ? (double)iTickVolume(_Symbol, P_TF, b) / (vs2 / vn2) : 0, P_TrendEMA, Px(trend)));
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
               if(buyBase || sellBase)
                  EvAdd(StringFormat("Pha vo that: nen %d dong cua %s muc %s; nen vua dong test lai (%s %s) va dong cua %s van %s muc",
                                     j, buy ? "tren" : "duoi", Px(lvl), buy ? "day" : "dinh", Px(buy ? l1 : h1), Px(c1), buy ? "tren" : "duoi"));
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
               if(pat > 0) { buyBase = true; g_sigSL = MathMax(c1 - (MathMin(pl, gbU) - 0.25 * atr), 0.5 * atr); g_fvgUsed = tk; g_fvgPat = pat;
                             EvAdd(StringFormat("FVG tang %s - %s (nen lon %s, chua bi dong cua thung); nen xac nhan: %s", Px(gbU), Px(gtU),
                                                TimeToString(tk, TIME_DATE | TIME_MINUTES), CandleName(pat, true))); }
            }
            else
            {
               int pat = ZoneCandle(no, nh, nl, nc, maxSh, -gbD, -gtD, atr, pl);
               if(pat > 0) { sellBase = true; g_sigSL = MathMax((MathMax(-pl, gtD) + 0.25 * atr) - c1, 0.5 * atr); g_fvgUsed = tk; g_fvgPat = pat;
                             EvAdd(StringFormat("FVG giam %s - %s (nen lon %s, chua bi dong cua thung); nen xac nhan: %s", Px(gbD), Px(gtD),
                                                TimeToString(tk, TIME_DATE | TIME_MINUTES), CandleName(pat, false))); }
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
      // InpSpringFull (v5.29): khong vao o cay nen spring; cho du chuoi spring - test - pha nap - hoi ve (SpringFullPattern).
      if(P_SpringFull)
      {
         int L = (P_RangeBars < 8 ? 8 : P_RangeBars) + 140;
         double hi[], lo[], op[], cl[], tv[], nh[], nl[], no[], nc[];
         ArrayResize(hi, L); ArrayResize(lo, L); ArrayResize(op, L); ArrayResize(cl, L); ArrayResize(tv, L);
         ArrayResize(nh, L); ArrayResize(nl, L); ArrayResize(no, L); ArrayResize(nc, L);
         for(int i = 0; i < L; i++)
         {
            int sh = L - i;
            hi[i] = iHigh(_Symbol, P_TF, sh); lo[i] = iLow(_Symbol, P_TF, sh); op[i] = iOpen(_Symbol, P_TF, sh); cl[i] = iClose(_Symbol, P_TF, sh);
            tv[i] = (double)iTickVolume(_Symbol, P_TF, sh);
            if(hi[i] <= 0 || lo[i] <= 0) return false;
            nh[i] = -lo[i]; nl[i] = -hi[i]; no[i] = -op[i]; nc[i] = -cl[i];
         }
         double sd = 0, tp = 0;
         if(SpringFullPattern(hi, lo, op, cl, tv, L - 1, atr, sd, tp))
         { buyBase = true; g_sigSL = sd; g_sigTP = tp;
           EvAdd(StringFormat("Hop %s - %s sau cu giam tu %s; spring thung xuong %s roi quay lai; test day volume thap; nen tang manh pha nap, hoi ve cham nap van giu",
                              Px(g_pzA), Px(g_pzB), Px(g_pzD), Px(g_pzC))); }
         else if(SpringFullPattern(nh, nl, no, nc, tv, L - 1, atr, sd, tp))
         { sellBase = true; g_sigSL = sd; g_sigTP = -tp;
           EvAdd(StringFormat("Hop %s - %s sau cu tang tu %s; upthrust vot len %s roi quay lai; test dinh volume thap; nen giam manh thung day, hoi len cham day van giu",
                              Px(-g_pzB), Px(-g_pzA), Px(-g_pzD), Px(-g_pzC))); }
         return true;
      }
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
   else if(P_Strategy == STRAT_CHAIN)
      return ChainSignals(atr, trend, fast, c1, h1, l1, buyBase, sellBase);
   else if(P_Strategy == STRAT_SMART)
      return SmartSignals(atr, trend, fast, c1, h1, l1, buyBase, sellBase);
   else if(P_Strategy == STRAT_PD)
   {
      int dH = iHighest(_Symbol, PERIOD_D1, MODE_HIGH, P_PDDays, 1), dL = iLowest(_Symbol, PERIOD_D1, MODE_LOW, P_PDDays, 1);
      if(dH < 0 || dL < 0) return false;
      double bxHi = iHigh(_Symbol, PERIOD_D1, dH), bxLo = iLow(_Symbol, PERIOD_D1, dL);
      if(bxHi - bxLo < 3 * atr) return true;
      int L = P_PDLookback < 30 ? 30 : P_PDLookback;
      double hi[], lo[], op[], cl[], nh[], nl[], no[], nc[];
      datetime tm[];
      ArrayResize(hi, L); ArrayResize(lo, L); ArrayResize(op, L); ArrayResize(cl, L); ArrayResize(tm, L);
      ArrayResize(nh, L); ArrayResize(nl, L); ArrayResize(no, L); ArrayResize(nc, L);
      for(int i = 0; i < L; i++)
      {
         int sh = L - i;
         hi[i] = iHigh(_Symbol, P_TF, sh); lo[i] = iLow(_Symbol, P_TF, sh); op[i] = iOpen(_Symbol, P_TF, sh); cl[i] = iClose(_Symbol, P_TF, sh);
         tm[i] = iTime(_Symbol, P_TF, sh);
         if(hi[i] <= 0 || lo[i] <= 0) return false;
         nh[i] = -lo[i]; nl[i] = -hi[i]; no[i] = -op[i]; nc[i] = -cl[i];
      }
      double sd, t1, t2; int sx;
      if(PDPattern(hi, lo, op, cl, L - 1, atr, bxHi, bxLo, sd, t1, t2, sx) && tm[sx] != g_pdUsed)
      { buyBase = true; g_sigSL = sd; g_sigPartialPx = t1; g_sigTP = t2; g_pdUsed = tm[sx];
        EvAdd(StringFormat("Hop D1 %d nen: dinh %s / day %s / giua %s, gia %s o vung RE; quet day xuong %s, dong cua vuot dinh %s; FVG %s - %s",
                           P_PDDays, Px(bxHi), Px(bxLo), Px((bxHi + bxLo) / 2), Px(c1), Px(g_pzA), Px(g_pzB), Px(g_pzC), Px(g_pzD))); }
      else if(PDPattern(nh, nl, no, nc, L - 1, atr, -bxLo, -bxHi, sd, t1, t2, sx) && tm[sx] != g_pdUsed)
      { sellBase = true; g_sigSL = sd; g_sigPartialPx = -t1; g_sigTP = -t2; g_pdUsed = tm[sx];
        EvAdd(StringFormat("Hop D1 %d nen: dinh %s / day %s / giua %s, gia %s o vung DAT; quet dinh len %s, dong cua thung day %s; FVG %s - %s",
                           P_PDDays, Px(bxHi), Px(bxLo), Px((bxHi + bxLo) / 2), Px(c1), Px(-g_pzA), Px(-g_pzB), Px(-g_pzD), Px(-g_pzC))); }
   }
   else if(P_Strategy == STRAT_NEWS)
   {
      // Quet roi moi di (v5.27). Truoc tin, nguoi lon dung ngoai: gia di ngang sat dinh / day, lenh cho va dung lo don ve 2 dau.
      // Tin ra, so lenh mong: gia vot len quet het lenh mua + dung lo phia tren, nguoi lon dung chinh so lenh do de ban, roi quay dau
      // di theo huong that. Cu dau la lay thanh khoan, cu thu hai moi la con song that. Khong du cay nen tin dau tien:
      //  - vung truoc tin = dinh / day InpNewsRangeMin phut truoc gio tin (cao <= InpNewsRangeMaxATR ATR: di ngang);
      //  - cu quet = nen dau tien sau gio tin vuot ra ngoai vung; dinh quet = cao nhat tu do;
      //  - cau truc moi: nen vua dong (khong lap dinh quet moi) dong cua lai trong vung, la nen giam va thung day cay nen tao dinh quet
      //    -> Sell, SL tren dinh quet + 0,25 ATR. Quet xuong: nguoc lai. Chi trong InpNewsWindowMin phut sau tin, moi tin 1 lan.
      string nm;
      datetime nt = LastNewsTime(P_NewsWindowMin, nm);
      if(nt == 0 || nt == g_newsUsedT) return true;
      int sNews = iBarShift(_Symbol, P_TF, nt, false), sFrom = iBarShift(_Symbol, P_TF, nt - P_NewsRangeMin * 60, false);
      if(sNews < 2 || sFrom <= sNews) return true;
      double rHi = 0, rLo = DBL_MAX;
      for(int q = sNews + 1; q <= sFrom; q++) { rHi = MathMax(rHi, iHigh(_Symbol, P_TF, q)); rLo = MathMin(rLo, iLow(_Symbol, P_TF, q)); }
      if(rHi <= 0 || rHi - rLo > P_NewsRangeMaxATR * atr) return true;
      int dir = 0, xs = -1; double ext = 0;
      for(int q = sNews; q >= 2; q--)
      {
         double hq = iHigh(_Symbol, P_TF, q), lq = iLow(_Symbol, P_TF, q);
         if(dir == 0) { if(hq > rHi) { dir = 1; ext = hq; xs = q; } else if(lq < rLo) { dir = -1; ext = lq; xs = q; } }
         else if(dir == 1 && hq > ext)  { ext = hq; xs = q; }
         else if(dir == -1 && lq < ext) { ext = lq; xs = q; }
      }
      double o1 = iOpen(_Symbol, P_TF, 1);
      if(dir == 1 && h1 <= ext && c1 < rHi && c1 < iLow(_Symbol, P_TF, xs) && c1 < o1)
      { sellBase = true; g_sigSL = MathMax(ext + 0.25 * atr - c1, 0.5 * atr); g_newsUsedT = nt; }
      if(dir == -1 && l1 >= ext && c1 > rLo && c1 > iHigh(_Symbol, P_TF, xs) && c1 > o1)
      { buyBase = true; g_sigSL = MathMax(c1 - (ext - 0.25 * atr), 0.5 * atr); g_newsUsedT = nt; }
   }
   else if(P_Strategy == STRAT_SIMPLE)
   {
      bool sb; double ss;
      if(SimpleSignal(atr, c1, h1, l1, sb, ss)) { if(sb) buyBase = true; else sellBase = true; g_sigSL = ss; }
   }
   else if(P_Strategy == STRAT_KEYVOL)
   {
      bool kb; double ks;
      if(KeyVolSignal(atr, c1, h1, l1, kb, ks)) { if(kb) buyBase = true; else sellBase = true; g_sigSL = ks; }
   }
   else if(P_Strategy == STRAT_VWAP)
   {
      // Cap 1 (+-InpVwapBand1): day con trung, qua lai binh thuong. Cap 2: day da cang - gia o dai tren la dang dat, cho chot loi,
      // khong mua duoi. Cap 3: cang het co, hiem khi cham, cham thuong bi keo nguoc ve VWAP.
      // Cach 1 (theo xu huong, InpVwapMode 0/1): gia dang tren VWAP, hoi ve cham duong giua roi nen tang bat len, dong cua tren
      //   VWAP -> Buy, SL duoi nen do, TP dai 2 phia tren. Duoi VWAP: nguoc lai.
      // Cach 2 (bat nhip keo ve, InpVwapMode 0/2): gia vot cham dai 3 roi co nen bi tu choi manh (nen giam, rau tren >= 40% bien do,
      //   dong cua lai duoi dai 3) -> Sell, SL tren rau, TP = VWAP. Ngay xu huong rat manh gia bam dai xa rat lau: luon cho nen tu choi.
      // Bo qua neu loi toi TP < InpVwapMinRR x SL.
      double vw, sd, vw2, sd2;
      if(!VwapAt(1, vw, sd) || !VwapAt(2, vw2, sd2)) return true;
      double o1 = iOpen(_Symbol, P_TF, 1), c2 = iClose(_Symbol, P_TF, 2), r1 = h1 - l1;
      double tol = 0.1 * atr, sl = 0, tp = 0;
      if(P_VwapMode != 2)
      {
         if(c2 > vw2 && l1 <= vw + tol && c1 > vw && c1 > o1)
         { sl = MathMax(c1 - (l1 - 0.1 * atr), 0.3 * atr); tp = vw + P_VwapBand2 * sd; if(tp - c1 >= P_VwapMinRR * sl) { buyBase = true; g_sigSL = sl; g_sigTP = tp; } }
         else if(c2 < vw2 && h1 >= vw - tol && c1 < vw && c1 < o1)
         { sl = MathMax((h1 + 0.1 * atr) - c1, 0.3 * atr); tp = vw - P_VwapBand2 * sd; if(c1 - tp >= P_VwapMinRR * sl) { sellBase = true; g_sigSL = sl; g_sigTP = tp; } }
      }
      if(P_VwapMode != 1 && !buyBase && !sellBase && r1 > 0)
      {
         double up3 = vw + P_VwapBand3 * sd, dn3 = vw - P_VwapBand3 * sd;
         if(h1 >= up3 && c1 < up3 && c1 < o1 && h1 - MathMax(o1, c1) >= 0.4 * r1)
         { sl = MathMax((h1 + 0.1 * atr) - c1, 0.3 * atr); tp = vw; if(c1 - tp >= P_VwapMinRR * sl) { sellBase = true; g_sigSL = sl; g_sigTP = tp; } }
         else if(l1 <= dn3 && c1 > dn3 && c1 > o1 && MathMin(o1, c1) - l1 >= 0.4 * r1)
         { sl = MathMax(c1 - (l1 - 0.1 * atr), 0.3 * atr); tp = vw; if(tp - c1 >= P_VwapMinRR * sl) { buyBase = true; g_sigSL = sl; g_sigTP = tp; } }
      }
      if(buyBase || sellBase)
         EvAdd(StringFormat("VWAP hom nay %s, do lech chuan %s (dai 2: %s / %s, dai 3: %s / %s); nen vua dong %s - %s, dong cua %s; muc tieu %s",
                            Px(vw), Px(sd), Px(vw + P_VwapBand2 * sd), Px(vw - P_VwapBand2 * sd), Px(vw + P_VwapBand3 * sd), Px(vw - P_VwapBand3 * sd),
                            Px(l1), Px(h1), Px(c1), Px(g_sigTP)));
   }
   else if(P_Strategy == STRAT_DOW)
   {
      // Thuy trieu + con song (v5.23): chi giao dich theo chieu thuy trieu (DowOk, khung InpDowTF), dung con song nguoc chieu
      // lam cho vao lenh. Con song = cau truc khung chinh: dang giam (song hoi trong thuy trieu tang) va nen vua dong cua vuot
      // dinh gan nhat cua con song -> con song da het, Buy. SL duoi day con song - 0,25 ATR. Thuy trieu giam: nguoc lai.
      DowState w;
      if(!DowCalc(P_TF, 300, P_DowPivot, w)) return false;
      if(w.brk == 1 && w.prev == -1 && w.pl > 0)
      { buyBase = true;  g_sigSL = MathMax(c1 - (w.pl - 0.25 * atr), 0.5 * atr);
        EvAdd(StringFormat("Con song %s dang hoi xuong, nen dong cua %s vuot dinh gan nhat cua con song; day con song %s", EnumToString(P_TF), Px(c1), Px(w.pl))); }
      if(w.brk == -1 && w.prev == 1 && w.ph > 0)
      { sellBase = true; g_sigSL = MathMax((w.ph + 0.25 * atr) - c1, 0.5 * atr);
        EvAdd(StringFormat("Con song %s dang hoi len, nen dong cua %s thung day gan nhat cua con song; dinh con song %s", EnumToString(P_TF), Px(c1), Px(w.ph))); }
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
