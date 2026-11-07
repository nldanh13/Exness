//+------------------------------------------------------------------+
//| TrendBot/Filters.mqh: Bo loc gio, mau nen, du lieu ngoai (funding, Fear & Greed, Wikipedia, tin My, Nasdaq)
//+------------------------------------------------------------------+
//--- Bo loc thoi gian ----------------------------------------------
bool InWindow(const int hour, const int s, const int e)
{
   if(s < 0 || e < 0 || s == e) return false;
   if(s < e) return hour >= s && hour < e;
   return hour >= s || hour < e;                  // khung qua nua dem
}

bool TimeAllowed(string &why)
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   if(P_SkipWeekend && (dt.day_of_week == 0 || dt.day_of_week == 6)) { why = "cuoi tuan"; return false; }
   if(InWindow(dt.hour, P_Block1Start, P_Block1End) ||
      InWindow(dt.hour, P_Block2Start, P_Block2End)) { why = "khung gio tin tuc"; return false; }
   return true;
}

//--- Mau nen -------------------------------------------------------
bool BullCandle()
{
   double o1 = iOpen(_Symbol, P_TF, 1), c1 = iClose(_Symbol, P_TF, 1);
   double h1 = iHigh(_Symbol, P_TF, 1), l1 = iLow(_Symbol, P_TF, 1);
   double o2 = iOpen(_Symbol, P_TF, 2), c2 = iClose(_Symbol, P_TF, 2);
   double range = h1 - l1;
   if(range <= 0) return false;
   double body      = MathAbs(c1 - o1);
   double lowerWick = MathMin(o1, c1) - l1;
   bool pin       = lowerWick >= 0.5 * range && body <= 0.35 * range && c1 >= l1 + 0.5 * range;
   bool engulfing = c1 > o1 && c2 < o2 && c1 >= o2 && o1 <= c2;
   return pin || engulfing;
}

bool BearCandle()
{
   double o1 = iOpen(_Symbol, P_TF, 1), c1 = iClose(_Symbol, P_TF, 1);
   double h1 = iHigh(_Symbol, P_TF, 1), l1 = iLow(_Symbol, P_TF, 1);
   double o2 = iOpen(_Symbol, P_TF, 2), c2 = iClose(_Symbol, P_TF, 2);
   double range = h1 - l1;
   if(range <= 0) return false;
   double body      = MathAbs(c1 - o1);
   double upperWick = h1 - MathMax(o1, c1);
   bool pin       = upperWick >= 0.5 * range && body <= 0.35 * range && c1 <= h1 - 0.5 * range;
   bool engulfing = c1 < o1 && c2 > o2 && c1 <= o2 && o1 >= c2;
   return pin || engulfing;
}

//--- Khoi luong ----------------------------------------------------
//--- Funding rate (Binance USDT-M Futures) ----------------------------
// Backtest: doc file funding_<CAP>.csv trong thu muc Common\Files (script ChayThuNghiem tai ve).
// Chay that: hoi Binance moi gio qua WebRequest (them https://fapi.binance.com vao danh sach cho phep),
// loi thi dung gia tri moi nhat trong file.
datetime g_fT[];
double   g_fR[];
double   g_liveFunding = EMPTY_VALUE;
datetime g_liveFundingAt = 0;
int      g_fundBlocked = 0;     // so tin hieu bi bo vi funding (ghi vao ket qua backtest)
string FundingPair()
{
   if(P_FundingSymbol != "") return P_FundingSymbol;
   if(StringFind(_Symbol, "BTC") >= 0) return "BTCUSDT";
   if(StringFind(_Symbol, "ETH") >= 0) return "ETHUSDT";
   return "";
}
void LoadFunding()
{
   ArrayResize(g_fT, 0); ArrayResize(g_fR, 0);
   string pair = FundingPair();
   if(pair == "") return;
   int h = OpenCommonRead("funding_" + pair + ".csv", FILE_CSV | FILE_ANSI, ',');
   if(h == INVALID_HANDLE) { Print("Chua co file funding_", pair, ".csv: bo loc funding se khong chan lenh nao."); return; }
   while(!FileIsEnding(h))
   {
      string ms = FileReadString(h);
      string rt = FileReadString(h);
      long   t  = StringToInteger(ms);
      if(t <= 0) continue;                              // dong tieu de / dong trong
      int n = ArraySize(g_fT);
      ArrayResize(g_fT, n + 1); ArrayResize(g_fR, n + 1);
      g_fT[n] = (datetime)(t / 1000);
      g_fR[n] = StringToDouble(rt) * 100.0;             // doi sang %
   }
   FileClose(h);
   PrintFormat("Da nap %d moc funding %s.", ArraySize(g_fT), pair);
}
// Funding (%) da biet tai thoi diem t: moc gan nhat <= t. EMPTY_VALUE neu khong co du lieu.
double FundingAt(const datetime t)
{
   int n = ArraySize(g_fT);
   if(n == 0 || t < g_fT[0]) return EMPTY_VALUE;
   if(t - g_fT[n - 1] > 2 * 86400) return EMPTY_VALUE;  // du lieu cu qua 2 ngay: coi nhu khong co
   int lo = 0, hi = n - 1;
   while(lo < hi) { int mid = (lo + hi + 1) / 2; if(g_fT[mid] <= t) lo = mid; else hi = mid - 1; }
   return g_fR[lo];
}
string g_fundState = "";   // hien tren bang thong tin
datetime g_liveFundingOk = 0;
bool LiveFundingFresh() { return g_liveFunding != EMPTY_VALUE && TimeCurrent() - g_liveFundingOk <= 2 * 86400; }
double FundingNow()
{
   if(!MQLInfoInteger(MQL_TESTER) && FundingPair() != "" && TimeCurrent() - g_liveFundingAt >= 3600)
   {
      g_liveFundingAt = TimeCurrent();
      char req[], res[]; string hdr;
      // Muc funding DA CHOT gan nhat (giong du lieu backtest), khong dung muc du kien cua premiumIndex
      int code = WebRequest("GET", "https://fapi.binance.com/fapi/v1/fundingRate?limit=1&symbol=" + FundingPair(),
                            "", 5000, req, res, hdr);
      if(code == 200)
      {
         string js = CharArrayToString(res);
         int k = StringFind(js, "\"fundingRate\":\"");
         if(k >= 0)
         {
            k += StringLen("\"fundingRate\":\"");
            g_liveFunding = StringToDouble(StringSubstr(js, k, StringFind(js, "\"", k) - k)) * 100.0;
            g_liveFundingOk = TimeCurrent();
         }
      }
      else if(ShouldNotify("funding", 86400))
         PrintFormat("Khong lay duoc funding (%d). Them https://fapi.binance.com vao Tools > Options > Expert Advisors > Allow WebRequest.", code);
   }
   if(!MQLInfoInteger(MQL_TESTER))
   {
      if(LiveFundingFresh()) { g_fundState = StringFormat("%.4f%% (Binance)", g_liveFunding); return g_liveFunding; }
      double f = FundingAt(TimeCurrent());
      g_fundState = f == EMPTY_VALUE ? "KHONG CO DU LIEU - bo loc dang tat" : StringFormat("%.4f%% (file cu)", f);
      return f;
   }
   return FundingAt(TimeCurrent());
}

//--- Chuoi so lieu theo ngay (Fear & Greed, luot xem Wikipedia) ------
// File trong Common\Files, moi dong "unix_giay,gia_tri" (script ChayThuNghiem tai ve).
// Chi dung so lieu cua NGAY HOM QUA tro ve truoc, tranh nhin truoc tuong lai trong backtest.
datetime g_fngT[];  double g_fngV[];
datetime g_wikT[];  double g_wikV[];
datetime g_fngLiveAt = 0, g_wikLiveAt = 0;
int      g_fngBlocked = 0, g_attBlocked = 0, g_mktBlocked = 0, g_newsBlocked = 0;
datetime DayOf(const datetime t) { return t - t % 86400; }
string WikiArticle()
{
   if(P_WikiArticle != "") return P_WikiArticle;
   if(StringFind(_Symbol, "BTC") >= 0) return "Bitcoin";
   if(StringFind(_Symbol, "ETH") >= 0) return "Ethereum";
   return "";
}
// Them / cap nhat 1 ngay, giu mang tang dan theo thoi gian
void MergeDaily(datetime &t[], double &v[], const datetime day, const double val)
{
   int n = ArraySize(t);
   if(n > 0 && day == t[n - 1]) { v[n - 1] = val; return; }
   if(n > 0 && day < t[n - 1])
   {
      for(int i = n - 1; i >= 0 && t[i] >= day; i--) if(t[i] == day) { v[i] = val; return; }
      return;                                    // ngay cu khong co trong file: bo qua
   }
   ArrayResize(t, n + 1); ArrayResize(v, n + 1);
   t[n] = day; v[n] = val;
}
void LoadDaily(const string file, datetime &t[], double &v[])
{
   ArrayResize(t, 0); ArrayResize(v, 0);
   int h = OpenCommonRead(file, FILE_CSV | FILE_ANSI, ',');
   if(h == INVALID_HANDLE) { Print("Chua co file ", file, ": bo loc dung file nay se khong chan lenh nao."); return; }
   while(!FileIsEnding(h))
   {
      long   ts = StringToInteger(FileReadString(h));
      double x  = StringToDouble(FileReadString(h));
      if(ts > 0) MergeDaily(t, v, DayOf((datetime)ts), x);
   }
   FileClose(h);
   PrintFormat("Da nap %d ngay tu %s.", ArraySize(t), file);
}
// Trung binh cac ngay trong [lastDay - days + 1, lastDay]. EMPTY_VALUE neu thieu qua 30% so ngay.
double DailyAvg(const datetime &t[], const double &v[], const datetime lastDay, const int days)
{
   int n = ArraySize(t);
   if(n == 0 || lastDay < t[0]) return EMPTY_VALUE;
   int lo = 0, hi = n - 1;
   while(lo < hi) { int mid = (lo + hi + 1) / 2; if(t[mid] <= lastDay) lo = mid; else hi = mid - 1; }
   double sum = 0; int cnt = 0;
   for(int i = lo; i >= 0 && t[i] > lastDay - days * 86400; i--) { sum += v[i]; cnt++; }
   if(cnt < days * 0.7) return EMPTY_VALUE;
   return sum / cnt;
}
string JsonValue(const string js, const string key, const int from, int &pos)
{
   string k = "\"" + key + "\":";
   pos = StringFind(js, k, from);
   if(pos < 0) return "";
   int a = pos + StringLen(k);
   while(a < StringLen(js) && (StringGetCharacter(js, a) == ' ' || StringGetCharacter(js, a) == '"')) a++;
   int b = a;
   while(b < StringLen(js)) { ushort c = StringGetCharacter(js, b); if(c == '"' || c == ',' || c == '}') break; b++; }
   return StringSubstr(js, a, b - a);
}
bool HttpGet(const string url, string &body)
{
   char req[], res[]; string hdr;
   int code = WebRequest("GET", url, "User-Agent: BTC-EA/1.0\r\n", 8000, req, res, hdr);
   body = CharArrayToString(res, 0, WHOLE_ARRAY, CP_UTF8);
   if(code != 200 && ShouldNotify("http" + StringSubstr(url, 0, 30), 86400))
   {
      int e = StringFind(url, "/", 8);
      PrintFormat("Khong tai duoc %s (%d). Them %s vao Tools > Options > Expert Advisors > Allow WebRequest.",
                  url, code, StringSubstr(url, 0, e));
   }
   return code == 200;
}
// Chay that: cap nhat so lieu moi qua mang (6 gio / lan)
void RefreshDailyLive()
{
   if(MQLInfoInteger(MQL_TESTER)) return;
   string js; int pos;
   if(P_UseFearGreed && TimeCurrent() - g_fngLiveAt >= 6 * 3600)
   {
      g_fngLiveAt = TimeCurrent();
      datetime td[]; double tv[];
      if(HttpGet("https://api.alternative.me/fng/?limit=10", js))
         for(int from = 0; ; )
         {
            string val = JsonValue(js, "value", from, pos);
            if(pos < 0) break;
            string ts  = JsonValue(js, "timestamp", pos, pos);
            if(pos < 0) break;
            from = pos + 1;
            int k = ArraySize(td);
            ArrayResize(td, k + 1); ArrayResize(tv, k + 1);
            td[k] = DayOf((datetime)StringToInteger(ts)); tv[k] = StringToDouble(val);
         }
      // API tra ngay moi nhat truoc: sap xep tang dan roi gop vao chuoi
      for(int i = 1; i < ArraySize(td); i++)
         for(int j = i; j > 0 && td[j] < td[j - 1]; j--)
         { datetime x = td[j]; td[j] = td[j - 1]; td[j - 1] = x; double y = tv[j]; tv[j] = tv[j - 1]; tv[j - 1] = y; }
      for(int i = 0; i < ArraySize(td); i++) MergeDaily(g_fngT, g_fngV, td[i], tv[i]);
   }
   if(P_UseAttention && WikiArticle() != "" && TimeCurrent() - g_wikLiveAt >= 6 * 3600)
   {
      g_wikLiveAt = TimeCurrent();
      string a = TimeToString(TimeGMT() - 45 * 86400, TIME_DATE), b = TimeToString(TimeGMT(), TIME_DATE);
      StringReplace(a, ".", ""); StringReplace(b, ".", "");
      if(HttpGet("https://wikimedia.org/api/rest_v1/metrics/pageviews/per-article/en.wikipedia/all-access/user/"
                 + WikiArticle() + "/daily/" + a + "/" + b, js))
         for(int from = 0; ; )
         {
            string ts = JsonValue(js, "timestamp", from, pos);     // dang 2026110500
            if(pos < 0) break;
            string vw = JsonValue(js, "views", pos, pos);
            if(pos < 0) break;
            from = pos + 1;
            MqlDateTime m; ZeroMemory(m);
            m.year = (int)StringToInteger(StringSubstr(ts, 0, 4));
            m.mon  = (int)StringToInteger(StringSubstr(ts, 4, 2));
            m.day  = (int)StringToInteger(StringSubstr(ts, 6, 2));
            MergeDaily(g_wikT, g_wikV, StructToTime(m), StringToDouble(vw));
         }
   }
}
// Tin vi mo My quan trong trong khoang +-InpNewsHours (chi chay that; lich kinh te khong co trong backtest)
// Backtest: lich FOMC + CPI (gio UTC) tu file tin_my.csv (script chep tu du-lieu/ vao Common\Files).
datetime g_newsT[]; string g_newsN[];
void LoadNews()
{
   ArrayResize(g_newsT, 0); ArrayResize(g_newsN, 0);
   int h = OpenCommonRead("tin_my.csv", FILE_TXT | FILE_ANSI);
   if(h == INVALID_HANDLE) { Print("Chua co file tin_my.csv: bo loc tin se khong chan lenh nao trong backtest."); return; }
   while(!FileIsEnding(h))
   {
      string p[];
      if(StringSplit(FileReadString(h), ',', p) < 2) continue;
      long ts = StringToInteger(p[0]);
      if(ts <= 0) continue;                                   // dong ghi chu / tieu de
      int n = ArraySize(g_newsT);
      ArrayResize(g_newsT, n + 1); ArrayResize(g_newsN, n + 1);
      g_newsT[n] = (datetime)ts; g_newsN[n] = p[1];
   }
   FileClose(h);
}
// So gio tu thoi diem t toi tin gan nhat trong file (am = tin da qua). 9999 neu khong co.
double HoursToNews(const datetime t, string &name)
{
   double best = 9999; name = "";
   for(int i = 0; i < ArraySize(g_newsT); i++)
   {
      double hrs = (double)(g_newsT[i] - t) / 3600.0;
      if(MathAbs(hrs) < MathAbs(best)) { best = hrs; name = g_newsN[i]; }
      if(hrs > 48) break;
   }
   return best;
}
bool USNewsNear(string &name)
{
   if(MQLInfoInteger(MQL_TESTER))
      return MathAbs(HoursToNews(TimeCurrent(), name)) <= P_NewsHours;   // server Exness = GMT+0
   MqlCalendarValue vals[];
   datetime now = TimeTradeServer();
   if(CalendarValueHistory(vals, now - P_NewsHours * 3600, now + P_NewsHours * 3600, "US") <= 0) return false;
   for(int i = 0; i < ArraySize(vals); i++)
   {
      MqlCalendarEvent ev;
      if(CalendarEventById(vals[i].event_id, ev) && ev.importance == CALENDAR_IMPORTANCE_HIGH)
      { name = ev.name; return true; }
   }
   return false;
}

bool MarketFiltersOk(const bool isBuy)
{
   RefreshDailyLive();
   datetime yday = DayOf(TimeCurrent()) - 86400;          // chi dung so lieu da biet: hom qua tro ve truoc
   if(P_UseFearGreed)
   {
      double f = DailyAvg(g_fngT, g_fngV, yday, 1);
      if(f != EMPTY_VALUE && ((isBuy && f >= P_FngGreedMax) || (!isBuy && f <= P_FngFearMin)))
      {
         g_fngBlocked++;
         g_status = StringFormat("Bo tin hieu vi Fear & Greed = %.0f", f);
         return false;
      }
   }
   if(P_UseAttention)
   {
      double a7 = DailyAvg(g_wikT, g_wikV, yday, 7), a30 = DailyAvg(g_wikT, g_wikV, yday, 30);
      if(a7 != EMPTY_VALUE && a30 != EMPTY_VALUE && a7 <= a30)
      {
         g_attBlocked++;
         g_status = "Bo tin hieu vi su chu y dang giam (Wikipedia)";
         return false;
      }
   }
   if(hMkt != INVALID_HANDLE)
   {
      double ema, cl = iClose(g_mktSym, PERIOD_D1, 1);
      if(cl > 0 && GetValue(hMkt, 0, 1, ema) && ((isBuy && cl < ema) || (!isBuy && cl > ema)))
      {
         g_mktBlocked++;
         g_status = "Bo tin hieu vi Nasdaq nguoc chieu";
         return false;
      }
   }
   string news;
   if(P_AvoidUSNews && USNewsNear(news))
   {
      g_newsBlocked++;
      g_status = "Gan tin My: " + news;
      return false;
   }
   return true;
}

//+------------------------------------------------------------------+

//--- Dong thuan da khung: dem so khung (M1, M3, M5, M10, M15, M30, H1, H4) co nen da dong nam cung phia EMA20 cua khung do
ENUM_TIMEFRAMES g_mtfTF[8] = { PERIOD_M1, PERIOD_M3, PERIOD_M5, PERIOD_M10, PERIOD_M15, PERIOD_M30, PERIOD_H1, PERIOD_H4 };
int             g_mtfH[8]  = { INVALID_HANDLE, INVALID_HANDLE, INVALID_HANDLE, INVALID_HANDLE, INVALID_HANDLE, INVALID_HANDLE, INVALID_HANDLE, INVALID_HANDLE };
bool InitMTF()
{
   for(int i = 0; i < 8; i++)
   {
      g_mtfH[i] = iMA(_Symbol, g_mtfTF[i], 20, 0, MODE_EMA, PRICE_CLOSE);
      if(g_mtfH[i] == INVALID_HANDLE) return false;
   }
   return true;
}
void ReleaseMTF() { for(int i = 0; i < 8; i++) if(g_mtfH[i] != INVALID_HANDLE) IndicatorRelease(g_mtfH[i]); }
// So khung dong thuan voi huong buy (true) / sell (false)
int MTFCount(const bool buy)
{
   int n = 0;
   for(int i = 0; i < 8; i++)
   {
      double e;
      if(!GetValue(g_mtfH[i], 0, 1, e)) continue;
      double c = iClose(_Symbol, g_mtfTF[i], 1);
      if(c <= 0) continue;
      if(buy ? c > e : c < e) n++;
   }
   return n;
}
bool MTFOk(const bool buy) { return P_MTFAlign <= 0 || MTFCount(buy) >= P_MTFAlign; }
