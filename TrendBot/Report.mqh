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

// Phan phoi chuan: CDF (xap xi erf Abramowitz-Stegun 7.1.26, sai so < 1,5e-7) va nghich dao (Acklam, sai so ~1e-9)
double NormCdf(const double x)
{
   double z = MathAbs(x) / MathSqrt(2.0), t = 1.0 / (1.0 + 0.3275911 * z);
   double e = 1.0 - (((((1.061405429 * t - 1.453152027) * t) + 1.421413741) * t - 0.284496736) * t + 0.254829592) * t * MathExp(-z * z);
   return x >= 0 ? 0.5 * (1.0 + e) : 0.5 * (1.0 - e);
}
double NormInv(const double p)
{
   if(p <= 0) return -1e10;
   if(p >= 1) return 1e10;
   double a1 = -39.69683028665376, a2 = 220.9460984245205, a3 = -275.9285104469687, a4 = 138.3577518672690, a5 = -30.66479806614716, a6 = 2.506628277459239;
   double b1 = -54.47609879822406, b2 = 161.5858368580409, b3 = -155.6989798598866, b4 = 66.80131188771972, b5 = -13.28068155288572;
   double c1 = -0.007784894002430293, c2 = -0.3223964580411365, c3 = -2.400758277161838, c4 = -2.549732539343734, c5 = 4.374664141464968, c6 = 2.938163982698783;
   double d1 = 0.007784695709041462, d2 = 0.3224671290700398, d3 = 2.445134137142996, d4 = 3.754408661907416;
   double q, r;
   if(p < 0.02425) { q = MathSqrt(-2 * MathLog(p)); return (((((c1*q+c2)*q+c3)*q+c4)*q+c5)*q+c6) / ((((d1*q+d2)*q+d3)*q+d4)*q+1); }
   if(p > 1 - 0.02425) { q = MathSqrt(-2 * MathLog(1 - p)); return -(((((c1*q+c2)*q+c3)*q+c4)*q+c5)*q+c6) / ((((d1*q+d2)*q+d3)*q+d4)*q+1); }
   q = p - 0.5; r = q * q;
   return (((((a1*r+a2)*r+a3)*r+a4)*r+a5)*r+a6)*q / (((((b1*r+b2)*r+b3)*r+b4)*r+b5)*r+1);
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
   // 1% gia quy ra tien tai khoan qua tick value (dung ca khi ma dinh gia khac USD, vd USDJPY dinh gia bang JPY)
   double stTs = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE), stTv = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
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
         if(stTs > 0) posCost[k] += HistoryDealGetDouble(d, DEAL_VOLUME) * HistoryDealGetDouble(d, DEAL_PRICE) / 100.0 / stTs * stTv;  // = 1% gia
      }
   // Thoi gian giu lenh TB (gio) va tong swap. Ghi lai gio vao / ra / chieu tung vi the de gom dot nhoi lenh.
   double holdSum = 0, swapSum = 0, commSum = 0; int holdN = 0;
   int nPosAll = ArraySize(posIds);
   datetime posIn[], posOut[]; bool posBuy[];
   ArrayResize(posIn, nPosAll); ArrayResize(posOut, nPosAll); ArrayResize(posBuy, nPosAll);
   for(int j = 0; j < nPosAll; j++) { posIn[j] = 0; posOut[j] = 0; posBuy[j] = true; }
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
            if(en == DEAL_ENTRY_IN && tin == 0)
            { tin = tt; posBuy[j] = HistoryDealGetInteger(d, DEAL_TYPE) == DEAL_TYPE_BUY; }
            if(en == DEAL_ENTRY_OUT || en == DEAL_ENTRY_OUT_BY) tout = tt;
            swapSum += HistoryDealGetDouble(d, DEAL_SWAP);
            commSum += HistoryDealGetDouble(d, DEAL_COMMISSION) + HistoryDealGetDouble(d, DEAL_FEE);
         }
         posIn[j] = tin; posOut[j] = tout;
         if(tin > 0 && tout > tin) { holdSum += (double)(tout - tin) / 3600.0; holdN++; }
      }
   for(int s2 = 0; s2 < 2; s2++)
      for(int j = 0; j < ArraySize(posIds); j++)
      {
         double net = posNet[j] - posCost[j] * stressPct[s2];
         stressPL[s2] += net;
         if(net > 0) stressGP[s2] += net; else stressGL[s2] -= net;
      }

   // Gom thanh "dot": lop nhoi vao khi lop truoc cung chieu con mo thuoc cung dot (thang thua cung nhau, khong doc lap).
   // Moi thong ke ben duoi (E[R], t, ty le thang, bo top 5, Monte Carlo) tinh theo DOT. Khong nhoi lenh thi dot = lenh.
   // 1R cua dot = rui ro o SL ban dau cua lop dau tien.
   int nP = ArraySize(posIds);
   double campNet[], campRisk[];
   ArrayResize(campNet, nP); ArrayResize(campRisk, nP);
   int nC = 0; datetime campEnd = 0; bool campBuy = true;
   for(int j = 0; j < nP; j++)
   {
      bool join = nC > 0 && posIn[j] > 0 && posIn[j] < campEnd && posBuy[j] == campBuy;
      if(!join)
      {
         double sd = 0;
         campNet[nC] = 0; campRisk[nC] = PosRiskMoney(posIds[j], sd);
         campBuy = posBuy[j]; campEnd = 0; nC++;
      }
      campNet[nC - 1] += posNet[j];
      datetime e = posOut[j] > 0 ? posOut[j] : D'2999.12.31';   // chua dong (khong xay ra trong tester): coi nhu mo mai
      if(e > campEnd) campEnd = e;
   }
   ArrayResize(campNet, nC); ArrayResize(campRisk, nC);

   // Thong ke theo R (1R = tien rui ro o SL ban dau): E[R], t-stat, ty le thang kem can duoi Wilson 95%
   double sumR = 0, sumR2 = 0; int nR = 0, nWin = 0;
   double rs[]; ArrayResize(rs, nC);
   for(int j = 0; j < nC; j++)
   {
      if(campRisk[j] <= 0) continue;
      double r = campNet[j] / campRisk[j];
      rs[nR] = r;
      sumR += r; sumR2 += r * r; nR++;
      if(campNet[j] > 0) nWin++;
   }
   double meanR = nR > 0 ? sumR / nR : 0;
   double sdR   = nR > 1 ? MathSqrt(MathMax(0, (sumR2 - nR * meanR * meanR) / (nR - 1))) : 0;
   double tStat = sdR > 0 ? meanR / (sdR / MathSqrt(nR)) : 0;
   // Sharpe dieu chinh (Bailey & Lopez de Prado): skew / kurtosis cua R, so lenh toi thieu (MinTRL) va DSR.
   // SR = Sharpe moi dot. SR0 = Sharpe "tot nhat do may" khi da thu InpTrials cau hinh khong co loi the.
   // DSR% = xac suat Sharpe that > SR0. MinTRL = so dot can de SR > SR0 voi do tin cay 95% (1 phia); -1 = khong dat duoc.
   double skR = 0, kuR = 3, srR = sdR > 0 ? meanR / sdR : 0, sr0 = 0, dsr = 0, minTRL = -1;
   if(nR > 2 && sdR > 0)
   {
      double m2 = 0, m3 = 0, m4 = 0;
      for(int j = 0; j < nR; j++) { double dv = rs[j] - meanR; m2 += dv * dv; m3 += dv * dv * dv; m4 += dv * dv * dv * dv; }
      m2 /= nR; m3 /= nR; m4 /= nR;
      if(m2 > 0) { skR = m3 / MathPow(m2, 1.5); kuR = m4 / (m2 * m2); }
      double adj = 1.0 - skR * srR + (kuR - 1.0) / 4.0 * srR * srR;
      if(adj < 1e-6) adj = 1e-6;
      int trials = InpTrials > 1 ? InpTrials : 1;
      if(trials > 1)
      {
         double eg = 0.5772156649, vSR = adj / (nR - 1);
         sr0 = MathSqrt(vSR) * ((1 - eg) * NormInv(1.0 - 1.0 / trials) + eg * NormInv(1.0 - 1.0 / (trials * M_E)));
      }
      dsr = NormCdf((srR - sr0) * MathSqrt(nR - 1.0) / MathSqrt(adj)) * 100.0;
      if(srR > sr0) minTRL = 1.0 + adj * MathPow(1.6448536 / (srR - sr0), 2);
   }
   double wilson = 0;
   if(nR > 0)
   {
      double ph = (double)nWin / nR, z = 1.96, z2 = z * z;
      wilson = (ph + z2 / (2 * nR) - z * MathSqrt(ph * (1 - ph) / nR + z2 / (4.0 * nR * nR))) / (1 + z2 / nR) * 100.0;
   }

   // Monte Carlo (bootstrap): rut ngau nhien co hoan lai tu lai/lo cac vi the, 1000 lan, de xem
   // sut giam co the te toi dau neu thu tu lenh khac di. Mau duoi ~200 lenh thi chi nen xem la tham khao.
   double dep = TesterStatistics(STAT_INITIAL_DEPOSIT);
   int    nPos = nC, sims = 1000, ruin = 0, blk = 5;   // rut theo dot, khong theo tung lop
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
            eq += campNet[(st + q) % nPos];
            if(campNet[(st + q) % nPos] < 0) { run++; if(run > maxRun) maxRun = run; } else run = 0;
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

   // Phu thuoc vao vai dot thang lon: bo 5 dot lai nhieu nhat roi tinh lai loi nhuan va PF
   double srt[]; ArrayCopy(srt, campNet); ArraySort(srt);
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
                   "E_R", "tStat", "TyLeThang_CanDuoi95%", "MC_ChuoiThua95", "GiamCoDD", "NhoiLenh",
                   "SoDot", "ChoHoi_ChamGia", "ChoHoi_HetNen", "ChoHoi_BiHuy", "ChoHoi_Khop", "RuiRoMoMax%", "NhoiBiBoVoiRuiRo", "VaoLai",
                   "SkewR", "KurtR", "SoLanThu", "SR0", "DSR%", "MinTRL_dot");
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
                DoubleToString(mcStreak95, 0), g_ddScaled, g_pyrAdds,
                nC, g_pendHit, g_pendMissed, g_pendBlocked, g_pendFilled,
                DoubleToString(g_maxOpenRiskPct, 2), g_chainSkips, g_reEntries,
                DoubleToString(skR, 2), DoubleToString(kuR, 2), InpTrials > 1 ? InpTrials : 1, DoubleToString(sr0, 3),
                DoubleToString(dsr, 1), minTRL > 0 ? IntegerToString((int)MathCeil(minTRL)) : "-1");
      FileClose(h);
   }
   else
      PrintFormat("Khong ghi duoc file ket qua: %d", GetLastError());
   WriteTradeFeatures(posIds, posNet);
   return pf;
}
//+------------------------------------------------------------------+
