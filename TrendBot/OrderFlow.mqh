//+------------------------------------------------------------------+
//| TrendBot/OrderFlow.mqh: xac nhan tin hieu bang dong tien (v5.12) |
//| MAC DINH TAT (InpUseFlow = false). CHUA KIEM THU.                |
//+------------------------------------------------------------------+
// Y tuong: duong ho tro / khang cu chi DAT CAU HOI (gia tung quay dau o day), dong tien moi TRA LOI lan nay ra sao.
// Chi xet cay nen tin hieu (nen 1, vua dong), sau khi moi dieu kien khac da dat:
//  - Chien luoc PHA VO (Donchian, ORB, MACD, quan tinh): phai co
//      * phe theo chieu lenh CHU DONG ap dao: delta = (mua chu dong - ban chu dong) / tong >= InpFlowMinDelta
//      * khoi luong lon bat thuong ("big trades"): khoi luong nen >= InpFlowBigMult x trung binh 20 nen truoc
//      * gia GIU duoc quang duong: nen dong o phan tren (Buy) cua bien do >= InpFlowHoldPos.
//    Mua rat nhieu ma nen dong thap = lenh ban lon chan san phia tren nuot het luc mua (bi hap thu):
//    nguoi mua pha vo bi ket tren dinh -> bo tin hieu.
//  - Chien luoc BAT LAI o ho tro / khang cu (EMA pullback, RSI, dao chieu, FVG, spring, Fib + VP): phai co
//      * khoi luong lon bat thuong o vung do
//      * ben KIA chu dong do vao (Buy: delta <= 0, ban chu dong nhieu hon mua) ma nen van dong o phan tren:
//        co nguoi dung sau do lenh (hap thu) -> ho tro se giu. Ban do vao ma gia truot = khong ai do: khong co
//        nen xac nhan nen chien luoc da khong bao tin hieu.
// Exness (CFD) khong co chieu mua / ban chu dong, khong co kich thuoc tung lenh. Lay nen CUNG KHUNG cua Binance
// Futures (khoi luong + khoi luong mua chu dong), tuc la "footprint" rut gon cua CA cay nen, khong phai tung muc gia.
// Gia dinh gio server Exness = UTC (giong cac phan khac cua bot).
// Chay that: WebRequest https://fapi.binance.com (them vao Tools > Options > Expert Advisors > Allow WebRequest).
// Backtest: file Common\Files\flow_<CAP>_<khung>.csv (vd. flow_BTCUSDT_4h.csv), moi dong "openTime_ms,volume,takerBuyVolume".
// Thieu du lieu (khong co file, mat mang, lech gio): KHONG chan lenh, chi dem vao g_flowNoData.
int      g_flowBlocked = 0, g_flowNoData = 0;
string   g_flowState = "";
datetime g_flT[];
double   g_flV[], g_flB[];
bool     g_flLoaded = false;

string FlowInterval()
{
   switch(PeriodSeconds(P_TF) / 60)
   {
      case 1: return "1m";   case 3: return "3m";   case 5: return "5m";   case 15: return "15m";  case 30: return "30m";
      case 60: return "1h";  case 120: return "2h"; case 240: return "4h"; case 360: return "6h"; case 480: return "8h";
      case 720: return "12h"; case 1440: return "1d";
   }
   return "";
}

// Chien luoc pha vo: luc chu dong phai cung chieu lenh. Con lai la bat lai o vung gia: luc chu dong nguoc chieu bi hap thu.
bool FlowIsBreakout()
{
   return P_Strategy == STRAT_DONCHIAN || P_Strategy == STRAT_ORB || P_Strategy == STRAT_MACD || P_Strategy == STRAT_IMOM;
   // STRAT_DIVCVD tu dung CVD ben trong tin hieu: bo loc dong tien xem no la chien luoc dao chieu (bat lai)
}

void FlowLoadFile()
{
   g_flLoaded = true;
   ArrayResize(g_flT, 0); ArrayResize(g_flV, 0); ArrayResize(g_flB, 0);
   string pair = FundingPair(), iv = FlowInterval();
   if(pair == "" || iv == "") return;
   string name = "flow_" + pair + "_" + iv + ".csv";
   if(!FileIsExist(name, FILE_COMMON)) { Print("Chua co file ", name, ": bo loc dong tien se khong chan lenh nao."); return; }
   int h = OpenCommonRead(name, FILE_CSV | FILE_ANSI, ',');
   if(h == INVALID_HANDLE) return;
   while(!FileIsEnding(h))
   {
      string ms = FileReadString(h);
      string vs = FileReadString(h);
      string bs = FileReadString(h);
      long t = StringToInteger(ms);
      if(t <= 0) continue;                                   // tieu de / dong trong
      int n = ArraySize(g_flT);
      ArrayResize(g_flT, n + 1); ArrayResize(g_flV, n + 1); ArrayResize(g_flB, n + 1);
      g_flT[n] = (datetime)(t / 1000); g_flV[n] = StringToDouble(vs); g_flB[n] = StringToDouble(bs);
   }
   FileClose(h);
   PrintFormat("Da nap %d nen dong tien %s.", ArraySize(g_flT), name);
}

// back + 1 nen ket thuc o nen mo luc openT (nen cuoi = nen tin hieu), tu file (backtest)
bool FlowFromFile(const datetime openT, const int back, double &v[], double &b[])
{
   if(!g_flLoaded) FlowLoadFile();
   int n = ArraySize(g_flT);
   if(n == 0) return false;
   int lo = 0, hi = n - 1;
   while(lo < hi) { int mid = (lo + hi + 1) / 2; if(g_flT[mid] <= openT) lo = mid; else hi = mid - 1; }
   if(g_flT[lo] != openT || lo < back) return false;
   ArrayResize(v, back + 1); ArrayResize(b, back + 1);
   for(int i = 0; i <= back; i++) { v[i] = g_flV[lo - back + i]; b[i] = g_flB[lo - back + i]; }
   return true;
}

// Cung du lieu, hoi thang Binance (chay that / demo)
bool FlowFromBinance(const datetime openT, const int back, double &v[], double &b[])
{
   string pair = FundingPair(), iv = FlowInterval();
   if(pair == "" || iv == "") return false;
   long endMs = (long)openT * 1000 + (long)PeriodSeconds(P_TF) * 1000 - 1;
   string url = "https://fapi.binance.com/fapi/v1/klines?symbol=" + pair + "&interval=" + iv +
                "&endTime=" + IntegerToString(endMs) + "&limit=" + IntegerToString(back + 1);
   char req[], res[]; string hdr;
   int code = WebRequest("GET", url, "", 5000, req, res, hdr);
   if(code != 200)
   {
      if(ShouldNotify("flow", 86400))
         PrintFormat("Khong lay duoc nen Binance (%d). Them https://fapi.binance.com vao Tools > Options > Expert Advisors > Allow WebRequest.", code);
      return false;
   }
   // [[openTime,"open","high","low","close","volume",closeTime,"quoteVol",trades,"takerBuyBase","takerBuyQuote","0"],...]
   string js = CharArrayToString(res);
   ArrayResize(v, 0); ArrayResize(b, 0);
   datetime lastT = 0;
   int p = 1;
   while(true)
   {
      int a = StringFind(js, "[", p);
      if(a < 0) break;
      int z = StringFind(js, "]", a);
      if(z < 0) break;
      string row = StringSubstr(js, a + 1, z - a - 1);
      p = z + 1;
      StringReplace(row, "\"", "");
      string f[];
      if(StringSplit(row, ',', f) < 10) continue;
      int n = ArraySize(v);
      ArrayResize(v, n + 1); ArrayResize(b, n + 1);
      v[n] = StringToDouble(f[5]); b[n] = StringToDouble(f[9]);
      lastT = (datetime)(StringToInteger(f[0]) / 1000);
   }
   return ArraySize(v) >= 2 && lastT == openT;            // nen cuoi phai dung nen tin hieu (khong lech gio)
}

// true = cho vao lenh. Goi khi da co tin hieu (nen 1 vua dong).
bool FlowOk(const bool buy, const double h1, const double l1, const double c1)
{
   if(!P_UseFlow) return true;
   datetime t1 = iTime(_Symbol, P_TF, 1);
   double v[], b[];
   bool got = MQLInfoInteger(MQL_TESTER) ? FlowFromFile(t1, 20, v, b) : FlowFromBinance(t1, 20, v, b);
   int n = ArraySize(v);
   if(!got || n < 2 || v[n - 1] <= 0)
   {
      g_flowNoData++;
      g_flowState = "khong co du lieu - khong chan";
      return true;
   }
   double V = v[n - 1], B = b[n - 1];
   double delta = (2.0 * B - V) / V;                        // (mua chu dong - ban chu dong) / tong, tu -1 toi +1
   double avg = 0;
   for(int i = 0; i < n - 1; i++) avg += v[i];
   avg /= (n - 1);
   double volX = avg > 0 ? V / avg : 0;
   bool   big = P_FlowBigMult <= 0 || volX >= P_FlowBigMult;
   double rng = h1 - l1;
   double pos = rng > 0 ? (c1 - l1) / rng : 0.5;            // 1 = dong o dinh nen, 0 = dong o day
   double hold = buy ? pos : 1.0 - pos;                     // phan quang duong giu duoc theo chieu lenh
   double dDir = buy ? delta : -delta;                      // delta theo chieu lenh
   bool brk = FlowIsBreakout();
   bool ok = brk ? (big && dDir >= P_FlowMinDelta && hold >= P_FlowHoldPos)
                 : (big && dDir <= 0 && hold >= P_FlowHoldPos);
   g_flowState = StringFormat("delta %+.2f, khoi luong %.1fx TB, giu %.0f%%", delta, volX, hold * 100.0);
   if(!ok)
   {
      g_flowBlocked++;
      string why = brk ? (dDir >= P_FlowMinDelta && big ? "luc mua/ban bi hap thu, gia khong giu duoc" : "khong co luc chu dong ap dao")
                       : (big ? "khong thay ben kia do vao bi hap thu" : "khoi luong khong lon bat thuong");
      g_status = "Dong tien: " + why + " (" + g_flowState + ")";
   }
   return ok;
}
