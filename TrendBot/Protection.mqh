//+------------------------------------------------------------------+
//| TrendBot/Protection.mqh: Moc von, lai/lo cua bot, gioi han lo ngay, dung han khi sut giam
//+------------------------------------------------------------------+
//--- Bao ve tai khoan ----------------------------------------------
// Cac moc lo ngay / sut giam chi tinh tren LAI/LO CUA CHINH BOT (theo magic + symbol):
//   Von cua bot = von moc (balance luc bat dau theo doi) + lai/lo da dong + lai/lo dang chay
// Nap/rut tien hay EA khac tren cung tai khoan khong lam lech cac moc nay.
double GVGet(const string key, const double def = 0)
{
   string k = GVName(key);
   return GlobalVariableCheck(k) ? GlobalVariableGet(k) : def;
}
// Snapshot thu 2 (Common Files) cho peak/halt cua chien luoc P_Magic.
// Ghep voi Terminal GlobalVariables; khong tu dong mo khoa khi khoi dong lai.
bool g_botRiskLoaded = false;
ulong g_botRiskSavedMs = 0;
string BotRiskFile()
{
   return "TrendBot_botdd_" + IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)) + "_" +
          _Symbol + "_" + IntegerToString((long)P_Magic) + ".txt";
}
void BotRiskSave(const bool urgent = false)
{
   if(MQLInfoInteger(MQL_TESTER)) return;
   ulong ms = GetTickCount64();
   if(!urgent && ms - g_botRiskSavedMs < 30000) return;
   g_botRiskSavedMs = ms;
   int h = FileOpen(BotRiskFile(), FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_COMMON | FILE_SHARE_READ);
   if(h != INVALID_HANDLE)
   {
      // Snapshot du cac moc can thiet de khong ResetBaseline khi Global Variables bi mat sau crash.
      FileWriteString(h, DoubleToString(GVGet("peak"), 8) + "\\r\\n" +
                      (GVGet("halt") > 0 ? "1" : "0") + "\\r\\n" +
                      DoubleToString(GVGet("base"), 8) + "\\r\\n" +
                      DoubleToString(GVGet("epoch"), 0) + "\\r\\n" +
                      DoubleToString(GVGet("dayId", -1), 0) + "\\r\\n" +
                      DoubleToString(GVGet("dayEq"), 8) + "\\r\\n" +
                      DoubleToString(GVGet("dayLock", -1), 0) + "\\r\\n");
      FileClose(h);
   }
   GlobalVariablesFlush();
}
void BotRiskLoad()
{
   if(g_botRiskLoaded) return;
   g_botRiskLoaded = true;
   if(MQLInfoInteger(MQL_TESTER)) return;
   int h = FileOpen(BotRiskFile(), FILE_READ | FILE_TXT | FILE_ANSI | FILE_COMMON | FILE_SHARE_READ);
   if(h == INVALID_HANDLE) return;
   double savedPeak = StringToDouble(FileReadString(h));
   bool savedHalt = StringToInteger(FileReadString(h)) != 0;
   double savedBase = StringToDouble(FileReadString(h));
   double savedEpoch = StringToDouble(FileReadString(h));
   double savedDayId = StringToDouble(FileReadString(h));
   double savedDayEq = StringToDouble(FileReadString(h));
   double savedDayLock = StringToDouble(FileReadString(h));
   FileClose(h);
   if(savedBase > 0 && !GlobalVariableCheck(GVName("base"))) GlobalVariableSet(GVName("base"), savedBase);
   if(savedEpoch > 0 && !GlobalVariableCheck(GVName("epoch"))) GlobalVariableSet(GVName("epoch"), savedEpoch);
   if(savedDayId > 0 && !GlobalVariableCheck(GVName("dayId"))) GlobalVariableSet(GVName("dayId"), savedDayId);
   if(savedDayEq > 0 && !GlobalVariableCheck(GVName("dayEq"))) GlobalVariableSet(GVName("dayEq"), savedDayEq);
   if(savedDayLock > 0 && !GlobalVariableCheck(GVName("dayLock"))) GlobalVariableSet(GVName("dayLock"), savedDayLock);
   if(savedPeak > GVGet("peak")) GlobalVariableSet(GVName("peak"), savedPeak);
   if(savedHalt && GVGet("halt") <= 0) GlobalVariableSet(GVName("halt"), 1.0);
}

datetime DayStart()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   dt.hour = 0; dt.min = 0; dt.sec = 0;
   return StructToTime(dt);
}

double DealNet(const ulong d)
{
   return HistoryDealGetDouble(d, DEAL_PROFIT) + HistoryDealGetDouble(d, DEAL_SWAP) +
          HistoryDealGetDouble(d, DEAL_COMMISSION) + HistoryDealGetDouble(d, DEAL_FEE);
}

// Tinh lai lai/lo da dong tu lich su giao dich (khi co giao dich moi, hoac moi 60 giay)
void RefreshClosedPL()
{
   if(!g_plDirty && TimeCurrent() - g_lastPLCalc < 60) return;
   datetime epoch = (datetime)GVGet("epoch", 0);
   datetime today = DayStart();
   if(!HistorySelect(epoch, TimeCurrent() + 60)) return;
   double all = 0, day = 0;
   for(int i = HistoryDealsTotal() - 1; i >= 0; i--)
   {
      ulong d = HistoryDealGetTicket(i);
      if(d == 0) continue;
      if(HistoryDealGetString(d, DEAL_SYMBOL) != _Symbol ||
         HistoryDealGetInteger(d, DEAL_MAGIC) != (long)P_Magic) continue;
      double net = DealNet(d);
      all += net;
      if((datetime)HistoryDealGetInteger(d, DEAL_TIME) >= today) day += net;
   }
   g_closedPL    = all;
   g_closedToday = day;
   g_plDirty     = false;
   g_lastPLCalc  = TimeCurrent();
}

double FloatingPL()
{
   double f = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetTicket(i) == 0 || !IsOwnSelected()) continue;
      f += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
   }
   return f;
}

double BaseCapital() { return P_Capital > 0 ? P_Capital : GVGet("base"); }
double BotEquity() { return BaseCapital() + g_closedPL + FloatingPL(); }

// Von dung de xet gioi han: chi tru phan lo dang chay (duoi gia vao), KHONG tinh lai dang chay.
// Nho vay, lenh dang lai ma tra bot lai lai khong bi coi la lo ngay / sut giam.
double BotEquityForLimits() { return BaseCapital() + g_closedPL + MathMin(0.0, FloatingPL()); }

// Dat moc von cua bot (lan dau chay, hoac khi InpResetHalt = true)
// unlock = true chi khi nguoi dung chu dong dat InpResetHalt. Doi InpCapital chi dat lai moc,
// KHONG go trang thai dung han / khoa lo ngay, de khong vo tinh mo khoa bot da cham gioi han rui ro.
void ResetBaseline(const bool unlock)
{
   GlobalVariableSet(GVName("epoch"), (double)TimeCurrent());
   GlobalVariableSet(GVName("base"),  AccountInfoDouble(ACCOUNT_BALANCE));
   if(unlock)
   {
      // Chi mo dung han (sut giam). Khoa lo ngay KHONG mo duoc trong ngay, ke ca bang InpResetHalt:
      // lop bao ve chong lai viec nguoi van hanh muon "go lai" ngay sau khi thua. Tu het khi sang ngay moi.
      GlobalVariableDel(GVName("halt"));
   }
   GlobalVariableDel(GVName("dayId"));
   currentDay = -1;                                   // de UpdateDay chup lai moc dau ngay
   g_plDirty = true;
   RefreshClosedPL();
   GlobalVariableSet(GVName("peak"), BotEquityForLimits());
   BotRiskSave(true);
}

// Von cua bot luc dau ngay duoc luu vao Global Variable, nen khoi dong lai giua ngay khong reset
void UpdateDay()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   int dayId = dt.year * 1000 + dt.day_of_year;
   if(dayId != currentDay)
   {
      currentDay    = dayId;
      dailyNotified = false;
      g_plDirty     = true;
      RefreshClosedPL();
      if((int)GVGet("dayId", -1) == dayId && GlobalVariableCheck(GVName("dayEq")))
         dayStartEquity = GVGet("dayEq");
      else
      {
         dayStartEquity = BotEquityForLimits();
         GlobalVariableSet(GVName("dayId"), dayId);
         GlobalVariableSet(GVName("dayEq"), dayStartEquity);
      }
   }
}

// Lai/lo trong ngay = thay doi cua "von xet gioi han" so voi luc dau ngay
//   = lai/lo dong hom nay + (lo dang chay bay gio - lo dang chay luc 00:00)
// Lenh giu qua dem dang lo 70 luc 00:00 roi lo them 20 -> lo ngay = 20, khong phai 90.
double DayPL() { return BotEquityForLimits() - dayStartEquity; }

// Da cham lo ngay thi KHOA den het ngay, ke ca khi lo hoi phuc lai sau do
bool DailyLocked() { return (int)GVGet("dayLock", -1) == currentDay; }
bool DailyLossHit()
{
   if(P_MaxDailyLossPct <= 0 || dayStartEquity <= 0) return false;
   if(DailyLocked()) return true;
   return DayPL() <= -dayStartEquity * P_MaxDailyLossPct / 100.0;
}

// Kiem tra lo ngay moi tick: chan lenh moi va (tuy chon) dong lenh dang mo
void CheckDailyLoss()
{
   static int hits = 0;
   if(!DailyLossHit()) { hits = 0; return; }
   if(!DailyLocked() && ++hits < 2) return;
   GlobalVariableSet(GVName("dayLock"), currentDay);
   if(!dailyNotified)
   {
      Notify(StringFormat("[%s] Cham gioi han lo ngay %.1f%% (%.2f). Ngung vao lenh den mai%s.",
                          _Symbol, P_MaxDailyLossPct, DayPL(), P_CloseOnDailyLoss ? ", da dong lenh dang mo" : ""));
      dailyNotified = true;
   }
   if(P_CloseOnDailyLoss && HasOwnPosition()) CloseAll();
}

bool IsHalted() { return GVGet("halt") > 0; }

// Chong "lo gia": ngay sau khi so lenh mo thay doi, lich su giao dich co the chua cap nhat,
// nen bo qua kiem tra trong 2 tick va chi kich hoat khi dieu kien dung 2 lan lien tiep.
int  g_lastPosCount = -1;
int  g_skipTicks    = 0;
int  CountOwnPositions()
{
   int n = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
      if(PositionGetTicket(i) != 0 && IsOwnSelected()) n++;
   return n;
}
bool LimitsReady()
{
   int n = CountOwnPositions();
   if(n != g_lastPosCount) { g_lastPosCount = n; g_plDirty = true; g_skipTicks = 2; }
   if(g_skipTicks > 0) { g_skipTicks--; return false; }
   return true;
}

void CheckDrawdown()
{
   double eq   = BotEquityForLimits();
   double peak = GVGet("peak");
   if(eq > peak) { GlobalVariableSet(GVName("peak"), eq); peak = eq; }
   static int hits = 0;
   if(P_MaxDrawdownPct <= 0 || IsHalted() || peak <= 0) return;
   if(eq > peak * (1.0 - P_MaxDrawdownPct / 100.0)) { hits = 0; return; }
   if(++hits >= 2)
   {
      GlobalVariableSet(GVName("halt"), 1);
      BotRiskSave(true);
      Notify(StringFormat("[%s] BOT DUNG HAN: von cua bot sut %.1f%% tu dinh %.2f. Dat InpResetHalt=true de chay lai.",
                          _Symbol, (1.0 - eq / peak) * 100.0, peak));
      if(P_CloseOnHalt) CloseAll();
   }
}
