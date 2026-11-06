//+------------------------------------------------------------------+
//| TrendBot/Signals.mqh: tin hieu goc (Donchian breakout / EMA pullback)
//| Chua xet bo loc. Tra false khi nen nay phai bo qua han (thieu du lieu, nen qua dai).
//+------------------------------------------------------------------+
bool BaseSignals(const double atr, const double trend, const double fast,
                 const double c1, const double h1, const double l1,
                 bool &buyBase, bool &sellBase)
{
   buyBase = false; sellBase = false;
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
      datetime rs = day + P_OrbStartMin * 60, re = rs + P_OrbMinutes * 60;
      if(t1 < re || t1 >= re + 4 * 3600) return true;
      int sIdx = iBarShift(_Symbol, P_TF, rs, false), eIdx = iBarShift(_Symbol, P_TF, re - 1, false);
      if(sIdx < 0 || eIdx < 1 || sIdx < eIdx || iTime(_Symbol, P_TF, sIdx) < rs - PeriodSeconds(P_TF)) return true;
      int cnt = sIdx - eIdx + 1;
      double rh = iHigh(_Symbol, P_TF, iHighest(_Symbol, P_TF, MODE_HIGH, cnt, eIdx));
      double rl = iLow(_Symbol,  P_TF, iLowest(_Symbol,  P_TF, MODE_LOW,  cnt, eIdx));
      double c2 = iClose(_Symbol, P_TF, 2);
      buyBase  = c1 > rh && (c2 <= rh || eIdx == 2);
      sellBase = c1 < rl && (c2 >= rl || eIdx == 2);
   }
   else
   {
      buyBase  = c1 > trend && fast > trend && l1 <= fast && c1 > fast;
      sellBase = c1 < trend && fast < trend && h1 >= fast && c1 < fast;
   }
   return true;
}
