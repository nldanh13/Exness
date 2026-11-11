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
int g_groupSkips  = 0;   // So tin hieu bi bo vi nhom BTC/ETH da dung het tran rui ro
bool g_grpLocked = false;
double g_grpLockToken = 0; // chi nguoi giu dung gia tri nay moi duoc mo khoa
// Tra false neu bot nay thuoc nhom ma khong lay duoc khoa: KHONG duoc vao lenh (thu lai o tick sau).
bool GroupLock()
{
   g_grpLocked = false;
   g_grpLockToken = 0;
   if(MQLInfoInteger(MQL_TESTER) || !InGroup()) return true;     // backtest 1 ma / khong thuoc nhom: khong can khoa
   string k = GrpKey("LOCK");
   // Tao bien khoa mot cach nguyen tu: GlobalVariableTemp chi tao khi chua co (gia tri 0) va KHONG ghi de
   // khoa bot kia vua dat. (Check roi Set(0) co the xoa mat khoa cua bot kia neu hai bot cung khoi tao.)
   if(!GlobalVariableCheck(k) && !GlobalVariableTemp(k) && !GlobalVariableCheck(k)) return false;
   for(int i = 0; i < 100 && !IsStopped(); i++)                // toi da ~5 giay
   {
      double now = (double)TimeLocal();
      if(GlobalVariableSetOnCondition(k, now, 0)) { g_grpLocked = true; g_grpLockToken = now; return true; }
      double v = GlobalVariableGet(k);
      // Khoa bi bo quen (bot kia bi tat giua chung): giu qua 60 giay thi coi nhu het han
      if(v > 0 && now - v > 60 && GlobalVariableSetOnCondition(k, now, v)) { g_grpLocked = true; g_grpLockToken = now; return true; }
      Sleep(50);
   }
   return false;
}
void GroupUnlock() { if(g_grpLocked) GlobalVariableSetOnCondition(GrpKey("LOCK"), 0, g_grpLockToken); g_grpLocked = false; g_grpLockToken = 0; }
// GlobalVariableTime khong phu hop lam TTL: do THOI DIEM TRUY CAP, ke ca doc gia tri.
// TTL 60 giay tinh tu TimeLocal trong CHINH gia tri khoa; khong duoc ha tuy tien xuong 30s khi server co the tre.
// Giu cho theo tung bot (ma + Magic): nhieu chien luoc tren CUNG ma cung duoc tinh vao tran chung
string ResKey(const string p, const string sym, const long magic) { return GrpKey(p + sym + "_" + IntegerToString(magic)); }
void GroupReserve(const double risk)
{
   if(MQLInfoInteger(MQL_TESTER) || !InGroup()) return;
   GlobalVariableSet(ResKey("R_", _Symbol, (long)P_Magic), risk);
   GlobalVariableSet(ResKey("T_", _Symbol, (long)P_Magic), (double)TimeLocal());
}
void GroupClear() { GlobalVariableDel(ResKey("R_", _Symbol, (long)P_Magic)); GlobalVariableDel(ResKey("T_", _Symbol, (long)P_Magic)); }

// Du tru rieng cho lenh magic0 do bot tu vao/nh oi. Dung magic am ao de
// HasPosition(sym, P_Magic) khong lam mat reservation khi con pending fill.
// Reservation het han sau 120s, doi tinh an toan lay tan suat giao dich.
long GroupGuardReserveTag() { return -(long)P_Magic - 1; }
void GroupReserveGuard(const double risk)
{
   if(MQLInfoInteger(MQL_TESTER) || !InGroup()) return;
   GlobalVariableSet(ResKey("R_", _Symbol, GroupGuardReserveTag()), risk);
   GlobalVariableSet(ResKey("T_", _Symbol, GroupGuardReserveTag()), (double)TimeLocal());
}
void GroupClearGuard()
{
   if(MQLInfoInteger(MQL_TESTER) || !InGroup()) return;
   GlobalVariableDel(ResKey("R_", _Symbol, GroupGuardReserveTag()));
   GlobalVariableDel(ResKey("T_", _Symbol, GroupGuardReserveTag()));
}

bool HasPosition(const string sym, const long magic)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
      if(PositionGetSymbol(i) == sym && PositionGetInteger(POSITION_MAGIC) == magic) return true;
   return false;
}
bool IsMine(const string sym, const long magic) { return sym == _Symbol && magic == (long)P_Magic; }
// Rui ro ma cac bot khac (khac ma, hoac cung ma khac Magic) da giu cho trong 2 phut qua nhung lenh chua hien ra.
// onlySym = "" : moi ma; khac "": chi ma do.
double GroupReserved(const string onlySym = "")
{
   string pre = GrpKey("R_");
   double sum = 0;
   for(int i = GlobalVariablesTotal() - 1; i >= 0; i--)
   {
      string n = GlobalVariableName(i);
      if(StringFind(n, pre) != 0) continue;
      string rest = StringSubstr(n, StringLen(pre));          // "<ma>_<magic>"
      int last = -1; for(int q = StringFind(rest, "_"); q >= 0; q = StringFind(rest, "_", q + 1)) last = q;
      if(last <= 0) continue;
      string sym = StringSubstr(rest, 0, last);
      long   mg  = StringToInteger(StringSubstr(rest, last + 1));
      if(IsMine(sym, mg) || (onlySym != "" && sym != onlySym)) continue;
      string tk = ResKey("T_", sym, mg);
      if(!GlobalVariableCheck(tk) || (double)TimeLocal() - GlobalVariableGet(tk) > 120 || HasPosition(sym, mg)) continue;
      sum += GlobalVariableGet(n);
   }
   return sum;
}
double g_lastRisk = 0;   // rui ro (tien) cua lenh CalcLots vua tinh

// Tien co the mat (tinh tu gia vao toi SL) cua cac lenh dang mo trong nhom, tru lenh cua chinh bot nay:
// gom ma khac trong nhom VA cac bot khac (Magic khac, ke ca lenh tay) tren cung ma.
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
      if(sym == "" || StringFind(list, "," + sym + ",") < 0 || IsMine(sym, PositionGetInteger(POSITION_MAGIC))) continue;
      double sl = PositionGetDouble(POSITION_SL), op = PositionGetDouble(POSITION_PRICE_OPEN);
      double vol = PositionGetDouble(POSITION_VOLUME);
      bool   buy = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY;
      double ts = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_SIZE);
      double tv = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_VALUE_LOSS);
      if(tv <= 0) tv = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_VALUE);
      if(sl <= 0 || ts <= 0 || tv <= 0) return DBL_MAX; // rui ro khong the dinh luong: cam mo them
      double dist = buy ? op - sl : sl - op;
      if(dist > 0) sum += dist / ts * tv * vol;
   }
   return sum + GroupReserved();
}
// Rui ro con mo cua cac lop dang mo cua CHINH bot nay (gia vao -> SL hien tai). SL da o hoa von hoac qua: 0.
// Lenh khong co SL: tinh bang rui ro chuan cua 1 lenh.
// Day la rui ro theo mo hinh (SL khop dung gia). Gap / truot gia manh thi lo that co the lon hon.
double OwnOpenRisk(const double stdRisk)
{
   double sum = 0;
   double ts = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double tv = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE_LOSS);
   if(tv <= 0) tv = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetTicket(i) == 0 || !IsOwnSelected()) continue;
      double sl = PositionGetDouble(POSITION_SL), op = PositionGetDouble(POSITION_PRICE_OPEN);
      double vol = PositionGetDouble(POSITION_VOLUME);
      bool   buy = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY;
      if(sl <= 0 || ts <= 0 || tv <= 0) return DBL_MAX; // rui ro khong the dinh luong: cam mo them
      double dist = buy ? op - sl : sl - op;
      if(dist > 0) sum += dist / ts * tv * vol;
   }
   return sum;
}
// Bat buoc goi TRONG GroupLock(), truoc khi gui lenh magic=0 cua GuardAutoEntry/GuardPyramid.
// GroupOpenRisk gom ca cac lenh magic=0 BTC/ETH; OwnOpenRisk gom P_Magic chart nay.
// Neu khong co SL, dung 1 rui ro mot lenh uoc tinh thay vi coi la 0.
bool GroupGuardRiskAllowed(const double newRisk)
{
   if(newRisk <= 0) return false;
   if(!InGroup() || P_MaxGroupRiskPct <= 0) return true;
   if(!MQLInfoInteger(MQL_TESTER) && !g_grpLocked) return false; // fail-closed: chua giu khoa chung
   double eq = AccountInfoDouble(ACCOUNT_EQUITY), bot = BotEquity();
   double base = MathMin(eq, bot);
   if(base <= 0) return false;
   double maxOnePct = MathMax(P_RiskPercent, InpGuardMaxRiskPct);
   if(InpGuardAutoRiskPct > maxOnePct) maxOnePct = InpGuardAutoRiskPct;
   double unknownSLRisk = base * maxOnePct / 100.0;
   double used = GroupOpenRisk(unknownSLRisk) + OwnOpenRisk(unknownSLRisk);
   double cap = base * P_MaxGroupRiskPct / 100.0;
   if(used + newRisk <= cap + 1e-8) return true;
   g_groupSkips++;
   if(ShouldNotify("guardGroupRisk", 600))
      PrintFormat("[%s] BO magic0: rui ro nhom BTC/ETH %.2f + lenh moi %.2f > tran %.2f %s (%.1f%%).",
                  _Symbol, used, newRisk, cap, AccountInfoString(ACCOUNT_CURRENCY), P_MaxGroupRiskPct);
   return false;
}

// Ma khac trong InpCorrSymbols, hoac bot khac tren cung ma, dang co lenh -> tra mo ta, khong co -> ""
string CorrOpen()
{
   string list = "," + P_CorrSymbols + ",";
   StringReplace(list, " ", "");
   if(StringFind(list, "," + _Symbol + ",") < 0) return "";
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      string sym = PositionGetSymbol(i);
      if(sym == "" || StringFind(list, "," + sym + ",") < 0 || IsMine(sym, PositionGetInteger(POSITION_MAGIC))) continue;
      return sym == _Symbol ? sym + " (bot khac)" : sym;
   }
   if(GroupReserved() > 0) return "Bot khac (dang vao lenh)";
   return "";
}
int g_minLotSkips = 0;
int g_roundUps    = 0;   // So lenh vao lot toi thieu (rui ro that > InpRiskPercent nhung <= InpMaxRiskRoundUp)
int g_ddScaled   = 0;   // So lenh bi giam co vi dang sut giam
// g_groupSkips khai bao truoc GroupGuardRiskAllowed de dung duoc trong module.
int g_chainSkips  = 0;   // So lan nhoi bi bo vi cac lop cu cua bot con rui ro (chua o hoa von) da bang 1 lenh chuan
double g_maxOpenRiskPct = 0;   // Rui ro mo lon nhat cua bot (moi lop, ngay sau khi vao lop moi), % von cua bot
double CalcLots(const double slDistance)
{
   double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE_LOSS);
   if(tickValue <= 0) tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   if(tickSize <= 0 || tickValue <= 0 || slDistance <= 0) return 0;

   // Rui ro tinh tren "von cua bot" (cung moc voi gioi han lo), khong phai equity ca tai khoan.
   // Sau khi nap/rut tien, dat InpResetHalt = true 1 lan de cap nhat moc.
   // InpCapital la von AO cua bot; khong duoc co rui ro lon hon equity that.
   // Tren Cent, OrderCalcProfit va equity cung tinh theo USC (100 USC = 1 USD).
   double riskBase = MathMin(BotEquity(), AccountInfoDouble(ACCOUNT_EQUITY));
   if(riskBase <= 0 || P_RiskPercent <= 0) return 0;
   double riskMoney  = riskBase * P_RiskPercent / 100.0;
   // Giam co theo sut giam tu dinh von cua bot: < 5% giu nguyen, 5-10% con 50%, > 10% con 25%.
   // Chi tro lai muc chuan khi von lap dinh moi. Khong bao gio tang co de "go".
   if(P_DDScale)
   {
      double pk = GVGet("peak", 0), eqL = BotEquityForLimits();
      double dd = pk > 0 ? (pk - eqL) / pk * 100.0 : 0;
      double f  = dd >= 10 ? 0.25 : dd >= 5 ? 0.5 : 1.0;
      if(f < 1) { riskMoney *= f; g_ddScaled++; }
   }
   // BTC va ETH di cung nhau (tuong quan cao): ma cung nhom dang co lenh thi giam rui ro lenh moi
   string corr = CorrOpen();
   if(corr != "" && P_CorrRiskScale > 0 && P_CorrRiskScale < 1)
   {
      riskMoney *= P_CorrRiskScale;
      PrintFormat("%s dang co lenh, giam rui ro lenh nay x%.2f.", corr, P_CorrRiskScale);
   }
   // Chuoi nhoi cua chinh bot: rui ro con mo cua cac lop cu + lop moi khong vuot 1 lenh chuan (InpRiskPercent).
   // Binh thuong lop cu da doi SL ve hoa von nen own = 0 va khong doi gi. Lop cu chua co SL hoa von thi lop moi nho lai / bo.
   double stdRisk = riskBase * P_RiskPercent / 100.0;
   double own = OwnOpenRisk(stdRisk);
   double allowed = DBL_MAX;
   if(own > 0)
   {
      allowed = stdRisk - own;
      if(allowed <= 0)
      {
         g_chainSkips++;
         g_status = "Cac lop dang mo con rui ro du 1 lenh, khong nhoi them";
         PrintFormat("Lop dang mo cua bot con rui ro %.2f (>= 1 lenh chuan %.2f). Bo qua lan nhoi.", own, stdRisk);
         return 0;
      }
      if(riskMoney > allowed) riskMoney = allowed;
   }
   // Tran chung cho ca nhom: lenh moi + lenh dang mo tren ma cung nhom (ca lop cu cua chinh bot) khong vuot InpMaxGroupRiskPct
   // Khong doi corr != "": lenh dau tien cung phai tuan thu tran nhom.
   if(P_MaxGroupRiskPct > 0 && InGroup())
   {
      double used = GroupOpenRisk(stdRisk) + own;
      allowed = MathMin(allowed, riskBase * P_MaxGroupRiskPct / 100.0 - used);
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
      // VON TOI THIEU PHU THUOC THUC TE vao tick value, volume min va SL/ATR - khong dung muc USD co dinh.
      double minLoss = minL * lossPerLot;
      PrintFormat("Can %.4f lot < min %.2f. SL=%.2f: minlot rui ro %.2f %s; can von >= %.2f (1%%) hoac %.2f (2%%). BO lenh.",
                  riskMoney / lossPerLot, minL, slDistance, minLoss, AccountInfoString(ACCOUNT_CURRENCY),
                  minLoss / 0.01, minLoss / 0.02);
      return 0;
   }
   if(lots > maxL) lots = maxL;
   g_lastRisk = lots * lossPerLot;
   if(riskBase > 0) g_maxOpenRiskPct = MathMax(g_maxOpenRiskPct, (own + g_lastRisk) / riskBase * 100.0);
   return lots;
}
