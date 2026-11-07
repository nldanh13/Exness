//+------------------------------------------------------------------+
//| TrendBot/Journal.mqh: Nhat ky giao dich + canh bao ky luat (chi chay that / demo)
//| - Ghi MOI giao dich cua tai khoan (bot, lenh tay, nap, rut) vao Common\Files\TrendBot_nhatky.csv
//|   Lan dau chay: ghi lai toan bo lich su cu (khong canh bao).
//| - Tong ket moi ngay vao Common\Files\TrendBot_tongket.csv + gui thong bao.
//| - Canh bao rut ra tu sao ke giao dich tay: nap lai sau khi rut, nap vuot muc thang, lot tang vot,
//|   vao qua nhieu lenh, thua lien tiep, thang lon (nhac rut tien / nghi), lai thang dat moc (nhac rut).
//| Moi tai khoan chi 1 chart ghi nhat ky (chart dau tien bat), cac bot khac tu bo qua.
//+------------------------------------------------------------------+
#define JR_FILE "TrendBot_nhatky.csv"
#define JS_FILE "TrendBot_tongket.csv"

datetime g_jLast = 0;
double   g_jLots[];                          // lot cac lenh tay gan nhat (toi da 20)

string JKey(const string k) { return "TBJS_" + IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)) + "_" + k; }
double JGet(const string k, const double def = 0) { string n = JKey(k); return GlobalVariableCheck(n) ? GlobalVariableGet(n) : def; }
void   JSet(const string k, const double v) { GlobalVariableSet(JKey(k), v); }

// Chi 1 chart moi tai khoan ghi nhat ky
bool JournalOwner()
{
   string pre = "TBJ_" + IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)) + "_";
   string mine = pre + IntegerToString(ChartID());
   for(int i = GlobalVariablesTotal() - 1; i >= 0; i--)
   {
      string n = GlobalVariableName(i);
      if(StringFind(n, pre) != 0 || n == mine) continue;
      long id = StringToInteger(StringSubstr(n, StringLen(pre)));
      if(ChartSymbol(id) != "") return false;               // chart khac van dang mo va giu viec ghi
      GlobalVariableDel(n);                                  // chart cu da dong
   }
   if(!GlobalVariableCheck(mine)) GlobalVariableTemp(mine);
   return true;
}
void JournalRelease() { GlobalVariableDel("TBJ_" + IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)) + "_" + IntegerToString(ChartID())); }

string JClean(string s) { StringReplace(s, ",", " "); StringReplace(s, "\n", " "); StringReplace(s, "\r", " "); return s; }

void JAppend(const string file, const string header, const string line)
{
   int h = FileOpen(file, FILE_READ | FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_COMMON | FILE_SHARE_READ);
   if(h == INVALID_HANDLE) { Print("Khong ghi duoc ", file, " loi ", GetLastError()); return; }
   if(FileSize(h) == 0) FileWriteString(h, header + "\r\n");
   FileSeek(h, 0, SEEK_END);
   FileWriteString(h, line + "\r\n");
   FileClose(h);
}

#define JR_HEAD "ThoiGian,Loai,Ma,Nguon,Magic,Chieu,Lot,Gia,SL_LucVao,LaiLo,GiuGio,ViTri,SoDuHienTai,GhiChu"
void JRow(const datetime t, const string kind, const string sym, const long magic, const string side,
          const double vol, const double price, const double sl, const double pl, const double holdH,
          const ulong pos, const string note)
{
   JAppend(JR_FILE, JR_HEAD, StringFormat("%s,%s,%s,%s,%I64d,%s,%.2f,%s,%s,%.2f,%s,%I64u,%.2f,%s",
           TimeToString(t, TIME_DATE | TIME_SECONDS), kind, sym, magic < 0 ? "" : magic == 0 ? "Tay" : "Bot", magic, side, vol,
           DoubleToString(price, 5), sl > 0 ? DoubleToString(sl, 5) : "", pl, holdH >= 0 ? DoubleToString(holdH, 2) : "",
           pos, AccountInfoDouble(ACCOUNT_BALANCE), JClean(note)));
}

void JWarn(const string msg)
{
   JSet("warnDay", JGet("warnDay") + 1);
   JRow(TimeCurrent(), "CANHBAO", "", -1, "", 0, 0, 0, 0, -1, 0, msg);
   Notify("[KY LUAT] " + msg);
}

void JPushLot(const double v)
{
   int n = ArraySize(g_jLots);
   if(n >= 20) { ArrayRemove(g_jLots, 0, 1); n--; }
   ArrayResize(g_jLots, n + 1); g_jLots[n] = v;
}
double JMedianLot()
{
   int n = ArraySize(g_jLots);
   if(n < 5) return 0;
   double a[]; ArrayCopy(a, g_jLots); ArraySort(a);
   return n % 2 ? a[n / 2] : (a[n / 2 - 1] + a[n / 2]) / 2;
}

int JDayKey(const datetime t) { MqlDateTime d; TimeToStruct(t, d); return d.year * 10000 + d.mon * 100 + d.day; }
int JMonKey(const datetime t) { MqlDateTime d; TimeToStruct(t, d); return d.year * 100 + d.mon; }
datetime JDayStart(const datetime t) { MqlDateTime d; TimeToStruct(t, d); return t - (d.hour * 3600 + d.min * 60 + d.sec); }
datetime JMonStart(const datetime t) { MqlDateTime d; TimeToStruct(t, d); d.day = 1; d.hour = 0; d.min = 0; d.sec = 0; return StructToTime(d); }

// Tong nap / rut trong [from, to)
void JBalanceFlows(const datetime from, const datetime to, double &dep, double &wd, datetime &lastWd)
{
   dep = 0; wd = 0; lastWd = 0;
   if(!HistorySelect(from, to)) return;
   for(int i = 0; i < HistoryDealsTotal(); i++)
   {
      ulong d = HistoryDealGetTicket(i);
      if(d == 0 || HistoryDealGetInteger(d, DEAL_TYPE) != DEAL_TYPE_BALANCE) continue;
      double a = HistoryDealGetDouble(d, DEAL_PROFIT);
      if(a > 0) dep += a; else { wd -= a; lastWd = (datetime)HistoryDealGetInteger(d, DEAL_TIME); }
   }
}

// Tong ket 1 ngay [from, from + 1 ngay)
void JDailySummary(const datetime from)
{
   datetime to = from + 86400;
   double plBot = 0, plTay = 0, dep = 0, wd = 0; int nBot = 0, nTay = 0, nTayThua = 0;
   if(HistorySelect(from, to))
      for(int i = 0; i < HistoryDealsTotal(); i++)
      {
         ulong d = HistoryDealGetTicket(i);
         if(d == 0) continue;
         long type = HistoryDealGetInteger(d, DEAL_TYPE), entry = HistoryDealGetInteger(d, DEAL_ENTRY), mg = HistoryDealGetInteger(d, DEAL_MAGIC);
         double v = HistoryDealGetDouble(d, DEAL_PROFIT) + HistoryDealGetDouble(d, DEAL_SWAP) + HistoryDealGetDouble(d, DEAL_COMMISSION);
         if(type == DEAL_TYPE_BALANCE) { double a = HistoryDealGetDouble(d, DEAL_PROFIT); if(a > 0) dep += a; else wd -= a; continue; }
         if(type != DEAL_TYPE_BUY && type != DEAL_TYPE_SELL) continue;
         if(mg == 0) { plTay += v; if(entry != DEAL_ENTRY_IN) { nTay++; if(v < 0) nTayThua++; } }
         else        { plBot += v; if(entry != DEAL_ENTRY_IN) nBot++; }
      }
   int warns = (int)JGet("warnDay");
   string cur = AccountInfoString(ACCOUNT_CURRENCY);
   JAppend(JS_FILE, "Ngay,LaiLoBot,LenhBot,LaiLoTay,LenhTay,LenhTayThua,Nap,Rut,SoCanhBao,SoDu,Equity",
           StringFormat("%s,%.2f,%d,%.2f,%d,%d,%.2f,%.2f,%d,%.2f,%.2f", TimeToString(from, TIME_DATE), plBot, nBot, plTay, nTay, nTayThua,
                        dep, wd, warns, AccountInfoDouble(ACCOUNT_BALANCE), AccountInfoDouble(ACCOUNT_EQUITY)));
   if(nBot + nTay > 0 || dep > 0 || wd > 0)
      Notify(StringFormat("[TONG KET %s] Bot: %.0f %s (%d lenh). Tay: %.0f %s (%d lenh, %d thua). Nap %.0f, rut %.0f. %d canh bao.",
                          TimeToString(from, TIME_DATE), plBot, cur, nBot, plTay, cur, nTay, nTayThua, dep, wd, warns));
   JSet("warnDay", 0);
}

struct JDeal { ulong tk; datetime t; long type; long entry; string sym; long magic; double vol; double price; double pl; ulong pos; ulong order; string cmt; };

void JournalScan()
{
   if(!InpJournal || MQLInfoInteger(MQL_TESTER)) return;
   if(TimeCurrent() - g_jLast < 15) return;
   g_jLast = TimeCurrent();
   if(!JournalOwner()) return;

   datetime now = TimeCurrent();
   bool first = !GlobalVariableCheck(JKey("last"));
   ulong last = (ulong)JGet("last");

   // Ngay / thang moi
   int dk = JDayKey(now), mk = JMonKey(now);
   int oldDay = (int)JGet("day", dk);
   if(oldDay != dk)
   {
      MqlDateTime d; d.year = oldDay / 10000; d.mon = oldDay / 100 % 100; d.day = oldDay % 100; d.hour = 0; d.min = 0; d.sec = 0;
      if(!first) JDailySummary(StructToTime(d));
      JSet("tday", 0);
   }
   JSet("day", dk);
   if((int)JGet("mon") != mk)
   {
      // Moc dau thang = so du luc chuyen thang (hoac luc bat nhat ky), cong them tien nap / tru tien rut trong thang
      JSet("mon", mk); JSet("monBase", AccountInfoDouble(ACCOUNT_BALANCE)); JSet("monDep", 0); JSet("monLvl", 0);
   }

   // Thu cac giao dich moi
   if(!HistorySelect(first ? 0 : now - 30 * 86400, now + 60)) return;
   JDeal arr[]; int n = 0;
   for(int i = 0; i < HistoryDealsTotal(); i++)
   {
      ulong d = HistoryDealGetTicket(i);
      if(d == 0 || d <= last) continue;
      ArrayResize(arr, n + 1);
      arr[n].tk = d; arr[n].t = (datetime)HistoryDealGetInteger(d, DEAL_TIME);
      arr[n].type = HistoryDealGetInteger(d, DEAL_TYPE); arr[n].entry = HistoryDealGetInteger(d, DEAL_ENTRY);
      arr[n].sym = HistoryDealGetString(d, DEAL_SYMBOL); arr[n].magic = HistoryDealGetInteger(d, DEAL_MAGIC);
      arr[n].vol = HistoryDealGetDouble(d, DEAL_VOLUME); arr[n].price = HistoryDealGetDouble(d, DEAL_PRICE);
      arr[n].pl = HistoryDealGetDouble(d, DEAL_PROFIT) + HistoryDealGetDouble(d, DEAL_SWAP) + HistoryDealGetDouble(d, DEAL_COMMISSION);
      arr[n].pos = (ulong)HistoryDealGetInteger(d, DEAL_POSITION_ID); arr[n].order = (ulong)HistoryDealGetInteger(d, DEAL_ORDER);
      arr[n].cmt = HistoryDealGetString(d, DEAL_COMMENT);
      n++;
   }
   if(first && n > 0) PrintFormat("Nhat ky: lan dau, ghi lai %d giao dich cu vao Common\\Files\\%s", n, JR_FILE);

   for(int k = 0; k < n; k++)
   {
      JDeal x = arr[k];
      if(x.tk > last) last = x.tk;
      bool warn = !first && x.t > now - 3600;               // chi canh bao giao dich vua xay ra
      if(x.type == DEAL_TYPE_BALANCE)
      {
         bool dep = x.pl > 0;
         JRow(x.t, dep ? "NAP" : "RUT", "", -1, "", 0, 0, 0, x.pl, -1, 0, "");   // bo ghi chu: co ma giao dich ngan hang
         if(!first && JMonKey(x.t) == mk) JSet("monDep", JGet("monDep") + x.pl);
         if(dep && warn)
         {
            double d2, w2; datetime lw;
            if(InpWarnRedepositDays > 0)
            {
               JBalanceFlows(x.t - InpWarnRedepositDays * 86400, x.t, d2, w2, lw);
               if(w2 > 0) JWarn(StringFormat("Ban vua NAP %.0f trong khi %d ngay qua da rut %.0f. Da rut thi khong nap lai de go.", x.pl, InpWarnRedepositDays, w2));
            }
            if(InpMonthDepositCap > 0)
            {
               JBalanceFlows(JMonStart(x.t), x.t + 1, d2, w2, lw);
               if(d2 > InpMonthDepositCap) JWarn(StringFormat("Tong nap thang nay %.0f, vuot muc ban tu dat %.0f. Dung nap them toi thang sau.", d2, InpMonthDepositCap));
            }
         }
         continue;
      }
      if(x.type != DEAL_TYPE_BUY && x.type != DEAL_TYPE_SELL) { JRow(x.t, "KHAC", x.sym, x.magic, "", x.vol, x.price, 0, x.pl, -1, x.pos, x.cmt); continue; }
      string side = x.type == DEAL_TYPE_BUY ? "BUY" : "SELL";
      if(x.entry == DEAL_ENTRY_IN)
      {
         double sl = HistoryOrderSelect(x.order) ? HistoryOrderGetDouble(x.order, ORDER_SL) : 0;
         JRow(x.t, "VAO", x.sym, x.magic, side, x.vol, x.price, sl, x.pl, -1, x.pos, x.cmt);
         if(x.magic != 0) continue;
         double med = JMedianLot();
         if(warn)
         {
            if(InpWarnLotJump > 0 && med > 0 && x.vol > med * InpWarnLotJump + 1e-9)
               JWarn(StringFormat("Lenh tay %s %.2f lot %s, gap %.1f lan lot thuong dung (%.2f). Lot to la nguon lo lon nhat trong sao ke cua ban.", side, x.vol, x.sym, x.vol / med, med));
            if(sl == 0) JWarn(StringFormat("Lenh tay %s %.2f lot %s KHONG CO SL. Dat SL ngay.", side, x.vol, x.sym));
            JSet("tday", JGet("tday") + 1);
            if(InpWarnMaxTradesDay > 0 && (int)JGet("tday") == InpWarnMaxTradesDay + 1)
               JWarn(StringFormat("Hom nay da vao %d lenh tay (muc toi da %d). Vao nhieu lenh thuong la dang go hoac dang hung phan: nghi.", InpWarnMaxTradesDay + 1, InpWarnMaxTradesDay));
         }
         JPushLot(x.vol);
      }
      else
      {
         // Thoi gian giu: tu lenh vao cua vi the
         double hold = -1;
         if(HistorySelectByPosition(x.pos))
            for(int j = 0; j < HistoryDealsTotal(); j++)
            {
               ulong d = HistoryDealGetTicket(j);
               if(HistoryDealGetInteger(d, DEAL_ENTRY) == DEAL_ENTRY_IN) { hold = (double)(x.t - (datetime)HistoryDealGetInteger(d, DEAL_TIME)) / 3600.0; break; }
            }
         JRow(x.t, "RA", x.sym, x.magic, side, x.vol, x.price, 0, x.pl, hold, x.pos, x.cmt);
         if(x.magic == 0 && !first)
         {
            double st = x.pl < 0 ? JGet("streak") + 1 : 0;
            JSet("streak", st);
            if(warn && InpWarnLossStreak > 0 && (int)st == InpWarnLossStreak)
               JWarn(StringFormat("Thua tay %d lenh lien tiep. Nghi het hom nay, khong vao lenh de go.", InpWarnLossStreak));
         }
         double bal = AccountInfoDouble(ACCOUNT_BALANCE);
         if(warn && InpWarnBigWinPct > 0 && x.pl > bal * InpWarnBigWinPct / 100.0)
            JWarn(StringFormat("Lenh vua lai %.0f (%.0f%% so du). Viec dau tien: RUT tien goc + mot nua lai ve ngan hang, nghi 1-2 ngay, KHONG tang lot.", x.pl, x.pl / bal * 100.0));
      }
   }
   JSet("last", (double)last);
   if(first) { JSet("monBase", AccountInfoDouble(ACCOUNT_BALANCE)); JSet("monDep", 0); }

   // Lai trong thang dat moc: nhac rut
   if(InpWarnProfitPct > 0)
   {
      double base = JGet("monBase") + JGet("monDep");
      if(base > 0)
      {
         double pct = (AccountInfoDouble(ACCOUNT_EQUITY) - base) / base * 100.0;
         int lvl = (int)MathFloor(pct / InpWarnProfitPct);
         if(lvl >= 1 && lvl > (int)JGet("monLvl"))
         {
            JSet("monLvl", lvl);
            JWarn(StringFormat("Tai khoan da lai %.0f%% trong thang. Rut tien goc + mot nua lai ve ngan hang truoc khi giao dich tiep.", pct));
         }
      }
   }
}
