//+------------------------------------------------------------------+
//| TrendBot/LiveR.mqh: Theo doi tong R khi chay that so voi backtest
//+------------------------------------------------------------------+
// Moi lenh da dong cua bot (magic P_Magic, ma cua chart): R = lai/lo rong / rui ro o SL luc vao.
// Nguong xem lai sau n lenh = E[R] * n - 2 * sd(R) * sqrt(n) (InpLiveExpR, InpLiveSdR lay tu backtest: cot E_R va do lech chuan).
// Duoi nguong: kha nang < 2,5% neu loi the trong backtest con dung -> dung lai va xem lai, khong tu sua cau hinh.
// Tinh theo tung vi the; voi nhoi lenh, backtest tinh theo dot nen chi so chi gan dung.

int      g_lrN      = 0;      // so lenh da dong co SL luc vao
double   g_lrSum    = 0;      // tong R
double   g_lrLimit  = 0;      // nguong xem lai o g_lrN lenh
datetime g_lrLast   = 0;

double LRRiskMoney(const ulong pid)
{
   if(!HistorySelectByPosition(pid)) return 0;
   for(int i = 0; i < HistoryDealsTotal(); i++)
   {
      ulong d = HistoryDealGetTicket(i);
      if(HistoryDealGetInteger(d, DEAL_ENTRY) != DEAL_ENTRY_IN) continue;
      ulong ord = (ulong)HistoryDealGetInteger(d, DEAL_ORDER);
      if(!HistoryOrderSelect(ord)) return 0;
      double sl = HistoryOrderGetDouble(ord, ORDER_SL);
      if(sl <= 0) return 0;
      double price = HistoryDealGetDouble(d, DEAL_PRICE), vol = HistoryDealGetDouble(d, DEAL_VOLUME);
      double tsz = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE), tv = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
      return tsz > 0 ? MathAbs(price - sl) / tsz * tv * vol : 0;
   }
   return 0;
}

// Tinh lai moi 5 phut (quet lich su ton thoi gian). Tra ve false khi tat theo doi.
bool UpdateLiveR()
{
   if(InpLiveExpR <= 0 || InpLiveSdR <= 0) return false;
   if(MQLInfoInteger(MQL_TESTER)) return false;
   if(g_lrLast > 0 && TimeCurrent() - g_lrLast < 300) return true;
   g_lrLast = TimeCurrent();
   if(!HistorySelect(0, TimeCurrent() + 60)) return true;

   ulong ids[]; double net[];
   for(int i = 0; i < HistoryDealsTotal(); i++)
   {
      ulong d = HistoryDealGetTicket(i);
      if(d == 0) continue;
      if(HistoryDealGetString(d, DEAL_SYMBOL) != _Symbol || HistoryDealGetInteger(d, DEAL_MAGIC) != (long)P_Magic) continue;
      ulong pid = (ulong)HistoryDealGetInteger(d, DEAL_POSITION_ID);
      int k = -1;
      for(int j = 0; j < ArraySize(ids); j++) if(ids[j] == pid) { k = j; break; }
      if(k < 0) { k = ArraySize(ids); ArrayResize(ids, k + 1); ArrayResize(net, k + 1); ids[k] = pid; net[k] = 0; }
      net[k] += HistoryDealGetDouble(d, DEAL_PROFIT) + HistoryDealGetDouble(d, DEAL_SWAP) +
                HistoryDealGetDouble(d, DEAL_COMMISSION) + HistoryDealGetDouble(d, DEAL_FEE);
   }

   int n = 0; double sum = 0;
   for(int j = 0; j < ArraySize(ids); j++)
   {
      if(PositionSelectByTicket(ids[j])) continue;       // con mo: chua tinh
      double risk = LRRiskMoney(ids[j]);
      if(risk <= 0) continue;
      sum += net[j] / risk; n++;
   }
   g_lrN = n; g_lrSum = sum;
   g_lrLimit = InpLiveExpR * n - 2.0 * InpLiveSdR * MathSqrt((double)n);

   // Bao 1 lan khi lan dau xuong duoi nguong (sau it nhat 10 lenh), nho qua GlobalVariable
   string key = "TBLR_" + IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)) + "_" + _Symbol + "_" + IntegerToString((long)P_Magic);
   if(n >= 10 && sum < g_lrLimit)
   {
      if(!GlobalVariableCheck(key))
      {
         GlobalVariableSet(key, n);
         Notify(StringFormat("TrendBot %s: tong R that %+.1fR sau %d lenh, duoi nguong xem lai %+.1fR. Dung bot va xem lai, khong tu sua cau hinh.",
                             _Symbol, sum, n, g_lrLimit));
      }
   }
   else if(GlobalVariableCheck(key)) GlobalVariableDel(key);
   return true;
}
//+------------------------------------------------------------------+
