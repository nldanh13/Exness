//+------------------------------------------------------------------+
//| TrendBot/Grid.mqh: danh luoi trong vung di ngang (v5.16)         |
//| Chien luoc 13 (InpStrategy = 13). CHUA KIEM THU.                 |
//+------------------------------------------------------------------+
// Giang luoi trong ao: gia len xuong trong mot vung, moi lan roi xuong mot nac thi mua, len lai nac tren thi ban
// (moi lenh mua co TP o nac ngay tren), an phan chenh lech. Khong doan tang hay giam.
// Rui ro: ca boi ra khoi ao. Gia thung day va roi tiep -> luoi mua o moi nac tren duong xuong, lo lon hon moi thu
// luoi da kiem duoc. Vi vay 4 luat:
//  1) Chi giang luoi khi THAT SU di ngang (khung chinh, InpGridBars nen): vung cao InpGridMinATR..InpGridMaxATR ATR,
//     ADX < InpGridMaxADX (khong co xu huong), da cham dinh va day moi phia it nhat 2 lan.
//  2) Khong giang qua day: moi mat luoi >= InpGridMinStepCost x spread, neu khong thi giam so nac; < 3 nac thi khong giang.
//  3) Diem dung NGOAI luoi: moi lenh co SL tai day vung - InpGridStopATR x ATR (dat san o server). Nen dong cua thung
//     day vung: tat luoi, dong het, cat lo. Gia pha len tren dinh vung: tat luoi (huy lenh cho), lenh con lai giu TP.
//  4) Khong dung don bay cao: khoi luong moi nac tinh sao cho NEU moi nac deu khop roi cham SL thi tong lo = InpRiskPercent
//     von bot; ky quy cua ca luoi <= 50% ky quy tu do. Tam tat luoi (huy lenh cho) truoc tin lon / khi cham lo ngay /
//     ngoai gio giao dich / spread rong (cac dieu kien chung cua bot, EntryGatesOk + MarketFiltersOk).
// Sau khi luoi bi tat: nghi InpGridBars / 2 nen roi moi tim vung moi. Trang thai luoi luu Global Variable (khoi dong lai van nho).
bool     g_gridOn = false;
double   g_gridLo = 0, g_gridHi = 0, g_gridStep = 0, g_gridStop = 0, g_gridLot = 0;
int      g_gridN = 0;
datetime g_gridOffUntil = 0, g_gridBar = 0;
int      g_gridOpened = 0, g_gridCuts = 0;
string   g_gridState = "";
bool     g_gridLoaded = false;

void GridSave()
{
   GlobalVariableSet(GVName("grid_on"), g_gridOn ? 1 : 0);
   GlobalVariableSet(GVName("grid_lo"), g_gridLo);   GlobalVariableSet(GVName("grid_hi"), g_gridHi);
   GlobalVariableSet(GVName("grid_n"), g_gridN);     GlobalVariableSet(GVName("grid_stop"), g_gridStop);
   GlobalVariableSet(GVName("grid_lot"), g_gridLot); GlobalVariableSet(GVName("grid_off"), (double)g_gridOffUntil);
}
void GridLoad()
{
   g_gridLoaded = true;
   g_gridOn = GVGet("grid_on", 0) > 0;
   g_gridLo = GVGet("grid_lo", 0); g_gridHi = GVGet("grid_hi", 0); g_gridN = (int)GVGet("grid_n", 0);
   g_gridStop = GVGet("grid_stop", 0); g_gridLot = GVGet("grid_lot", 0); g_gridOffUntil = (datetime)GVGet("grid_off", 0);
   if(g_gridOn && (g_gridN < 3 || g_gridHi <= g_gridLo || g_gridLot <= 0)) g_gridOn = false;
   g_gridStep = g_gridOn ? (g_gridHi - g_gridLo) / g_gridN : 0;
}

// Huy moi lenh cho cua bot tren ma nay
void GridCancel()
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong t = OrderGetTicket(i);
      if(t == 0 || OrderGetString(ORDER_SYMBOL) != _Symbol || OrderGetInteger(ORDER_MAGIC) != (long)P_Magic) continue;
      trade.OrderDelete(t);
   }
}

// Tat luoi. cut = true: dong ca cac lenh dang mo (gia thung day vung).
void GridOff(const bool cut, const string why)
{
   GridCancel();
   if(cut && HasOwnPosition()) { CloseAll(); g_gridCuts++; }
   g_gridOn = false;
   g_gridOffUntil = (datetime)(TimeCurrent() + (long)MathMax(1, P_GridBars / 2) * PeriodSeconds(P_TF));
   GridSave();
   g_status = "Luoi: " + why;
   Notify("[" + _Symbol + "] Tat luoi: " + why);
}

// 1) Vung di ngang ro rang tren khung chinh
bool GridDetect(const double atr, double &lo, double &hi)
{
   int N = P_GridBars < 20 ? 20 : P_GridBars;
   int hiI = iHighest(_Symbol, P_TF, MODE_HIGH, N, 1), loI = iLowest(_Symbol, P_TF, MODE_LOW, N, 1);
   if(hiI < 0 || loI < 0 || atr <= 0) return false;
   hi = iHigh(_Symbol, P_TF, hiI); lo = iLow(_Symbol, P_TF, loI);
   double h = hi - lo;
   if(h < P_GridMinATR * atr) { g_gridState = "vung gia qua hep"; return false; }
   if(h > P_GridMaxATR * atr) { g_gridState = "vung gia qua rong (dang co xu huong)"; return false; }
   double adx = 0;
   if(!GetValue(hADX, 0, 1, adx)) return false;
   if(adx >= P_GridMaxADX) { g_gridState = StringFormat("ADX %.0f: dang co xu huong, khong giang luoi", adx); return false; }
   int tH = 0, tL = 0;
   double z = 0.15 * h;
   for(int s = 1; s <= N; s++)
   {
      if(iHigh(_Symbol, P_TF, s) >= hi - z && iHigh(_Symbol, P_TF, s + 1) < hi - z) tH++;
      if(iLow(_Symbol, P_TF, s)  <= lo + z && iLow(_Symbol, P_TF, s + 1)  > lo + z) tL++;
   }
   if(tH < 2 || tL < 2) { g_gridState = StringFormat("chua cham du dinh / day (%d / %d lan)", tH, tL); return false; }
   double c1 = iClose(_Symbol, P_TF, 1);
   if(c1 <= lo + z || c1 >= hi - z) { g_gridState = "gia dang sat bien vung, cho"; return false; }
   return true;
}

// 2) + 4) So nac, mat luoi, diem dung, khoi luong moi nac
bool GridPlan(const double lo, const double hi, const double atr)
{
   double cost = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * _Point;
   if(cost <= 0) cost = _Point;
   int n = P_GridLevels < 3 ? 3 : P_GridLevels;
   while(n >= 3 && (hi - lo) / n < P_GridMinStepCost * cost) n--;
   if(n < 3) { g_gridState = "mat luoi qua day so voi phi (spread)"; return false; }
   double step = (hi - lo) / n, stop = lo - P_GridStopATR * atr;
   double ts = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double tv = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE_LOSS);
   if(tv <= 0) tv = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   if(ts <= 0 || tv <= 0) return false;
   double perLot = 0;                                   // lo cua 1 lot moi nac neu MOI nac khop roi cham SL
   for(int i = 0; i < n; i++) perLot += (lo + i * step - stop) / ts * tv;
   double base = MathMin(BotEquity(), AccountInfoDouble(ACCOUNT_EQUITY));
   if(base <= 0 || perLot <= 0 || P_RiskPercent <= 0) return false;
   double vMin = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN), vStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double vMax = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lot = base * P_RiskPercent / 100.0 / perLot;
   if(vStep > 0) lot = MathFloor(lot / vStep) * vStep;
   if(lot < vMin)
   {
      double maxPct = MathMax(P_RiskPercent, P_MaxRiskRoundUp);
      if(vMin * perLot > base * maxPct / 100.0)
      { g_gridState = StringFormat("von qua nho: 0,01 lot moi nac da rui ro %.1f%% von", vMin * perLot / base * 100.0); return false; }
      lot = vMin;
   }
   if(lot > vMax) lot = vMax;
   double margin = 0;
   if(OrderCalcMargin(ORDER_TYPE_BUY, _Symbol, lot, hi, margin) && margin * n > 0.5 * AccountInfoDouble(ACCOUNT_MARGIN_FREE))
   { g_gridState = "ky quy cua ca luoi vuot 50% ky quy tu do"; return false; }
   g_gridLo = lo; g_gridHi = hi; g_gridN = n; g_gridStep = step; g_gridStop = stop; g_gridLot = lot;
   return true;
}

// Dat lai lenh cho o moi nac duoi gia hien tai chua co lenh cho / vi the
void GridMaintain()
{
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double minDist = (double)(SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) + 1) * _Point;
   for(int i = 0; i < g_gridN; i++)
   {
      double px = NormalizeDouble(g_gridLo + i * g_gridStep, _Digits);
      if(px >= ask - minDist) continue;                  // nac nam tren gia: cho gia len lai moi dat
      bool have = false;
      for(int k = PositionsTotal() - 1; k >= 0 && !have; k--)
         if(PositionGetTicket(k) > 0 && IsOwnSelected() && MathAbs(PositionGetDouble(POSITION_PRICE_OPEN) - px) < g_gridStep / 2) have = true;
      for(int k = OrdersTotal() - 1; k >= 0 && !have; k--)
      {
         ulong t = OrderGetTicket(k);
         if(t > 0 && OrderGetString(ORDER_SYMBOL) == _Symbol && OrderGetInteger(ORDER_MAGIC) == (long)P_Magic &&
            MathAbs(OrderGetDouble(ORDER_PRICE_OPEN) - px) < g_gridStep / 2) have = true;
      }
      if(have) continue;
      double tp = NormalizeDouble(px + g_gridStep, _Digits), sl = NormalizeDouble(g_gridStop, _Digits);
      if(PrepSend() && trade.BuyLimit(g_gridLot, px, _Symbol, sl, tp, ORDER_TIME_GTC, 0, "TB luoi " + IntegerToString(i)))
         g_gridOpened++;
   }
}

// Goi moi lan quan ly lenh khi InpStrategy = 13 (thay cho duong tin hieu thuong)
void GridTick()
{
   if(!g_gridLoaded) GridLoad();
   if(IsHalted()) { GridCancel(); g_status = "DUNG HAN: luoi da huy lenh cho"; return; }
   double atr = 0;
   if(!GetValue(hATR, 0, 1, atr)) return;
   datetime bar = iTime(_Symbol, P_TF, 0);
   bool newBar = bar != g_gridBar;
   if(newBar) g_gridBar = bar;
   if(g_gridOn)
   {
      double c1 = iClose(_Symbol, P_TF, 1);
      if(newBar && c1 < g_gridLo) { GridOff(true, "nen dong cua thung day vung, da dong het va cat lo"); return; }
      if(newBar && c1 > g_gridHi) { GridOff(false, "gia pha len tren dinh vung, da huy lenh cho (lenh con lai giu TP)"); return; }
      // Tam tat: tin lon, lo ngay, ngoai gio, spread rong... -> huy lenh cho, giu luoi va cac lenh dang mo (co SL / TP)
      if(!EntryGatesOk() || !MarketFiltersOk(true, false)) { GridCancel(); g_gridState = "tam tat: " + g_status; return; }
      GridMaintain();
      g_gridState = StringFormat("dang chay: %d nac %s - %s, moi nac %.2f lot, dung o %s", g_gridN,
                                 DoubleToString(g_gridLo, _Digits), DoubleToString(g_gridHi, _Digits), g_gridLot,
                                 DoubleToString(g_gridStop, _Digits));
      g_status = "Luoi " + g_gridState;
      return;
   }
   // Luoi dang tat: neu da het thoi gian nghi va het lenh, tim vung moi o moi nen moi
   if(!newBar) return;
   if(TimeCurrent() < g_gridOffUntil) { g_status = "Luoi: nghi sau khi tat, cho vung moi"; return; }
   if(HasOwnPosition()) { g_status = "Luoi: con lenh cu, cho dong het"; return; }
   if(!EntryGatesOk()) return;
   double lo = 0, hi = 0;
   if(!GridDetect(atr, lo, hi) || !GridPlan(lo, hi, atr)) { g_status = "Luoi: " + g_gridState; return; }
   g_gridOn = true;
   GridSave();
   Notify(StringFormat("[%s] Giang luoi %d nac %s - %s, %.2f lot moi nac, diem dung %s", _Symbol, g_gridN,
                       DoubleToString(g_gridLo, _Digits), DoubleToString(g_gridHi, _Digits), g_gridLot,
                       DoubleToString(g_gridStop, _Digits)));
   GridMaintain();
}
