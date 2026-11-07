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

bool BaseSignals(const double atr, const double trend, const double fast,
                 const double c1, const double h1, const double l1,
                 bool &buyBase, bool &sellBase)
{
   buyBase = false; sellBase = false;
   g_sigSL = 0; g_sigTP = 0;
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
      for(int k = 3; k <= P_FvgLookback + 2 && !buyBase && !sellBase; k++)
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
   else
   {
      buyBase  = c1 > trend && fast > trend && l1 <= fast && c1 > fast;
      sellBase = c1 < trend && fast < trend && h1 >= fast && c1 < fast;
   }
   return true;
}
