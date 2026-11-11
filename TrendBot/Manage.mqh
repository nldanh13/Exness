//+------------------------------------------------------------------+
//| TrendBot/Manage.mqh: Doi soat lenh da dong, chot mot phan, hoa von, trailing
//+------------------------------------------------------------------+
//--- Quan ly lenh dang mo ------------------------------------------
//--- Doi soat vi the da dong het -----------------------------------
// Khong dua vao thu tu su kien OnTradeTransaction: moi vi the bot quan ly co marker O_<id>.
// Dinh ky (va ngay sau moi deal) kiem tra: vi the khong con mo VA lich su da co du khoi luong
// dong >= khoi luong vao thi moi chot (cooldown + don trang thai). Chua du thi thu lai lan sau.
bool     g_reconcile     = true;
datetime g_lastReconcile = 0;
void MarkTracked(const ulong posId)
{
   string k = GVName("O_" + (string)posId);
   if(!GlobalVariableCheck(k)) GlobalVariableSet(k, (double)TimeCurrent());
}
void FinalizeClosed(const ulong posId)
{
   double total = 0, inVol = 0, outVol = 0;
   datetime lastOut = 0;
   if(HistorySelectByPosition(posId))
      for(int i = 0; i < HistoryDealsTotal(); i++)
      {
         ulong d = HistoryDealGetTicket(i);
         if(d == 0) continue;
         long e = HistoryDealGetInteger(d, DEAL_ENTRY);
         total += DealNet(d);
         if(e == DEAL_ENTRY_IN) inVol += HistoryDealGetDouble(d, DEAL_VOLUME);
         else
         {
            outVol += HistoryDealGetDouble(d, DEAL_VOLUME);
            lastOut = (datetime)MathMax((double)lastOut, (double)HistoryDealGetInteger(d, DEAL_TIME));
         }
      }
   string oKey = GVName("O_" + (string)posId);
   // Vi the tu ban cu chi co R_: gan marker de dong ho "bo sau 1 ngay" bat dau tu bay gio
   if(!GlobalVariableCheck(oKey)) MarkTracked(posId);
   if(inVol <= 0 || outVol < inVol - 1e-8)
   {
      // Lich su chua ve kip: thu lai sau. Qua 1 ngay van khong co thi bo marker cho khoi ton.
      datetime seen = (datetime)(GlobalVariableCheck(oKey) ? GlobalVariableGet(oKey) : TimeCurrent());
      if(TimeCurrent() - seen < 86400) return;
   }
   else
   {
      string rKey      = GVName("R_" + (string)posId);
      double rDist     = GlobalVariableCheck(rKey) ? GlobalVariableGet(rKey) : 0;
      double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
      double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE_LOSS);
      double riskMoney = (rDist > 0 && tickSize > 0) ? rDist / tickSize * tickValue * inVol : 0;
      // Chi tinh la lenh thua khi lo hon 10% cua 1R; lenh hoa von am vai cent khong kich hoat nghi
      if(total < -MathMax(riskMoney * 0.1, 0.01) && lastOut > lastLossTime)
      {
         lastLossTime = lastOut;
         GlobalVariableSet(GVName("lastLoss"), (double)lastLossTime);   // giu qua khi khoi dong lai
      }
   }
   GlobalVariableDel(oKey);
   GlobalVariableDel(GVName("R_"  + (string)posId));
   GlobalVariableDel(GVName("P_"  + (string)posId));
   GlobalVariableDel(GVName("C_"  + (string)posId));
   GlobalVariableDel(GVName("PT_" + (string)posId));
   GlobalVariableDel(GVName("PV_" + (string)posId));
}
void ReconcileClosed()
{
   if(!g_reconcile && TimeCurrent() - g_lastReconcile < 5) return;
   g_reconcile = false;
   g_lastReconcile = TimeCurrent();
   string pO = GVName("O_"), pR = GVName("R_");     // R_ de bat ca vi the tu ban cu chua co marker
   ulong ids[];
   for(int i = GlobalVariablesTotal() - 1; i >= 0; i--)
   {
      string n = GlobalVariableName(i), rest = "";
      if(StringFind(n, pO) == 0)      rest = StringSubstr(n, StringLen(pO));
      else if(StringFind(n, pR) == 0) rest = StringSubstr(n, StringLen(pR));
      else continue;
      ulong id = (ulong)StringToInteger(rest);
      if(id == 0 || (string)id != rest) continue;  // bo qua ten kieu cu khong phai so
      int sz = ArraySize(ids); ArrayResize(ids, sz + 1); ids[sz] = id;
   }
   for(int j = 0; j < ArraySize(ids); j++)
      if(!PositionOpenById(ids[j])) FinalizeClosed(ids[j]);
}

void ManagePositions()
{
   double atr = 0;
   bool haveAtr = GetValue(hATR, 0, 1, atr);
   if(haveAtr) atr = SLAtr(atr);           // InpSLTFmin: trailing / uoc luong 1R theo ATR khung SL
   double minL  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double minDist = (double)MathMax(SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL),
                                    SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL)) * _Point;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !IsOwnSelected()) continue;
      // Trang thai va lich su gan voi POSITION_IDENTIFIER (khong doi suot doi vi the),
      // con lenh gui len server dung ticket.
      ulong posId = (ulong)PositionGetInteger(POSITION_IDENTIFIER);
      MarkTracked(posId);

      double open = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl   = PositionGetDouble(POSITION_SL);
      double tp   = PositionGetDouble(POSITION_TP);
      double vol  = PositionGetDouble(POSITION_VOLUME);
      bool   isBuy = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);

      // Luu khoang rui ro ban dau (1R) ngay lan dau thay lenh
      string rKey = GVName("R_" + (string)posId);
      string pKey = GVName("P_" + (string)posId);
      if(!GlobalVariableCheck(rKey))
      {
         // 1) Nhan lai trang thai tu ten bien cua ban cu (truoc v2.3: chi co magic)
         string oldR = "BTCEA_" + (string)P_Magic + "_R_" + (string)ticket;   // ban <= 2.2
         string oldP = "BTCEA_" + (string)P_Magic + "_P_" + (string)ticket;
         if(!GlobalVariableCheck(oldR))                                         // ban 2.3-2.5 (theo ticket)
         {
            oldR = GVName("R_" + (string)ticket);
            oldP = GVName("P_" + (string)ticket);
         }
         if(GlobalVariableCheck(oldR))
         {
            GlobalVariableSet(rKey, GlobalVariableGet(oldR));
            if(GlobalVariableCheck(oldP)) GlobalVariableSet(pKey, GlobalVariableGet(oldP));
            GlobalVariableDel(oldR); GlobalVariableDel(oldP);
         }
         else
         {
            if(sl <= 0) continue;
            bool slOnProfitSide = isBuy ? (sl >= open) : (sl <= open);
            double estR = haveAtr ? atr * P_ATRMult : 0;
            if(slOnProfitSide || (estR > 0 && MathAbs(open - sl) < 0.3 * estR))
            {
               // 2) Mat trang thai va SL da doi ve hoa von/lai: khong suy ra duoc 1R that.
               //    Uoc luong 1R bang ATR x he so, va coi nhu da chot mot phan de khong chot nham.
               if(estR <= 0) continue;
               GlobalVariableSet(rKey, estR);
               GlobalVariableSet(pKey, 1);
               PrintFormat("Lenh #%s: khong co trang thai cu, uoc luong 1R = %.2f", (string)ticket, estR);
            }
            else
               GlobalVariableSet(rKey, MathAbs(open - sl));
         }
      }
      double risk = GlobalVariableGet(rKey);
      if(risk <= 0) continue;

      // Muc hoa von thuc: gia vao + (phi 2 chieu + swap am) quy ra gia + buffer
      string cKey = GVName("C_" + (string)posId);
      if(!GlobalVariableCheck(cKey))
      {
         double comm = 0, inVol = 0;
         if(HistorySelectByPosition(posId))
            for(int k = 0; k < HistoryDealsTotal(); k++)
            {
               ulong d = HistoryDealGetTicket(k);
               if(d > 0 && HistoryDealGetInteger(d, DEAL_ENTRY) == DEAL_ENTRY_IN)
               {
                  comm  += HistoryDealGetDouble(d, DEAL_COMMISSION) + HistoryDealGetDouble(d, DEAL_FEE);
                  inVol += HistoryDealGetDouble(d, DEAL_VOLUME);
               }
            }
         // Phi mot chieu tren 1 lot, chia cho khoi luong LUC VAO LENH (khong phai khoi luong con lai)
         GlobalVariableSet(cKey, MathAbs(comm) / MathMax(inVol > 0 ? inVol : vol, 1e-8));
      }
      double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
      double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE_LOSS);
      double costMoney = GlobalVariableGet(cKey) * vol * 2.0 + MathMax(0.0, -PositionGetDouble(POSITION_SWAP));
      double costPrice = (tickSize > 0 && tickValue > 0) ? costMoney / (tickValue * vol) * tickSize : 0;
      double beOffset  = costPrice + P_BEBufferR * risk;
      double beLevel   = isBuy ? open + beOffset : open - beOffset;

      double price = isBuy ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double rNow  = (isBuy ? price - open : open - price) / risk;

      // 1) Chot loi mot phan
      // Luu khoi luong CON LAI muc tieu (PV_) o lan dau. Moi lan chi dong phan con thieu so voi muc tieu,
      // nen neu server chi khop mot phan (DONE_PARTIAL) thi lan sau bot dong not, khong dong lo qua tay.
      string vKey = GVName("PV_" + (string)posId);
      if(P_UsePartial && !GlobalVariableCheck(pKey) && (rNow >= P_PartialR || GlobalVariableCheck(vKey)))
      {
         if(!GlobalVariableCheck(vKey))
         {
            double firstClose = NormalizeVolume(vol * P_PartialPct / 100.0);
            if(firstClose < minL || vol - firstClose < minL - 1e-9)
            {
               GlobalVariableSet(pKey, 1);              // lot qua nho de chia, bo qua
               continue;
            }
            GlobalVariableSet(vKey, vol - firstClose);
         }
         double target   = GlobalVariableGet(vKey);
         double closeVol = NormalizeVolume(vol - target);
         if(vol <= target + 1e-9 || closeVol < minL - 1e-9)
         {
            GlobalVariableSet(pKey, 1);                 // da dat muc tieu (hoac phan thieu nho hon lot toi thieu)
            GlobalVariableDel(vKey);
            GlobalVariableDel(GVName("PT_" + (string)posId));
            continue;
         }
         // Thu lai toi da 1 lan / 10 giay moi lenh (tu choi, hoac cho vi the cap nhat sau khop mot phan)
         string tKey = GVName("PT_" + (string)posId);
         bool sentNow = false;
         if(TimeCurrent() - (datetime)(GlobalVariableCheck(tKey) ? GlobalVariableGet(tKey) : 0) >= 10)
         {
            sentNow = true;
            GlobalVariableSet(tKey, (double)TimeCurrent());
            bool sent;
            if(IsHedging())
               sent = PrepSend() && trade.PositionClosePartial(ticket, closeVol);
            else   // Netting: gui lenh nguoc chieu cung magic de giam khoi luong vi the
               sent = PrepSend() && (isBuy ? trade.Sell(closeVol, _Symbol, 0, 0, 0, "partial")
                                           : trade.Buy (closeVol, _Symbol, 0, 0, 0, "partial"));
            if(TradeDone(sent, "Chot mot phan", "#" + (string)ticket))
            {
               // Chi khi khop DU moi danh dau xong; DONE_PARTIAL thi giu PV_ de lan sau dong not phan thieu
               if(trade.ResultRetcode() == TRADE_RETCODE_DONE && trade.ResultVolume() >= closeVol - 1e-9)
               {
                  GlobalVariableSet(pKey, 1);
                  GlobalVariableDel(vKey);
                  GlobalVariableDel(tKey);
               }
               // Netting: neu server xoa SL/TP cua vi the sau deal giam, dat lai nhu cu
               if(!IsHedging() && PositionSelect(_Symbol) &&
                  ((sl > 0 && PositionGetDouble(POSITION_SL) <= 0) || (tp > 0 && PositionGetDouble(POSITION_TP) <= 0)))
                  TradeDone(PrepSend() && trade.PositionModify(_Symbol, sl, tp), "Dat lai SL/TP", _Symbol);
            }
         }
         // Vua gui lenh dong thi de tick sau moi sua SL (khoi luong/vi the co the vua doi).
         // Neu dang cho thu lai (bi tu choi), van chay hoa von + trailing ben duoi de SL khong bi dung.
         if(sentNow) continue;
      }

      // 2) Hoa von va 3) trailing ATR
      double newSL = sl;
      if(P_UseBreakeven && rNow >= P_BreakevenR)
      {
         if(isBuy  && (sl <= 0 || sl < beLevel)) newSL = beLevel;
         if(!isBuy && (sl <= 0 || sl > beLevel)) newSL = beLevel;
      }
      if(P_UseTrailing && haveAtr && rNow >= P_TrailStartR)
      {
         double cand = isBuy ? price - atr * P_TrailATRMult : price + atr * P_TrailATRMult;
         if(isBuy  && cand > newSL) newSL = cand;
         if(!isBuy && (newSL <= 0 || cand < newSL)) newSL = cand;
      }
      newSL = NormalizeDouble(newSL, _Digits);

      double minStep = MathMax(_Point * 10, risk * 0.05);   // tranh sua lenh lien tuc
      bool better    = isBuy ? (newSL > sl + minStep) : (sl <= 0 || newSL < sl - minStep);
      bool validDist = isBuy ? (price - newSL > minDist) : (newSL - price > minDist);
      if(newSL > 0 && better && validDist)
         TradeDone(PrepSend() && trade.PositionModify(ticket, newSL, tp), "Sua SL", "#" + (string)ticket);
   }
}

//--- Nhoi lenh theo da (pyramiding) va thoat khi het da. Goi moi nen moi khi dang co lenh.
// Gia di thuan them InpPyramidStepATR x ATR tu lenh gan nhat va van dung phia EMA nhanh -> vao them 1 lenh
// cung chieu (toi da InpPyramidMax). Truoc khi vao them, cac lenh cu doi SL ve hoa von, nen rui ro mo
// cua ca chuoi chi con khoang 1 lenh. Khong bao gio nhoi khi dang lo.
// InpExitOnEMA: nen dong cat EMA nhanh nguoc chieu -> dong het (chot loi khi co dau hieu dao chieu).
int g_pyrAdds = 0;
ENUM_TIMEFRAMES PyrTF()
{
   switch(P_PyramidTFmin)
   {
      case 1: return PERIOD_M1;   case 5: return PERIOD_M5;   case 15: return PERIOD_M15;
      case 30: return PERIOD_M30; case 60: return PERIOD_H1;  case 120: return PERIOD_H2;
   }
   return P_TF;
}
// addOnly = true: goi tu khung nho (InpPyramidTFmin), chi xet them lop; cac luat thoat van chay theo nen khung chinh
void PyramidStep(const bool addOnly = false)
{
   double fast, atr;
   if(!GetValue(hFast, 0, 1, fast) || !GetValue(hATR, 0, 1, atr) || atr <= 0) return;
   atr = SLAtr(atr);                       // InpSLTFmin: buoc nhoi va SL lop moi theo ATR khung SL
   double c1 = iClose(_Symbol, addOnly ? PyrTF() : P_TF, 1);
   int cnt = 0; bool buy = true; double lastOpen = 0; datetime lastT = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetTicket(i) == 0 || !IsOwnSelected()) continue;
      cnt++;
      buy = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY;
      datetime t = (datetime)PositionGetInteger(POSITION_TIME);
      if(t >= lastT) { lastT = t; lastOpen = PositionGetDouble(POSITION_PRICE_OPEN); }
   }
   if(cnt == 0) return;
   if(!addOnly && P_Strategy == STRAT_IMOM)
   {
      datetime t0 = iTime(_Symbol, P_TF, 0);
      MqlDateTime d; TimeToStruct(t0, d);
      datetime day = t0 - (d.hour * 3600 + d.min * 60 + d.sec);
      // Dong o nen dau tien tu 17:00 New York (hoac neu vi ly do nao do lenh con giu ngoai khung 16:30-17:00)
      datetime tExit = NYTime(day, 17 * 60);
      if(t0 >= tExit || t0 < NYTime(day, 16 * 60 + 30)) { g_status = "Het phien (17:00 New York), dong lenh"; CloseAll(); return; }
   }
   if(!addOnly && P_ExitOnBar)
   {
      double o1 = iOpen(_Symbol, P_TF, 1);
      if(buy ? c1 < o1 : c1 > o1) { g_status = "Nen nguoc chieu, dong het"; CloseAll(); return; }
   }
   if(!addOnly && P_ExitOnEMA && (buy ? c1 < fast : c1 > fast))
   {
      g_status = "Het da (cat EMA), dong het";
      CloseAll();
      return;
   }
   if(cnt >= P_PyramidMax || IsHalted() || GuardHalted() || DailyLossHit()) return;
   if(!MTFOk(buy)) return;                                   // cac khung nho/lon chua dong thuan thi chua nhoi
   if(buy ? (c1 - lastOpen < P_PyramidStepATR * atr || c1 <= fast) : (lastOpen - c1 < P_PyramidStepATR * atr || c1 >= fast)) return;
   if(P_MaxSpreadPoints > 0 && SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) > P_MaxSpreadPoints) return;
   // Gio nghi / cuoi tuan va tin My (v5.10.19): nhoi la them rui ro, phai qua cung bo loc nhu lenh vao moi
   string pw = "", pn = "";
   if(!TimeAllowed(pw)) return;
   if(P_AvoidUSNews && USNewsNear(pn)) return;

   // Doi SL cac lenh cu ve it nhat hoa von
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong tk = PositionGetTicket(i);
      if(tk == 0 || !IsOwnSelected()) continue;
      double op = PositionGetDouble(POSITION_PRICE_OPEN), sl = PositionGetDouble(POSITION_SL), tp = PositionGetDouble(POSITION_TP);
      bool better = buy ? (sl < op) : (sl <= 0 || sl > op);
      if(better) TradeDone(PrepSend() && trade.PositionModify(tk, NormalizeDouble(op, _Digits), tp), "Sua SL", "#" + (string)tk);
   }
   // Chi nhoi khi DOC LAI trang thai vi the thay moi lop cu da co SL >= hoa von. Server tu choi sua SL
   // (gan gia, thi truong dong...) thi lop cu van chiu rui ro day du -> bo qua lan nhoi nay, thu lai o nen sau.
   // Them mot lop bao ve trong CalcLots (v5.9): rui ro con mo cua lop cu + lop moi khong vuot 1 lenh chuan.
   double tol = _Point * 2;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong tk = PositionGetTicket(i);
      if(tk == 0 || !IsOwnSelected()) continue;
      double op = PositionGetDouble(POSITION_PRICE_OPEN), sl = PositionGetDouble(POSITION_SL);
      bool safe = buy ? (sl > 0 && sl >= op - tol) : (sl > 0 && sl <= op + tol);
      if(!safe)
      {
         g_status = "Chua doi duoc SL lop cu ve hoa von, chua nhoi";
         if(ShouldNotify("pyrsl", 3600)) Print("Nhoi lenh: lenh #", tk, " chua co SL hoa von (SL=", sl, ", gia vao=", op, "), bo qua lan nhoi nay.");
         return;
      }
   }
   double slDist = atr * P_ATRMult;
   if(!GroupLock()) { lastBarTime = 0; return; }
   double lots = CalcLots(slDist);
   MqlTick tick;
   if(lots <= 0 || !SymbolInfoTick(_Symbol, tick)) { GroupUnlock(); return; }
   // Geometric pyramiding: lớp 2 <= factor, lớp 3 <= factor^2; KHONG lam tron len min lot.
   if(P_PyramidLotFactor <= 0 || P_PyramidLotFactor > 1) { GroupUnlock(); return; }
   double scaled = NormalizeVolume(lots * MathPow(P_PyramidLotFactor, cnt));
   if(scaled < SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN) - 1e-9)
   {
      if(ShouldNotify("pyrMinLot", 3600)) PrintFormat("Bo nhoi: %.2f lot x %.3f^%d < minlot, can von lon hon de nhoi giam khoi luong.", lots, P_PyramidLotFactor, cnt);
      GroupUnlock(); return;
   }
   g_lastRisk *= scaled / lots;
   lots = scaled;
   GroupReserve(g_lastRisk);
   double price = buy ? tick.ask : tick.bid;
   g_reqPrice = price; g_reqSpread = (long)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   double sl = buy ? price - slDist : price + slDist;
   double tp = P_RR > 0 ? (buy ? price + slDist * P_RR : price - slDist * P_RR) : 0.0;
   bool ok = PrepSend() && (buy ? trade.Buy(lots, _Symbol, price, NormalizeDouble(sl, _Digits), tp > 0 ? NormalizeDouble(tp, _Digits) : 0.0, "BTC bot BUY+")
                                : trade.Sell(lots, _Symbol, price, NormalizeDouble(sl, _Digits), tp > 0 ? NormalizeDouble(tp, _Digits) : 0.0, "BTC bot SELL+"));
   uint rc = trade.ResultRetcode();
   bool filled = ok && (rc == TRADE_RETCODE_DONE || rc == TRADE_RETCODE_DONE_PARTIAL);
   if(!filled) GroupClear(); else g_pyrAdds++;
   GroupUnlock();
   TradeDone(ok, "Nhoi lenh", buy ? "BUY" : "SELL");
}
