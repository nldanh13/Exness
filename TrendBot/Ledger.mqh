//+------------------------------------------------------------------+
//| TrendBot/Ledger.mqh: attribution by opening POSITION_IDENTIFIER   |
//| All exits inherit the origin of the opening position, NOT exit   |
//| DEAL_MAGIC.  Unknown history fails closed for new risk.          |
//+------------------------------------------------------------------+
bool g_ledgerHealthy = true;

// Source: 1 = human magic0; 2 = TrendBot auto magic0; 3 = magic != 0 EA.
// On hedging accounts a position has one opening origin; on netting we refuse to run.
bool LedgerOrigin(const ulong pid, string &sym, int &source, long &magic,
                  double &openPrice, datetime &opened, bool &wasBuy)
{
   source = 0; magic = -1; openPrice = 0; opened = 0; sym = ""; wasBuy = true;
   if(pid == 0 || !HistorySelectByPosition(pid)) return false;
   long firstMs = LONG_MAX;
   ulong firstDeal = 0;
   for(int i = 0; i < HistoryDealsTotal(); i++)
   {
      ulong d = HistoryDealGetTicket(i);
      if(d == 0 || HistoryDealGetInteger(d, DEAL_ENTRY) != DEAL_ENTRY_IN) continue;
      long ty = HistoryDealGetInteger(d, DEAL_TYPE);
      if(ty != DEAL_TYPE_BUY && ty != DEAL_TYPE_SELL) continue;
      long when = HistoryDealGetInteger(d, DEAL_TIME_MSC);
      if(firstDeal == 0 || when < firstMs || (when == firstMs && d < firstDeal))
      { firstMs = when; firstDeal = d; }
   }
   if(firstDeal == 0 || !HistoryDealSelect(firstDeal)) return false;
   sym = HistoryDealGetString(firstDeal, DEAL_SYMBOL);
   magic = HistoryDealGetInteger(firstDeal, DEAL_MAGIC);
   openPrice = HistoryDealGetDouble(firstDeal, DEAL_PRICE);
   opened = (datetime)HistoryDealGetInteger(firstDeal, DEAL_TIME);
   wasBuy = HistoryDealGetInteger(firstDeal, DEAL_TYPE) == DEAL_TYPE_BUY;
   if(sym == "" || openPrice <= 0) return false;
   if(magic != 0) { source = 3; return true; }

   string c = HistoryDealGetString(firstDeal, DEAL_COMMENT);
   string key = "TBG_" + IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)) + "_" + sym + "_";
   string id = IntegerToString((long)pid);
   source = (StringFind(c, "TB ") == 0 || GlobalVariableCheck(key + "bm" + id) ||
             GlobalVariableCheck(key + "ba" + id)) ? 2 : 1;
   return true;
}

// Tinh theo NGAY SERVER. bucket=0: tat ca magic0 cua _Symbol de bao ve lenh tay
// legacy; bucket=1: HUMAN magic0 moi symbol; bucket=2: EA (P_Magic va bot magic0,
// cung cac EA magic khac) moi symbol. Khong bo sot lenh dong voi magic khac.
// Khong co lich su mo lenh hoac khong co gia D1 => fail closed, caller khong
// duoc coi gia tri 0 la bang chung da khong lo.
bool LedgerDayPL(const int bucket, double &pl)
{
   pl = 0;
   datetime start = TimeCurrent() - TimeCurrent() % 86400;
   if(!HistorySelect(start, TimeCurrent() + 60)) { g_ledgerHealthy = false; return false; }
   ulong tickets[];
   int nd = HistoryDealsTotal();
   ArrayResize(tickets, nd);
   for(int i = 0; i < nd; i++) tickets[i] = HistoryDealGetTicket(i);
   // chi cache class theo identifier trong MOT LAN doi soat.
   ulong ids[]; int sources[]; string symbols[];
   double opens[]; datetime opened[]; bool buys[];
   int originN = 0;
   for(int i = 0; i < nd; i++)
   {
      ulong d = tickets[i];
      if(d == 0 || !HistoryDealSelect(d)) continue;
      long ty = HistoryDealGetInteger(d, DEAL_TYPE);
      if(ty != DEAL_TYPE_BUY && ty != DEAL_TYPE_SELL) continue;
      ulong pid = (ulong)HistoryDealGetInteger(d, DEAL_POSITION_ID);
      if(pid == 0) { g_ledgerHealthy = false; return false; }
      int k = -1;
      for(int j = 0; j < originN; j++) if(ids[j] == pid) { k = j; break; }
      if(k < 0)
      {
         string sm; int src; long mg; double op; datetime ot; bool by;
         if(!LedgerOrigin(pid, sm, src, mg, op, ot, by)) { g_ledgerHealthy = false; return false; }
         k = originN++;
         ArrayResize(ids, originN); ArrayResize(sources, originN); ArrayResize(symbols, originN);
         ArrayResize(opens, originN); ArrayResize(opened, originN); ArrayResize(buys, originN);
         ids[k] = pid; sources[k] = src; symbols[k] = sm;
         opens[k] = op; opened[k] = ot; buys[k] = by;
      }
      bool belongs = bucket == 0 ? (sources[k] != 3 && symbols[k] == _Symbol) :
                     bucket == 1 ? sources[k] == 1 : sources[k] >= 2;
      if(!belongs) continue;
      if(!HistoryDealSelect(d)) { g_ledgerHealthy = false; return false; }
      double net = HistoryDealGetDouble(d, DEAL_PROFIT) + HistoryDealGetDouble(d, DEAL_SWAP) +
                   HistoryDealGetDouble(d, DEAL_COMMISSION) + HistoryDealGetDouble(d, DEAL_FEE);
      long entry = HistoryDealGetInteger(d, DEAL_ENTRY);
      // Dong vi the mo tu hom truoc: phan gia tang tu 00:00, khong cong lai loi/l o cu.
      if((entry == DEAL_ENTRY_OUT || entry == DEAL_ENTRY_OUT_BY) && opened[k] < start)
      {
         double dayOpen = iOpen(symbols[k], PERIOD_D1, 0), oldPL = 0;
         if(dayOpen <= 0 || !OrderCalcProfit(buys[k] ? ORDER_TYPE_BUY : ORDER_TYPE_SELL,
                  symbols[k], HistoryDealGetDouble(d, DEAL_VOLUME), opens[k], dayOpen, oldPL))
         { g_ledgerHealthy = false; return false; }
         net -= oldPL;
      }
      pl += net;
   }
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetTicket(i) == 0) continue;
      ulong pid = (ulong)PositionGetInteger(POSITION_IDENTIFIER);
      string sm; int src; long mg; double op; datetime ot; bool by;
      bool found = false;
      for(int k = 0; k < originN; k++)
      {
         if(ids[k] == pid) { sm = symbols[k]; src = sources[k]; op = opens[k];
            ot = opened[k]; by = buys[k]; found = true; break; }
      }
      if(!found && !LedgerOrigin(pid, sm, src, mg, op, ot, by))
      { g_ledgerHealthy = false; return false; }
      bool belongs = bucket == 0 ? (src != 3 && sm == _Symbol) :
                     bucket == 1 ? src == 1 : src >= 2;
      if(!belongs) continue;
      pl += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
      if(ot < start)
      {
         double dayOpen = iOpen(sm, PERIOD_D1, 0), oldPL = 0;
         if(dayOpen <= 0 || !OrderCalcProfit(by ? ORDER_TYPE_BUY : ORDER_TYPE_SELL, sm,
                            PositionGetDouble(POSITION_VOLUME), op, dayOpen, oldPL))
         { g_ledgerHealthy = false; return false; }
         pl -= oldPL;
      }
   }
   g_ledgerHealthy = true;
   return true;
}

// Lich su cac deal dong co the mang magic cua nguoi dong; chi opening magic moi
// quyet dinh P_Magic. Cho phep ke toan lai/l o P_Magic khi close bang tay.
bool LedgerMainClosedPL(const datetime from, double &all, double &day)
{
   all = 0; day = 0;
   if(!HistorySelect(from, TimeCurrent() + 60)) return false;
   ulong tickets[];
   int n = HistoryDealsTotal(); ArrayResize(tickets, n);
   for(int i = 0; i < n; i++) tickets[i] = HistoryDealGetTicket(i);
   ulong ids[]; bool isOwn[];
   for(int i = 0; i < n; i++)
   {
      ulong d = tickets[i];
      if(d == 0 || !HistoryDealSelect(d)) continue;
      if(HistoryDealGetString(d, DEAL_SYMBOL) != _Symbol) continue;
      ulong pid = (ulong)HistoryDealGetInteger(d, DEAL_POSITION_ID);
      if(pid == 0) continue;
      int k = -1;
      for(int j = 0; j < ArraySize(ids); j++) if(ids[j] == pid) { k = j; break; }
      if(k < 0)
      {
         string sm; int src; long mg; double op; datetime ot; bool by;
         if(!LedgerOrigin(pid, sm, src, mg, op, ot, by)) return false;
         k = ArraySize(ids); ArrayResize(ids, k+1); ArrayResize(isOwn, k+1);
         ids[k] = pid; isOwn[k] = (mg == (long)P_Magic);
      }
      if(!isOwn[k] || !HistoryDealSelect(d)) continue;
      double net = HistoryDealGetDouble(d, DEAL_PROFIT) + HistoryDealGetDouble(d, DEAL_SWAP) +
                   HistoryDealGetDouble(d, DEAL_COMMISSION) + HistoryDealGetDouble(d, DEAL_FEE);
      all += net;
      if((datetime)HistoryDealGetInteger(d, DEAL_TIME) >= TimeCurrent()-TimeCurrent()%86400) day += net;
   }
   return true;
}
