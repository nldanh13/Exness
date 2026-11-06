//+------------------------------------------------------------------+
//| TrendBot/Core.mqh: Bien chung, ten bien toan cuc, tien ich gui lenh, vi the cua bot
//+------------------------------------------------------------------+
CTrade   trade;
int      hFast = INVALID_HANDLE, hTrend = INVALID_HANDLE, hATR = INVALID_HANDLE;
int      hHTF  = INVALID_HANDLE, hADX   = INVALID_HANDLE;
int      hMkt  = INVALID_HANDLE;
int      hRSI  = INVALID_HANDLE;
int      hATRD1 = INVALID_HANDLE, hBB = INVALID_HANDLE;
double   g_sigSL = 0, g_sigTP = 0;       // SL (khoang cach) / TP (gia) do chien luoc dat; 0 = dung mac dinh ATR / RR
datetime g_fvgUsed = 0;                  // FVG da vao lenh (moi khoang trong chi vao 1 lan)
double   g_rsi = 50;
string   g_mktSym = "";
datetime lastBarTime    = 0;
datetime lastPanel      = 0;
double   dayStartEquity = 0;     // "Von cua bot" luc dau ngay
double   g_closedPL     = 0;     // Lai/lo da dong cua bot tu moc (epoch)
double   g_closedToday  = 0;     // Lai/lo da dong cua bot trong ngay
bool     g_plDirty      = true;  // Can tinh lai tu lich su
datetime g_lastPLCalc   = 0;
int      currentDay     = -1;
bool     dailyNotified  = false;
string   g_status         = "Khoi dong";
datetime lastLossTime   = 0;

//+------------------------------------------------------------------+
// Ten bien trang thai gan voi tai khoan + symbol + magic, tranh xung dot giua nhieu bieu do / tai khoan
string GVName(const string key)
{
   return "BTCEA_" + (string)AccountInfoInteger(ACCOUNT_LOGIN) + "_" + _Symbol + "_" + (string)P_Magic + "_" + key;
}

// Gioi han thong bao: moi loai (key) toi da 1 lan moi `seconds` giay
string   g_ntKeys[];
datetime g_ntTimes[];
bool ShouldNotify(const string key, const int seconds)
{
   int n = ArraySize(g_ntKeys);
   for(int i = 0; i < n; i++)
      if(g_ntKeys[i] == key)
      {
         if(TimeCurrent() - g_ntTimes[i] < seconds) return false;
         g_ntTimes[i] = TimeCurrent();
         return true;
      }
   ArrayResize(g_ntKeys, n + 1);
   ArrayResize(g_ntTimes, n + 1);
   g_ntKeys[n]  = key;
   g_ntTimes[n] = TimeCurrent();
   return true;
}

// Xac nhan server da thuc hien lenh (khong chi dua vao gia tri tra ve cua CTrade).
// `kind` la loai thao tac (khong kem so ticket) de gom thong bao trung.
// Xoa ma loi cu ngay truoc khi gui lenh, de GetLastError() trong TradeDone dung la loi cua lan nay.
// Dung: PrepSend() && trade.Xxx(...)  (&& dung ngay sau PrepSend nen khong anh huong ket qua)
bool PrepSend() { ResetLastError(); return true; }

bool TradeDone(const bool sent, const string kind, const string detail = "")
{
   uint rc = trade.ResultRetcode();
   // Chi DONE / DONE_PARTIAL moi la da khop; PLACED chi la da dat lenh, chua chac khop
   bool ok = sent && (rc == TRADE_RETCODE_DONE || rc == TRADE_RETCODE_DONE_PARTIAL);
   if(ok) return true;
   string msg;
   if(!sent && rc == 0)
      // Bi tu choi truoc khi gui len server: lay loi kiem tra cua lan nay, khong phai ma cu
      msg = StringFormat("[%s] %s %s chua gui duoc: kiem tra %u %s, loi %d", _Symbol, kind, detail,
                         trade.CheckResultRetcode(), trade.CheckResultRetcodeDescription(), GetLastError());
   else
      msg = StringFormat("[%s] %s %s that bai: %u %s", _Symbol, kind, detail, rc, trade.ResultRetcodeDescription());
   Print(msg);
   // Sua SL chi ghi log; cac loai khac bao ve dien thoai toi da 1 lan / 5 phut moi loai
   if(kind != "Sua SL" && ShouldNotify(kind, 300) && !MQLInfoInteger(MQL_TESTER))
   {
      if(P_PushNotify) SendNotification(msg);
      if(P_Telegram)   SendTelegram(msg);
   }
   return false;
}

bool IsHedging()
{
   return (ENUM_ACCOUNT_MARGIN_MODE)AccountInfoInteger(ACCOUNT_MARGIN_MODE) == ACCOUNT_MARGIN_MODE_RETAIL_HEDGING;
}

// Vi the (theo POSITION_IDENTIFIER) con mo khong
bool PositionOpenById(const ulong id)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
      if(PositionGetTicket(i) != 0 && (ulong)PositionGetInteger(POSITION_IDENTIFIER) == id) return true;
   return false;
}

//--- Moi Magic + ma chi duoc 1 bot dung. Moi bot ghi 1 bien Temp mang so chart cua minh trong TEN bien
// (gia tri double khong chua du so chart). Bien Temp tu mat khi tat MT5, nen khong bi ket sau khi may sap.
string MagicPrefix() { return "BTCEA_" + IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)) + "_OWN_" + _Symbol + "_" + (string)P_Magic + "_"; }
bool ClaimMagic()
{
   string pre = MagicPrefix();
   for(int i = GlobalVariablesTotal() - 1; i >= 0; i--)
   {
      string n = GlobalVariableName(i);
      if(StringFind(n, pre) != 0) continue;
      long other = StringToInteger(StringSubstr(n, StringLen(pre)));
      if(other == ChartID()) continue;
      if(other != 0 && ChartSymbol(other) != "")          // chart kia van mo va van con bot
      {
         string msg = StringFormat("[%s] Da co bot khac dung Magic %I64u tren %s. Doi InpMagic hoac go bot kia.",
                                   _Symbol, P_Magic, _Symbol);
         Print(msg); Alert(msg);
         return false;
      }
      GlobalVariableDel(n);                                 // chart da dong: bien cu bo lai
   }
   GlobalVariableTemp(pre + IntegerToString(ChartID()));
   GlobalVariableSet(pre + IntegerToString(ChartID()), 1);
   return true;
}
void ReleaseMagic() { GlobalVariableDel(MagicPrefix() + IntegerToString(ChartID())); }

bool IsOwnSelected()
{
   return PositionGetString(POSITION_SYMBOL) == _Symbol &&
          PositionGetInteger(POSITION_MAGIC) == (long)P_Magic;
}

bool GetValue(const int handle, const int buffer, const int shift, double &value)
{
   double buf[];
   if(CopyBuffer(handle, buffer, shift, 1, buf) != 1) return false;
   value = buf[0];
   return true;
}

double NormalizeVolume(double lots)
{
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(step <= 0) step = 0.01;
   lots = MathFloor(lots / step + 1e-9) * step;
   int digits = (int)MathMax(0, MathCeil(-MathLog10(step)));
   return NormalizeDouble(lots, digits);
}

//--- Vi the ----------------------------------------------------------
bool HasOwnPosition()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetTicket(i) == 0) continue;
      if(IsOwnSelected()) return true;
   }
   return false;
}

void CloseAll()
{
   // Gioi han 1 lan moi 10 giay de khong spam lenh/thong bao khi server tu choi lien tuc
   static datetime lastTry = 0;
   if(TimeCurrent() - lastTry < 10) return;
   lastTry = TimeCurrent();
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !IsOwnSelected()) continue;
      TradeDone(PrepSend() && trade.PositionClose(ticket), "Dong lenh", "#" + (string)ticket);
   }
}
