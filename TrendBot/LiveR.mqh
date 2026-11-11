//+------------------------------------------------------------------+
//| TrendBot/LiveR.mqh: tong R da DONG, tach P_Magic va magic0 EA      |
//+------------------------------------------------------------------+
// R = net P/L / tong rui ro ban dau cua cac deal VAO vi the.
// POSITION_IDENTIFIER == DEAL_POSITION_ID; KHONG duoc dung ID lam ticket.
// Voi nhieu lenh nh oi, phan phoi theo tung vi the khac backtest tinh theo dot.
// Ket qua magic0 chi la quan sat, KHONG dung benchmark Donchian de canh bao.
int      g_lrN = 0, g_lrAutoN = 0;
double   g_lrSum = 0, g_lrAutoSum = 0, g_lrLimit = 0;
datetime g_lrLast = 0;

// 1 = giao dich P_Magic, 2 = magic 0 do EA auto/nh oi; 0 = khong theo doi.
// Chi phan loai tu deal VAO, khong dua vao Magic cua deal dong bang tay.
int LRDealSource(const ulong deal)
{
   if(HistoryDealGetInteger(deal, DEAL_ENTRY) != DEAL_ENTRY_IN) return 0;
   if(HistoryDealGetString(deal, DEAL_SYMBOL) != _Symbol) return 0;
   long mg = HistoryDealGetInteger(deal, DEAL_MAGIC);
   if(P_Magic != 0 && mg == (long)P_Magic) return 1;
   if(mg != 0) return 0;
   string comment = HistoryDealGetString(deal, DEAL_COMMENT);
   if(StringFind(comment, "TB tu vao") == 0 || StringFind(comment, "TB nhoi tay") == 0 ||
      GuardDealAuto(deal)) return 2;
   return 0;
}

// Tai vi the co the thay doi POSITION_TICKET khi server xu ly swap/service.
// Chi POSITION_IDENTIFIER moi bat bien trong suot vong doi vi the.
bool LRStillOpen(const ulong pid) { return PositionOpenById(pid); }

// Deal vao khop nhieu lan: tinh rui ro tung fill theo SL ban dau cua deal.
// OrderCalcProfit tra tien theo currency tai khoan, chinh xac hon gia tri tick co dinh.
double LREntryRisk(const ulong deal)
{
   long typ = HistoryDealGetInteger(deal, DEAL_TYPE);
   if(typ != DEAL_TYPE_BUY && typ != DEAL_TYPE_SELL) return 0;
   double vol = HistoryDealGetDouble(deal, DEAL_VOLUME);
   double entry = HistoryDealGetDouble(deal, DEAL_PRICE);
   double sl = HistoryDealGetDouble(deal, DEAL_SL);
   if(sl <= 0)
   {
      ulong order = (ulong)HistoryDealGetInteger(deal, DEAL_ORDER);
      if(order > 0 && HistoryOrderSelect(order)) sl = HistoryOrderGetDouble(order, ORDER_SL);
   }
   if(vol <= 0 || entry <= 0 || sl <= 0) return 0;
   double profit = 0;
   ENUM_ORDER_TYPE direction = typ == DEAL_TYPE_BUY ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   if(!OrderCalcProfit(direction, _Symbol, vol, entry, sl, profit) || profit >= 0) return 0;
   return -profit;
}

// Doc lich su 5 phut/lan; tat khi backtest. Khong tinh deal moi vao dang mo,
// hay partial close thanh mot lenh da DONG. Gom tat ca fee/swap theo POSITION_ID.
bool UpdateLiveR()
{
   if(MQLInfoInteger(MQL_TESTER)) return false;
   bool checkMain = InpLiveExpR > 0 && InpLiveSdR > 0;
   if(!checkMain && !InpGuardManual && !InpGuardAutoEntry) return false;
   if(g_lrLast > 0 && TimeCurrent() - g_lrLast < 300) return true;
   g_lrLast = TimeCurrent();

   datetime from = (datetime)GVGet("epoch", 0);
   if(!HistorySelect(from, TimeCurrent() + 60)) return true;
   ulong ids[];
   int kind[];
   double net[], risk[];
   for(int i = 0; i < HistoryDealsTotal(); i++)
   {
      ulong d = HistoryDealGetTicket(i);
      if(d == 0 || HistoryDealGetString(d, DEAL_SYMBOL) != _Symbol) continue;
      ulong pid = (ulong)HistoryDealGetInteger(d, DEAL_POSITION_ID);
      if(pid == 0) continue;
      int k = -1;
      for(int j = 0; j < ArraySize(ids); j++)
         if(ids[j] == pid) { k = j; break; }
      if(k < 0)
      {
         k = ArraySize(ids);
         ArrayResize(ids, k + 1); ArrayResize(kind, k + 1);
         ArrayResize(net, k + 1); ArrayResize(risk, k + 1);
         ids[k] = pid; kind[k] = 0; net[k] = 0; risk[k] = 0;
      }
      net[k] += HistoryDealGetDouble(d, DEAL_PROFIT) + HistoryDealGetDouble(d, DEAL_SWAP) +
                HistoryDealGetDouble(d, DEAL_COMMISSION) + HistoryDealGetDouble(d, DEAL_FEE);
      int source = LRDealSource(d);
      if(source != 0)
      {
         // 1 vi the khong duoc vua la thu cong vua la P_Magic tren Hedging.
         if(kind[k] == 0) kind[k] = source;
         if(kind[k] == source) risk[k] += LREntryRisk(d);
      }
   }
   int nMain = 0, nAuto = 0;
   double sumMain = 0, sumAuto = 0;
   for(int j = 0; j < ArraySize(ids); j++)
   {
      if(kind[j] == 0 || risk[j] <= 0 || LRStillOpen(ids[j])) continue;
      double r = net[j] / risk[j];
      if(kind[j] == 1) { nMain++; sumMain += r; }
      else if(kind[j] == 2) { nAuto++; sumAuto += r; }
   }
   g_lrN = nMain; g_lrSum = sumMain;
   g_lrAutoN = nAuto; g_lrAutoSum = sumAuto;
   g_lrLimit = checkMain ? InpLiveExpR * nMain - 2.0 * InpLiveSdR * MathSqrt((double)nMain) : 0;

   // Canh bao CHI cho P_Magic; thong ke magic0 chua co E[R], SD out-of-sample
   // de chon nguong, nen tuyet doi khong dung nguong Donchian cho magic0.
   string key = "TBLR_" + IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)) + "_" +
                _Symbol + "_" + IntegerToString((long)P_Magic);
   if(checkMain && nMain >= 10 && sumMain < g_lrLimit)
   {
      if(!GlobalVariableCheck(key))
      {
         GlobalVariableSet(key, nMain);
         Notify(StringFormat("TrendBot %s: P_Magic tong R thuc %+.1fR sau %d vi the, duoi nguong xem lai %+.1fR. Kiem tra ket qua, khong tu nang lot.",
                             _Symbol, sumMain, nMain, g_lrLimit));
      }
   }
   else if(GlobalVariableCheck(key)) GlobalVariableDel(key);
   return true;
}
//+------------------------------------------------------------------+
