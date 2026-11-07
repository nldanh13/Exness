//+------------------------------------------------------------------+
//| TrendBot/Report.mqh: OnTester: ghi ket qua backtest, phep thu chi phi, Monte Carlo
//+------------------------------------------------------------------+
//--- Dac diem tung lenh: vao "dau", "giua" hay "muon" cua xu huong? ------------------
// Tinh lai tu lich su gia tai thoi diem vao lenh (chi dung du lieu da co luc do).
double DonHi(const int from) { int i = iHighest(_Symbol, P_TF, MODE_HIGH, P_DonchianPeriod, from); return i < 0 ? 0 : iHigh(_Symbol, P_TF, i); }
double DonLo(const int from) { int i = iLowest(_Symbol,  P_TF, MODE_LOW,  P_DonchianPeriod, from); return i < 0 ? 0 : iLow(_Symbol,  P_TF, i); }
// Phan vi (0-100) cua funding hien tai so voi 365 ngay truoc do
double FundingPct(const datetime t, const double f)
{
   int n = ArraySize(g_fT);
   if(n == 0 || f == EMPTY_VALUE) return -1;
   int below = 0, cnt = 0;
   for(int i = n - 1; i >= 0; i--)
   {
      if(g_fT[i] > t) continue;
      if(g_fT[i] < t - 365 * 86400) break;
      cnt++; if(g_fR[i] < f) below++;
   }
   return cnt >= 300 ? 100.0 * below / cnt : -1;
}
// Rui ro ban dau cua vi the (tien), tu SL gui kem lenh vao. slDist tra ve khoang cach gia vao -> SL.
double PosRiskMoney(const ulong pid, double &slDist)
{
   slDist = 0;
   if(!HistorySelectByPosition(pid)) return 0;
   for(int i = 0; i < HistoryDealsTotal(); i++)
   {
      ulong d = HistoryDealGetTicket(i);
      if(HistoryDealGetInteger(d, DEAL_ENTRY) != DEAL_ENTRY_IN) continue;
      ulong ord = (ulong)HistoryDealGetInteger(d, DEAL_ORDER);
      double price = HistoryDealGetDouble(d, DEAL_PRICE), vol = HistoryDealGetDouble(d, DEAL_VOLUME);
      if(!HistoryOrderSelect(ord)) return 0;
      double sl = HistoryOrderGetDouble(ord, ORDER_SL);
      if(sl <= 0) return 0;
      double tsz = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE), tv = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
      slDist = MathAbs(price - sl);
      return tsz > 0 ? slDist / tsz * tv * vol : 0;
   }
   return 0;
}

void WriteTradeFeatures(const ulong &ids[], const double &net[])
{
   if(ArraySize(g_fT) == 0) LoadFunding();
   if(ArraySize(g_newsT) == 0) LoadNews();
   string file = InpPreset > 0 ? StringFormat("TrendBotTrades\\%03d.csv", InpPreset)
                               : "TrendBotTrades\\" + (P_TestLabel == "" ? "khong-ten" : P_TestLabel) + ".csv";
   int h = FileOpen(file, FILE_WRITE | FILE_CSV | FILE_ANSI | FILE_COMMON, ',');
   if(h == INVALID_HANDLE) return;
   FileWrite(h, "Lan", "ViThe", "Chieu", "ThoiGianVao", "KhoangCach_ATR", "DoRongKenh_ATR", "TuoiXuHuong_nen",
             "NenTuPhaVoDau", "SoLanPhaVo", "Funding%", "FundingPhanVi", "LaiRong", "R", "MFE_R", "MAE_R", "GioGiu", "GioToiTin", "Tin", "Spread_diem",
             "ADX", "ER20", "ATR_PhanVi90ngay", "GioUTC", "Thu");
   double tsz = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE), tv = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   for(int j = 0; j < ArraySize(ids); j++)
   {
      double slD = 0, riskM = PosRiskMoney(ids[j], slD);
      if(!HistorySelectByPosition(ids[j])) continue;
      datetime tin = 0, tout = 0; double pin = 0, pout = 0, vol = 0; bool buy = true;
      for(int i = 0; i < HistoryDealsTotal(); i++)
      {
         ulong d = HistoryDealGetTicket(i);
         long en = HistoryDealGetInteger(d, DEAL_ENTRY);
         if(en == DEAL_ENTRY_IN && tin == 0)
         {
            tin = (datetime)HistoryDealGetInteger(d, DEAL_TIME); pin = HistoryDealGetDouble(d, DEAL_PRICE);
            vol = HistoryDealGetDouble(d, DEAL_VOLUME); buy = HistoryDealGetInteger(d, DEAL_TYPE) == DEAL_TYPE_BUY;
         }
         if(en == DEAL_ENTRY_OUT || en == DEAL_ENTRY_OUT_BY)
         { tout = (datetime)HistoryDealGetInteger(d, DEAL_TIME); pout = HistoryDealGetDouble(d, DEAL_PRICE); }
      }
      if(tin == 0) continue;
      int s = iBarShift(_Symbol, P_TF, tin, false) + 1;          // nen tin hieu (nen vua dong luc vao lenh)
      double ab[];
      if(CopyBuffer(hATR, 0, s, 1, ab) != 1 || ab[0] <= 0) continue;
      double atr = ab[0];
      double chH = DonHi(s + 1), chL = DonLo(s + 1);
      double dist  = (buy ? pin - chH : chL - pin) / atr;        // da chay qua mep kenh bao xa (mua/ban duoi)
      double width = (chH - chL) / atr;                          // kenh hep = vua thoat tich luy
      // Dot xu huong hien tai: lui ve truoc cho toi khi gia dong o nua kia cua giua kenh
      int k = s, first = -1, breaks = 0;
      for(; k < s + 300; k++)
      {
         double hi = DonHi(k + 1), lo = DonLo(k + 1), c = iClose(_Symbol, P_TF, k);
         if(hi <= 0 || lo <= 0) break;
         if(buy ? c <= (hi + lo) / 2 : c >= (hi + lo) / 2) break;
         if(buy ? c > hi : c < lo) { first = k; breaks++; }
      }
      double f  = FundingAt(tin);
      double fp = FundingPct(tin, f);
      string nn; double hn = HoursToNews(tin, nn);           // tin FOMC / CPI gan nhat (am = da ra truoc khi vao)
      // Du dia di tiep (MFE) va muc bat loi lon nhat (MAE), tinh theo R = khoang SL ban dau.
      // Dung nen M1 nam tron trong khoang [vao, thoat] + gia vao/thoat that: khong tinh gia sau khi da dong lenh
      // (sai so toi da 1 phut o moi dau). Truoc day dung nen H4 gom ca nen thoat nen MFE bi thoi phong.
      double rDist = slD > 0 ? slD : atr * P_ATRMult, mfe = 0, mae = 0, hh = pin, ll = pin;
      long spr = -1;
      MqlRates m1[];
      int n1 = CopyRates(_Symbol, PERIOD_M1, tin - 60, tout > tin ? tout : tin, m1);
      for(int q = 0; q < n1; q++)
      {
         if(m1[q].time <= tin && m1[q].time + 60 > tin) spr = m1[q].spread;   // spread cua phut vao lenh
         if(m1[q].time <= tin || (tout > 0 && m1[q].time + 60 > tout)) continue;
         hh = MathMax(hh, m1[q].high); ll = MathMin(ll, m1[q].low);
      }
      if(pout > 0) { hh = MathMax(hh, pout); ll = MathMin(ll, pout); }
      if(rDist > 0)
      {
         mfe = (buy ? hh - pin : pin - ll) / rDist;
         mae = (buy ? pin - ll : hh - pin) / rDist;
      }
      double riskMoney = riskM > 0 ? riskM : (tsz > 0 ? rDist / tsz * tv * vol : 0);
      // Che do thi truong luc vao (nen tin hieu s): ADX, Efficiency Ratio 20 nen, phan vi ATR trong 90 ngay
      double adxV[]; double adxS = CopyBuffer(hADX, 0, s, 1, adxV) == 1 ? adxV[0] : -1;
      double er = -1, pathSum = 0;
      for(int q = s; q < s + 20; q++) pathSum += MathAbs(iClose(_Symbol, P_TF, q) - iClose(_Symbol, P_TF, q + 1));
      if(pathSum > 0) er = MathAbs(iClose(_Symbol, P_TF, s) - iClose(_Symbol, P_TF, s + 20)) / pathSum;
      int nA = (int)MathMin(3000, 90 * 86400 / PeriodSeconds(P_TF));
      double aH[]; double atrPct = -1;
      int gotA = CopyBuffer(hATR, 0, s, nA, aH);
      if(gotA > 50) { int below = 0; for(int q = 0; q < gotA; q++) if(aH[q] < atr) below++; atrPct = 100.0 * below / gotA; }
      MqlDateTime tm; TimeToStruct(tin, tm);
      FileWrite(h, P_TestLabel, (long)ids[j], buy ? "Buy" : "Sell", TimeToString(tin, TIME_DATE | TIME_MINUTES),
                DoubleToString(dist, 2), DoubleToString(width, 2), k - s, first >= 0 ? first - s : -1, breaks,
                f == EMPTY_VALUE ? "" : DoubleToString(f, 4), fp < 0 ? "" : DoubleToString(fp, 0),
                DoubleToString(net[j], 2), DoubleToString(riskMoney > 0 ? net[j] / riskMoney : 0, 2),
                DoubleToString(mfe, 2), DoubleToString(mae, 2),
                DoubleToString(tout > tin ? (double)(tout - tin) / 3600.0 : 0, 1),
                DoubleToString(hn, 1), nn, spr < 0 ? "" : IntegerToString(spr),
                adxS < 0 ? "" : DoubleToString(adxS, 1), er < 0 ? "" : DoubleToString(er, 2),
                atrPct < 0 ? "" : DoubleToString(atrPct, 0), tm.hour, tm.day_of_week);
   }
   FileClose(h);
}

//--- Ghi ket qua backtest ra file chung de so sanh nhieu cau hinh -----
double OnTester()
{
   double trades   = TesterStatistics(STAT_TRADES);
   double wins     = TesterStatistics(STAT_PROFIT_TRADES);
   double losses   = TesterStatistics(STAT_LOSS_TRADES);
   double gProfit  = TesterStatistics(STAT_GROSS_PROFIT);
   double gLoss    = TesterStatistics(STAT_GROSS_LOSS);
   double pf       = TesterStatistics(STAT_PROFIT_FACTOR);

   // Lai/lo theo tung nam (theo thoi diem cua tung deal, gom ca phi vao lenh) de xem co lai deu hay chi nho 1 dot
   double yearPL[]; int years[];
   datetime firstDeal = 0;   // lenh dau tien: neu muon hon ngay bat dau nhieu thi MT5 thieu du lieu
   if(HistorySelect(0, TimeCurrent()))
      for(int i = 0; i < HistoryDealsTotal(); i++)
      {
         ulong d = HistoryDealGetTicket(i);
         if(d == 0) continue;
         // Moi deal mua/ban (ca deal vao lenh, de tinh phi vao lenh), bo qua nap tien / credit
         long dt = HistoryDealGetInteger(d, DEAL_TYPE);
         if(dt != DEAL_TYPE_BUY && dt != DEAL_TYPE_SELL) continue;
         if(firstDeal == 0) firstDeal = (datetime)HistoryDealGetInteger(d, DEAL_TIME);
         MqlDateTime t; TimeToStruct((datetime)HistoryDealGetInteger(d, DEAL_TIME), t);
         int k = -1;
         for(int j = 0; j < ArraySize(years); j++) if(years[j] == t.year) { k = j; break; }
         if(k < 0) { k = ArraySize(years); ArrayResize(years, k + 1); ArrayResize(yearPL, k + 1); years[k] = t.year; yearPL[k] = 0; }
         yearPL[k] += DealNet(d);
      }
   // Phep thu chiu dung: tru them chi phi truot gia + spread moi chieu = % gia, cong theo tung vi the
   double stressPL[2], stressGP[2], stressGL[2];
   double stressPct[2] = {0.05, 0.10};
   ArrayInitialize(stressPL, 0); ArrayInitialize(stressGP, 0); ArrayInitialize(stressGL, 0);
   ulong  posIds[]; double posNet[]; double posCost[];
   double contract = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_CONTRACT_SIZE);
   if(HistorySelect(0, TimeCurrent()))
      for(int i = 0; i < HistoryDealsTotal(); i++)
      {
         ulong d = HistoryDealGetTicket(i);
         if(d == 0) continue;
         long ty = HistoryDealGetInteger(d, DEAL_TYPE);
         if(ty != DEAL_TYPE_BUY && ty != DEAL_TYPE_SELL) continue;
         ulong pid = (ulong)HistoryDealGetInteger(d, DEAL_POSITION_ID);
         int k = -1;
         for(int j = ArraySize(posIds) - 1; j >= 0; j--) if(posIds[j] == pid) { k = j; break; }
         if(k < 0) { k = ArraySize(posIds); ArrayResize(posIds, k + 1); ArrayResize(posNet, k + 1); ArrayResize(posCost, k + 1);
                     posIds[k] = pid; posNet[k] = 0; posCost[k] = 0; }
         posNet[k]  += DealNet(d);
         posCost[k] += HistoryDealGetDouble(d, DEAL_VOLUME) * contract * HistoryDealGetDouble(d, DEAL_PRICE) / 100.0;  // = 1% gia
      }
   // Thoi gian giu lenh TB (gio) va tong swap
   double holdSum = 0, swapSum = 0, commSum = 0; int holdN = 0;
   if(HistorySelect(0, TimeCurrent()))
      for(int j = 0; j < ArraySize(posIds); j++)
      {
         datetime tin = 0, tout = 0;
         if(!HistorySelectByPosition(posIds[j])) continue;
         for(int i = 0; i < HistoryDealsTotal(); i++)
         {
            ulong d = HistoryDealGetTicket(i);
            long en = HistoryDealGetInteger(d, DEAL_ENTRY);
            datetime tt = (datetime)HistoryDealGetInteger(d, DEAL_TIME);
            if(en == DEAL_ENTRY_IN && tin == 0) tin = tt;
            if(en == DEAL_ENTRY_OUT || en == DEAL_ENTRY_OUT_BY) tout = tt;
            swapSum += HistoryDealGetDouble(d, DEAL_SWAP);
            commSum += HistoryDealGetDouble(d, DEAL_COMMISSION) + HistoryDealGetDouble(d, DEAL_FEE);
         }
         if(tin > 0 && tout > tin) { holdSum += (double)(tout - tin) / 3600.0; holdN++; }
      }
   for(int s2 = 0; s2 < 2; s2++)
      for(int j = 0; j < ArraySize(posIds); j++)
      {
         double net = posNet[j] - posCost[j] * stressPct[s2];
         stressPL[s2] += net;
         if(net > 0) stressGP[s2] += net; else stressGL[s2] -= net;
      }

   // Thong ke theo R (1R = tien rui ro o SL ban dau): E[R], t-stat, ty le thang kem can duoi Wilson 95%
   int nP = ArraySize(posIds);
   double posR[]; ArrayResize(posR, nP);
   double sumR = 0, sumR2 = 0; int nR = 0, nWin = 0;
   for(int j = 0; j < nP; j++)
   {
      double sd = 0, rm = PosRiskMoney(posIds[j], sd);
      posR[j] = rm > 0 ? posNet[j] / rm : 0;
      if(rm <= 0) continue;
      sumR += posR[j]; sumR2 += posR[j] * posR[j]; nR++;
      if(posNet[j] > 0) nWin++;
   }
   double meanR = nR > 0 ? sumR / nR : 0;
   double sdR   = nR > 1 ? MathSqrt(MathMax(0, (sumR2 - nR * meanR * meanR) / (nR - 1))) : 0;
   double tStat = sdR > 0 ? meanR / (sdR / MathSqrt(nR)) : 0;
   double wilson = 0;
   if(nR > 0)
   {
      double ph = (double)nWin / nR, z = 1.96, z2 = z * z;
      wilson = (ph + z2 / (2 * nR) - z * MathSqrt(ph * (1 - ph) / nR + z2 / (4.0 * nR * nR))) / (1 + z2 / nR) * 100.0;
   }

   // Monte Carlo (bootstrap): rut ngau nhien co hoan lai tu lai/lo cac vi the, 1000 lan, de xem
   // sut giam co the te toi dau neu thu tu lenh khac di. Mau duoi ~200 lenh thi chi nen xem la tham khao.
   double dep = TesterStatistics(STAT_INITIAL_DEPOSIT);
   int    nPos = ArraySize(posNet), sims = 1000, ruin = 0, blk = 5;
   double stopDD = P_MaxDrawdownPct > 0 ? P_MaxDrawdownPct : 15.0;   // nguong bot tu dung han
   double mcDD[], mcStreak[];
   ArrayResize(mcDD, sims); ArrayResize(mcStreak, sims);
   MathSrand(12345);                                   // co dinh de chay lai ra cung so
   for(int m = 0; m < sims; m++)
   {
      double eq = dep, pk = dep, dd = 0; int run = 0, maxRun = 0;
      // Rut theo khoi 5 lenh lien tiep (giu cac chuoi thua theo cum khi thi truong di ngang)
      for(int j = 0; j < nPos; j += blk)
      {
         int st = (int)((double)MathRand() / 32768.0 * nPos);
         for(int q = 0; q < blk && j + q < nPos; q++)
         {
            eq += posNet[(st + q) % nPos];
            if(posNet[(st + q) % nPos] < 0) { run++; if(run > maxRun) maxRun = run; } else run = 0;
            if(eq > pk) pk = eq;
            if(pk > 0) dd = MathMax(dd, (pk - eq) / pk * 100.0);
         }
      }
      mcDD[m] = dd; mcStreak[m] = maxRun;
      if(dd >= stopDD) ruin++;
   }
   ArraySort(mcDD); ArraySort(mcStreak);
   double mcStreak95 = nPos > 0 ? mcStreak[(int)(sims * 0.95)] : 0;
   double mcMed = nPos > 0 ? mcDD[sims / 2] : 0;
   double mc95  = nPos > 0 ? mcDD[(int)(sims * 0.95)] : 0;

   // Phu thuoc vao vai lenh thang lon: bo 5 vi the lai nhieu nhat roi tinh lai loi nhuan va PF
   double srt[]; ArrayCopy(srt, posNet); ArraySort(srt);
   double top5 = 0, rGP = 0, rGL = 0, totNet = 0;
   for(int j = 0; j < nPos; j++)
   {
      totNet += srt[j];
      if(j >= nPos - 5 && srt[j] > 0) { top5 += srt[j]; continue; }
      if(srt[j] > 0) rGP += srt[j]; else rGL -= srt[j];
   }
   double plNoTop = totNet - top5;

   string byYear = "";
   for(int j = 0; j < ArraySize(years); j++)
      byYear += (j > 0 ? " " : "") + StringFormat("%d=%+.0f", years[j], yearPL[j]);

   // Moi lan chay 1 file rieng (chay song song nhieu lan cung luc khong ghi de nhau); script gom lai theo so thu tu.
   string file = InpPreset > 0 ? StringFormat("TrendBotRes\\%03d.csv", InpPreset)
                               : "TrendBotRes\\" + (P_TestLabel == "" ? "khong-ten" : P_TestLabel) + ".csv";
   int h = FileOpen(file, FILE_WRITE | FILE_CSV | FILE_ANSI | FILE_COMMON, ',');
   if(h != INVALID_HANDLE)
   {
         FileWrite(h, "Lan", "LoiNhuan", "ProfitFactor", "SoLenh", "TyLeThang%", "LaiTB", "LoTB",
                   "SutGiamMax%", "RecoveryFactor", "Sharpe", "Buy", "Sell", "BoQuaLot", "LenhDau", "LaiTheoNam",
                   "LoiNhuan_Truot0.05%", "PF_Truot0.05%", "LoiNhuan_Truot0.1%", "PF_Truot0.1%",
                   "MC_SutGiamTB%", "MC_SutGiam95%", "MC_XacSuatDungHan%", "ChanFunding", "ChanFearGreed", "ChanChuY", "ChanNasdaq",
                   "LamTronLot", "GiuLenhTB_gio", "TongSwap", "TongPhiHoaHong", "LoiNhuanTruocPhi", "ChanTin",
                   "LoiNhuan_BoTop5", "PF_BoTop5", "TyTrongTop5%",
                   "E_R", "tStat", "TyLeThang_CanDuoi95%", "MC_ChuoiThua95", "GiamCoDD", "NhoiLenh");
      FileWrite(h,
                P_TestLabel == "" ? "khong-ten" : P_TestLabel,
                DoubleToString(TesterStatistics(STAT_PROFIT), 2),
                DoubleToString(pf, 2),
                (int)trades,
                DoubleToString(trades > 0 ? wins / trades * 100.0 : 0, 1),
                DoubleToString(wins > 0 ? gProfit / wins : 0, 2),
                DoubleToString(losses > 0 ? gLoss / losses : 0, 2),
                DoubleToString(TesterStatistics(STAT_EQUITY_DDREL_PERCENT), 2),
                DoubleToString(TesterStatistics(STAT_RECOVERY_FACTOR), 2),
                DoubleToString(TesterStatistics(STAT_SHARPE_RATIO), 2),
                (int)TesterStatistics(STAT_LONG_TRADES),
                (int)TesterStatistics(STAT_SHORT_TRADES),
                g_minLotSkips,
                firstDeal > 0 ? TimeToString(firstDeal, TIME_DATE) : "-",
                byYear,
                DoubleToString(stressPL[0], 2), DoubleToString(stressGL[0] > 0 ? stressGP[0] / stressGL[0] : 0, 2),
                DoubleToString(stressPL[1], 2), DoubleToString(stressGL[1] > 0 ? stressGP[1] / stressGL[1] : 0, 2),
                DoubleToString(mcMed, 2), DoubleToString(mc95, 2), DoubleToString(100.0 * ruin / sims, 1), g_fundBlocked,
                g_fngBlocked, g_attBlocked, g_mktBlocked,
                g_roundUps, DoubleToString(holdN > 0 ? holdSum / holdN : 0, 1), DoubleToString(swapSum, 2),
                DoubleToString(commSum, 2), DoubleToString(TesterStatistics(STAT_PROFIT) - swapSum - commSum, 2), g_newsBlocked,
                DoubleToString(plNoTop, 2), DoubleToString(rGL > 0 ? rGP / rGL : 0, 2),
                DoubleToString(totNet > 0 ? top5 / totNet * 100.0 : 0, 0),
                DoubleToString(meanR, 3), DoubleToString(tStat, 2), DoubleToString(wilson, 1),
                DoubleToString(mcStreak95, 0), g_ddScaled, g_pyrAdds);
      FileClose(h);
   }
   else
      PrintFormat("Khong ghi duoc file ket qua: %d", GetLastError());
   WriteTradeFeatures(posIds, posNet);
   return pf;
}
//+------------------------------------------------------------------+
