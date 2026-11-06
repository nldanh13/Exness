//+------------------------------------------------------------------+
//| TrendBot/Signals.mqh: tin hieu goc (Donchian breakout / EMA pullback)
//| Chua xet bo loc. Tra false khi nen nay phai bo qua han (thieu du lieu, nen qua dai).
//+------------------------------------------------------------------+
bool BaseSignals(const double atr, const double trend, const double fast,
                 const double c1, const double h1, const double l1,
                 bool &buyBase, bool &sellBase)
{
   buyBase = false; sellBase = false;
   if(InpStrategy == STRAT_DONCHIAN)
   {
      // Pha vo: nen "b" dong vuot dinh/day cao nhat/thap nhat cua N nen truoc no.
      // b = 1 (nen vua dong); neu InpBreakConfirm thi b = 2 va nen 1 phai van dong ngoai kenh.
      int b = InpBreakConfirm ? 2 : 1;
      int hiIdx = iHighest(_Symbol, InpTF, MODE_HIGH, InpDonchianPeriod, b + 1);
      int loIdx = iLowest(_Symbol,  InpTF, MODE_LOW,  InpDonchianPeriod, b + 1);
      if(hiIdx < 0 || loIdx < 0) return false;
      double chHigh = iHigh(_Symbol, InpTF, hiIdx);
      double chLow  = iLow(_Symbol,  InpTF, loIdx);
      double cb = iClose(_Symbol, InpTF, b), ob = iOpen(_Symbol, InpTF, b);
      double hb = iHigh(_Symbol, InpTF, b),  lb = iLow(_Symbol, InpTF, b);
      double margin = InpBreakMinATR * atr;                         // vuot kenh bao xa
      double range  = hb - lb;
      // Nen qua dai thuong la thanh ly day chuyen (lenh bi ep dong tren so lenh mong): vao theo la duoi gia
      bool   tooLong = InpBreakMaxATR > 0 && range > InpBreakMaxATR * atr;
      double body   = MathAbs(cb - ob);
      // Than nen: nen pha vo phai la nen cung chieu, than chiem it nhat X% bien do (khong phai chi rau dai)
      bool   bodyBuy  = InpBreakMinBody <= 0 || (cb > ob && range > 0 && body >= range * InpBreakMinBody / 100.0);
      bool   bodySell = InpBreakMinBody <= 0 || (cb < ob && range > 0 && body >= range * InpBreakMinBody / 100.0);
      buyBase  = cb > chHigh + margin && bodyBuy  && c1 > trend && (b == 1 || c1 > chHigh);
      sellBase = cb < chLow  - margin && bodySell && c1 < trend && (b == 1 || c1 < chLow);
      if(tooLong && (buyBase || sellBase)) { g_status = "Nen pha vo qua dai, bo qua"; return false; }
   }
   else
   {
      buyBase  = c1 > trend && fast > trend && l1 <= fast && c1 > fast;
      sellBase = c1 < trend && fast < trend && h1 >= fast && c1 < fast;
   }
   return true;
}
