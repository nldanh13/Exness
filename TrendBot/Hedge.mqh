//+------------------------------------------------------------------+
//| TrendBot/Hedge.mqh: Khoa lenh (hedging) 3 buoc - khoa, mo khoa, nhoi (v5.18, THU NGHIEM)
//+------------------------------------------------------------------+
// Buoc 1 - KHOA: mo them 1 lenh nguoc chieu cung khoi luong voi lenh dang giu (chi khi bot giu dung 1 lenh).
//   - Khoa lo  (InpHedgeLockLossR > 0): lenh dang lo >= x R (x < 1, truoc khi cham SL) va chua ro hoi hay roi tiep.
//   - Khoa loi (InpHedgeLockProfitR > 0): lenh dang loi >= x R va sap co tin My (InpHedgeNews) hoac sap cuoi tuan
//     (thu Sau tu InpHedgeFriHour gio server, ca thu Bay / Chu nhat).
//   Luc khoa: bo SL / TP cua lenh goc (2 lenh bu tru nhau, tai khoan gan nhu dung yen), ghi lai vung gia quan trong
//   = dinh / day InpHedgeZoneBars nen gan nhat.
// Buoc 2 - MO KHOA: KHONG mo vi 1 cay nen. Chi mo khi nen dong cua han ra ngoai vung, sau do co nen hoi ve test lai
//   (cham trong InpHedgeRetestATR x ATR quanh mep vung) va van dong cua ngoai vung. Gia xac nhan tang: dong lenh ban,
//   giu lenh mua; xac nhan giam: nguoc lai. Pha vo gia (dong lai vao trong vung) thi bo, cho xac nhan moi.
//   Khoa loi: chi mo khoa sau khi tin / cuoi tuan da qua.
//   Lenh con lai: SL duoi day nen test lai (tren dinh voi lenh ban) - 0,25 ATR; dang loi thi SL it nhat hoa von.
// Buoc 3 - NHOI: lenh con lai tra ve quan ly binh thuong (hoa von, trailing, nhoi lenh InpPyramidMax > 1).
// Khong khoa qua lau: giu ca 2 lenh qua InpHedgeMaxBars nen thi dong ca 2 (= cat lo). Ton phi gap doi khi giu 2 lenh.
// Trang thai luu Global Variables HG_* (giu qua khi khoi dong lai). Ca 2 lenh deu mang magic cua bot.
ulong    HG_Main = 0, HG_Leg = 0;        // ticket lenh goc / lenh khoa (tai khoan hedging: ticket vi the)
double   HG_Hi = 0, HG_Lo = 0;           // vung gia quan trong luc khoa
datetime HG_T = 0;                       // thoi diem khoa
int      HG_Brk = 0;                     // +1 da dong cua tren vung, -1 duoi vung, 0 chua
int      HG_Kind = 0;                    // 1 khoa lo, 2 khoa loi
bool     HG_Loaded = false;
datetime HG_LastBar = 0;
int      g_hgLocks = 0, g_hgUnlocks = 0, g_hgTimeouts = 0;

void HedgeSave()
{
   GlobalVariableSet(GVName("HG_main"), (double)HG_Main); GlobalVariableSet(GVName("HG_leg"), (double)HG_Leg);
   GlobalVariableSet(GVName("HG_hi"), HG_Hi);             GlobalVariableSet(GVName("HG_lo"), HG_Lo);
   GlobalVariableSet(GVName("HG_t"), (double)HG_T);       GlobalVariableSet(GVName("HG_brk"), HG_Brk);
   GlobalVariableSet(GVName("HG_kind"), HG_Kind);
}
void HedgeLoadOnce()
{
   if(HG_Loaded) return;
   HG_Loaded = true;
   if(!GlobalVariableCheck(GVName("HG_main"))) return;
   HG_Main = (ulong)GlobalVariableGet(GVName("HG_main")); HG_Leg = (ulong)GlobalVariableGet(GVName("HG_leg"));
   HG_Hi = GlobalVariableGet(GVName("HG_hi"));             HG_Lo = GlobalVariableGet(GVName("HG_lo"));
   HG_T = (datetime)GlobalVariableGet(GVName("HG_t"));     HG_Brk = (int)GlobalVariableGet(GVName("HG_brk"));
   HG_Kind = (int)GlobalVariableGet(GVName("HG_kind"));
}
void HedgeClear()
{
   HG_Main = 0; HG_Leg = 0; HG_Hi = 0; HG_Lo = 0; HG_T = 0; HG_Brk = 0; HG_Kind = 0;
   string k[] = {"HG_main", "HG_leg", "HG_hi", "HG_lo", "HG_t", "HG_brk", "HG_kind"};
   for(int i = 0; i < ArraySize(k); i++) GlobalVariableDel(GVName(k[i]));
}
// Dang khoa: ManagePositions / nhoi / thoat lenh dung yen tam nghi (2 lenh khong co SL, bu tru nhau)
bool HedgeActive() { HedgeLoadOnce(); return HG_Main > 0; }

// Tin / cuoi tuan sap toi hoac dang dien ra (ly do khoa loi; con dung thi chua mo khoa)
bool HedgeEventNear()
{
   if(P_HedgeNews) { string nm = ""; if(USNewsNear(nm)) return true; }
   if(P_HedgeFriHour >= 0)
   {
      MqlDateTime dt; TimeToStruct(TimeCurrent(), dt);
      if(dt.day_of_week == 6 || dt.day_of_week == 0 || (dt.day_of_week == 5 && dt.hour >= P_HedgeFriHour)) return true;
   }
   return false;
}

// Dat SL cho lenh con lai roi tra ve quan ly binh thuong. Khong dat duoc SL thi dong luon: khong de lenh tran.
void HedgeRelease(const ulong keep, const double structSL, const string why)
{
   HedgeClear();
   if(!PositionSelectByTicket(keep)) return;
   bool buy = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY;
   double op = PositionGetDouble(POSITION_PRICE_OPEN), cur = PositionGetDouble(POSITION_PRICE_CURRENT);
   double minDist = (double)MathMax(SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL),
                                    SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL)) * _Point + _Point * 2;
   double sl = structSL;
   if(buy && cur - op > minDist) sl = MathMax(sl, op);          // dang loi: SL it nhat hoa von
   if(!buy && op - cur > minDist) sl = MathMin(sl, op);
   bool valid = buy ? (sl > 0 && sl < cur - minDist) : (sl > cur + minDist);
   bool ok = valid && PrepSend() && trade.PositionModify(keep, NormalizeDouble(sl, _Digits), 0);
   if(!ok)
   {
      PrintFormat("Mo khoa (%s): khong dat duoc SL %.2f cho lenh #%s -> dong lenh, khong de lenh khong co SL.", why, sl, (string)keep);
      if(PrepSend()) trade.PositionClose(keep);
      return;
   }
   g_hgUnlocks++;
   string msg = StringFormat("MO KHOA (%s): giu lenh %s #%s, SL %.2f", why, buy ? "MUA" : "BAN", (string)keep, sl);
   Print(msg);
   DecisionLog("khoa-lenh", msg);
   if(ShouldNotify("hedgeOpen", 60)) Notify(msg);
}

void HedgeTryLock()
{
   if((P_HedgeLockLossR <= 0 && P_HedgeLockProfitR <= 0) || P_Strategy == STRAT_GRID || IsHalted() || !IsHedging()) return;
   int cnt = 0; ulong t = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong tk = PositionGetTicket(i);
      if(tk == 0 || !IsOwnSelected()) continue;
      cnt++; t = tk;
   }
   if(cnt != 1 || !PositionSelectByTicket(t)) return;          // chi khoa 1 lenh don (khong khoa ca chuoi nhoi)
   ulong  posId = (ulong)PositionGetInteger(POSITION_IDENTIFIER);
   bool   buy = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY;
   double op = PositionGetDouble(POSITION_PRICE_OPEN), cur = PositionGetDouble(POSITION_PRICE_CURRENT);
   double vol = PositionGetDouble(POSITION_VOLUME);
   string rKey = GVName("R_" + (string)posId);
   double r = GlobalVariableCheck(rKey) ? GlobalVariableGet(rKey) : 0;
   if(r <= 0) return;
   if(GlobalVariableCheck(GVName("HL_" + (string)posId))) return;   // moi lenh chi khoa 1 lan (khong khoa / mo lien tuc ton phi)
   double move = (buy ? cur - op : op - cur) / r;
   int kind = 0;
   if(P_HedgeLockLossR > 0 && move <= -P_HedgeLockLossR) kind = 1;
   else if(P_HedgeLockProfitR > 0 && move >= P_HedgeLockProfitR && HedgeEventNear()) kind = 2;
   if(kind == 0) return;
   if(P_MaxSpreadPoints > 0 && SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) > P_MaxSpreadPoints) return;

   int n = MathMax(5, P_HedgeZoneBars);
   int hi = iHighest(_Symbol, P_TF, MODE_HIGH, n, 1), lo = iLowest(_Symbol, P_TF, MODE_LOW, n, 1);
   if(hi < 0 || lo < 0) return;
   double zHi = MathMax(iHigh(_Symbol, P_TF, hi), cur), zLo = MathMin(iLow(_Symbol, P_TF, lo), cur);

   bool ok = PrepSend() && (buy ? trade.Sell(vol, _Symbol, 0, 0, 0, "BTC bot KHOA") : trade.Buy(vol, _Symbol, 0, 0, 0, "BTC bot KHOA"));
   uint rc = trade.ResultRetcode();
   if(!ok || (rc != TRADE_RETCODE_DONE && rc != TRADE_RETCODE_DONE_PARTIAL))
   {
      if(ShouldNotify("hedgeFail", 3600)) PrintFormat("Khoa lenh that bai: retcode %u %s", rc, trade.ResultComment());
      return;
   }
   ulong leg = trade.ResultOrder();                                     // hedging: ticket vi the = ticket lenh mo
   ulong deal = trade.ResultDeal();
   if(deal > 0 && HistoryDealSelect(deal)) leg = (ulong)HistoryDealGetInteger(deal, DEAL_POSITION_ID);
   HG_Main = t; HG_Leg = leg; HG_Hi = zHi; HG_Lo = zLo; HG_T = TimeCurrent(); HG_Brk = 0; HG_Kind = kind;
   HedgeSave();
   g_hgLocks++;
   // Lenh khoa mang 1R cua lenh goc (khi duoc giu lai sau mo khoa, hoa von / trailing tinh theo R nay)
   GlobalVariableSet(GVName("R_" + (string)leg), r);
   string pK = GVName("P_" + (string)posId);
   if(GlobalVariableCheck(pK)) GlobalVariableSet(GVName("P_" + (string)leg), GlobalVariableGet(pK));
   MarkTracked(leg);
   GlobalVariableSet(GVName("HL_" + (string)posId), 1); GlobalVariableSet(GVName("HL_" + (string)leg), 1);
   TradeDone(PrepSend() && trade.PositionModify(t, 0, 0), "Bo SL/TP lenh goc khi khoa", "#" + (string)t);
   string msg = StringFormat("KHOA %s: lenh %s #%s %.2f R, vung %.2f - %.2f", kind == 1 ? "LO" : "LOI",
                             buy ? "MUA" : "BAN", (string)t, move, zLo, zHi);
   Print(msg);
   DecisionLog("khoa-lenh", msg);
   if(ShouldNotify("hedgeLock", 60)) Notify(msg);
}

void HedgeManage()
{
   bool mOk = PositionSelectByTicket(HG_Main), lOk = PositionSelectByTicket(HG_Leg);
   double atr = 0;
   bool haveAtr = GetValue(hATR, 0, 1, atr) && atr > 0;
   if(!mOk && !lOk) { HedgeClear(); return; }
   if(!mOk || !lOk)
   {
      // Mot lenh bi dong ngoai y muon (dong tay, stop out...): lenh con lai can SL ngay, dat o mep vung ben kia
      ulong keep = mOk ? HG_Main : HG_Leg;
      PositionSelectByTicket(keep);
      bool buy = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY;
      double buf = haveAtr ? 0.25 * atr : 0;
      HedgeRelease(keep, buy ? HG_Lo - buf : HG_Hi + buf, "mot lenh da dong");
      return;
   }
   int held = (int)((TimeCurrent() - HG_T) / MathMax(1, PeriodSeconds(P_TF)));
   if(P_HedgeMaxBars > 0 && held >= P_HedgeMaxBars)
   {
      bool c1 = PrepSend() && trade.PositionClose(HG_Main);
      bool c2 = PrepSend() && trade.PositionClose(HG_Leg);
      if(c1 && c2)
      {
         g_hgTimeouts++;
         PrintFormat("Khoa qua %d nen chua co xac nhan: dong ca 2 lenh (cat lo).", held);
         HedgeClear();
      }
      return;
   }
   datetime b = iTime(_Symbol, P_TF, 0);
   if(b == 0 || b == HG_LastBar || !haveAtr) return;
   HG_LastBar = b;
   if(IsHalted()) return;                                       // dung han: giu khoa, khong mo them rui ro
   if(HG_Kind == 2 && HedgeEventNear()) return;                 // khoa loi: cho tin / cuoi tuan qua
   if(iTime(_Symbol, P_TF, 1) < HG_T) return;                    // nen dong cua dau tien sau khi khoa
   double c = iClose(_Symbol, P_TF, 1), h = iHigh(_Symbol, P_TF, 1), l = iLow(_Symbol, P_TF, 1);
   double tol = P_HedgeRetestATR * atr;
   int brk0 = HG_Brk;
   if(HG_Brk == 1 && c > HG_Hi && l <= HG_Hi + tol)
   {
      // Xac nhan tang: dong lenh ban, giu lenh mua
      bool mainBuy = PositionSelectByTicket(HG_Main) && PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY;
      ulong keep = mainBuy ? HG_Main : HG_Leg, drop = mainBuy ? HG_Leg : HG_Main;
      if(PrepSend() && trade.PositionClose(drop)) HedgeRelease(keep, MathMin(l, HG_Hi) - 0.25 * atr, "xac nhan tang");
      return;
   }
   if(HG_Brk == -1 && c < HG_Lo && h >= HG_Lo - tol)
   {
      bool mainBuy = PositionSelectByTicket(HG_Main) && PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY;
      ulong keep = mainBuy ? HG_Leg : HG_Main, drop = mainBuy ? HG_Main : HG_Leg;
      if(PrepSend() && trade.PositionClose(drop)) HedgeRelease(keep, MathMax(h, HG_Lo) + 0.25 * atr, "xac nhan giam");
      return;
   }
   if(c > HG_Hi) HG_Brk = 1;                                    // dong cua han tren vung: cho nen test lai
   else if(c < HG_Lo) HG_Brk = -1;
   else HG_Brk = 0;                                             // quay lai trong vung: pha vo gia, cho tiep
   if(HG_Brk != brk0) HedgeSave();
}

// Goi moi lan quan ly lenh, TRUOC ManagePositions
void HedgeTick()
{
   if(P_Strategy == STRAT_GRID) return;
   if(HedgeActive()) HedgeManage();
   else HedgeTryLock();
}
