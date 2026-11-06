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
