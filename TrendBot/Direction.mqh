//+------------------------------------------------------------------+
//| TrendBot/Direction.mqh - SHADOW directional forecasts (M15)      |
//| v5.43 experimental: OBSERVATION ONLY. Never alter trades/risk.   |
//| Dow D1, EMA H4+D1, MACD H4, H4 price structure vote once each.   |
//| Inputs and forecasts use CLOSED candles; score at +4/+8/+16 M15.|
//+------------------------------------------------------------------+
#define DIR_SOURCES 4
struct DirForecast
{
   datetime t;
   double entry, atr, spread;
   int ensemble, dow, ema, macd, structure, done;
};
DirForecast g_dirOpen[];
datetime g_dirLastBar = 0;
bool g_dirLoaded = false, g_dirIoWarned = false;
int g_dirEmaH4 = INVALID_HANDLE, g_dirEmaD1 = INVALID_HANDLE;
int g_dirMacdH4 = INVALID_HANDLE, g_dirAtrM15 = INVALID_HANDLE;
int g_dirLastVote = 0, g_dirLastAgree = 0, g_dirLastDisagree = 0;
int g_dirLastDow = 0, g_dirLastEma = 0, g_dirLastMacd = 0, g_dirLastStructure = 0;
string g_dirLastSummary = "chua co du lieu";
int g_dirLogged = 0, g_dirResolved = 0;

// Account + symbol + EA magic: no cross-chart writes or accidental mixing.
string DirFile()
{
   return StringFormat("TrendBot_huong_%I64d_%s_%I64d_M15.csv",
                       AccountInfoInteger(ACCOUNT_LOGIN), _Symbol, (long)P_Magic);
}
string DirPendingFile()
{
   return StringFormat("TrendBot_huong_mo_%I64d_%s_%I64d_M15.txt",
                       AccountInfoInteger(ACCOUNT_LOGIN), _Symbol, (long)P_Magic);
}
string DirName(const int v) { return v > 0 ? "TANG" : v < 0 ? "GIAM" : "DUNG NGOAI"; }

// Show the same four votes before and AFTER restart. The most recent
// pending forecast is authoritative for the last CLOSED M15 bar.
void DirApplySnapshot(const DirForecast &r)
{
   int votes[4]; votes[0] = r.dow; votes[1] = r.ema;
   votes[2] = r.macd; votes[3] = r.structure;
   int up = 0, down = 0;
   for(int i = 0; i < 4; i++) { if(votes[i] > 0) up++; else if(votes[i] < 0) down++; }
   g_dirLastAgree = MathMax(up, down); g_dirLastDisagree = MathMin(up, down);
   g_dirLastVote = r.ensemble;
   g_dirLastDow = r.dow; g_dirLastEma = r.ema;
   g_dirLastMacd = r.macd; g_dirLastStructure = r.structure;
   g_dirLastSummary = StringFormat("M15: %s (%d/4, nguoc %d), Dow %s | EMA %s | MACD %s | H4 %s. CHI QUAN SAT",
                                  DirName(g_dirLastVote), g_dirLastAgree, g_dirLastDisagree,
                                  DirName(g_dirLastDow), DirName(g_dirLastEma),
                                  DirName(g_dirLastMacd), DirName(g_dirLastStructure));
}

bool DirInitHandles()
{
   if(g_dirEmaH4 == INVALID_HANDLE) g_dirEmaH4 = iMA(_Symbol, PERIOD_H4, 50, 0, MODE_EMA, PRICE_CLOSE);
   if(g_dirEmaD1 == INVALID_HANDLE) g_dirEmaD1 = iMA(_Symbol, PERIOD_D1, 50, 0, MODE_EMA, PRICE_CLOSE);
   if(g_dirMacdH4 == INVALID_HANDLE) g_dirMacdH4 = iMACD(_Symbol, PERIOD_H4, 12, 26, 9, PRICE_CLOSE);
   if(g_dirAtrM15 == INVALID_HANDLE) g_dirAtrM15 = iATR(_Symbol, PERIOD_M15, 14);
   return g_dirEmaH4 != INVALID_HANDLE && g_dirEmaD1 != INVALID_HANDLE &&
          g_dirMacdH4 != INVALID_HANDLE && g_dirAtrM15 != INVALID_HANDLE;
}
void DirRelease()
{
   if(g_dirEmaH4 != INVALID_HANDLE) IndicatorRelease(g_dirEmaH4);
   if(g_dirEmaD1 != INVALID_HANDLE) IndicatorRelease(g_dirEmaD1);
   if(g_dirMacdH4 != INVALID_HANDLE) IndicatorRelease(g_dirMacdH4);
   if(g_dirAtrM15 != INVALID_HANDLE) IndicatorRelease(g_dirAtrM15);
   g_dirEmaH4 = g_dirEmaD1 = g_dirMacdH4 = g_dirAtrM15 = INVALID_HANDLE;
}
// One line per forecast (F) and horizon result (R). Evaluated R always
// refers to the original forecast date and EXACTLY h later closed M15 bars.
void DirAppend(const string row)
{
   if(MQLInfoInteger(MQL_TESTER)) return;
   string f = DirFile();
   bool fresh = !FileIsExist(f, FILE_COMMON);
   int h = FileOpen(f, FILE_READ | FILE_WRITE | FILE_TXT | FILE_ANSI |
                      FILE_COMMON | FILE_SHARE_READ);
   if(h == INVALID_HANDLE)
   {
      if(!g_dirIoWarned) { Print("DU DOAN HUONG: khong ghi duoc CSV ", f, " err=", GetLastError()); g_dirIoWarned = true; }
      return;
   }
   FileSeek(h, 0, SEEK_END);
   if(fresh) FileWriteString(h, "event,t_m15_server_epoch,horizon,entry,close,delta_price,atr_m15,spread,ensemble,dow,ema,macd,structure,label\r\n");
   FileWriteString(h, row + "\r\n");
   FileClose(h);
}
string DirRow(const string event, const DirForecast &r, const int horizon,
              const double close, const string outcome)
{
   return StringFormat("%s,%I64d,%d,%.8f,%.8f,%.8f,%.8f,%.8f,%d,%d,%d,%d,%d,%s",
                       event, (long)r.t, horizon, r.entry, close, close > 0 ? close - r.entry : 0,
                       r.atr, r.spread, r.ensemble, r.dow, r.ema, r.macd, r.structure, outcome);
}
// Persist unresolved forecasts across terminal restart; never replay them
// as new forecasts or label from hindsight. lastbar survives empty queues.
void DirSavePending()
{
   if(MQLInfoInteger(MQL_TESTER)) return;
   int h = FileOpen(DirPendingFile(), FILE_WRITE | FILE_TXT | FILE_ANSI |
                     FILE_COMMON | FILE_SHARE_READ);
   if(h == INVALID_HANDLE) return;
   FileWriteString(h, StringFormat("LAST,%I64d\r\n", (long)g_dirLastBar));
   for(int i = 0; i < ArraySize(g_dirOpen); i++)
   {
      DirForecast r = g_dirOpen[i];
      FileWriteString(h, StringFormat("P,%I64d,%.8f,%.8f,%.8f,%d,%d,%d,%d,%d,%d\r\n",
                                     (long)r.t, r.entry, r.atr, r.spread,
                                     r.ensemble, r.dow, r.ema, r.macd, r.structure, r.done));
   }
   FileClose(h);
}
void DirLoadPending()
{
   if(g_dirLoaded) return;
   g_dirLoaded = true;
   ArrayResize(g_dirOpen, 0);
   if(MQLInfoInteger(MQL_TESTER)) return;
   int h = FileOpen(DirPendingFile(), FILE_READ | FILE_TXT | FILE_ANSI |
                     FILE_COMMON | FILE_SHARE_READ | FILE_SHARE_WRITE);
   if(h == INVALID_HANDLE) return;
   while(!FileIsEnding(h))
   {
      string p[];
      int n = StringSplit(FileReadString(h), ',', p);
      if(n >= 2 && p[0] == "LAST")
         g_dirLastBar = (datetime)StringToInteger(p[1]);
      else if(n == 11 && p[0] == "P")
      {
         DirForecast r;
         r.t = (datetime)StringToInteger(p[1]); r.entry = StringToDouble(p[2]);
         r.atr = StringToDouble(p[3]); r.spread = StringToDouble(p[4]);
         r.ensemble = (int)StringToInteger(p[5]); r.dow = (int)StringToInteger(p[6]);
         r.ema = (int)StringToInteger(p[7]); r.macd = (int)StringToInteger(p[8]);
         r.structure = (int)StringToInteger(p[9]); r.done = (int)StringToInteger(p[10]);
         if(r.t <= 0 || r.entry <= 0 || r.done == 7) continue;
         int k = ArraySize(g_dirOpen);
         ArrayResize(g_dirOpen, k + 1);
         g_dirOpen[k] = r;
         if(r.t == g_dirLastBar) DirApplySnapshot(r);
      }
   }
   FileClose(h);
}

// Higher-high + higher-low (or opposite) over TWO DISJOINT H4 windows,
// always using closed candles, never the forming H4 candle.
int DirPriceStructureH4()
{
   if(Bars(_Symbol, PERIOD_H4) < 40) return 0;
   int ah = iHighest(_Symbol, PERIOD_H4, MODE_HIGH, 8, 1);
   int al = iLowest(_Symbol, PERIOD_H4, MODE_LOW, 8, 1);
   int bh = iHighest(_Symbol, PERIOD_H4, MODE_HIGH, 8, 9);
   int bl = iLowest(_Symbol, PERIOD_H4, MODE_LOW, 8, 9);
   if(ah < 0 || al < 0 || bh < 0 || bl < 0) return 0;
   double newH = iHigh(_Symbol, PERIOD_H4, ah), newL = iLow(_Symbol, PERIOD_H4, al);
   double oldH = iHigh(_Symbol, PERIOD_H4, bh), oldL = iLow(_Symbol, PERIOD_H4, bl);
   if(newH <= 0 || newL <= 0 || oldH <= 0 || oldL <= 0) return 0;
   if(newH > oldH && newL > oldL) return 1;
   if(newH < oldH && newL < oldL) return -1;
   return 0;
}
void DirVotes(int &dow, int &ema, int &macd, int &structure)
{
   dow = ema = macd = structure = 0;
   DowState d;
   // A pending Dow reversal makes the Dow vote neutral, not a prediction.
   if(DowTide(d) && d.pend == 0) dow = d.trend;

   double eh = 0, ed = 0;
   double ch = iClose(_Symbol, PERIOD_H4, 1), cd = iClose(_Symbol, PERIOD_D1, 1);
   if(DirInitHandles() && ch > 0 && cd > 0 &&
      GetValue(g_dirEmaH4, 0, 1, eh) && GetValue(g_dirEmaD1, 0, 1, ed))
   {
      if(ch > eh && cd > ed) ema = 1;
      if(ch < eh && cd < ed) ema = -1;
   }
   double m = 0, signal = 0, prev = 0;
   if(g_dirMacdH4 != INVALID_HANDLE &&
      GetValue(g_dirMacdH4, 0, 1, m) &&
      GetValue(g_dirMacdH4, 1, 1, signal) &&
      GetValue(g_dirMacdH4, 0, 2, prev))
   {
      if(m > signal && m > prev) macd = 1;
      if(m < signal && m < prev) macd = -1;
   }
   structure = DirPriceStructureH4();
}
int DirConsensus(const int dow, const int ema, const int macd, const int structure,
                 int &agree, int &against)
{
   int votes[4]; votes[0] = dow; votes[1] = ema; votes[2] = macd; votes[3] = structure;
   int up = 0, down = 0;
   for(int i = 0; i < 4; i++) { if(votes[i] > 0) up++; if(votes[i] < 0) down++; }
   agree = MathMax(up, down); against = MathMin(up, down);
   // Three consenting sources, ZERO opposite vote, else abstain.
   if(up >= 3 && down == 0) return 1;
   if(down >= 3 && up == 0) return -1;
   return 0;
}

// Evaluate using the close h CLOSED M15 bars AFTER the recorded closed bar.
// shift is derived from the original bar timestamp, never the current chart TF.
void DirResolve()
{
   const int horizons[3] = {4, 8, 16};
   for(int i = ArraySize(g_dirOpen) - 1; i >= 0; i--)
   {
      DirForecast r = g_dirOpen[i];
      int shift = iBarShift(_Symbol, PERIOD_M15, r.t, true);
      if(shift < 0) continue; // insufficient or missing history -> retain
      for(int j = 0; j < 3; j++)
      {
         int mask = 1 << j;
         if((r.done & mask) != 0 || shift <= horizons[j]) continue;
         double close = iClose(_Symbol, PERIOD_M15, shift - horizons[j]);
         if(close <= 0) continue;
         double delta = close - r.entry;
         double band = MathMax(2.0 * r.spread, 0.10 * r.atr);
         string label = MathAbs(delta) <= band ? "FLAT" : delta > 0 ? "UP" : "DOWN";
         DirAppend(DirRow("R", r, horizons[j], close, label));
         r.done |= mask; g_dirResolved++;
      }
      if(r.done == 7) ArrayRemove(g_dirOpen, i, 1);
      else g_dirOpen[i] = r;
   }
}
void DirectionStep()
{
   if(P_Strategy != STRAT_SMART) return; // no effect on other strategies
   DirLoadPending();
   datetime bar = iTime(_Symbol, PERIOD_M15, 1);
   double price = iClose(_Symbol, PERIOD_M15, 1);
   if(bar <= 0 || price <= 0) return;
   if(bar == g_dirLastBar) return;
   // Resolve old labels BEFORE predicting for this bar. Do not include
   // the newly closed bar as a lookahead for its own forecast.
   DirResolve();
   int dow, ema, macd, structure, agree, disagree;
   DirVotes(dow, ema, macd, structure);
   int vote = DirConsensus(dow, ema, macd, structure, agree, disagree);
   DirForecast rec;
   rec.t = bar; rec.entry = price; rec.ensemble = vote;
   rec.dow = dow; rec.ema = ema; rec.macd = macd; rec.structure = structure;
   rec.done = 0; rec.atr = 0;
   if(g_dirAtrM15 != INVALID_HANDLE) GetValue(g_dirAtrM15, 0, 1, rec.atr);
   MqlTick tick;
   rec.spread = SymbolInfoTick(_Symbol, tick) ? MathMax(0.0, tick.ask - tick.bid) : 0.0;
   int n = ArraySize(g_dirOpen); ArrayResize(g_dirOpen, n + 1); g_dirOpen[n] = rec;
   g_dirLastBar = bar;
   DirApplySnapshot(rec);
   DirAppend(DirRow("F", rec, 0, 0, "PENDING"));
   DirSavePending();
   g_dirLogged++;
}
