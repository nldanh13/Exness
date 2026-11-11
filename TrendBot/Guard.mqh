//+------------------------------------------------------------------+
//| TrendBot/Guard.mqh: Bao ve lenh vao tay (magic 0) tren ma cua chart
//| Rut ra tu sao ke giao dich tay 9/2025-3/2026: thang 66% lenh nhung lo vi
//|  - lenh khong SL giu qua dem (lenh giu > 1 ngay: thang 29%, chiem phan lon so lo)
//|  - nhoi them khi lenh dang lo (44% so lenh)
//|  - lenh qua to (> 0,5 lot lo, lenh nho lai)
//|  - vai ngay lo rat lon lien tiep
//| Chi chay that / demo (backtest khong co lenh tay). Bat bang InpGuardManual.
//| Lenh cho dat tay (Limit / Stop / Stop Limit, InpGuardPending): GuardPending() o cuoi file.
//+------------------------------------------------------------------+
ulong    g_gSeen[];            // lenh tay da xem (de chi xu ly "lenh moi" 1 lan)
bool     g_gInit      = false;
ulong    g_gLast      = 0;      // GetTickCount64 (ms): chay duoc ca tu OnTimer khi khong co tick (TimeCurrent dung yen)

// Trang thai luu qua lan khoi dong lai (Global Variables cua terminal)
string GKey(const string k) { return "TBG_" + IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)) + "_" + _Symbol + "_" + k; }
int    GDayKey(const datetime t) { MqlDateTime d; TimeToStruct(t, d); return d.year * 10000 + d.mon * 100 + d.day; }
// Dung han theo sut giam CA TAI KHOAN (v5.10.13, InpGuardMaxDDPct): lenh tay / tu vao dung magic 0 nen KHONG nam trong moc
// lo ngay 3% / sut giam 15% cua chien luoc chinh (chi tinh P_Magic). Moc nay tinh equity ca tai khoan so voi dinh, chung moi ma.
// Cham thi dong lenh tay, khong tu vao, khong nhoi, toi khi dat InpResetHalt = true mot lan.
string GAcctKey(const string k) { return "TBG_" + IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)) + "_" + k; }
bool   GuardHalted() { return GlobalVariableCheck(GAcctKey("halt")); }
void   GuardResetHalt()
{
   GlobalVariableDel(GAcctKey("halt"));
   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   if(eq > 0) GlobalVariableSet(GAcctKey("peak"), eq);
}
// true = vua cham hoac dang dung han
bool GuardCheckAcctDD(const double eq)
{
   if(GuardHalted()) return true;
   if(InpGuardMaxDDPct <= 0 || eq <= 0) return false;
   string pk = GAcctKey("peak");
   double peak = GlobalVariableCheck(pk) ? GlobalVariableGet(pk) : 0;
   if(eq > peak) { GlobalVariableSet(pk, eq); return false; }
   double dd = (peak - eq) / peak * 100.0;
   if(dd < InpGuardMaxDDPct) return false;
   GlobalVariableSet(GAcctKey("halt"), (double)TimeCurrent());
   Notify(StringFormat("[%s] DUNG HAN: von tai khoan sut %.1f%% tu dinh %.0f (gioi han %.1f%%). Dong lenh tay, ngung tu vao va nhoi. "
                       "Muon chay lai: dat InpResetHalt = true mot lan roi doi ve false.", _Symbol, dd, peak, InpGuardMaxDDPct));
   return true;
}

bool   GuardDayLocked() { string n = GKey("lock"); return GuardHalted() || (GlobalVariableCheck(n) && (int)GlobalVariableGet(n) == GDayKey(TimeCurrent())); }
void   GuardSetDayLock() { GlobalVariableSet(GKey("lock"), GDayKey(TimeCurrent())); }
// Lenh mo truoc luc bat bao ve lan dau = "lenh cu": chi canh bao, khong sua / dong (tru khi InpGuardOldTrades)
datetime GuardSince()
{
   string n = GKey("since");
   if(!GlobalVariableCheck(n)) GlobalVariableSet(n, (double)TimeCurrent());
   return (datetime)GlobalVariableGet(n);
}

bool GuardSeen(const ulong t)
{
   for(int i = 0; i < ArraySize(g_gSeen); i++) if(g_gSeen[i] == t) return true;
   return false;
}
void GuardMark(const ulong t) { int n = ArraySize(g_gSeen); ArrayResize(g_gSeen, n + 1); g_gSeen[n] = t; }

// Moi tai khoan + ma chi 1 chart duoc bat bao ve lenh tay (v5.10.11). Hai chart cung canh lenh magic 0 tren mot ma se cung
// dat SL, cung nhoi, cung tu vao, cung chot gop - lenh bi xu ly 2 lan. Chart bat truoc giu quyen; chart sau chi hien canh bao.
string GOwnPre() { return "TBO_" + IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)) + "_" + _Symbol + "_"; }
long   g_gOtherChart = 0;          // chart khac dang giu quyen (0 = chart nay giu)
bool GuardOwner()
{
   string pre = GOwnPre(), mine = pre + IntegerToString(ChartID());
   for(int i = GlobalVariablesTotal() - 1; i >= 0; i--)
   {
      string n = GlobalVariableName(i);
      if(StringFind(n, pre) != 0 || n == mine) continue;
      long id = StringToInteger(StringSubstr(n, StringLen(pre)));
      if(ChartSymbol(id) != "") { g_gOtherChart = id; return false; }   // chart khac van mo va dang giu
      GlobalVariableDel(n);                                              // chart cu da dong
   }
   if(!GlobalVariableCheck(mine)) GlobalVariableTemp(mine);
   g_gOtherChart = 0;
   return true;
}
void GuardOwnerRelease() { GlobalVariableDel(GOwnPre() + IntegerToString(ChartID())); }

bool IsManualSelected() { return PositionGetInteger(POSITION_MAGIC) == 0 && PositionGetString(POSITION_SYMBOL) == _Symbol; }

double GuardFloating(const ulong ticket)
{
   if(!PositionSelectByTicket(ticket)) return 0;
   return PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
}

void GuardClose(const ulong ticket, const string reason)
{
   if(PrepSend() && TradeDone(trade.PositionClose(ticket), "Dong lenh tay", reason))
      Notify(StringFormat("[%s] BAO VE LENH TAY: da dong lenh #%I64u. Ly do: %s", _Symbol, ticket, reason));
}

// Lai/lo lenh tay tren ma nay PHAT SINH trong ngay:
//   da dong hom nay + tha noi bay gio - tha noi luc 0:00 (cua cac lenh da mo tu truoc 0:00, tinh theo gia mo cua nen D1)
// Lenh am 200 tu hom qua, hom nay van am 200 -> lo trong ngay = 0.
double GuardManualDayPL(const datetime dayStart)
{
   double pl = 0;
   if(HistorySelect(dayStart, TimeCurrent() + 60))
      for(int i = HistoryDealsTotal() - 1; i >= 0; i--)
      {
         ulong d = HistoryDealGetTicket(i);
         if(d == 0 || HistoryDealGetInteger(d, DEAL_MAGIC) != 0 || HistoryDealGetString(d, DEAL_SYMBOL) != _Symbol) continue;
         if(HistoryDealGetInteger(d, DEAL_ENTRY) == DEAL_ENTRY_IN) { pl += HistoryDealGetDouble(d, DEAL_COMMISSION); continue; }
         pl += HistoryDealGetDouble(d, DEAL_PROFIT) + HistoryDealGetDouble(d, DEAL_SWAP) + HistoryDealGetDouble(d, DEAL_COMMISSION);
      }
   double dayOpen = iOpen(_Symbol, PERIOD_D1, 0);
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetTicket(i) == 0 || !IsManualSelected()) continue;
      pl += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
      if((datetime)PositionGetInteger(POSITION_TIME) < dayStart && dayOpen > 0)
      {
         // tru phan lai/lo da co tu truoc 0:00 (gia vao -> gia mo cua ngay)
         bool b = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY;
         double p0 = 0;
         if(OrderCalcProfit(b ? ORDER_TYPE_BUY : ORDER_TYPE_SELL, _Symbol, PositionGetDouble(POSITION_VOLUME),
                            PositionGetDouble(POSITION_PRICE_OPEN), dayOpen, p0)) pl -= p0;
      }
   }
   // Lenh mo tu truoc 0:00 va da dong hom nay: phan lai/lo truoc 0:00 nam trong deal dong -> tru ra
   if(HistorySelect(dayStart, TimeCurrent() + 60))
      for(int i = HistoryDealsTotal() - 1; i >= 0; i--)
      {
         ulong d = HistoryDealGetTicket(i);
         if(d == 0 || HistoryDealGetInteger(d, DEAL_MAGIC) != 0 || HistoryDealGetString(d, DEAL_SYMBOL) != _Symbol) continue;
         if(HistoryDealGetInteger(d, DEAL_ENTRY) == DEAL_ENTRY_IN) continue;
         ulong pos = (ulong)HistoryDealGetInteger(d, DEAL_POSITION_ID);
         double vol = HistoryDealGetDouble(d, DEAL_VOLUME);
         long   dt  = HistoryDealGetInteger(d, DEAL_TYPE);            // deal dong Sell = vi the Buy
         if(!HistorySelectByPosition(pos)) break;
         double op = 0; datetime ot = 0;
         for(int j = 0; j < HistoryDealsTotal(); j++)
         {
            ulong e = HistoryDealGetTicket(j);
            if(HistoryDealGetInteger(e, DEAL_ENTRY) == DEAL_ENTRY_IN) { op = HistoryDealGetDouble(e, DEAL_PRICE); ot = (datetime)HistoryDealGetInteger(e, DEAL_TIME); break; }
         }
         double p0 = 0;
         if(ot > 0 && ot < dayStart && dayOpen > 0 &&
            OrderCalcProfit(dt == DEAL_TYPE_SELL ? ORDER_TYPE_BUY : ORDER_TYPE_SELL, _Symbol, vol, op, dayOpen, p0)) pl -= p0;
         if(!HistorySelect(dayStart, TimeCurrent() + 60)) break;    // chon lai lich su ngay de lap tiep
      }
   return pl;
}

//--- Chot loi lenh tay (v5.10.4): hoa von o InpGuardBreakevenR x R, roi keo SL theo InpGuardTrailATR x ATR khung InpGuardTrailTFmin.
// R = khoang cach gia vao -> SL luc bot thay lenh lan dau (luu Global Variable theo ticket, qua khoi dong lai).
// Khong dat / sua TP. Chi dich SL theo huong co loi, khong bao gio noi SL ra.
int g_gATR = INVALID_HANDLE;

double GuardInitialR(const ulong t, const double open, const double sl)
{
   string n = GKey("r" + IntegerToString((long)t));
   if(GlobalVariableCheck(n)) return GlobalVariableGet(n);
   if(sl <= 0) return 0;
   double r = MathAbs(open - sl);
   GlobalVariableSet(n, r);
   return r;
}

// Khung (phut) cho keo SL va dem nen: InpGuardTrailTFmin, 0 = theo khung tu vao lenh (v5.10.8)
int GuardTFmin() { return InpGuardTrailTFmin > 0 ? InpGuardTrailTFmin : InpGuardAutoEntry ? InpGuardAutoTFmin : 15; }

void GuardExitRelease();
void GuardRelease() { if(g_gATR != INVALID_HANDLE) IndicatorRelease(g_gATR); g_gATR = INVALID_HANDLE; GuardExitRelease(); }

void GuardProfitLock(const ulong t, const bool buy, const double open, const double sl, const double tp)
{
   if(InpGuardBreakevenR <= 0 && InpGuardTrailATR <= 0 && InpGuardTPR <= 0) return;
   double r = GuardInitialR(t, open, sl);
   if(r <= 0 || sl <= 0) return;
   double px   = buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double gain = buy ? px - open : open - px;
   double rNow = gain / r;
   double spr  = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * _Point;
   double be   = buy ? open + spr : open - spr;                 // hoa von + bu spread
   bool   beDone = buy ? sl >= open : sl <= open;
   double nsl  = sl;
   double ntp  = tp;
   // TP co dinh theo R (v5.10.8): chi dat cho lenh chua co TP. Bat chot gop (InpGuardBasketR, v5.10.9) thi khong dat TP tung lop.
   if(InpGuardTPR > 0 && InpGuardBasketR <= 0 && tp <= 0) ntp = NormalizeDouble(buy ? open + InpGuardTPR * r : open - InpGuardTPR * r, _Digits);

   if(InpGuardBreakevenR > 0 && rNow >= InpGuardBreakevenR && !beDone) nsl = be;
   // trailing chi bat dau sau khi da hoa von (hoac khi tat hoa von: tu luc co lai 1R)
   double startR = InpGuardBreakevenR > 0 ? InpGuardBreakevenR : 1.0;
   if(InpGuardTrailATR > 0 && rNow >= startR)
   {
      if(g_gATR == INVALID_HANDLE) g_gATR = iATR(_Symbol, TFFromMin(GuardTFmin()), 14);
      double atr;
      if(g_gATR != INVALID_HANDLE && GetValue(g_gATR, 0, 1, atr) && atr > 0)
      {
         double cand = buy ? px - atr * InpGuardTrailATR : px + atr * InpGuardTrailATR;
         if(buy ? cand > nsl : cand < nsl) nsl = cand;
      }
   }
   nsl = NormalizeDouble(nsl, _Digits);
   double minStep = MathMax(_Point * 10, r * 0.05);             // tranh sua lenh lien tuc
   double minDist = (SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) + 1) * _Point + spr;
   bool better = buy ? nsl > sl + minStep : nsl < sl - minStep;
   bool valid  = buy ? px - nsl > minDist : nsl - px > minDist;
   if(!better || !valid) nsl = sl;
   bool tpNew  = ntp != tp && (buy ? ntp - px > minDist : px - ntp > minDist);
   if(!tpNew) ntp = tp;
   if(nsl == sl && ntp == tp) return;
   bool toBE = !beDone && (buy ? nsl >= open : nsl <= open);
   if(PrepSend() && TradeDone(trade.PositionModify(t, nsl, ntp), nsl != sl ? "Sua SL" : "Dat TP", "lenh tay #" + (string)t) && toBE)
      Notify(StringFormat("[%s] BAO VE LENH TAY: lenh #%I64u lai %.1fR, da doi SL ve hoa von %.2f. Tu gio lenh nay khong con lo; bot keo SL theo gia.",
                          _Symbol, t, rNow, nsl));
}

void GuardManual()
{
   if(!InpGuardManual || MQLInfoInteger(MQL_TESTER)) return;
   if(GetTickCount64() - g_gLast < 1000) return;              // moi giay (truoc v5.10.13: 2 giay)
   g_gLast = GetTickCount64();
   if(!GuardOwner()) return;                                  // chart khac cung ma dang bao ve

   MqlDateTime dt; TimeToStruct(TimeCurrent(), dt);
   datetime dayStart = TimeCurrent() - (dt.hour * 3600 + dt.min * 60 + dt.sec);
   datetime since = GuardSince();

   // Lan dau trong phien nay: ghi nho lenh dang co de khong coi chung la "lenh moi" (luat chan nhoi lenh chi xet lenh moi)
   if(!g_gInit)
   {
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         ulong t = PositionGetTicket(i);
         if(t != 0 && IsManualSelected()) GuardMark(t);
      }
      g_gInit = true;
   }

   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   // 0) Sut giam ca tai khoan tu dinh (InpGuardMaxDDPct): dung han, coi nhu khoa (dong lenh tay, khong tu vao / nhoi)
   GuardCheckAcctDD(eq);
   // 1) Lo trong ngay cua lenh tay vuot gioi han: dong het, khoa toi het ngay
   bool locked = GuardDayLocked();
   if(InpGuardDayLossPct > 0 && !locked)
   {
      double pl = GuardManualDayPL(dayStart);
      double base = eq - pl;                                  // uoc tinh von dau ngay
      if(base > 0 && pl <= -base * InpGuardDayLossPct / 100.0)
      {
         locked = true; GuardSetDayLock();                    // luu qua khoi dong lai, het hieu luc sang ngay moi
         Notify(StringFormat("[%s] BAO VE LENH TAY: lenh tay lo %.1f%% trong ngay (gioi han %.1f%%). Dong het va khong cho lenh tay moi toi 0:00 (gio server).",
                             _Symbol, -pl / base * 100.0, InpGuardDayLossPct));
      }
   }

   GuardPending(locked, since, eq);                          // lenh cho dat tay (truoc khi khop)

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong t = PositionGetTicket(i);
      if(t == 0 || !IsManualSelected()) continue;
      bool isNew = !GuardSeen(t);
      if(isNew) GuardMark(t);
      if(!PositionSelectByTicket(t)) continue;
      bool   buy  = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY;
      double open = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl   = PositionGetDouble(POSITION_SL);
      double tp   = PositionGetDouble(POSITION_TP);
      double vol  = PositionGetDouble(POSITION_VOLUME);
      datetime ot = (datetime)PositionGetInteger(POSITION_TIME);

      // Dung han vi sut giam ca tai khoan (v5.10.14): dong CA lenh mo truoc khi bat bao ve. Lenh cu cung lam von sut,
      // diem dung khan cap khong duoc bo sot chung (truoc v5.10.14 chung bi bo qua vi luat "lenh cu chi canh bao").
      // Khoa lo ngay cung vay (v5.10.15): lai/lo lenh cu DA duoc tinh vao lo ngay (GuardManualDayPL), nen khi khoa cung dong chung,
      // khong de lenh cu tiep tuc lo sau khi da cham gioi han.
      if(locked) { GuardClose(t, GuardHalted() ? "dung han vi von tai khoan sut giam qua gioi han" : "da cham gioi han lo ngay cua lenh tay"); continue; }
      // Lenh mo truoc khi bat bao ve lan dau: chi canh bao 1 lan, khong tu sua / dong
      if(ot < since && !InpGuardOldTrades)
      {
         if((sl == 0 || locked) && ShouldNotify("gold" + IntegerToString((long)t), 24 * 3600))
            Notify(StringFormat("[%s] BAO VE LENH TAY: lenh cu #%I64u (mo truoc khi bat bao ve)%s. Bot KHONG tu sua lenh nay; dat InpGuardOldTrades = true neu muon.",
                                _Symbol, t, sl == 0 ? " chua co SL" : " dang trong ngay da cham gioi han lo"));
         continue;
      }
      if(locked) { GuardClose(t, GuardHalted() ? "dung han vi von tai khoan sut giam qua gioi han" : "da cham gioi han lo ngay cua lenh tay"); continue; }

      // 2) Nhoi them khi lenh cung chieu dang lo: dong lenh moi
      if(isNew && InpGuardNoAverage)
      {
         bool losingSame = false;
         for(int j = PositionsTotal() - 1; j >= 0; j--)
         {
            ulong u = PositionGetTicket(j);
            if(u == 0 || u == t || !IsManualSelected()) continue;
            if((PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) == buy &&
               PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP) < 0) { losingSame = true; break; }
         }
         if(losingSame) { GuardClose(t, "nhoi them vao lenh cung chieu dang lo (trung binh gia xuong)"); continue; }
         if(!PositionSelectByTicket(t)) continue;
      }

      // 3) Chua co SL: tu dat SL cach gia vao x%
      if(sl == 0 && InpGuardSLPct > 0)
      {
         int    dg  = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
         double px  = buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         double nsl = NormalizeDouble(buy ? open * (1 - InpGuardSLPct / 100.0) : open * (1 + InpGuardSLPct / 100.0), dg);
         if((buy && nsl >= px) || (!buy && nsl <= px)) { GuardClose(t, StringFormat("khong co SL va da lo qua %.1f%%", InpGuardSLPct)); continue; }
         if(PrepSend() && TradeDone(trade.PositionModify(t, nsl, tp), "Dat SL lenh tay"))
         {
            sl = nsl;
            Notify(StringFormat("[%s] BAO VE LENH TAY: lenh #%I64u chua co SL, da dat SL %.2f (cach gia vao %.1f%%).", _Symbol, t, nsl, InpGuardSLPct));
         }
      }

      // 4) Lenh qua to: neu cham SL ma lo hon x% von thi dong bot khoi luong
      if(sl > 0 && InpGuardMaxRiskPct > 0)
      {
         double pr = 0;
         if(OrderCalcProfit(buy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL, _Symbol, vol, open, sl, pr) && pr < 0)
         {
            double allow = eq * InpGuardMaxRiskPct / 100.0;
            if(-pr > allow * 1.05)
            {
               double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP), vmin = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
               double keep = MathFloor(vol * allow / -pr / step) * step;
               string why  = StringFormat("neu cham SL se lo %.1f%% von (gioi han %.1f%%)", -pr / eq * 100.0, InpGuardMaxRiskPct);
               if(keep < vmin - 1e-9) { GuardClose(t, why + ", lot nho nhat van qua rui ro"); continue; }
               if(PrepSend() && TradeDone(trade.PositionClosePartial(t, NormalizeDouble(vol - keep, 2)), "Giam lot lenh tay", why))
                  Notify(StringFormat("[%s] BAO VE LENH TAY: lenh #%I64u %s. Da giam tu %.2f xuong %.2f lot.", _Symbol, t, why, vol, keep));
               continue;
            }
         }
      }

      // 5) Chot loi: hoa von roi keo SL theo gia
      GuardProfitLock(t, buy, open, sl, tp);

      // 5b) Lenh chua toi hoa von sau InpGuardMaxBars nen cua khung vao lenh: dong (v5.10.8)
      if(InpGuardMaxBars > 0 && TimeCurrent() - ot >= (long)InpGuardMaxBars * GuardTFmin() * 60)
      {
         double r0 = GuardInitialR(t, open, sl);
         bool   be0 = buy ? sl >= open : sl <= open;
         double px0 = buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         double g0  = buy ? px0 - open : open - px0;
         if(r0 > 0 && !be0 && g0 < r0 * (InpGuardBreakevenR > 0 ? InpGuardBreakevenR : 1.0))
         {
            GuardClose(t, StringFormat("sau %d nen M%d van chua toi hoa von (khung nho de dao chieu, khong om lenh)", InpGuardMaxBars, GuardTFmin()));
            continue;
         }
      }

      // 6) Giu qua lau ma van lo: dong
      if(InpGuardMaxHoldH > 0 && TimeCurrent() - ot > InpGuardMaxHoldH * 3600 && GuardFloating(t) < 0)
         GuardClose(t, StringFormat("giu qua %d gio ma van lo (lenh giu qua 1 ngay la nhom lo nang nhat trong sao ke)", InpGuardMaxHoldH));
   }
}


//+------------------------------------------------------------------+
//| Lenh cho dat tay (v5.10.2): sua NGAY khi con dang cho, truoc khi khop
//|  - ngay da khoa lo: huy lenh cho
//|  - lenh cho cung chieu, gia vao te hon mot lenh tay dang lo (Buy Limit duoi Buy dang lo,
//|    Sell Limit tren Sell dang lo): huy - neu de khop thi bot cung dong ngay va mat spread
//|  - chua co SL: dat SL cach gia cho InpGuardSLPct %
//|  - cham SL lo hon InpGuardMaxRiskPct % von: MT5 khong cho sua lot lenh cho, nen huy
//|    va dat lai lenh cung loai, cung gia, SL, TP, han voi lot nho hon
//| Lenh cho dat truoc khi bat bao ve lan dau: chi canh bao (tru khi InpGuardOldTrades).
//+------------------------------------------------------------------+
bool IsManualPendingSelected()
{
   if(OrderGetInteger(ORDER_MAGIC) != 0 || OrderGetString(ORDER_SYMBOL) != _Symbol) return false;
   ENUM_ORDER_TYPE ty = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
   return ty == ORDER_TYPE_BUY_LIMIT || ty == ORDER_TYPE_SELL_LIMIT || ty == ORDER_TYPE_BUY_STOP ||
          ty == ORDER_TYPE_SELL_STOP || ty == ORDER_TYPE_BUY_STOP_LIMIT || ty == ORDER_TYPE_SELL_STOP_LIMIT;
}

bool PendingIsBuy(const ENUM_ORDER_TYPE ty)
{
   return ty == ORDER_TYPE_BUY_LIMIT || ty == ORDER_TYPE_BUY_STOP || ty == ORDER_TYPE_BUY_STOP_LIMIT;
}

string PendingName(const ENUM_ORDER_TYPE ty)
{
   switch(ty)
   {
      case ORDER_TYPE_BUY_LIMIT:       return "Buy Limit";
      case ORDER_TYPE_SELL_LIMIT:      return "Sell Limit";
      case ORDER_TYPE_BUY_STOP:        return "Buy Stop";
      case ORDER_TYPE_SELL_STOP:       return "Sell Stop";
      case ORDER_TYPE_BUY_STOP_LIMIT:  return "Buy Stop Limit";
      case ORDER_TYPE_SELL_STOP_LIMIT: return "Sell Stop Limit";
   }
   return "lenh cho";
}

void GuardDeletePending(const ulong ticket, const string what, const string reason)
{
   if(PrepSend() && TradeDone(trade.OrderDelete(ticket), "Huy lenh cho tay", reason))
      Notify(StringFormat("[%s] BAO VE LENH TAY: da huy %s #%I64u. Ly do: %s", _Symbol, what, ticket, reason));
}

void GuardPending(const bool locked, const datetime since, const double eq)
{
   if(!InpGuardPending) return;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong t = OrderGetTicket(i);
      if(t == 0 || !IsManualPendingSelected()) continue;
      ENUM_ORDER_TYPE ty = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      bool     buy   = PendingIsBuy(ty);
      string   name  = PendingName(ty);
      double   price = OrderGetDouble(ORDER_PRICE_OPEN);       // gia kich hoat (Stop Limit: gia Stop)
      double   lim   = OrderGetDouble(ORDER_PRICE_STOPLIMIT);  // gia Limit cua Stop Limit (0 voi loai khac)
      double   entry = lim > 0 ? lim : price;                  // gia se khop
      double   sl    = OrderGetDouble(ORDER_SL);
      double   tp    = OrderGetDouble(ORDER_TP);
      double   vol   = OrderGetDouble(ORDER_VOLUME_CURRENT);
      ENUM_ORDER_TYPE_TIME tt = (ENUM_ORDER_TYPE_TIME)OrderGetInteger(ORDER_TYPE_TIME);
      datetime exp   = (datetime)OrderGetInteger(ORDER_TIME_EXPIRATION);
      datetime setup = (datetime)OrderGetInteger(ORDER_TIME_SETUP);
      string   cmt   = OrderGetString(ORDER_COMMENT);

      // Dung han vi sut giam ca tai khoan (v5.10.14): huy CA lenh cho dat truoc khi bat bao ve - day la diem dung khan cap
      if(locked) { GuardDeletePending(t, name, GuardHalted() ? "dung han vi von tai khoan sut giam qua gioi han" : "da cham gioi han lo ngay cua lenh tay"); continue; }
      if(setup < since && !InpGuardOldTrades)
      {
         if((sl == 0 || locked) && ShouldNotify("gpold" + IntegerToString((long)t), 24 * 3600))
            Notify(StringFormat("[%s] BAO VE LENH TAY: %s cu #%I64u (dat truoc khi bat bao ve)%s. Bot KHONG tu sua lenh nay; dat InpGuardOldTrades = true neu muon.",
                                _Symbol, name, t, sl == 0 ? " chua co SL" : " trong ngay da cham gioi han lo"));
         continue;
      }
      if(locked) { GuardDeletePending(t, name, "da cham gioi han lo ngay cua lenh tay"); continue; }

      // 1) Lenh cho de nhoi vao lenh cung chieu dang lo, o gia te hon (trung binh gia xuong)
      if(InpGuardNoAverage)
      {
         ulong bad = 0;
         for(int j = PositionsTotal() - 1; j >= 0; j--)
         {
            ulong u = PositionGetTicket(j);
            if(u == 0 || !IsManualSelected()) continue;
            if((PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) != buy) continue;
            if(PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP) >= 0) continue;
            double op = PositionGetDouble(POSITION_PRICE_OPEN);
            if(buy ? entry < op : entry > op) { bad = u; break; }
         }
         if(bad != 0)
         {
            GuardDeletePending(t, name, StringFormat("nhoi vao lenh %s #%I64u dang lo o gia te hon (trung binh gia xuong)", buy ? "Buy" : "Sell", bad));
            continue;
         }
      }

      int dg = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
      // 2) Chua co SL: dat SL cach gia se khop x%
      if(sl == 0 && InpGuardSLPct > 0)
      {
         double nsl = NormalizeDouble(buy ? entry * (1 - InpGuardSLPct / 100.0) : entry * (1 + InpGuardSLPct / 100.0), dg);
         if(PrepSend() && TradeDone(trade.OrderModify(t, price, nsl, tp, tt, exp, lim), "Dat SL lenh cho tay"))
         {
            sl = nsl;
            Notify(StringFormat("[%s] BAO VE LENH TAY: %s #%I64u chua co SL, da dat SL %.2f (cach gia vao %.1f%%).", _Symbol, name, t, nsl, InpGuardSLPct));
         }
         else continue;                                        // thu lai lan sau
      }

      // 3) Lot qua to: huy roi dat lai voi lot nho hon (MT5 khong sua duoc lot lenh cho)
      if(sl > 0 && InpGuardMaxRiskPct > 0)
      {
         double pr = 0;
         if(OrderCalcProfit(buy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL, _Symbol, vol, entry, sl, pr) && pr < 0)
         {
            double allow = eq * InpGuardMaxRiskPct / 100.0;
            if(-pr > allow * 1.05)
            {
               double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP), vmin = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
               double keep = NormalizeDouble(MathFloor(vol * allow / -pr / step) * step, 2);
               string why  = StringFormat("neu khop roi cham SL se lo %.1f%% von (gioi han %.1f%%)", -pr / eq * 100.0, InpGuardMaxRiskPct);
               if(keep < vmin - 1e-9) { GuardDeletePending(t, name, why + ", lot nho nhat van qua rui ro"); continue; }
               if(!(PrepSend() && TradeDone(trade.OrderDelete(t), "Huy lenh cho tay de giam lot", why))) continue;
               ulong magic = P_Magic;
               trade.SetExpertMagicNumber(0);                  // lenh dat lai van la lenh tay
               bool sent = PrepSend() && trade.OrderOpen(_Symbol, ty, keep, lim, price, sl, tp, tt, exp, cmt);
               uint rc = trade.ResultRetcode();
               bool ok = sent && (rc == TRADE_RETCODE_PLACED || rc == TRADE_RETCODE_DONE);   // lenh cho: PLACED la thanh cong
               if(!ok) Print(StringFormat("[%s] Dat lai lenh cho tay that bai: %u %s", _Symbol, rc, trade.ResultRetcodeDescription()));
               trade.SetExpertMagicNumber(magic);
               if(ok)
               {
                  ulong nt = trade.ResultOrder();
                  Notify(StringFormat("[%s] BAO VE LENH TAY: %s #%I64u %s. Da dat lai thanh #%I64u voi %.2f lot (thay %.2f).", _Symbol, name, t, why, nt, keep, vol));
               }
               else
                  Notify(StringFormat("[%s] BAO VE LENH TAY: da huy %s #%I64u (%s) nhung KHONG dat lai duoc lenh %.2f lot. Hay tu dat lai neu van muon vao.", _Symbol, name, t, why, keep));
            }
         }
      }
   }
}
