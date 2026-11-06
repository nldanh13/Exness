//+------------------------------------------------------------------+
//| TrendBot/Risk.mqh: Tinh lot theo % rui ro, tran rui ro nhom BTC/ETH, khoa chung giua cac bot
//+------------------------------------------------------------------+
//--- Khoa chung + giu cho rui ro giua cac bot trong nhom (cung 1 terminal) ---
// Hai bot H4 dong nen cung luc nen co the cung vao lenh truoc khi thay lenh cua nhau.
// Truoc khi tinh lot, bot giu khoa chung; tinh xong thi ghi "da giu cho" so rui ro cua minh roi moi gui lenh.
string GrpKey(const string x) { return "BTCEA_" + IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)) + "_GRP_" + x; }
bool InGroup()
{
   string list = "," + P_CorrSymbols + ",";
   StringReplace(list, " ", "");
   return StringFind(list, "," + _Symbol + ",") >= 0;
}
bool g_grpLocked = false;
// Tra false neu bot nay thuoc nhom ma khong lay duoc khoa: KHONG duoc vao lenh (thu lai o tick sau).
bool GroupLock()
{
   g_grpLocked = false;
   if(MQLInfoInteger(MQL_TESTER) || !InGroup()) return true;     // backtest 1 ma / khong thuoc nhom: khong can khoa
   string k = GrpKey("LOCK");
   // Tao bien khoa mot cach nguyen tu: GlobalVariableTemp chi tao khi chua co (gia tri 0) va KHONG ghi de
   // khoa bot kia vua dat. (Check roi Set(0) co the xoa mat khoa cua bot kia neu hai bot cung khoi tao.)
   if(!GlobalVariableCheck(k) && !GlobalVariableTemp(k) && !GlobalVariableCheck(k)) return false;
   for(int i = 0; i < 100 && !IsStopped(); i++)                // toi da ~5 giay
   {
      double now = (double)TimeLocal();
      if(GlobalVariableSetOnCondition(k, now, 0)) { g_grpLocked = true; return true; }
      double v = GlobalVariableGet(k);
      // Khoa bi bo quen (bot kia bi tat giua chung): giu qua 60 giay thi coi nhu het han
      if(v > 0 && now - v > 60 && GlobalVariableSetOnCondition(k, now, v)) { g_grpLocked = true; return true; }
      Sleep(50);
   }
   return false;
}
void GroupUnlock() { if(g_grpLocked) GlobalVariableSet(GrpKey("LOCK"), 0); g_grpLocked = false; }
void GroupReserve(const double risk)
{
   if(MQLInfoInteger(MQL_TESTER) || !InGroup()) return;
   GlobalVariableSet(GrpKey("R_" + _Symbol), risk);
   GlobalVariableSet(GrpKey("T_" + _Symbol), (double)TimeLocal());
}
void GroupClear() { GlobalVariableDel(GrpKey("R_" + _Symbol)); GlobalVariableDel(GrpKey("T_" + _Symbol)); }
bool SymbolHasPosition(const string sym)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--) if(PositionGetSymbol(i) == sym) return true;
   return false;
}
// Rui ro ma bot khac da giu cho trong 2 phut qua nhung lenh chua hien ra
double GroupReserved(const string sym)
{
   if(!GlobalVariableCheck(GrpKey("T_" + sym))) return 0;
   if((double)TimeLocal() - GlobalVariableGet(GrpKey("T_" + sym)) > 120 || SymbolHasPosition(sym)) return 0;
   return GlobalVariableGet(GrpKey("R_" + sym));
}
double g_lastRisk = 0;   // rui ro (tien) cua lenh CalcLots vua tinh

// Tien co the mat (tinh tu gia vao toi SL) cua cac lenh dang mo tren ma khac trong nhom.
// Lenh khong co SL: tinh bang rui ro chuan cua 1 lenh. SL da qua gia vao (khoa lai): 0.
double GroupOpenRisk(const double stdRisk)
{
   string list = "," + P_CorrSymbols + ",";
   StringReplace(list, " ", "");
   if(StringFind(list, "," + _Symbol + ",") < 0) return 0;
   double sum = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      string sym = PositionGetSymbol(i);
      if(sym == "" || sym == _Symbol || StringFind(list, "," + sym + ",") < 0) continue;
      double sl = PositionGetDouble(POSITION_SL), op = PositionGetDouble(POSITION_PRICE_OPEN);
      double vol = PositionGetDouble(POSITION_VOLUME);
      bool   buy = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY;
      double ts = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_SIZE);
      double tv = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_VALUE_LOSS);
      if(tv <= 0) tv = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_VALUE);
      if(sl <= 0 || ts <= 0 || tv <= 0) { sum += stdRisk; continue; }
      double dist = buy ? op - sl : sl - op;
      if(dist > 0) sum += dist / ts * tv * vol;
   }
   string syms[];
   int n = StringSplit(P_CorrSymbols, ',', syms);
   for(int i = 0; i < n; i++)
   {
      StringTrimLeft(syms[i]); StringTrimRight(syms[i]);
      if(syms[i] != "" && syms[i] != _Symbol) sum += GroupReserved(syms[i]);
   }
   return sum;
}
// Ma khac trong InpCorrSymbols dang co lenh (cua bat ky bot nao) -> tra ten ma, khong co -> ""
string CorrOpen()
{
   string list = "," + P_CorrSymbols + ",";
   StringReplace(list, " ", "");
   if(StringFind(list, "," + _Symbol + ",") < 0) return "";
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      string sym = PositionGetSymbol(i);
      if(sym != "" && sym != _Symbol && StringFind(list, "," + sym + ",") >= 0) return sym;
   }
   string syms[];
   int n = StringSplit(P_CorrSymbols, ',', syms);
   for(int i = 0; i < n; i++)
   {
      StringTrimLeft(syms[i]); StringTrimRight(syms[i]);
      if(syms[i] != "" && syms[i] != _Symbol && GroupReserved(syms[i]) > 0) return syms[i] + " (dang vao lenh)";
   }
   return "";
}
int g_minLotSkips = 0;
int g_roundUps    = 0;   // So lenh vao lot toi thieu (rui ro that > InpRiskPercent nhung <= InpMaxRiskRoundUp)
int g_groupSkips  = 0;   // So tin hieu bi bo vi nhom BTC/ETH da dung het tran rui ro
double CalcLots(const double slDistance)
{
   double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE_LOSS);
   if(tickValue <= 0) tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   if(tickSize <= 0 || tickValue <= 0 || slDistance <= 0) return 0;

   // Rui ro tinh tren "von cua bot" (cung moc voi gioi han lo), khong phai equity ca tai khoan.
   // Sau khi nap/rut tien, dat InpResetHalt = true 1 lan de cap nhat moc.
   double riskBase   = BotEquity();
   double riskMoney  = riskBase * P_RiskPercent / 100.0;
   // BTC va ETH di cung nhau (tuong quan cao): ma cung nhom dang co lenh thi giam rui ro lenh moi
   string corr = CorrOpen();
   if(corr != "" && P_CorrRiskScale > 0 && P_CorrRiskScale < 1)
   {
      riskMoney *= P_CorrRiskScale;
      PrintFormat("%s dang co lenh, giam rui ro lenh nay x%.2f.", corr, P_CorrRiskScale);
   }
   // Tran chung cho ca nhom: lenh moi + lenh dang mo tren ma cung nhom khong vuot InpMaxGroupRiskPct
   double allowed = DBL_MAX;
   if(P_MaxGroupRiskPct > 0 && corr != "")
   {
      double used = GroupOpenRisk(riskBase * P_RiskPercent / 100.0);
      allowed = riskBase * P_MaxGroupRiskPct / 100.0 - used;
      if(allowed <= 0)
      {
         g_groupSkips++;
         g_status = "Nhom BTC/ETH da dung het tran rui ro, bo qua lenh";
         PrintFormat("Lenh dang mo trong nhom da rui ro %.2f (tran %.2f%%). Bo qua tin hieu.", used, P_MaxGroupRiskPct);
         return 0;
      }
      if(riskMoney > allowed) riskMoney = allowed;
   }
   double lossPerLot = slDistance / tickSize * tickValue;
   double lots       = NormalizeVolume(riskMoney / lossPerLot);
   double minL = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxL = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   // Lam tron len cung bi gioi han boi he so nhom va tran nhom, khong duoc vuot qua cac gioi han do
   double roundCap = riskBase * P_MaxRiskRoundUp / 100.0 * (corr != "" ? MathMin(1.0, MathMax(P_CorrRiskScale, 0.0)) : 1.0);
   if(roundCap > allowed) roundCap = allowed;
   if(lots < minL && P_MaxRiskRoundUp > 0 && riskBase > 0 && minL * lossPerLot <= roundCap)
   {
      g_roundUps++;
      PrintFormat("Lam tron len %.2f lot: rui ro that %.2f%% (tran %.2f%%).", minL, minL * lossPerLot / riskBase * 100.0, P_MaxRiskRoundUp);
      lots = minL;
   }
   if(lots < minL)
   {
      g_status = "Von qua nho cho SL nay, bo qua lenh";
      g_minLotSkips++;
      PrintFormat("Can %.4f lot < toi thieu %.2f. Bo qua de khong vuot rui ro.", riskMoney / lossPerLot, minL);
      return 0;
   }
   if(lots > maxL) lots = maxL;
   g_lastRisk = lots * lossPerLot;
   return lots;
}
