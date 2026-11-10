//+------------------------------------------------------------------+
//| TrendBot/Panel.mqh: Bang thong tin tren bieu do
//+------------------------------------------------------------------+
//--- Bang thong tin ------------------------------------------------
int TradesToday()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   dt.hour = 0; dt.min = 0; dt.sec = 0;
   if(!HistorySelect(StructToTime(dt), TimeCurrent() + 60)) return 0;
   int n = 0;
   for(int i = HistoryDealsTotal() - 1; i >= 0; i--)
   {
      ulong d = HistoryDealGetTicket(i);
      if(d == 0) continue;
      if(HistoryDealGetString(d, DEAL_SYMBOL) == _Symbol &&
         HistoryDealGetInteger(d, DEAL_MAGIC) == (long)P_Magic &&
         HistoryDealGetInteger(d, DEAL_ENTRY) == DEAL_ENTRY_IN) n++;
   }
   return n;
}

//--- Nhac khi co lenh vao tay (Magic 0) tren cung tai khoan: gioi han lo ngay / sut giam cua bot khong tinh lenh do
void CheckManualTrades()
{
   if(MQLInfoInteger(MQL_TESTER)) return;
   static datetime last = 0;
   if(TimeCurrent() - last < 60) return;
   last = TimeCurrent();
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetTicket(i) == 0 || PositionGetInteger(POSITION_MAGIC) != 0) continue;
      if(ShouldNotify("manual", 6 * 3600))
         Notify(StringFormat("[%s] Co lenh vao tay (%s) tren tai khoan dang chay bot. Quy tac: khong giao dich tay song song voi bot; "
                             "gioi han lo cua bot khong tinh lenh nay.", _Symbol, PositionGetString(POSITION_SYMBOL)));
      break;
   }
}

//--- Bang thong tin: hop nen toi o goc trai tren, chu tieng Viet co dau (thay Comment() de khong de len nen)
#define PN_PFX "TBPN_"
#define PN_W   410

string PNMoney(const double v, const string cur)
{
   bool big = cur == "VND" || cur == "IDR" || cur == "USC";
   string s = DoubleToString(MathAbs(v), big ? 0 : 2);
   int dot = StringFind(s, ".");
   string ip = dot >= 0 ? StringSubstr(s, 0, dot) : s, fp = dot >= 0 ? StringSubstr(s, dot) : "";
   if(big) fp = ""; else StringReplace(fp, ".", ",");
   string out = "";
   for(int k = StringLen(ip); k > 0; k -= 3) out = StringSubstr(ip, MathMax(0, k - 3), MathMin(3, k)) + (out == "" ? "" : "." + out);
   return (v < 0 ? "-" : "") + out + fp + " " + cur;
}

void PNBox(const string name, const int x, const int y, const int w, const int h)
{
   string n = PN_PFX + name;
   if(ObjectFind(0, n) < 0)
   {
      ObjectCreate(0, n, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(0, n, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, n, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(0, n, OBJPROP_BGCOLOR, C'24,28,36');
      ObjectSetInteger(0, n, OBJPROP_COLOR, C'60,66,80');
      ObjectSetInteger(0, n, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, n, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, n, OBJPROP_BACK, false);
   }
   ObjectSetInteger(0, n, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, n, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, n, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, n, OBJPROP_YSIZE, h);
}

void PNText(const string name, const int x, const int y, const string text, const color c, const int size = 9, const string font = "Segoe UI")
{
   string n = PN_PFX + name;
   if(ObjectFind(0, n) < 0)
   {
      ObjectCreate(0, n, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, n, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, n, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
      ObjectSetInteger(0, n, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, n, OBJPROP_HIDDEN, true);
   }
   ObjectSetInteger(0, n, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, n, OBJPROP_YDISTANCE, y);
   ObjectSetString(0, n, OBJPROP_TEXT, text);
   ObjectSetString(0, n, OBJPROP_FONT, font);
   ObjectSetInteger(0, n, OBJPROP_FONTSIZE, size);
   ObjectSetInteger(0, n, OBJPROP_COLOR, c);
}

void PanelDelete() { ObjectsDeleteAll(0, PN_PFX); }

void UpdatePanel()
{
   CheckManualTrades();
   if(!P_ShowPanel) { PanelDelete(); return; }
   if(MQLInfoInteger(MQL_TESTER) && !MQLInfoInteger(MQL_VISUAL_MODE)) return;
   if(TimeCurrent() - lastPanel < 2) return;
   lastPanel = TimeCurrent();

   double eq    = BotEquity();
   double peak  = GVGet("peak", eq);
   double dayPL = DayPL();
   double dd    = peak > 0 ? (1.0 - BotEquityForLimits() / peak) * 100.0 : 0;   // cung cach tinh voi gioi han
   string cur   = AccountInfoString(ACCOUNT_CURRENCY);
   color  cTxt = C'205,210,220', cDim = C'130,138,152', cOk = C'90,200,120', cBad = C'235,95,85', cWarn = C'240,180,60';

   string txt[12]; color col[12]; int n = 0;
   bool guardOnly = InpGuardManual && !P_AllowBuy && !P_AllowSell && !P_ManualEntry;
   string strat = P_Strategy == STRAT_DONCHIAN ? "Donchian" : P_Strategy == STRAT_RSI_REVERT ? "RSI lướt sóng" : P_Strategy == STRAT_ORB ? "ORB phiên Mỹ" :
                  P_Strategy == STRAT_EXHAUST ? "Đảo chiều" : P_Strategy == STRAT_FVG ? "FVG" : P_Strategy == STRAT_SPRING ? "Spring/Upthrust" :
                  P_Strategy == STRAT_MACD ? "MACD đa khung" : P_Strategy == STRAT_IMOM ? "Quán tính trong ngày" : "EMA pullback";
   string head = "TrendBot v" + BOT_VERSION + "  ·  " + _Symbol + "  ·  " + (guardOnly ? "Bảo vệ lệnh tay" : P_ManualEntry ? "Tự bấm lệnh" : strat);

   if(guardOnly)
   {
      MqlDateTime dt; TimeToStruct(TimeCurrent(), dt);
      datetime dayStart = TimeCurrent() - (dt.hour * 3600 + dt.min * 60 + dt.sec);
      double mpl = GuardManualDayPL(dayStart);
      double base = AccountInfoDouble(ACCOUNT_EQUITY) - mpl;
      double pct = base > 0 ? mpl / base * 100.0 : 0;
      int pos = 0, pend = 0;
      for(int i = PositionsTotal() - 1; i >= 0; i--) if(PositionGetTicket(i) != 0 && IsManualSelected()) pos++;
      for(int i = OrdersTotal() - 1; i >= 0; i--) if(OrderGetTicket(i) != 0 && IsManualPendingSelected()) pend++;
      bool locked = GuardDayLocked();
      bool algo = (bool)TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) && (bool)MQLInfoInteger(MQL_TRADE_ALLOWED);
      txt[n] = algo ? (locked ? "ĐÃ KHÓA lệnh tay tới hết ngày" : "Đang canh lệnh tay") : "Algo Trading đang TẮT: bot không sửa được lệnh";
      col[n++] = algo ? (locked ? cBad : cOk) : cBad;
      txt[n] = "Số dư: " + PNMoney(AccountInfoDouble(ACCOUNT_BALANCE), cur);  col[n++] = cTxt;
      txt[n] = StringFormat("Lãi/lỗ tay hôm nay: %s (%+.1f%% / giới hạn -%.0f%%)", PNMoney(mpl, cur), pct, InpGuardDayLossPct);
      col[n++] = mpl < 0 ? (pct <= -InpGuardDayLossPct * 0.6 ? cBad : cWarn) : cOk;
      txt[n] = StringFormat("Lệnh tay đang mở: %d   ·   Lệnh chờ: %d", pos, pend);  col[n++] = cTxt;
      txt[n] = StringFormat("Luật: SL tự đặt %.2f%%  ·  rủi ro tối đa %.0f%%/lệnh", InpGuardSLPct, InpGuardMaxRiskPct);  col[n++] = cDim;
      txt[n] = (InpGuardNoAverage ? "Cấm nhồi vào lệnh lỗ" : "Cho nhồi vào lệnh lỗ") +
               (InpGuardMaxHoldH > 0 ? StringFormat("  ·  đóng lệnh lỗ sau %d giờ", InpGuardMaxHoldH) : "");  col[n++] = cDim;
   }
   else
   {
      txt[n] = IsHalted() ? "DỪNG HẲN (sụt giảm)" : g_status;  col[n++] = IsHalted() ? cBad : cOk;
      txt[n] = "Vốn của bot: " + PNMoney(eq, cur);  col[n++] = cTxt;
      txt[n] = StringFormat("Lãi/lỗ hôm nay: %s (%+.2f%%)%s", PNMoney(dayPL, cur), dayStartEquity > 0 ? dayPL / dayStartEquity * 100.0 : 0,
                            DailyLocked() ? "  ĐÃ KHÓA" : "");
      col[n++] = DailyLocked() ? cBad : dayPL < 0 ? cBad : cTxt;
      txt[n] = StringFormat("Đã đóng hôm nay: %s  ·  Lệnh: %d", PNMoney(g_closedToday, cur), TradesToday());  col[n++] = cTxt;
      txt[n] = StringFormat("Sụt giảm từ đỉnh: %.2f%% / giới hạn %.1f%%", dd, P_MaxDrawdownPct);  col[n++] = dd > P_MaxDrawdownPct * 0.6 ? cWarn : cTxt;
      if(P_UseFunding) { txt[n] = "Funding: " + (g_fundState == "" ? "chưa kiểm tra" : g_fundState); col[n++] = cDim; }
   }
   txt[n] = StringFormat("Spread: %d point", (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD));  col[n++] = cDim;

   int x = 8, y = 22, lh = 17;
   PNBox("bg", x, y, PN_W, 34 + n * lh);
   PNText("h", x + 10, y + 6, head, C'120,170,255', 9, "Segoe UI Semibold");
   for(int i = 0; i < 12; i++)
   {
      if(i < n) PNText("l" + IntegerToString(i), x + 10, y + 26 + i * lh, txt[i], col[i], 9);
      else ObjectDelete(0, PN_PFX + "l" + IntegerToString(i));
   }
   ChartRedraw();
}

//+------------------------------------------------------------------+
