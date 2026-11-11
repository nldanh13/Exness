//+------------------------------------------------------------------+
//| TrendBot/ManualEntry.mqh: Ban tu bam vao lenh + bang xu huong moi khung
//| - InpManualEntry = true: bot KHONG tu vao lenh. Tren chart co nut BUY / SELL / DONG HET.
//|   Bam 1 lan -> nut doi thanh "Bam lan nua de ..." (5 giay) -> bam lan 2 moi gui lenh.
//|   Lenh dung Magic cua bot: bot tu tinh lot (rui ro InpRiskPercent), dat SL x ATR,
//|   doi SL ve hoa von, nhoi them, trailing... dung nhu lenh bot tu vao.
//|   Van ton trong moi gioi han: lo ngay, sut giam, so lenh/ngay, nghi sau lenh thua, spread.
//| - InpTrendBoard = true: bang xu huong M1 -> D1 o goc phai tren chart (chi chay that / demo).
//+------------------------------------------------------------------+
#define ME_PFX "TBME_"

ENUM_TIMEFRAMES g_tbTF[9]   = { PERIOD_M1, PERIOD_M3, PERIOD_M5, PERIOD_M10, PERIOD_M15, PERIOD_M30, PERIOD_H1, PERIOD_H4, PERIOD_D1 };
string          g_tbName[9] = { "M1", "M3", "M5", "M10", "M15", "M30", "H1", "H4", "D1" };
int             g_tbE20[9], g_tbE50[9];
bool            g_tbReady = false;
string          g_meArmed = "";        // nut dang cho bam lan 2
datetime        g_meArmedAt = 0;
datetime        g_meLastDraw = 0;

bool MEActive() { return !MQLInfoInteger(MQL_TESTER) || MQLInfoInteger(MQL_VISUAL_MODE); }

void MELabel(const string name, const int x, const int y, const string text, const color c, const int size = 9, const string font = "Consolas")
{
   string n = ME_PFX + name;
   if(ObjectFind(0, n) < 0)
   {
      ObjectCreate(0, n, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, n, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
      ObjectSetInteger(0, n, OBJPROP_ANCHOR, ANCHOR_RIGHT_UPPER);
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

void MEButton(const string name, const int x, const int y, const int w, const int h, const string text, const color bg)
{
   string n = ME_PFX + name;
   if(ObjectFind(0, n) < 0)
   {
      ObjectCreate(0, n, OBJ_BUTTON, 0, 0, 0);
      ObjectSetInteger(0, n, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
      ObjectSetInteger(0, n, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, n, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, n, OBJPROP_COLOR, clrWhite);
      ObjectSetString(0, n, OBJPROP_FONT, "Arial Bold");
      ObjectSetInteger(0, n, OBJPROP_FONTSIZE, 9);
   }
   ObjectSetInteger(0, n, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, n, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, n, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, n, OBJPROP_YSIZE, h);
   ObjectSetString(0, n, OBJPROP_TEXT, text);
   ObjectSetInteger(0, n, OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(0, n, OBJPROP_STATE, false);
}

//--- Bang xu huong -------------------------------------------------
bool TrendBoardInit()
{
   for(int i = 0; i < 9; i++)
   {
      g_tbE20[i] = iMA(_Symbol, g_tbTF[i], 20, 0, MODE_EMA, PRICE_CLOSE);
      g_tbE50[i] = iMA(_Symbol, g_tbTF[i], 50, 0, MODE_EMA, PRICE_CLOSE);
      if(g_tbE20[i] == INVALID_HANDLE || g_tbE50[i] == INVALID_HANDLE) return false;
   }
   g_tbReady = true;
   return true;
}

// 1 = tang (gia > EMA20 > EMA50), -1 = giam (gia < EMA20 < EMA50), 0 = di ngang / chua ro
int TrendOf(const int i)
{
   double e20, e50;
   if(!GetValue(g_tbE20[i], 0, 1, e20) || !GetValue(g_tbE50[i], 0, 1, e50)) return 0;
   double c = iClose(_Symbol, g_tbTF[i], 1);
   if(c > e20 && e20 > e50) return 1;
   if(c < e20 && e20 < e50) return -1;
   return 0;
}

void MEBox(const string name, const int x, const int y, const int w, const int h)
{
   string n = ME_PFX + name;
   if(ObjectFind(0, n) < 0)
   {
      ObjectCreate(0, n, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(0, n, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
      ObjectSetInteger(0, n, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(0, n, OBJPROP_BGCOLOR, C'24,28,36');
      ObjectSetInteger(0, n, OBJPROP_COLOR, C'60,66,80');
      ObjectSetInteger(0, n, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, n, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, n, OBJPROP_BACK, false);
   }
   // goc phai: XDISTANCE tinh tu mep phai toi CANH TRAI cua hop
   ObjectSetInteger(0, n, OBJPROP_XDISTANCE, x + w);
   ObjectSetInteger(0, n, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, n, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, n, OBJPROP_YSIZE, h);
}

void DrawTrendBoard(int &y)
{
   if(!g_tbReady) return;
   int w = 210, lh = 16;
   MEBox("tb_bg", 8, y, w, 26 + 9 * lh + 22);          // tao truoc cac nhan de nam duoi chu
   y += 6;
   MELabel("tb_h", 18, y, "XU HƯỚNG  (nến đã đóng, EMA20/50)", C'130,138,152', 8, "Segoe UI"); y += 20;
   int up = 0, dn = 0;
   for(int i = 0; i < 9; i++)
   {
      int t = TrendOf(i);
      if(t > 0) up++; else if(t < 0) dn++;
      string s = t > 0 ? "TĂNG   ▲" : t < 0 ? "GIẢM   ▼" : "NGANG  –";
      color  c = t > 0 ? C'90,200,120' : t < 0 ? C'235,95,85' : C'130,138,152';
      MELabel("tb_" + g_tbName[i], 18, y, StringFormat("%-4s %s", g_tbName[i], s), c, 9, "Consolas"); y += lh;
   }
   y += 4;
   string sum = StringFormat("Tăng %d · Giảm %d · Ngang %d", up, dn, 9 - up - dn);
   MELabel("tb_sum", 18, y, sum, up >= 7 ? C'90,200,120' : dn >= 7 ? C'235,95,85' : C'205,210,220', 8, "Segoe UI"); y += 24;
}

//--- Tu nhoi lenh tay theo xu huong (v5.10.4, InpGuardPyramidMax > 1, chi tai khoan hedging)
// Them 1 lop cung chieu (magic 0, cung lot voi lop dau, SL cach 1R) khi:
//  - moi lop dang mo cung chieu va DA DOI SL ve hoa von (rui ro mo cua ca chuoi ~ 1 lop)
//  - gia di them InpGuardPyramidStepR x R tu gia vao cua lop moi nhat
//  - it nhat InpGuardPyramidTrend / 9 khung bang xu huong cung chieu
//  - chua khoa lo ngay, spread < 20% R, chua du so lop
datetime g_gpLast = 0;

int TrendCount(const bool up)
{
   if(!g_tbReady && !TrendBoardInit()) return 0;
   int c = 0;
   for(int i = 0; i < 9; i++) { int t = TrendOf(i); if(up ? t > 0 : t < 0) c++; }
   return c;
}

// Chien luoc chinh (magic P_Magic) dang dung han vi sut giam hoac da cham lo ngay: khong mo them lenh nao,
// ke ca tu nhoi / tu vao (magic 0). Hai co che nay truoc v5.10.13 doc lap voi nhau.
bool MainStopped() { return IsHalted() || DailyLossHit(); }

// Danh dau vi the do chinh bot mo (tu vao / nhoi) bang Global Variable (v5.10.13). Truoc chi dua vao ghi chu "TB ...",
// ma san co the doi / cat ghi chu. Khoa = ticket lenh da mo vi the (trade.ResultOrder()) = POSITION_IDENTIFIER cua vi the do;
// identifier khong doi suot doi vi the, con POSITION_TICKET co the doi sau thao tac cua may chu (v5.10.17 tra theo identifier).
void GuardMarkBotMade(const ulong ticket) { if(ticket > 0) GlobalVariableSet(GKey("bm" + IntegerToString((long)ticket)), 1); }
// Lenh TU VAO (khong tinh nhoi) - danh dau rieng de dem so lenh/ngay khong phu thuoc ghi chu (v5.10.14)
void GuardMarkAuto(const ulong ticket)
{
   if(ticket == 0) return;
   GuardMarkBotMade(ticket);
   GlobalVariableSet(GKey("ba" + IntegerToString((long)ticket)), 1);
   MqlDateTime d; TimeToStruct(TimeCurrent(), d);
   string k = GKey("acnt" + IntegerToString(d.year * 1000 + d.day_of_year));    // bo dem trong ngay (gio server)
   GlobalVariableSet(k, (GlobalVariableCheck(k) ? GlobalVariableGet(k) : 0) + 1);
}

// Rui ro tien te cua cac lenh tay dang mo cung chieu tren ma nay neu tat ca cham SL (lop da hoa von tinh 0)
double GuardOpenRisk(const bool buy)
{
   double sum = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetTicket(i) == 0 || !IsManualSelected()) continue;
      if((PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) != buy) continue;
      double op = PositionGetDouble(POSITION_PRICE_OPEN), sl = PositionGetDouble(POSITION_SL), v = PositionGetDouble(POSITION_VOLUME), pr = 0;
      if(sl <= 0) return -1;                                   // co lop khong SL: khong tinh duoc -> khong nhoi
      if(OrderCalcProfit(buy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL, _Symbol, v, op, sl, pr) && pr < 0) sum += -pr;
   }
   return sum;
}

void GuardPyramid()
{
   if(!InpGuardManual || InpGuardPyramidMax <= 1 || (MQLInfoInteger(MQL_TESTER) && !P_GuardBacktest) || !IsHedging()) return;
   if(TimeCurrent() - g_gpLast < 5 || GuardDayLocked() || g_gOtherChart != 0 || MainStopped()) return;
   g_gpLast = TimeCurrent();
   if(!GuardTradeOk()) return;

   int cnt = 0, dir = 0;
   double lastOpen = 0, lastR = 0, lot = 0;
   datetime lastTime = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong t = PositionGetTicket(i);
      if(t == 0 || !IsManualSelected()) continue;
      int d = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ? 1 : -1;
      if(dir != 0 && d != dir) return;                       // dang giu ca 2 chieu: khong nhoi
      dir = d; cnt++;
      double op = PositionGetDouble(POSITION_PRICE_OPEN), sl = PositionGetDouble(POSITION_SL);
      if(sl <= 0 || (d > 0 ? sl < op : sl > op)) return;   // co lop chua hoa von
      double r = GuardInitialR(t, op, sl);
      if(r <= 0) return;
      double v = PositionGetDouble(POSITION_VOLUME);
      if(lot == 0 || v < lot) lot = v;
      datetime ot = (datetime)PositionGetInteger(POSITION_TIME);
      if(ot >= lastTime) { lastTime = ot; lastOpen = op; lastR = r; }
   }
   if(cnt == 0 || cnt >= InpGuardPyramidMax) return;
   for(int i = OrdersTotal() - 1; i >= 0; i--)                // dang co lenh cho tay: de ban tu quyet
      if(OrderGetTicket(i) != 0 && IsManualPendingSelected()) return;

   bool buy = dir > 0;
   double px  = buy ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double spr = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * _Point;
   if((buy ? px - lastOpen : lastOpen - px) < InpGuardPyramidStepR * lastR) return;
   if(spr > lastR * 0.2) return;
   // Cung bo loc voi lenh tu vao (v5.10.18): gio nghi / cuoi tuan, spread toi da, tin My. Truoc day nhoi chi xet spread so voi R.
   string gw = "", nw = "";
   if(!TimeAllowed(gw)) return;
   if(P_MaxSpreadPoints > 0 && SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) > P_MaxSpreadPoints) return;
   if(P_AvoidUSNews && USNewsNear(nw)) return;
   int tc = TrendCount(buy);
   if(InpGuardPyramidTrend > 0 && tc < InpGuardPyramidTrend) return;

   // Khong the nhoi 0.005 lot neu san chi cho 0.01: bo lop, KHONG lam tron len (pha vo cap so nhan).
   if(P_GuardPyramidLotFactor <= 0 || P_GuardPyramidLotFactor > 1) return;
   double newLot = NormalizeVolume(lot * P_GuardPyramidLotFactor);
   if(newLot < SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN) - 1e-9)
   {
      if(ShouldNotify("guardPyrMin", 3600)) PrintFormat("Khong nhoi: lot %.2f x he so %.2f < lot toi thieu. Can von du de mo lop lon hon.", lot, P_GuardPyramidLotFactor);
      return;
   }
   double sl = NormalizeDouble(buy ? px - lastR : px + lastR, _Digits);
   // Tong rui ro TRUOC khi gui (v5.10.13): rui ro con mo cua cac lop (sau hoa von ~0) + lop moi khong vuot InpGuardMaxRiskPct
   double eq = AccountInfoDouble(ACCOUNT_EQUITY), newRisk = 0;
   double openRisk = GuardOpenRisk(buy);
   if(openRisk < 0 || eq <= 0) return;
   if(!OrderCalcProfit(buy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL, _Symbol, newLot, px, sl, newRisk)) return;
   newRisk = MathAbs(newRisk);
   if(InpGuardMaxRiskPct > 0 && openRisk + newRisk > eq * InpGuardMaxRiskPct / 100.0)
   {
      if(ShouldNotify("pyrRisk", 3600))
         Notify(StringFormat("[%s] KHONG NHOI: rui ro mo %.0f + lop moi %.0f = %.1f%% von, vuot gioi han %.1f%%.", _Symbol,
                             openRisk, newRisk, (openRisk + newRisk) / eq * 100.0, InpGuardMaxRiskPct));
      return;
   }
   ulong magic = P_Magic;
   trade.SetExpertMagicNumber(0);                          // lop moi van la lenh tay: moi luat bao ve ap dung
   double reqPx = buy ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   long   reqSp = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   bool ok = PrepSend() && TradeDone(buy ? trade.Buy(newLot, _Symbol, 0, sl, 0, "TB nhoi tay")
                                         : trade.Sell(newLot, _Symbol, 0, sl, 0, "TB nhoi tay"), "Nhoi lenh tay");
   if(ok) { GuardMarkBotMade(trade.ResultOrder()); LogSlippageAt(buy, reqPx, reqSp, trade.ResultPrice(), 0); }
   trade.SetExpertMagicNumber(magic);
   if(ok)
      Notify(StringFormat("[%s] NHOI THEO XU HUONG: them lop %d/%d %s %.2f lot, SL %.2f. Cac lop truoc da hoa von; %d/9 khung cung chieu.",
                          _Symbol, cnt + 1, InpGuardPyramidMax, buy ? "BUY" : "SELL", newLot, sl, tc));
}

//--- Chot loi linh hoat cho chuoi lenh tay cung chieu tren ma nay (v5.10.9). R = so tien lop DAU TIEN mat neu cham SL ban dau
// (GuardInitialR); cac lop nhoi cung lot nen 1R cua chuoi = 1R cua lop dau. Tong lai = lai + swap moi lop dang mo.
//  a) Chot gop (InpGuardBasketR > 0): tong lai dat x R thi dong het mot luot. Bat thi khong dat TP tung lop.
//     De loi chay (InpGuardRunTrend > 0): dat muc chot ma van con >= x/9 khung cung chieu thi giu tiep; dong khi xu huong yeu di
//     (duoi x/9 khung), khi co dau hieu dao chieu, hoac khi tong lai rut ve duoi muc chot (chot gan dung muc, khong tra lai them).
//  b) Chot khi dao chieu (InpGuardRevExit): nen vua dong cua khung keo SL (mac dinh khung vao lenh) bao dao chieu va tong lai
//     >= InpGuardRevMinR x R thi dong het. Dau hieu: dong cua vuot lai EMA20 nguoc chieu lenh, nen nhan chim nguoc chieu
//     (than >= than nen truoc va >= 0,5 ATR), hoac rau nen dai ve phia lenh (>= 2 lan than va >= 0,6 ATR: gia bi tu choi).
//     Chi xet nen dong SAU khi lop dau da vao. Them: gia dang giat nguoc >= InpGuardSpikeATR x ATR trong nen dang chay (khong cho nen dong).
// Lenh mo truoc khi bat bao ve (lenh cu) khong tinh, tru khi InpGuardOldTrades. Dang giu ca 2 chieu: khong lam gi.
// Nhom lenh (v5.10.11, InpGuardExitScope): 0 = chi lenh bot mo (ghi chu "TB tu vao" / "TB nhoi tay"), lenh ban tu dat khong bi
// cong lai hay dong theo; 1 = moi lenh tay cung ma (nhu v5.10.9).
ulong    g_gbLast = 0;         // GetTickCount64 (ms)
int      g_grEMA = INVALID_HANDLE, g_grATR = INVALID_HANDLE;

void GuardExitRelease()
{
   if(g_grEMA != INVALID_HANDLE) IndicatorRelease(g_grEMA);
   if(g_grATR != INVALID_HANDLE) IndicatorRelease(g_grATR);
   g_grEMA = INVALID_HANDLE; g_grATR = INVALID_HANDLE;
}

// Nen vua dong (shift 1) bao dao chieu NGUOC voi lenh dang giu (buy = dang giu Buy)
bool GuardReversal(const bool buy, const datetime firstTime, const double ext, string &why)
{
   ENUM_TIMEFRAMES tf = TFFromMin(GuardTFmin());
   bool barAfter = iTime(_Symbol, tf, 0) > firstTime;                  // nen 1 dong sau khi vao lenh
   bool candles  = InpGuardRevExit;                                     // 3 mau nen; giat nguoc xet rieng theo InpGuardSpikeATR
   if(g_grEMA == INVALID_HANDLE) g_grEMA = iMA(_Symbol, tf, 20, 0, MODE_EMA, PRICE_CLOSE);
   if(g_grATR == INVALID_HANDLE) g_grATR = iATR(_Symbol, tf, 14);
   double ema, atr;
   if(!GetValue(g_grEMA, 0, 1, ema) || !GetValue(g_grATR, 0, 1, atr) || atr <= 0) return false;
   double o1 = iOpen(_Symbol, tf, 1), c1 = iClose(_Symbol, tf, 1), h1 = iHigh(_Symbol, tf, 1), l1 = iLow(_Symbol, tf, 1);
   double o2 = iOpen(_Symbol, tf, 2), c2 = iClose(_Symbol, tf, 2);
   if(o1 <= 0 || o2 <= 0) return false;
   double body1 = MathAbs(c1 - o1), body2 = MathAbs(c2 - o2);
   string m = "M" + IntegerToString(GuardTFmin());
   if(candles && barAfter && (buy ? c1 < ema : c1 > ema))
   { why = StringFormat("nen %s dong cua %s EMA20", m, buy ? "duoi" : "tren"); return true; }
   bool against1 = buy ? c1 < o1 : c1 > o1, with2 = buy ? c2 > o2 : c2 < o2;
   if(candles && barAfter && against1 && with2 && body1 >= body2 && body1 >= 0.5 * atr)
   { why = StringFormat("nen %s nhan chim %s", m, buy ? "giam" : "tang"); return true; }
   // Giat nguoc (InpGuardSpikeATR): gia vua chay ve phia lenh roi bat nguoc >= x ATR (rau nen dang hinh thanh). Bat ngay, khong
   // cho nen dong. ext = gia tot nhat SAU KHI lop dau khop, tinh tu moi tick (v5.10.13, GuardExit doc CopyTicksRange) - khong dung dinh / day
   // cua nen da co tu truoc luc vao lenh.
   if(InpGuardSpikeATR > 0)
   {
      double px  = buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double back = buy ? ext - px : px - ext;
      if(ext > 0 && back >= InpGuardSpikeATR * atr)
      { why = StringFormat("gia giat %s %.1f ATR %s tu %s", buy ? "xuong" : "len", back / atr, m, buy ? "dinh" : "day"); return true; }
   }
   double wick = buy ? h1 - MathMax(o1, c1) : MathMin(o1, c1) - l1;
   if(candles && barAfter && wick >= 2.0 * body1 && wick >= 0.6 * atr)
   { why = StringFormat("nen %s co rau %s dai (gia bi tu choi)", m, buy ? "tren" : "duoi"); return true; }
   return false;
}

// Lenh tay do chinh bot mo: tu vao ("TB tu vao") hoac nhoi ("TB nhoi tay"). Vi the dang duoc chon.
ulong g_gbWait = 0;
bool GuardBotMade()
{
   if(GlobalVariableCheck(GKey("bm" + IntegerToString(PositionGetInteger(POSITION_IDENTIFIER))))) return true;
   if(GlobalVariableCheck(GKey("bm" + IntegerToString(PositionGetInteger(POSITION_TICKET))))) return true;
   return StringFind(PositionGetString(POSITION_COMMENT), "TB ") == 0;   // lenh mo truoc v5.10.13
}

void GuardExit()
{
   if(!InpGuardManual || (InpGuardBasketR <= 0 && !InpGuardRevExit && InpGuardSpikeATR <= 0) || (MQLInfoInteger(MQL_TESTER) && !P_GuardBacktest)) return;
   if(GetTickCount64() - g_gbLast < 250 || g_gOtherChart != 0) return;   // 4 lan / giay
   if(g_gbWait > 0 && GetTickCount64() < g_gbWait) return;              // vua dong that bai: doi 5 giay
   g_gbWait = 0;
   g_gbLast = GetTickCount64();
   if(!GuardTradeOk(true)) return;

   datetime since = GuardSince();
   int cnt = 0, dir = 0;
   double pl = 0, firstOpen = 0, firstVol = 0;
   ulong firstT = 0;
   ulong tickets[];
   long  posIds[];
   datetime firstTime = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong t = PositionGetTicket(i);
      if(t == 0 || !IsManualSelected()) continue;
      if(InpGuardExitScope == 0 && !GuardBotMade()) continue;          // chi lenh bot mo (tu vao / nhoi)
      datetime ot = (datetime)PositionGetInteger(POSITION_TIME);
      if(ot < since && !InpGuardOldTrades) continue;
      int d = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ? 1 : -1;
      if(dir != 0 && d != dir) return;
      dir = d;
      pl += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
      ArrayResize(tickets, cnt + 1); tickets[cnt++] = t;
      ArrayResize(posIds, cnt); posIds[cnt - 1] = PositionGetInteger(POSITION_IDENTIFIER);
      if(firstT == 0 || ot < firstTime)
      {
         firstT = t; firstTime = ot;
         firstOpen = PositionGetDouble(POSITION_PRICE_OPEN); firstVol = PositionGetDouble(POSITION_VOLUME);
      }
   }
   string clsKey = GKey("closing");                         // dang chot ma con khoi luong (khop mot phan), v5.10.17
   if(cnt == 0) { GlobalVariableDel(clsKey); return; }
   bool buy = dir > 0;
   if(GlobalVariableCheck(clsKey))
   {
      // Lan truoc da quyet dinh chot nhung lenh dong chi khop mot phan: dong not phan con lai, khong xet lai dieu kien
      bool fail = false;
      for(int i = 0; i < cnt; i++) if(PrepSend() && !TradeDone(trade.PositionClose(tickets[i]), "Chot loi lenh tay", "dong not phan con lai")) fail = true;
      int left = 0;
      for(int i = 0; i < cnt; i++) if(GuardPosLeft(posIds[i])) left++;
      if(left > 0 && fail) g_gbWait = GetTickCount64() + 5000;
      if(left == 0) { GlobalVariableDel(clsKey); Notify(StringFormat("[%s] CHOT LOI: da dong not phan con lai (%d lop).", _Symbol, cnt)); }
      return;
   }
   // Phi (commission) cua chuoi (v5.10.13): phi luc vao da tru vao so du nhung khong nam trong POSITION_PROFIT; luc dong thuong
   // tinh them bang ay. Tru uoc 2 lan phi vao de quyet dinh chot theo lai THAT. Tai khoan Standard cua Exness: phi = 0.
   for(int i = 0; i < cnt; i++)
      if(HistorySelectByPosition(posIds[i]))
         for(int k = HistoryDealsTotal() - 1; k >= 0; k--)
         {
            ulong dl = HistoryDealGetTicket(k);
            if(dl != 0 && HistoryDealGetInteger(dl, DEAL_ENTRY) == DEAL_ENTRY_IN)
               pl += 2.0 * (HistoryDealGetDouble(dl, DEAL_COMMISSION) + HistoryDealGetDouble(dl, DEAL_FEE));
         }

   // R cua lop dau: chi dung khi da luu luc lenh con SL ban dau; neu chua luu ma SL da ve hoa von thi bo qua (tranh R ~ 0)
   long   firstId = GuardPosId(firstT);                     // khoa trang thai theo identifier (v5.10.18)
   string key = GKey("r" + IntegerToString(firstId)), keyOld = GKey("r" + IntegerToString((long)firstT));
   double r = 0;
   if(GlobalVariableCheck(key)) r = GlobalVariableGet(key);
   else if(GlobalVariableCheck(keyOld)) r = GlobalVariableGet(keyOld);
   else if(PositionSelectByTicket(firstT))
   {
      double sl = PositionGetDouble(POSITION_SL);
      if(sl > 0 && (buy ? sl < firstOpen : sl > firstOpen)) r = GuardInitialR(firstT, firstOpen, sl);
   }
   if(r <= 0) return;
   double rMoney = 0;
   if(!OrderCalcProfit(buy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL, _Symbol, firstVol, firstOpen,
                       buy ? firstOpen - r : firstOpen + r, rMoney)) return;
   rMoney = MathAbs(rMoney);
   if(rMoney <= 0) return;
   double rNow = pl / rMoney;

   string why = "", rev = "";
   // Gia tot nhat tu luc lop dau khop (cho chot khi giat nguoc): bat dau tu gia vao, cap nhat moi giay
   // Doc MOI tick tu lan kiem tra truoc (CopyTicksRange), khong chi gia luc kiem tra, nen khong bo sot dinh / day giua hai lan.
   string extKey = GKey("ext" + IntegerToString(firstId)), extMsKey = GKey("extms" + IntegerToString(firstId));
   double ext = GlobalVariableCheck(extKey) ? GlobalVariableGet(extKey) : firstOpen;
   ulong  fromMs = GlobalVariableCheck(extMsKey) ? (ulong)GlobalVariableGet(extMsKey) : (ulong)firstTime * 1000;
   // Toi da 5000 tick moi lan (v5.10.17): lenh mo lau thi doc dan qua nhieu chu ky, khong doc mot luc ca ngay tick.
   // Doc loi (lich su tick chua tai xong, tra -1): giu nguyen moc, lan sau doc lai; bao log toi da 1 lan / phut.
   MqlTick tk[];
   int nt = CopyTicks(_Symbol, tk, COPY_TICKS_INFO, fromMs, 5000);
   if(nt < 0 && ShouldNotify("tickErr", 60)) Print(StringFormat("[%s] Chua doc duoc tick (loi %d), dung gia hien tai", _Symbol, GetLastError()));
   ulong lastMs = fromMs;
   for(int i = 0; i < nt; i++)
   {
      double p = buy ? tk[i].bid : tk[i].ask;
      if(p > 0 && (buy ? p > ext : p < ext)) ext = p;
      if((ulong)tk[i].time_msc > lastMs) lastMs = (ulong)tk[i].time_msc;
   }
   double pxNow = buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(pxNow > 0 && (buy ? pxNow > ext : pxNow < ext)) ext = pxNow;
   GlobalVariableSet(extKey, ext);
   GlobalVariableSet(extMsKey, (double)lastMs);
   string runKey = GKey("run" + IntegerToString(firstId));      // da qua muc chot gop, dang de loi chay
   bool running = GlobalVariableCheck(runKey);
   if((InpGuardRevExit || InpGuardSpikeATR > 0) && rNow >= InpGuardRevMinR && GuardReversal(buy, firstTime, ext, rev))
      why = "dau hieu dao chieu: " + rev;
   else if(InpGuardBasketR > 0 && rNow >= InpGuardBasketR)
   {
      int tc = InpGuardRunTrend > 0 ? TrendCount(buy) : 0;
      if(InpGuardRunTrend > 0 && tc >= InpGuardRunTrend)
      {
         if(!running)
         {
            GlobalVariableSet(runKey, 1);
            Notify(StringFormat("[%s] DE LOI CHAY: %d lop %s da loi %.1fR (muc chot %.1fR) nhung %d/9 khung con cung chieu. "
                                "Bot giu tiep, chot khi xu huong yeu, co dau hieu dao chieu hoac loi rut ve %.1fR.",
                                _Symbol, cnt, buy ? "BUY" : "SELL", rNow, InpGuardBasketR, tc, InpGuardBasketR));
         }
         return;
      }
      why = running ? StringFormat("xu huong yeu di (con %d/9 khung cung chieu)", tc) : StringFormat("dat muc chot gop %.1fR", InpGuardBasketR);
   }
   else if(running && InpGuardBasketR > 0 && rNow < InpGuardBasketR)
      why = StringFormat("loi rut ve duoi muc chot %.1fR", InpGuardBasketR);
   if(why == "") return;

   bool fail = false;
   for(int i = 0; i < cnt; i++)
      if(PrepSend() && !TradeDone(trade.PositionClose(tickets[i]), "Chot loi lenh tay", why)) fail = true;
   if(fail) g_gbWait = GetTickCount64() + 5000;
   // Chi tinh la DA DONG khi vi the that su khong con (v5.10.17): khop mot phan (DONE_PARTIAL) van con khoi luong,
   // giu trang thai chot gop de chu ky sau (250 ms) dong tiep phan con lai.
   int closed = 0;
   for(int i = 0; i < cnt; i++) if(!GuardPosLeft(posIds[i])) closed++;
   if(closed == cnt) { if(running) GlobalVariableDel(runKey); GlobalVariableDel(extKey); GlobalVariableDel(extMsKey); }
   else GlobalVariableSet(clsKey, dir);                    // con khoi luong: chu ky sau dong tiep
   Notify(StringFormat("[%s] CHOT LOI: da dong %d/%d lop %s, tong lai khoang %.0f %s (%.1fR). Ly do: %s.", _Symbol, closed, cnt,
                       buy ? "BUY" : "SELL", pl, AccountInfoString(ACCOUNT_CURRENCY), rNow, why));
}

//--- Bot tu vao lenh dau tien o che do bao ve lenh tay (v5.10.5, InpGuardAutoEntry, THU NGHIEM - chua backtest)
// Vao 1 lenh (magic 0, ghi chu "TB tu vao", lot nho nhat, SL cach InpGuardSLPct %) khi:
//  - khong co lenh tay / lenh cho nao tren ma nay, chua khoa lo ngay, Algo Trading bat
//  - it nhat InpGuardAutoTrend / 9 khung cung chieu, va H1 + H4 cung chieu (InpGuardAutoNeedHTF)
//  - nen khung InpGuardAutoTFmin (mac dinh M5) vua dong cham EMA20 cung khung roi dong cua tro lai ve phia xu huong (gia hoi roi bat lai)
//  - chua qua InpGuardAutoMaxDay lenh tu vao trong ngay; da qua InpGuardAutoCooldownMin phut tu lenh tay thua gan nhat
// Sau khi vao, lenh duoc xu ly nhu lenh tay: hoa von, keo SL, nhoi theo xu huong, khoa lo ngay.
datetime g_aeLastBar = 0;
int      g_aeSkipDay = 0;      // ngay da bao "bo tin hieu vi lot qua lon"

int GuardAutoCountToday(datetime &lastLossClose)
{
   lastLossClose = 0;
   MqlDateTime dt; TimeToStruct(TimeCurrent(), dt);
   datetime dayStart = TimeCurrent() - (dt.hour * 3600 + dt.min * 60 + dt.sec);
   int n = 0;
   if(!HistorySelect(dayStart - 86400, TimeCurrent() + 60)) return 0;
   for(int i = HistoryDealsTotal() - 1; i >= 0; i--)
   {
      ulong d = HistoryDealGetTicket(i);
      if(d == 0 || HistoryDealGetInteger(d, DEAL_MAGIC) != 0 || HistoryDealGetString(d, DEAL_SYMBOL) != _Symbol) continue;
      datetime t = (datetime)HistoryDealGetInteger(d, DEAL_TIME);
      long entry = HistoryDealGetInteger(d, DEAL_ENTRY);
      if(entry == DEAL_ENTRY_IN && t >= dayStart &&
         (StringFind(HistoryDealGetString(d, DEAL_COMMENT), "TB tu vao") == 0 ||
          GlobalVariableCheck(GKey("ba" + IntegerToString(HistoryDealGetInteger(d, DEAL_POSITION_ID)))))) n++;
      if(entry != DEAL_ENTRY_IN && lastLossClose == 0 &&
         HistoryDealGetDouble(d, DEAL_PROFIT) + HistoryDealGetDouble(d, DEAL_SWAP) + HistoryDealGetDouble(d, DEAL_COMMISSION) < 0)
         lastLossClose = t;
   }
   // Bo dem rieng (tang moi lan tu vao thanh cong): lay so lon hon, de san doi / cat ghi chu cung khong lam dem thieu
   MqlDateTime d0; TimeToStruct(TimeCurrent(), d0);
   string k = GKey("acnt" + IntegerToString(d0.year * 1000 + d0.day_of_year));
   if(GlobalVariableCheck(k)) n = MathMax(n, (int)GlobalVariableGet(k));
   return n;
}

void GuardAutoEntry()
{
   if(!InpGuardManual || !InpGuardAutoEntry || (MQLInfoInteger(MQL_TESTER) && !P_GuardBacktest) || g_gOtherChart != 0) return;
   int ti = InpGuardAutoTFmin == 1 ? 0 : InpGuardAutoTFmin == 3 ? 1 : InpGuardAutoTFmin == 10 ? 3 :
            InpGuardAutoTFmin == 15 ? 4 : InpGuardAutoTFmin == 30 ? 5 : 2;      // vi tri trong bang xu huong (mac dinh M5)
   ENUM_TIMEFRAMES tf = g_tbTF[ti];
   datetime bar = iTime(_Symbol, tf, 0);
   if(bar == 0 || bar == g_aeLastBar) return;                 // moi nen xet 1 lan
   if(GuardDayLocked() || MainStopped()) return;
   // Bo loc chung voi chien luoc chinh (v5.10.13): khung gio nghi / cuoi tuan / tin (InpSkipWeekend, InpBlock*...) va spread toi da
   string gateWhy = "";
   if(!TimeAllowed(gateWhy)) return;
   if(P_MaxSpreadPoints > 0 && SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) > P_MaxSpreadPoints) return;
   if(!GuardTradeOk()) return;
   for(int i = PositionsTotal() - 1; i >= 0; i--) if(PositionGetTicket(i) != 0 && IsManualSelected()) return;
   for(int i = OrdersTotal() - 1; i >= 0; i--) if(OrderGetTicket(i) != 0 && IsManualPendingSelected()) return;
   if(!g_tbReady && !TrendBoardInit()) return;

   double e20;
   if(!GetValue(g_tbE20[ti], 0, 1, e20)) return;
   g_aeLastBar = bar;
   double lo = iLow(_Symbol, tf, 1), hi = iHigh(_Symbol, tf, 1), cl = iClose(_Symbol, tf, 1);
   int up = TrendCount(true), dn = TrendCount(false);
   int dir = 0;
   if(up >= InpGuardAutoTrend && lo <= e20 && cl > e20) dir = 1;
   if(dn >= InpGuardAutoTrend && hi >= e20 && cl < e20) dir = -1;
   if(dir == 0) return;
   // Khung lon phai cung chieu: tranh truong hop 6/9 khung nho (M1..M30) quay len trong khi H1/H4 van giam
   if(InpGuardAutoNeedHTF && (TrendOf(6) != dir || TrendOf(7) != dir)) return;   // g_tbTF[6] = H1, [7] = H4
   // Bo loc thi truong cua chien luoc chinh (v5.10.16): tin My (InpAvoidUSNews), funding, Fear & Greed, su chu y, Nasdaq.
   // Cac ham nay ghi g_status cua chien luoc chinh, nen giu lai trang thai cu.
   string keepStatus = g_status;
   bool mktOk = FundingOk(dir > 0) && MarketFiltersOk(dir > 0);
   g_status = keepStatus;
   if(!mktOk) return;

   datetime lastLoss;
   int n = GuardAutoCountToday(lastLoss);
   if(InpGuardAutoMaxDay > 0 && n >= InpGuardAutoMaxDay) return;
   if(InpGuardAutoCooldownMin > 0 && lastLoss > 0 && TimeCurrent() - lastLoss < InpGuardAutoCooldownMin * 60) return;

   bool   buy = dir > 0;
   double px  = buy ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double slp = InpGuardSLPct > 0 ? InpGuardSLPct : 0.25;
   if(px <= 0) return;                                      // chua co gia (mat ket noi / chua tai)
   double sl  = NormalizeDouble(buy ? px * (1 - slp / 100.0) : px * (1 + slp / 100.0), _Digits);
   if(SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * _Point > MathAbs(px - sl) * 0.2) return;   // spread > 20% R: nhu luat nhoi
   double stopsMin = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
   if(stopsMin > 0 && MathAbs(px - sl) < stopsMin * 1.1) return;      // SL gan hon muc san cho phep: san se tu choi
   // Khoi luong tinh TRUOC khi vao (v5.10.10): lo khi cham SL khong vuot ngan sach. Truoc day luon vao lot nho nhat roi de
   // bo bao ve (buoc 4 trong GuardManual) dong / giam lot SAU khi da khop - mat spread va truot gia vo ich.
   //  - InpGuardAutoRiskPct > 0: lot = von x % / lo cua 1 lot tai SL, lam tron xuong theo buoc lot.
   //  - InpGuardAutoRiskPct = 0: lot nho nhat.
   //  - Tran: InpGuardMaxRiskPct. Lot nho nhat da vuot tran (hoac ngan sach) thi BO tin hieu, bao 1 lan / ngay.
   double vmin = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN), vmax = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double eq   = AccountInfoDouble(ACCOUNT_EQUITY);
   double loss1 = 0;                                        // so tien lo cua 1,0 lot neu cham SL
   if(!OrderCalcProfit(buy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL, _Symbol, 1.0, px, sl, loss1) || loss1 >= 0 || eq <= 0) return;
   loss1 = -loss1;
   double cap = InpGuardMaxRiskPct > 0 ? eq * InpGuardMaxRiskPct / 100.0 : 0;
   double budget = InpGuardAutoRiskPct > 0 ? eq * InpGuardAutoRiskPct / 100.0 : 0;
   if(cap > 0 && budget > cap) budget = cap;
   double limPct = (budget > 0 ? budget : cap) / eq * 100.0;
   double lot = vmin;
   if(budget > 0 && step > 0) lot = MathMin(MathFloor(budget / loss1 / step + 1e-9) * step, vmax);
   lot = NormalizeDouble(lot, 2);
   double riskMin = loss1 * vmin;
   bool tooBig = lot < vmin - 1e-9 || (cap > 0 && loss1 * lot > cap * 1.0001);
   if(tooBig)
   {
      MqlDateTime d; TimeToStruct(TimeCurrent(), d);
      int dayKey = d.year * 1000 + d.day_of_year;
      if(g_aeSkipDay != dayKey)
      {
         g_aeSkipDay = dayKey;
         Notify(StringFormat("[%s] BO TIN HIEU TU VAO: %.2f lot (nho nhat) voi SL %.2f%% se lo %.0f %s = %.1f%% von, vuot gioi han %.1f%%. "
                             "Can von lon hon, SL gan hon hoac noi gioi han. Bao 1 lan / ngay.", _Symbol, vmin, slp, riskMin,
                             AccountInfoString(ACCOUNT_CURRENCY), riskMin / eq * 100.0, limPct));
      }
      return;
   }
   ulong magic = P_Magic;
   trade.SetExpertMagicNumber(0);                          // xu ly nhu lenh tay
   double reqPx = buy ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   long   reqSp = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   bool ok = PrepSend() && TradeDone(buy ? trade.Buy(lot, _Symbol, 0, sl, 0, "TB tu vao")
                                         : trade.Sell(lot, _Symbol, 0, sl, 0, "TB tu vao"), "Tu vao lenh");
   if(ok) { GuardMarkAuto(trade.ResultOrder()); LogSlippageAt(buy, reqPx, reqSp, trade.ResultPrice(), 0); }
   trade.SetExpertMagicNumber(magic);
   if(ok)
      Notify(StringFormat("[%s] BOT TU VAO LENH (thu nghiem): %s %.2f lot, SL %.2f (rui ro %.1f%% von). %d/9 khung cung chieu, nen %s hoi ve EMA20 roi bat lai. Lenh thu %d hom nay.",
                          _Symbol, buy ? "BUY" : "SELL", lot, sl, loss1 * lot / eq * 100.0, buy ? up : dn, g_tbName[ti], n + 1));
}

//--- Nut vao lenh --------------------------------------------------
double MEPreviewLots(const double slDist)
{
   double ts = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double tv = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE_LOSS);
   if(tv <= 0) tv = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   if(ts <= 0 || tv <= 0 || slDist <= 0) return 0;
   double lots = BotEquity() * P_RiskPercent / 100.0 / (slDist / ts * tv);
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   return step > 0 ? MathFloor(lots / step) * step : lots;
}

double MESlDist()
{
   double atr;
   if(!GetValue(hATR, 0, 1, atr) || atr <= 0) return 0;
   return SLAtr(atr) * P_ATRMult;
}

int OwnDirection()    // 1 = dang giu Buy, -1 = Sell, 0 = khong giu
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
      if(PositionGetTicket(i) != 0 && IsOwnSelected())
         return PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ? 1 : -1;
   return 0;
}

void DrawManualButtons(int &y)
{
   if(!P_ManualEntry) return;
   if(g_meArmed != "" && TimeCurrent() - g_meArmedAt > 5) g_meArmed = "";
   double sl = MESlDist();
   double lots = MEPreviewLots(sl);
   double vmin = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   string info = sl > 0 ? StringFormat("~%.2f lot | SL cach %s | rui ro %.1f%%", lots, DoubleToString(sl, 0), P_RiskPercent) : "Dang tai ATR...";
   if(sl > 0 && lots < vmin) info = StringFormat("Lot tinh ra %.3f < %.2f: von qua nho cho SL nay", lots, vmin);
   MELabel("me_info", 12, y, info, clrSilver, 8, "Arial"); y += 16;
   int dir = OwnDirection();
   string bt = g_meArmed == "buy"  ? "BAM LAN NUA DE BUY"  : (dir > 0 ? "BUY (nhoi them)" : "BUY");
   string st = g_meArmed == "sell" ? "BAM LAN NUA DE SELL" : (dir < 0 ? "SELL (nhoi them)" : "SELL");
   // Nut o goc phai: XDISTANCE tinh tu mep phai toi CANH TRAI cua nut
   MEButton("buy",  12 + 124 + 120, y, 120, 30, bt, g_meArmed == "buy"  ? clrDarkOrange : clrSeaGreen);
   MEButton("sell", 12 + 120,       y, 120, 30, st, g_meArmed == "sell" ? clrDarkOrange : clrFireBrick);
   y += 34;
   MEButton("close", 12 + 244, y, 244, 22, g_meArmed == "close" ? "BAM LAN NUA DE DONG HET" : "DONG HET LENH CUA BOT", g_meArmed == "close" ? clrDarkOrange : clrDimGray);
   y += 28;
}

void ManualUI()
{
   if(!MEActive() || (!P_ManualEntry && !P_TrendBoard)) return;
   if(TimeCurrent() - g_meLastDraw < 1 && g_meArmed == "") return;
   g_meLastDraw = TimeCurrent();
   int y = 20;
   DrawManualButtons(y);
   if(P_TrendBoard) DrawTrendBoard(y);
   ChartRedraw();
}

void ManualUIDelete()
{
   ObjectsDeleteAll(0, ME_PFX);
   if(g_tbReady) for(int i = 0; i < 9; i++) { IndicatorRelease(g_tbE20[i]); IndicatorRelease(g_tbE50[i]); }
   g_tbReady = false;
}

// Bam BUY / SELL: kiem tra gioi han, roi gui lenh nhu bot tu vao (lot theo rui ro, SL x ATR)
void ManualFire(const bool buy)
{
   if(IsHalted() || GuardHalted()) { Notify("[" + _Symbol + "] Bot dang DUNG HAN (sut giam toi da): khong vao lenh, ke ca nhoi."); return; }
   int dir = OwnDirection();
   // Cung bo loc voi bot cho CA vao moi lan nhoi tay (v5.10.19): truoc day nut nhoi bo qua lo ngay, gio nghi, spread, tin My
   string nw = "", gw = "";
   if(DailyLossHit()) { Notify("[" + _Symbol + "] Cham gioi han lo ngay: khong vao / nhoi toi het ngay."); return; }
   if(P_AvoidUSNews && USNewsNear(nw)) { Notify("[" + _Symbol + "] Gan tin My (" + nw + "): khong vao / nhoi."); return; }
   if(dir != 0)
   {
      if((dir > 0) != buy) { Notify("[" + _Symbol + "] Dang giu lenh nguoc chieu. Bam DONG HET truoc neu muon dao chieu."); return; }
      if(!TimeAllowed(gw)) { Notify("[" + _Symbol + "] Tam nghi: " + gw + ", chua nhoi."); return; }
      if(P_MaxSpreadPoints > 0 && SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) > P_MaxSpreadPoints) { Notify("[" + _Symbol + "] Spread qua rong, chua nhoi."); return; }
      // Nhoi tay: chi khi cac lop cu da doi duoc SL ve hoa von (giong luat nhoi cua bot)
      int cnt = 0;
      for(int i = PositionsTotal() - 1; i >= 0; i--) if(PositionGetTicket(i) != 0 && IsOwnSelected()) cnt++;
      if(cnt >= MathMax(P_PyramidMax, 1)) { Notify(StringFormat("[%s] Da du %d lop (InpPyramidMax), khong nhoi them.", _Symbol, cnt)); return; }
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         ulong tk = PositionGetTicket(i);
         if(tk == 0 || !IsOwnSelected()) continue;
         double op = PositionGetDouble(POSITION_PRICE_OPEN), sl = PositionGetDouble(POSITION_SL), tp = PositionGetDouble(POSITION_TP);
         double px = buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         if(buy ? px <= op : px >= op) { Notify("[" + _Symbol + "] Lop cu dang lo: KHONG nhoi vao lenh dang lo."); return; }
         bool need = buy ? (sl < op) : (sl <= 0 || sl > op);
         if(need) TradeDone(PrepSend() && trade.PositionModify(tk, NormalizeDouble(op, _Digits), tp), "Sua SL", "#" + (string)tk);
      }
      double tol = _Point * 2;
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         if(PositionGetTicket(i) == 0 || !IsOwnSelected()) continue;
         double op = PositionGetDouble(POSITION_PRICE_OPEN), sl = PositionGetDouble(POSITION_SL);
         if(!(sl > 0 && (buy ? sl >= op - tol : sl <= op + tol))) { Notify("[" + _Symbol + "] Chua doi duoc SL lop cu ve hoa von, chua nhoi. Thu lai sau."); return; }
      }
   }
   else if(!EntryGatesOk()) { Notify("[" + _Symbol + "] Chua vao lenh: " + g_status); return; }
   double atr;
   if(!GetValue(hATR, 0, 1, atr) || atr <= 0) { Notify("[" + _Symbol + "] Chua co ATR, thu lai sau."); return; }
   g_sigSL = 0; g_sigTP = 0;
   int r = SendEntry(buy, atr, true);
   if(r <= 0) Notify("[" + _Symbol + "] Khong vao duoc lenh: " + g_status);
}

void ManualChartEvent(const int id, const string sparam)
{
   if(id != CHARTEVENT_OBJECT_CLICK || StringFind(sparam, ME_PFX) != 0 || !P_ManualEntry) return;
   string b = StringSubstr(sparam, StringLen(ME_PFX));
   if(b != "buy" && b != "sell" && b != "close") return;
   ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
   if(g_meArmed != b || TimeCurrent() - g_meArmedAt > 5)
   {
      g_meArmed = b; g_meArmedAt = TimeCurrent();      // bam lan 1: chi "len co"
   }
   else
   {
      g_meArmed = "";
      if(b == "close") { if(HasOwnPosition()) { g_status = "Ban bam dong het"; CloseAll(); } }
      else ManualFire(b == "buy");
   }
   g_meLastDraw = 0;
   ManualUI();
}
