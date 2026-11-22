//+------------------------------------------------------------------+
//| TrendBot/Intervene.mqh (v5.50.0): Nhat ky can thiep giua BAN va BOT
//| Ghi Common\Files\TrendBot_cantiep.csv, moi dong = 1 hanh dong, co gio, gia, ly do:
//|  - BAN mo / dong / dong mot phan lenh (MT5 cho biet tu web, dien thoai hay MT5 may tinh)
//|  - BAN dat / doi / xoa SL, TP lenh dang mo; dat / sua / huy lenh cho
//|  - BOT dat / doi SL, dat TP, dong lenh, giam lot, sua / huy lenh cho (kem ly do), ca khi lam that bai
//|  - BOT khoa lenh tay (lo ngay, bucket, sut giam); bot bat / tat (go khoi chart, doi thong so...)
//|  - SAN dong lenh vi cham SL / TP / stop out, kem "SL nay do ai dat lan cuoi"
//| Chi tai khoan that / demo, bat cung InpJournal.
//| Phan "BAN lam gi": 1 chart moi tai khoan ghi (theo doi moi ma). Phan "BOT lam gi": chart nao gui lenh thi chart do ghi.
//| MT5 khong cho biet ai sua SL / TP. Bot tu danh dau moi lan chinh no sua; thay doi khong co dau cua bot = BAN
//| (hoac EA khac). Cho 3 giay truoc khi ket luan de chart bot khac kip danh dau.
//+------------------------------------------------------------------+
#define IV_FILE     "TrendBot_cantiep.csv"
#define IV_HEAD     "ThoiGianServer,GioMay,Ai,HanhDong,Ma,Ve,LenhCua,Chieu,Lot,Gia,SL_Cu,SL_Moi,TP_Cu,TP_Moi,LaiLo,GiaThiTruong,LyDo"
#define IV_GRACE_MS 3000

struct IvItem
{
   ulong  t;            // ticket vi the / lenh cho
   bool   pend;         // true = lenh cho
   string sym;
   string owner;        // lenh cua ai: TAY / BOT tu vao / BOT magic N
   long   magic;
   int    type;         // 0 BUY, 1 SELL, 2..7 lenh cho
   double vol, price, sl, tp;
   ulong  waitMs;       // thay doi chua thay dau cua bot: cho IV_GRACE_MS roi moi ghi la BAN sua
   double wvol, wprice, wsl, wtp;
   ulong  goneMs;       // lenh cho bien mat: cho lich su cap nhat
   bool   live;
};
IvItem g_iv[];
bool   g_ivInit    = false;   // da chup trang thai lan dau
bool   g_ivOwner   = false;   // chart nay ghi phan "BAN lam gi"
bool   g_ivStarted = false;
ulong  g_ivOwnMs   = 0;

bool   IvOn() { return InpJournal && !MQLInfoInteger(MQL_TESTER); }
string IvKey(const string k) { return "TBIV_" + IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)) + "_" + k; }
string IvT(const ulong t) { return IntegerToString((long)t); }

int IvDigits(const string sym)
{
   int dg = sym != "" ? (int)SymbolInfoInteger(sym, SYMBOL_DIGITS) : 0;
   return dg > 0 ? dg : 2;
}
// Gia / lot: <= 0 = de trong
string IvPx(const string sym, const double v) { return v > 0 ? DoubleToString(v, IvDigits(sym)) : ""; }
// SL / TP: < 0 = khong ro (de trong), 0 = "khong" (khong co SL / TP)
string IvStop(const string sym, const double v) { return v < 0 ? "" : v == 0 ? "khong" : DoubleToString(v, IvDigits(sym)); }
bool   IvSame(const string sym, const double a, const double b)
{
   double pt = sym != "" ? SymbolInfoDouble(sym, SYMBOL_POINT) : 0;
   if(pt <= 0) pt = 1e-8;
   return MathAbs(a - b) < pt * 0.5;
}

string IvSide(const int ty)
{
   switch(ty)
   {
      case 0: return "BUY";
      case 1: return "SELL";
      case 2: return "BUY LIMIT";
      case 3: return "SELL LIMIT";
      case 4: return "BUY STOP";
      case 5: return "SELL STOP";
      case 6: return "BUY STOP LIMIT";
      case 7: return "SELL STOP LIMIT";
   }
   return "";
}

// Ai lam: theo DEAL_REASON / ORDER_REASON cua MT5
string IvWhoDeal(const long r)
{
   if(r == DEAL_REASON_CLIENT) return "BAN (MT5 may tinh)";
   if(r == DEAL_REASON_MOBILE) return "BAN (dien thoai)";
   if(r == DEAL_REASON_WEB)    return "BAN (web)";
   if(r == DEAL_REASON_EXPERT) return "BOT";
   if(r == DEAL_REASON_SL)     return "SAN (cham SL)";
   if(r == DEAL_REASON_TP)     return "SAN (cham TP)";
   if(r == DEAL_REASON_SO)     return "SAN (stop out)";
   return "SAN / KHAC";
}
string IvWhoOrder(const long r)
{
   if(r == ORDER_REASON_CLIENT) return "BAN (MT5 may tinh)";
   if(r == ORDER_REASON_MOBILE) return "BAN (dien thoai)";
   if(r == ORDER_REASON_WEB)    return "BAN (web)";
   if(r == ORDER_REASON_EXPERT) return "BOT";
   return "SAN / KHAC";
}

// Lenh cua ai: magic khac 0 = bot; magic 0 do bot tu vao (danh dau cua Guard / comment "TB ") = BOT tu vao; con lai = TAY
string IvOwnerOf(const string sym, const long magic, const string cmt, const ulong t)
{
   if(magic != 0) return "BOT magic " + IntegerToString(magic);
   string g = "TBG_" + IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)) + "_" + sym + "_";
   if(GlobalVariableCheck(g + "bm" + IvT(t)) || GlobalVariableCheck(g + "ba" + IvT(t)) || StringFind(cmt, "TB ") == 0)
      return "BOT tu vao (magic 0)";
   return "TAY";
}

void IvAppend(const string line)
{
   for(int k = 0; k < 3; k++)
   {
      int h = FileOpen(IV_FILE, FILE_READ | FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_COMMON | FILE_SHARE_READ | FILE_SHARE_WRITE);
      if(h == INVALID_HANDLE) { Sleep(20); continue; }     // chart khac dang ghi
      if(FileSize(h) == 0) FileWriteString(h, IV_HEAD + "\r\n");
      FileSeek(h, 0, SEEK_END);
      FileWriteString(h, line + "\r\n");
      FileClose(h);
      return;
   }
   Print("Khong ghi duoc ", IV_FILE, " loi ", GetLastError());
}

// vol / price <= 0 va SL / TP < 0 = de trong
void IvWrite(const datetime when, const string who, const string act, const string sym, const ulong tk, const string owner,
             const string side, const double vol, const double price, const double osl, const double nsl,
             const double otp, const double ntp, const string pl, const string why)
{
   datetime t = when > 0 ? when : TimeCurrent();
   string mkt = sym != "" ? IvPx(sym, SymbolInfoDouble(sym, SYMBOL_BID)) : "";
   string line = StringFormat("%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s",
                              TimeToString(t, TIME_DATE | TIME_SECONDS), TimeToString(TimeLocal(), TIME_DATE | TIME_SECONDS),
                              JClean(who), JClean(act), sym, tk > 0 ? IvT(tk) : "", JClean(owner), side,
                              vol > 0 ? DoubleToString(vol, 2) : "", IvPx(sym, price),
                              IvStop(sym, osl), IvStop(sym, nsl), IvStop(sym, otp), IvStop(sym, ntp),
                              pl, mkt, JClean(why));
   IvAppend(line);
   PrintFormat("[CAN THIEP] %s | %s | %s %s | %s", who, act, sym, tk > 0 ? "#" + IvT(tk) : "", why);
}

// Ghi chu chung (khoa, bat / tat bot...)
void IvNote(const string who, const string act, const string sym, const string why)
{
   if(!IvOn()) return;
   IvWrite(0, who, act, sym, 0, "", "", 0, 0, -1, -1, -1, -1, "", why);
}

// Ten hanh dong sua SL / TP. osl / otp < 0 = khong ro gia tri cu.
string IvModAct(const string sym, const bool buy, const double osl, const double nsl, const double otp, const double ntp)
{
   string s = "", p = "";
   if(osl < 0) { if(nsl > 0) s = "DAT / DOI SL"; }
   else if(!IvSame(sym, osl, nsl))
   {
      if(nsl <= 0)      s = "XOA SL";
      else if(osl <= 0) s = "DAT SL";
      else if(buy ? nsl > osl : nsl < osl) s = "DOI SL sat gia hon";
      else              s = "NOI SL xa hon (tang rui ro)";
   }
   if(otp < 0) { if(ntp > 0) p = "DAT / DOI TP"; }
   else if(!IvSame(sym, otp, ntp)) p = ntp <= 0 ? "XOA TP" : otp <= 0 ? "DAT TP" : "DOI TP";
   if(s != "" && p != "") return s + " + " + p;
   if(s != "") return s;
   if(p != "") return p;
   return "SUA SL / TP";
}

//--- Dau cua bot: chart bot ghi lai gia tri vua sua, chart theo doi doi chieu de khong ghi nham la BAN sua
void IvDelMark(const string n) { GlobalVariableDel(n); GlobalVariableDel(n + "s"); GlobalVariableDel(n + "p"); GlobalVariableDel(n + "x"); }
void IvMark(const string kind, const ulong t, const double sl, const double tp, const double price)
{
   string n = IvKey(kind + IvT(t));
   GlobalVariableSet(n + "s", sl); GlobalVariableSet(n + "p", tp); GlobalVariableSet(n + "x", price);
   GlobalVariableSet(n, (double)TimeLocal());               // dat sau cung: co n la du 3 gia tri
}
bool IvBotMark(const int k, const double price, const double sl, const double tp)
{
   string n = IvKey((g_iv[k].pend ? "o" : "m") + IvT(g_iv[k].t));
   if(!GlobalVariableCheck(n)) return false;
   string sym = g_iv[k].sym;
   bool fresh = TimeLocal() - (datetime)GlobalVariableGet(n) <= 120;
   bool same = fresh && IvSame(sym, GlobalVariableGet(n + "s"), sl) && IvSame(sym, GlobalVariableGet(n + "p"), tp) &&
               (!g_iv[k].pend || IvSame(sym, GlobalVariableGet(n + "x"), price));
   if(same || !fresh) IvDelMark(n);
   return same;
}

//--- Anh chup lenh dang co ---------------------------------------------
int IvFind(const ulong t, const bool pend)
{
   for(int i = ArraySize(g_iv) - 1; i >= 0; i--) if(g_iv[i].t == t && g_iv[i].pend == pend) return i;
   return -1;
}
void IvApply(const int k, const double price, const double sl, const double tp, const double vol)
{
   g_iv[k].price = price; g_iv[k].sl = sl; g_iv[k].tp = tp; g_iv[k].vol = vol; g_iv[k].waitMs = 0;
}
bool IvDiff(const int k, const double price, const double sl, const double tp, const double vol)
{
   string s = g_iv[k].sym;
   if(!IvSame(s, sl, g_iv[k].sl) || !IvSame(s, tp, g_iv[k].tp)) return true;
   return g_iv[k].pend && (!IvSame(s, price, g_iv[k].price) || MathAbs(vol - g_iv[k].vol) > 1e-9);
}
bool IvDiffW(const int k, const double price, const double sl, const double tp, const double vol)
{
   string s = g_iv[k].sym;
   if(!IvSame(s, sl, g_iv[k].wsl) || !IvSame(s, tp, g_iv[k].wtp)) return true;
   return g_iv[k].pend && (!IvSame(s, price, g_iv[k].wprice) || MathAbs(vol - g_iv[k].wvol) > 1e-9);
}

// BAN sua SL / TP / lenh cho: ghi tu gia tri cu trong anh chup sang gia tri moi
void IvUserRow(const int k, const double price, const double sl, const double tp, const double vol, const double fl)
{
   string sym = g_iv[k].sym;
   bool buy = g_iv[k].type % 2 == 0;
   string act = IvModAct(sym, buy, g_iv[k].sl, sl, g_iv[k].tp, tp);
   string why = "khong phai bot nay sua (ban sua tren web / dien thoai / MT5, hoac EA khac)";
   if(g_iv[k].pend)
   {
      string ch = "";
      if(!IvSame(sym, price, g_iv[k].price)) ch += " gia vao " + IvPx(sym, g_iv[k].price) + " -> " + IvPx(sym, price);
      if(MathAbs(vol - g_iv[k].vol) > 1e-9) ch += StringFormat(" lot %.2f -> %.2f", g_iv[k].vol, vol);
      act = "SUA lenh cho: " + act;
      if(ch != "") why = "doi" + ch + " | " + why;
   }
   else
   {
      if(!IvSame(sym, sl, g_iv[k].sl)) GlobalVariableSet(IvKey("s" + IvT(g_iv[k].t)), 2);
      if(!IvSame(sym, tp, g_iv[k].tp)) GlobalVariableSet(IvKey("p" + IvT(g_iv[k].t)), 2);
   }
   IvWrite(0, "BAN", act, sym, g_iv[k].t, g_iv[k].owner, IvSide(g_iv[k].type), vol, price, g_iv[k].sl, sl, g_iv[k].tp, tp,
           g_iv[k].pend ? "" : DoubleToString(fl, 2), why);
   IvApply(k, price, sl, tp, vol);
}
// Ban sua chua kip ghi (dang cho 3 giay) ma bot sua tiep: ghi phan cua ban truoc
void IvFlushWait(const int k)
{
   if(k < 0 || !g_ivOwner || g_iv[k].waitMs == 0) return;
   if(IvBotMark(k, g_iv[k].wprice, g_iv[k].wsl, g_iv[k].wtp)) { IvApply(k, g_iv[k].wprice, g_iv[k].wsl, g_iv[k].wtp, g_iv[k].wvol); return; }
   IvUserRow(k, g_iv[k].wprice, g_iv[k].wsl, g_iv[k].wtp, g_iv[k].wvol, 0);
}

void IvSeen(const ulong t, const bool pend, const string sym, const long magic, const int ty, const double vol,
            const double price, const double sl, const double tp, const string cmt, const double fl, const long reason)
{
   int k = IvFind(t, pend);
   if(k < 0)
   {
      k = ArraySize(g_iv);
      ArrayResize(g_iv, k + 1);
      g_iv[k].t = t; g_iv[k].pend = pend; g_iv[k].sym = sym; g_iv[k].magic = magic; g_iv[k].type = ty;
      g_iv[k].owner = IvOwnerOf(sym, magic, cmt, t);
      g_iv[k].vol = vol; g_iv[k].price = price; g_iv[k].sl = sl; g_iv[k].tp = tp;
      g_iv[k].waitMs = 0; g_iv[k].goneMs = 0; g_iv[k].live = true;
      g_iv[k].wvol = vol; g_iv[k].wprice = price; g_iv[k].wsl = sl; g_iv[k].wtp = tp;
      // Vi the moi: dong "MO lenh" ghi o IvOnDeal (co ly do tu DEAL_REASON). Lenh cho moi: ghi o day.
      if(pend && g_ivInit && g_ivOwner)
         IvWrite(0, IvWhoOrder(reason), "DAT lenh cho", sym, t, g_iv[k].owner, IvSide(ty), vol, price, -1, sl, -1, tp, "",
                 (cmt != "" ? cmt + " | " : "") + (sl <= 0 ? "lenh cho KHONG co SL" : "co SL"));
      return;
   }
   g_iv[k].live = true;
   g_iv[k].goneMs = 0;
   if(!pend) g_iv[k].vol = vol;                         // lot vi the doi qua giao dich: dong / dong mot phan ghi o IvOnDeal
   if(!IvDiff(k, price, sl, tp, vol)) { g_iv[k].waitMs = 0; return; }
   if(!g_ivOwner) { IvApply(k, price, sl, tp, vol); return; }   // chart nay khong ghi phan cua ban: chi cap nhat
   if(IvBotMark(k, price, sl, tp))
   {
      // Ban sua (dang cho) roi bot sua lai ngay: ghi ca phan cua ban
      if(g_iv[k].waitMs > 0 && IvDiffW(k, price, sl, tp, vol)) IvUserRow(k, g_iv[k].wprice, g_iv[k].wsl, g_iv[k].wtp, g_iv[k].wvol, fl);
      IvApply(k, price, sl, tp, vol);
      return;
   }
   if(g_iv[k].waitMs == 0 || IvDiffW(k, price, sl, tp, vol))
   {
      if(g_iv[k].waitMs == 0) g_iv[k].waitMs = GetTickCount64();
      g_iv[k].wvol = vol; g_iv[k].wprice = price; g_iv[k].wsl = sl; g_iv[k].wtp = tp;
      return;
   }
   if(GetTickCount64() - g_iv[k].waitMs < IV_GRACE_MS) return;
   IvUserRow(k, price, sl, tp, vol, fl);
}

// Lenh cho bien mat: true = xong (da ghi / khong can ghi), false = cho them
bool IvOrderGone(const int k)
{
   ulong t = g_iv[k].t;
   if(g_iv[k].goneMs == 0) g_iv[k].goneMs = GetTickCount64();
   ulong waited = GetTickCount64() - g_iv[k].goneMs;
   if(!HistoryOrderSelect(t)) return waited > 10000;          // lich su chua cap nhat: cho toi 10 giay
   ENUM_ORDER_STATE st = (ENUM_ORDER_STATE)HistoryOrderGetInteger(t, ORDER_STATE);
   if(st == ORDER_STATE_FILLED || st == ORDER_STATE_PARTIAL) return true;   // khop: dong MO lenh ghi o IvOnDeal
   string d = IvKey("d" + IvT(t));
   if(GlobalVariableCheck(d)) { GlobalVariableDel(d); return true; }        // bot huy: da ghi o IvBotDone
   if(st == ORDER_STATE_EXPIRED)
   {
      IvWrite(0, "SAN", "HET HAN lenh cho", g_iv[k].sym, t, g_iv[k].owner, IvSide(g_iv[k].type), g_iv[k].vol, g_iv[k].price,
              g_iv[k].sl, -1, g_iv[k].tp, -1, "", "het thoi han dat cho lenh");
      return true;
   }
   if(st != ORDER_STATE_CANCELED) return true;
   if(waited < IV_GRACE_MS) return false;                     // cho chart bot khac kip danh dau
   IvWrite(0, "BAN", "HUY lenh cho", g_iv[k].sym, t, g_iv[k].owner, IvSide(g_iv[k].type), g_iv[k].vol, g_iv[k].price,
           g_iv[k].sl, -1, g_iv[k].tp, -1, "", "khong phai bot nay huy (ban huy tren web / dien thoai / MT5, hoac EA khac)");
   return true;
}

// Chart nay ghi phan "BAN lam gi"? (1 chart moi tai khoan, chart dau tien bat)
bool IvOwnerCheck()
{
   string pre = IvKey("own_");
   string mine = pre + IntegerToString(ChartID());
   for(int i = GlobalVariablesTotal() - 1; i >= 0; i--)
   {
      string n = GlobalVariableName(i);
      if(StringFind(n, pre) != 0 || n == mine) continue;
      long id = StringToInteger(StringSubstr(n, StringLen(pre)));
      if(ChartSymbol(id) != "") return false;                 // chart khac van mo va dang ghi
      GlobalVariableDel(n);                                    // chart cu da dong
   }
   if(!GlobalVariableCheck(mine)) GlobalVariableTemp(mine);
   return true;
}

// Bat dau ghi: xoa dau cu cua vi the / lenh cho khong con
void IvCleanMarks()
{
   string pre = IvKey("");
   int pl = StringLen(pre);
   for(int i = GlobalVariablesTotal() - 1; i >= 0; i--)
   {
      string n = GlobalVariableName(i);
      if(StringFind(n, pre) != 0) continue;
      string c = StringSubstr(n, pl, 1);
      if(c != "m" && c != "o" && c != "d" && c != "s" && c != "p") continue;
      ulong t = (ulong)StringToInteger(StringSubstr(n, pl + 1));
      if(t == 0) continue;
      bool alive = (c == "o" || c == "d") ? OrderSelect(t) : PositionSelectByTicket(t);
      if(!alive) GlobalVariableDel(n);
   }
}

void IvScan()
{
   if(!IvOn()) return;
   if(!g_ivStarted)
   {
      g_ivStarted = true;
      IvNote("HE THONG", "BOT BAT", _Symbol, StringFormat("TrendBot %s tren chart %s %s | bao ve lenh tay: %s | bot tu vao lenh: %s",
             BOT_VERSION, _Symbol, EnumToString((ENUM_TIMEFRAMES)Period()), InpGuardManual ? "BAT" : "TAT",
             (InpAllowBuy || InpAllowSell || InpGuardAutoEntry) ? "co the" : "KHONG"));
   }
   if(g_ivOwnMs == 0 || GetTickCount64() - g_ivOwnMs >= 5000)
   {
      g_ivOwnMs = GetTickCount64();
      bool own = IvOwnerCheck();
      if(own && !g_ivOwner)
      {
         IvCleanMarks();
         IvNote("HE THONG", "BAT DAU THEO DOI", _Symbol, "chart nay ghi moi thay doi cua BAN tren ca tai khoan (moi ma)");
      }
      g_ivOwner = own;
   }
   for(int i = ArraySize(g_iv) - 1; i >= 0; i--) g_iv[i].live = false;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong t = PositionGetTicket(i);
      if(t == 0) continue;
      IvSeen(t, false, PositionGetString(POSITION_SYMBOL), PositionGetInteger(POSITION_MAGIC), (int)PositionGetInteger(POSITION_TYPE),
             PositionGetDouble(POSITION_VOLUME), PositionGetDouble(POSITION_PRICE_OPEN), PositionGetDouble(POSITION_SL),
             PositionGetDouble(POSITION_TP), PositionGetString(POSITION_COMMENT),
             PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP), PositionGetInteger(POSITION_REASON));
   }
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong t = OrderGetTicket(i);
      if(t == 0) continue;
      int ty = (int)OrderGetInteger(ORDER_TYPE);
      if(ty < (int)ORDER_TYPE_BUY_LIMIT || ty > (int)ORDER_TYPE_SELL_STOP_LIMIT) continue;   // lenh thi truong dang khop: bo qua
      IvSeen(t, true, OrderGetString(ORDER_SYMBOL), OrderGetInteger(ORDER_MAGIC), ty, OrderGetDouble(ORDER_VOLUME_CURRENT),
             OrderGetDouble(ORDER_PRICE_OPEN), OrderGetDouble(ORDER_SL), OrderGetDouble(ORDER_TP), OrderGetString(ORDER_COMMENT),
             0, OrderGetInteger(ORDER_REASON));
   }
   // Lenh da bien mat
   for(int i = ArraySize(g_iv) - 1; i >= 0; i--)
   {
      if(g_iv[i].live) continue;
      if(g_iv[i].pend && g_ivOwner && g_ivInit && !IvOrderGone(i)) continue;
      IvDelMark(IvKey((g_iv[i].pend ? "o" : "m") + IvT(g_iv[i].t)));
      int n = ArraySize(g_iv);
      if(i < n - 1) g_iv[i] = g_iv[n - 1];
      ArrayResize(g_iv, n - 1);
   }
   // Lan dau: ghi lai trang thai luc bot bat (moc de so sanh)
   if(!g_ivInit && g_ivOwner)
      for(int i = 0; i < ArraySize(g_iv); i++)
         IvWrite(0, "HE THONG", g_iv[i].pend ? "DANG CO lenh cho (luc bot bat)" : "DANG MO (luc bot bat)", g_iv[i].sym, g_iv[i].t,
                 g_iv[i].owner, IvSide(g_iv[i].type), g_iv[i].vol, g_iv[i].price, -1, g_iv[i].sl, -1, g_iv[i].tp, "", "");
   g_ivInit = true;
}

//--- Giao dich (mo / dong) tu OnTradeTransaction: biet ai lam qua DEAL_REASON
void IvOnDeal(const ulong d)
{
   if(!HistoryDealSelect(d)) return;
   long dty = HistoryDealGetInteger(d, DEAL_TYPE);
   if(dty != DEAL_TYPE_BUY && dty != DEAL_TYPE_SELL) return;   // nap / rut / phi: co trong TrendBot_nhatky.csv
   long     entry  = HistoryDealGetInteger(d, DEAL_ENTRY);
   long     reason = HistoryDealGetInteger(d, DEAL_REASON);
   long     magic  = HistoryDealGetInteger(d, DEAL_MAGIC);
   ulong    pos    = (ulong)HistoryDealGetInteger(d, DEAL_POSITION_ID);
   ulong    ord    = (ulong)HistoryDealGetInteger(d, DEAL_ORDER);
   string   sym    = HistoryDealGetString(d, DEAL_SYMBOL);
   string   cmt    = HistoryDealGetString(d, DEAL_COMMENT);
   double   vol    = HistoryDealGetDouble(d, DEAL_VOLUME);
   double   px     = HistoryDealGetDouble(d, DEAL_PRICE);
   double   pl     = DealNet(d);
   datetime t      = (datetime)HistoryDealGetInteger(d, DEAL_TIME);
   string   who    = IvWhoDeal(reason);
   bool     still  = PositionSelectByTicket(pos);
   double   psl    = still ? PositionGetDouble(POSITION_SL) : 0;
   double   ptp    = still ? PositionGetDouble(POSITION_TP) : 0;
   int      k      = IvFind(pos, false);
   if(entry == DEAL_ENTRY_IN)
   {
      double sl = psl, tp = ptp;
      if(!still && HistoryOrderSelect(ord)) { sl = HistoryOrderGetDouble(ord, ORDER_SL); tp = HistoryOrderGetDouble(ord, ORDER_TP); }
      int by = reason == DEAL_REASON_EXPERT ? 1 : 2;
      if(sl > 0) GlobalVariableSet(IvKey("s" + IvT(pos)), by);
      if(tp > 0) GlobalVariableSet(IvKey("p" + IvT(pos)), by);
      string why = cmt;
      if(sl <= 0) why = (why != "" ? why + " | " : "") + "vao lenh KHONG co SL";
      IvWrite(t, who, "MO lenh", sym, pos, k >= 0 ? g_iv[k].owner : IvOwnerOf(sym, magic, cmt, pos),
              dty == DEAL_TYPE_BUY ? "BUY" : "SELL", vol, px, -1, sl, -1, tp, "", why);
      return;
   }
   // Dong: giao dich dong nguoc chieu vi the
   string act = still ? "DONG MOT PHAN" : "DONG lenh";
   string why = cmt;
   if(reason == DEAL_REASON_SL || reason == DEAL_REASON_TP)
   {
      bool   isSL = reason == DEAL_REASON_SL;
      string what = isSL ? "SL" : "TP";
      string n = IvKey((isSL ? "s" : "p") + IvT(pos));
      int by = GlobalVariableCheck(n) ? (int)GlobalVariableGet(n) : 0;
      act = "CHAM " + what + (still ? " (mot phan)" : "");
      why = what + (by == 1 ? " nay do BOT dat / doi lan cuoi" : by == 2 ? " nay do BAN dat / doi lan cuoi" : " khong ro ai dat (co tu truoc khi bot ghi)");
   }
   else if(reason == DEAL_REASON_SO) act = "STOP OUT (het ky quy)";
   else if(reason == DEAL_REASON_EXPERT) why = "khop lenh dong cua bot / EA (ly do o dong BOT ngay truoc)" + (cmt != "" ? " | " + cmt : "");
   IvWrite(t, who, act, sym, pos, k >= 0 ? g_iv[k].owner : "", dty == DEAL_TYPE_BUY ? "SELL" : "BUY", vol, px,
           k >= 0 ? g_iv[k].sl : -1, -1, k >= 0 ? g_iv[k].tp : -1, -1, DoubleToString(pl, 2), why);
   if(!still) { GlobalVariableDel(IvKey("s" + IvT(pos))); GlobalVariableDel(IvKey("p" + IvT(pos))); }
}

void IvOnTx(const MqlTradeTransaction &trans)
{
   if(!IvOn() || !g_ivOwner) return;
   if(trans.type == TRADE_TRANSACTION_DEAL_ADD) IvOnDeal(trans.deal);
   else if(trans.type == TRADE_TRANSACTION_POSITION || trans.type == TRADE_TRANSACTION_ORDER_ADD ||
           trans.type == TRADE_TRANSACTION_ORDER_UPDATE || trans.type == TRADE_TRANSACTION_ORDER_DELETE) IvScan();
}

//--- BOT lam gi: goi tu TradeDone sau MOI lenh sua / dong / huy cua bot (ca khi that bai)
// g_ivWhy (Core.mqh): ly do chi tiet do noi goi dat ngay truoc lenh; khong co thi dung kind + detail.
void IvBotDone(const bool ok, const string kind, const string detail, const string err)
{
   string why = g_ivWhy != "" ? g_ivWhy : (detail != "" ? kind + ": " + detail : kind);
   g_ivWhy = "";
   if(!IvOn()) return;
   uint rc = trade.ResultRetcode();
   // That bai ma chua gui len may chu (rc 0) thi du lieu yeu cau co the la cua lenh truoc: khong ghi
   if(!ok && (rc == 0 || rc == TRADE_RETCODE_DONE || rc == TRADE_RETCODE_DONE_PARTIAL)) return;
   if(!ok) why += " | THAT BAI: " + err;
   string who = ok ? "BOT" : "BOT (that bai)";
   string pre = ok ? "" : "THU ";
   ENUM_TRADE_REQUEST_ACTIONS a = trade.RequestAction();

   if(a == TRADE_ACTION_SLTP || (a == TRADE_ACTION_DEAL && trade.RequestPosition() > 0))
   {
      ulong t = trade.RequestPosition();
      int k = IvFind(t, false);
      IvFlushWait(k);                                          // ban vua sua ma chua kip ghi
      string sym = trade.RequestSymbol(), owner = "";
      int ty = 0;
      double vol = 0, op = 0, fl = 0, csl = -1, ctp = -1;
      bool has = PositionSelectByTicket(t);
      if(has)
      {
         sym = PositionGetString(POSITION_SYMBOL); ty = (int)PositionGetInteger(POSITION_TYPE);
         vol = PositionGetDouble(POSITION_VOLUME); op = PositionGetDouble(POSITION_PRICE_OPEN);
         fl  = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
         csl = PositionGetDouble(POSITION_SL); ctp = PositionGetDouble(POSITION_TP);
         owner = IvOwnerOf(sym, PositionGetInteger(POSITION_MAGIC), PositionGetString(POSITION_COMMENT), t);
      }
      if(k >= 0) { sym = g_iv[k].sym; ty = g_iv[k].type; owner = g_iv[k].owner; }
      if(a == TRADE_ACTION_SLTP)
      {
         double osl = k >= 0 ? g_iv[k].sl : -1, otp = k >= 0 ? g_iv[k].tp : -1;
         double nsl = trade.RequestSL(), ntp = trade.RequestTP();
         IvWrite(0, who, pre + IvModAct(sym, ty % 2 == 0, osl, nsl, otp, ntp), sym, t, owner, IvSide(ty), vol, op,
                 osl, nsl, otp, ntp, has ? DoubleToString(fl, 2) : "", why);
         if(ok)
         {
            if(osl < 0 || !IvSame(sym, osl, nsl)) GlobalVariableSet(IvKey("s" + IvT(t)), 1);
            if(otp < 0 || !IvSame(sym, otp, ntp)) GlobalVariableSet(IvKey("p" + IvT(t)), 1);
            if(k >= 0) IvApply(k, g_iv[k].price, nsl, ntp, g_iv[k].vol);
            if(!g_ivOwner) IvMark("m", t, nsl, ntp, 0);        // de chart theo doi biet day la bot sua
         }
      }
      else
      {
         double v = trade.RequestVolume();
         double full = k >= 0 ? g_iv[k].vol : vol;
         bool part = full > 0 && v < full - 1e-9;
         IvWrite(0, who, pre + (part ? StringFormat("DONG BOT %.2f lot (giam lot)", v) : "DONG lenh"), sym, t, owner, IvSide(ty), v,
                 ok ? trade.ResultPrice() : trade.RequestPrice(), k >= 0 ? g_iv[k].sl : csl, -1, k >= 0 ? g_iv[k].tp : ctp, -1,
                 has ? DoubleToString(fl, 2) : "", why);
      }
      return;
   }
   if(a == TRADE_ACTION_MODIFY || a == TRADE_ACTION_REMOVE)
   {
      ulong t = trade.RequestOrder();
      int k = IvFind(t, true);
      IvFlushWait(k);
      string sym = "", owner = "";
      int ty = 0;
      double vol = 0, op = -1, osl = -1, otp = -1;
      if(k >= 0) { sym = g_iv[k].sym; owner = g_iv[k].owner; ty = g_iv[k].type; vol = g_iv[k].vol; op = g_iv[k].price; osl = g_iv[k].sl; otp = g_iv[k].tp; }
      else if(OrderSelect(t))
      {
         sym = OrderGetString(ORDER_SYMBOL); ty = (int)OrderGetInteger(ORDER_TYPE); vol = OrderGetDouble(ORDER_VOLUME_CURRENT);
         owner = IvOwnerOf(sym, OrderGetInteger(ORDER_MAGIC), OrderGetString(ORDER_COMMENT), t);
      }
      else if(HistoryOrderSelect(t))
      {
         sym = HistoryOrderGetString(t, ORDER_SYMBOL); ty = (int)HistoryOrderGetInteger(t, ORDER_TYPE);
         vol = HistoryOrderGetDouble(t, ORDER_VOLUME_INITIAL);
      }
      if(a == TRADE_ACTION_MODIFY)
      {
         double np = trade.RequestPrice(), nsl = trade.RequestSL(), ntp = trade.RequestTP();
         string act = pre + "SUA lenh cho: " + IvModAct(sym, ty % 2 == 0, osl, nsl, otp, ntp);
         if(op > 0 && !IvSame(sym, op, np)) why = "doi gia vao " + IvPx(sym, op) + " -> " + IvPx(sym, np) + " | " + why;
         IvWrite(0, who, act, sym, t, owner, IvSide(ty), vol, np, osl, nsl, otp, ntp, "", why);
         if(ok)
         {
            if(k >= 0) IvApply(k, np, nsl, ntp, g_iv[k].vol);
            if(!g_ivOwner) IvMark("o", t, nsl, ntp, np);
         }
      }
      else
      {
         IvWrite(0, who, pre + "HUY lenh cho", sym, t, owner, IvSide(ty), vol, op, osl, -1, otp, -1, "", why);
         if(ok) GlobalVariableSet(IvKey("d" + IvT(t)), (double)TimeLocal());
      }
   }
   // Bot mo lenh moi / dat lenh cho moi: ghi o IvOnDeal / IvScan (ly do vao lenh co trong nhat ky quyet dinh)
}

// Go bot / doi thong so / tat MT5: bot ngung bao ve tu luc nay
string IvDeinitWhy(const int r)
{
   switch(r)
   {
      case REASON_REMOVE:      return "go bot khoi chart";
      case REASON_RECOMPILE:   return "bien dich lai bot";
      case REASON_CHARTCHANGE: return "doi ma / khung chart";
      case REASON_CHARTCLOSE:  return "dong chart";
      case REASON_PARAMETERS:  return "doi thong so bot";
      case REASON_ACCOUNT:     return "doi tai khoan";
      case REASON_TEMPLATE:    return "nap template khac";
      case REASON_INITFAILED:  return "khoi dong loi";
      case REASON_CLOSE:       return "tat MT5";
   }
   return "ly do " + IntegerToString(r);
}
void IvRelease(const int reason)
{
   if(!IvOn() || !g_ivStarted) return;
   IvNote("HE THONG", "BOT TAT", _Symbol, IvDeinitWhy(reason) + " | tu luc nay bot tren chart nay KHONG bao ve / ghi nua");
   if(g_ivOwner) GlobalVariableDel(IvKey("own_") + IntegerToString(ChartID()));
   g_ivOwner = false;
   g_ivOwnMs = 0;
   g_ivStarted = false;
}
