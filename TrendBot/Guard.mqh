//+------------------------------------------------------------------+
//| TrendBot/Guard.mqh: Bao ve lenh vao tay (magic 0) tren ma cua chart
//| Rut ra tu sao ke giao dich tay 9/2025-3/2026: thang 66% lenh nhung lo vi
//|  - lenh khong SL giu qua dem (lenh giu > 1 ngay: thang 29%, chiem phan lon so lo)
//|  - nhoi them khi lenh dang lo (44% so lenh)
//|  - lenh qua to (> 0,5 lot lo, lenh nho lai)
//|  - vai ngay lo rat lon lien tiep
//| Chi chay that / demo (backtest khong co lenh tay). Bat bang InpGuardManual.
//+------------------------------------------------------------------+
ulong    g_gSeen[];            // lenh tay da xem (de chi xu ly "lenh moi" 1 lan)
bool     g_gInit      = false;
datetime g_gLast      = 0;

// Trang thai luu qua lan khoi dong lai (Global Variables cua terminal)
string GKey(const string k) { return "TBG_" + IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)) + "_" + _Symbol + "_" + k; }
int    GDayKey(const datetime t) { MqlDateTime d; TimeToStruct(t, d); return d.year * 10000 + d.mon * 100 + d.day; }
bool   GuardDayLocked() { string n = GKey("lock"); return GlobalVariableCheck(n) && (int)GlobalVariableGet(n) == GDayKey(TimeCurrent()); }
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

void GuardManual()
{
   if(!InpGuardManual || MQLInfoInteger(MQL_TESTER)) return;
   if(TimeCurrent() - g_gLast < 2) return;
   g_gLast = TimeCurrent();

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

      // Lenh mo truoc khi bat bao ve lan dau: chi canh bao 1 lan, khong tu sua / dong
      if(ot < since && !InpGuardOldTrades)
      {
         if((sl == 0 || locked) && ShouldNotify("gold" + IntegerToString((long)t), 24 * 3600))
            Notify(StringFormat("[%s] BAO VE LENH TAY: lenh cu #%I64u (mo truoc khi bat bao ve)%s. Bot KHONG tu sua lenh nay; dat InpGuardOldTrades = true neu muon.",
                                _Symbol, t, sl == 0 ? " chua co SL" : " dang trong ngay da cham gioi han lo"));
         continue;
      }
      if(locked) { GuardClose(t, "da cham gioi han lo ngay cua lenh tay"); continue; }

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

      // 5) Giu qua lau ma van lo: dong
      if(InpGuardMaxHoldH > 0 && TimeCurrent() - ot > InpGuardMaxHoldH * 3600 && GuardFloating(t) < 0)
         GuardClose(t, StringFormat("giu qua %d gio ma van lo (lenh giu qua 1 ngay la nhom lo nang nhat trong sao ke)", InpGuardMaxHoldH));
   }
}
