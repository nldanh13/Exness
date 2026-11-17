//+------------------------------------------------------------------+
//| TrendBot/DirectionEngine.mqh - SINGLE research decision v5.45     |
//| SHADOW ONLY. Existing SyncEntryAllowed v5.44 remains SOLE gate.   |
//| Three de-duplicated groups: structure(40), EMA(35), MACD(25).    |
//| ADX identifies regime but is NOT a directional vote.             |
//| FVG/OB/VWAP remain trade setups; they are NOT direction votes.    |
//| Every vote recorded after a CLOSED M15 bar, scored at +4/8/16.   |
//+------------------------------------------------------------------+
struct EngineForecast
{
   datetime t;
   double entry, atr, spread, adx;
   int engine, legacy, structure, ema, momentum, up, down, done;
};
EngineForecast g_enginePending[];
datetime g_engineBar = 0;
bool g_engineLoaded = false, g_engineReady = false, g_engineIoWarned = false;
int g_engineDir = 0, g_engineLegacy = 0, g_engineUp = 0, g_engineDown = 0;
int g_engineTrend = 0, g_engineEMA = 0, g_engineMomentum = 0;
double g_engineADX = 0;
int g_engineForecastCount = 0, g_engineOutcomeCount = 0;
string g_engineSummary = "CHUA CO DU LIEU M15";

string EngineFile()
{
   return StringFormat("TrendBot_direction_engine_%I64d_%s_%I64d_M15.csv",
                       AccountInfoInteger(ACCOUNT_LOGIN), _Symbol, (long)P_Magic);
}
string EnginePendingFile()
{
   return StringFormat("TrendBot_direction_engine_pending_%I64d_%s_%I64d_M15.txt",
                       AccountInfoInteger(ACCOUNT_LOGIN), _Symbol, (long)P_Magic);
}
string EngineName(const int side)
{
   return side > 0 ? "MUA" : side < 0 ? "BAN" : "CHO";
}

// The exact rule is deliberately visible/testable; its score is
// qualitative support, NOT a calibrated win probability.
// 70/100 requires at least structure(40) + EMA(35) aligned.
// A contrary MACD(25) is recorded rather than silently overwritten.
int EngineScore(const int structure, const int ema, const int momentum,
                int &up, int &down)
{
   up = (structure > 0 ? 40 : 0) + (ema > 0 ? 35 : 0) + (momentum > 0 ? 25 : 0);
   down = (structure < 0 ? 40 : 0) + (ema < 0 ? 35 : 0) + (momentum < 0 ? 25 : 0);
   if(up >= 70 && up > down) return 1;
   if(down >= 70 && down > up) return -1;
   return 0;
}

// Dow D1 and H4 price structure are ONE structure bucket.
// Do not count Dow again as a fourth independent decision.
int EngineStructureGroup(const int dow, const int h4structure)
{
   if(dow == 0 || (h4structure != 0 && h4structure != dow)) return 0;
   return dow;
}

// EMA20/50 across nine frames and EMA50 H4+D1 are ONE EMA bucket.
// 5/9 including H4+D1 is an exploratory threshold, not a proven edge.
// If two EMA methods vote opposite, the bucket abstains.
int EngineEMAGroup(const int up9, const int down9, const int h4, const int d1,
                   const int ema50)
{
   int nine = 0;
   if(up9 >= 5 && h4 == 1 && d1 == 1) nine = 1;
   else if(down9 >= 5 && h4 == -1 && d1 == -1) nine = -1;
   if(nine != 0 && ema50 != 0 && nine != ema50) return 0;
   if(nine != 0) return nine;
   return ema50; // one remaining EMA vote, never an additional weight
}
void EngineApply(const EngineForecast &rec)
{
   g_engineBar = rec.t;
   g_engineReady = true;
   g_engineDir = rec.engine; g_engineLegacy = rec.legacy;
   g_engineTrend = rec.structure; g_engineEMA = rec.ema;
   g_engineMomentum = rec.momentum; g_engineUp = rec.up;
   g_engineDown = rec.down; g_engineADX = rec.adx;
   string regime = rec.adx <= 0 ? "ADX CHUA CO" :
                   rec.adx >= 25 ? "XU HUONG" :
                   rec.adx < 20 ? "DI NGANG" : "CHUYEN TIEP";
   string diff = rec.engine == rec.legacy ? "TRUNG v5.44" : "KHAC v5.44";
   g_engineSummary = StringFormat("ENGINE THU NGHIEM: %s (tang %d/giam %d diem) | Cautruc %s; EMA %s; MACD %s | %s ADX %.1f | LENH THUC v5.44: %s (%s). KHONG PHAI XAC SUAT",
                                   EngineName(rec.engine), rec.up, rec.down,
                                   EngineName(rec.structure), EngineName(rec.ema),
                                   EngineName(rec.momentum), regime, rec.adx,
                                   EngineName(rec.legacy), diff);
}
string EngineCsvRow(const string event, const EngineForecast &r,
                    const int horizon, const double close, const string label)
{
   return StringFormat("%s,%I64d,%d,%.8f,%.8f,%.8f,%.8f,%.8f,%d,%d,%d,%d,%d,%d,%d,%.2f,%s",
                       event, (long)r.t, horizon, r.entry, close,
                       close > 0 ? close - r.entry : 0, r.atr, r.spread,
                       r.engine, r.legacy, r.structure, r.ema, r.momentum,
                       r.up, r.down, r.adx, label);
}
void EngineAppend(const string row)
{
   if(MQLInfoInteger(MQL_TESTER)) return;
   string file = EngineFile();
   bool fresh = !FileIsExist(file, FILE_COMMON);
   int h = FileOpen(file, FILE_READ | FILE_WRITE | FILE_TXT | FILE_ANSI |
                   FILE_COMMON | FILE_SHARE_READ);
   if(h == INVALID_HANDLE)
   {
      if(!g_engineIoWarned)
      {
         Print("ENGINE: khong ghi duoc CSV ", file, " err=", GetLastError());
         g_engineIoWarned = true;
      }
      return;
   }
   FileSeek(h, 0, SEEK_END);
   if(fresh)
      FileWriteString(h, "event,t_m15_server_epoch,horizon,entry,close,delta_price,atr_m15,spread,engine,legacy,structure,ema,momentum,up_score,down_score,adx,label\r\n");
   FileWriteString(h, row + "\r\n");
   FileClose(h);
}
// Preserve last processed bar and unresolved forecasts after MT5 restart.
void EngineSavePending()
{
   if(MQLInfoInteger(MQL_TESTER)) return;
   int h = FileOpen(EnginePendingFile(), FILE_WRITE | FILE_TXT | FILE_ANSI |
                    FILE_COMMON | FILE_SHARE_READ);
   if(h == INVALID_HANDLE) return;
   FileWriteString(h, StringFormat("LAST,%I64d\r\n", (long)g_engineBar));
   for(int i = 0; i < ArraySize(g_enginePending); i++)
   {
      EngineForecast r = g_enginePending[i];
      FileWriteString(h, StringFormat("P,%I64d,%.8f,%.8f,%.8f,%d,%d,%d,%d,%d,%d,%d,%.2f,%d\r\n",
                                     (long)r.t, r.entry, r.atr, r.spread, r.engine,
                                     r.legacy, r.structure, r.ema, r.momentum,
                                     r.up, r.down, r.adx, r.done));
   }
   FileClose(h);
}
void EngineLoadPending()
{
   if(g_engineLoaded) return;
   g_engineLoaded = true;
   ArrayResize(g_enginePending, 0);
   if(MQLInfoInteger(MQL_TESTER)) return;
   int h = FileOpen(EnginePendingFile(), FILE_READ | FILE_TXT | FILE_ANSI |
                    FILE_COMMON | FILE_SHARE_READ | FILE_SHARE_WRITE);
   if(h == INVALID_HANDLE) return;
   while(!FileIsEnding(h))
   {
      string p[];
      int n = StringSplit(FileReadString(h), ',', p);
      if(n >= 2 && p[0] == "LAST")
         g_engineBar = (datetime)StringToInteger(p[1]);
      else if(n == 14 && p[0] == "P")
      {
         EngineForecast r;
         r.t = (datetime)StringToInteger(p[1]);
         r.entry = StringToDouble(p[2]); r.atr = StringToDouble(p[3]);
         r.spread = StringToDouble(p[4]);
         r.engine = (int)StringToInteger(p[5]); r.legacy = (int)StringToInteger(p[6]);
         r.structure = (int)StringToInteger(p[7]); r.ema = (int)StringToInteger(p[8]);
         r.momentum = (int)StringToInteger(p[9]);
         r.up = (int)StringToInteger(p[10]); r.down = (int)StringToInteger(p[11]);
         r.adx = StringToDouble(p[12]); r.done = (int)StringToInteger(p[13]);
         if(r.t <= 0 || r.entry <= 0 || r.done == 7) continue;
         int k = ArraySize(g_enginePending);
         ArrayResize(g_enginePending, k + 1);
         g_enginePending[k] = r;
         if(r.t == g_engineBar) EngineApply(r);
      }
   }
   FileClose(h);
}
void EngineResolve()
{
   const int horizons[3] = {4, 8, 16};
   for(int i = ArraySize(g_enginePending) - 1; i >= 0; i--)
   {
      EngineForecast r = g_enginePending[i];
      int shift = iBarShift(_Symbol, PERIOD_M15, r.t, true);
      if(shift < 0) continue;
      for(int j = 0; j < 3; j++)
      {
         int mask = 1 << j;
         if((r.done & mask) != 0 || shift <= horizons[j]) continue;
         double close = iClose(_Symbol, PERIOD_M15, shift - horizons[j]);
         if(close <= 0) continue;
         double band = MathMax(2.0 * r.spread, 0.10 * r.atr);
         double delta = close - r.entry;
         string label = MathAbs(delta) <= band ? "FLAT" : delta > 0 ? "UP" : "DOWN";
         EngineAppend(EngineCsvRow("R", r, horizons[j], close, label));
         r.done |= mask; g_engineOutcomeCount++;
      }
      if(r.done == 7) ArrayRemove(g_enginePending, i, 1);
      else g_enginePending[i] = r;
   }
}
// Only one new forecast per CLOSED M15 candle; no recalculation later.
// v5.44's final trading direction is captured as an IMMUTABLE baseline
// for the same exact candle, independent of the challenger.
void DirectionEngineStep()
{
   if(P_Strategy != STRAT_SMART) return;
   EngineLoadPending();
   datetime bar = iTime(_Symbol, PERIOD_M15, 1);
   if(bar <= 0 || g_dirLastBar != bar || !g_syncReady ||
      g_syncBar != bar || !g_tbSnapshotReady || g_tbSnapshotBar != bar)
   {
      g_engineReady = false;
      g_engineSummary = "ENGINE: CHO DU 9 KHUNG + 4 NGUON CUNG NEN M15";
      return;
   }
   if(bar == g_engineBar) return;
   double close = iClose(_Symbol, PERIOD_M15, 1);
   if(close <= 0) return;
   EngineResolve();
   EngineForecast r;
   r.t = bar; r.entry = close; r.atr = 0; r.spread = 0; r.adx = 0;
   r.legacy = g_syncDir;
   r.structure = EngineStructureGroup(g_dirLastDow, g_dirLastStructure);
   r.ema = EngineEMAGroup(g_syncNineUp, g_syncNineDn,
                          g_tbSnapshotVotes[7], g_tbSnapshotVotes[8], g_dirLastEma);
   r.momentum = g_dirLastMacd;
   r.engine = EngineScore(r.structure, r.ema, r.momentum, r.up, r.down);
   r.done = 0;
   if(g_dirAtrM15 != INVALID_HANDLE) GetValue(g_dirAtrM15, 0, 1, r.atr);
   if(hADX != INVALID_HANDLE) GetValue(hADX, 0, 1, r.adx);
   MqlTick tick;
   if(SymbolInfoTick(_Symbol, tick)) r.spread = MathMax(0.0, tick.ask - tick.bid);
   int n = ArraySize(g_enginePending);
   ArrayResize(g_enginePending, n + 1);
   g_enginePending[n] = r;
   EngineApply(r);
   EngineAppend(EngineCsvRow("F", r, 0, 0, "PENDING"));
   EngineSavePending();
   g_engineForecastCount++;
}
