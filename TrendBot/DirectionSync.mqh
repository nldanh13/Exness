//+------------------------------------------------------------------+
//| TrendBot/DirectionSync.mqh - ONE fail-closed direction decision   |
//| Raw 9TF / 4 source signals remain independent & auditable.       |
//| Only NEW automated entries of STRAT_SMART use this final gate.   |
//+------------------------------------------------------------------+
int      g_syncDir = 0, g_syncNineDir = 0;
int      g_syncNineUp = 0, g_syncNineDn = 0;
datetime g_syncBar = 0;
bool     g_syncReady = false;
string   g_syncText = "CHUA CO DU LIEU M15";

// Strict intersection: no source may veto the final side.
// Dow is required because SmartSignals uses Dow as its directional tide.
int SyncCombine(const int nine, const int four, const int dow)
{
   if(nine == 0 || four == 0 || dow == 0) return 0;
   return (nine == four && four == dow) ? nine : 0;
}
string SyncSide(const int dir)
{
   return dir > 0 ? "TANG" : dir < 0 ? "GIAM" : "CHUA RO";
}
void SyncDirectionStep()
{
   if(P_Strategy != STRAT_SMART) return;
   datetime lastClosed = iTime(_Symbol, PERIOD_M15, 1);
   // A missing/stale shadow forecast is NEVER interpreted as approval.
   if(lastClosed <= 0 || g_dirLastBar != lastClosed)
   {
      g_tbSnapshotReady = false; g_tbSnapshotBar = 0;
      g_tbSnapshotLabel = "CHO DU DOAN M15";
      g_syncReady = false; g_syncDir = 0; g_syncBar = 0;
      g_syncText = "CHO DU DOAN 4 NGUON TREN NEN M15 DA DONG";
      return;
   }
   if(g_syncReady && g_syncBar == lastClosed) return;
   if(!g_tbReady && !TrendBoardInit())
   {
      g_tbSnapshotReady = false; g_tbSnapshotBar = 0;
      g_tbSnapshotLabel = "THIEU EMA 9 KHUNG";
      g_syncReady = false; g_syncDir = 0; g_syncBar = 0;
      g_syncText = "THIEU DU LIEU EMA 9 KHUNG: DUNG NGOAI";
      return;
   }
   // All 9 displayed votes refer to the SAME M15 close, not 9 unrelated
   // "latest bars" at arbitrary later moments. Only completed TF bars.
   datetime at = lastClosed + PeriodSeconds(PERIOD_M15);
   int votes[9], up = 0, dn = 0;
   g_tbMissing = 0;
   for(int i = 0; i < 9; i++)
   {
      votes[i] = TrendAtM15Close(i, at);
      g_tbSnapshotVotes[i] = votes[i];
      if(votes[i] > 0) up++;
      else if(votes[i] < 0) dn++;
   }
   // v5.47: khung nao chua du du lieu (vua khoi dong, H4/D1/W1 chua tai xong) thi chua ket luan; thu lai o tick sau.
   // Van la DUNG NGOAI (fail-closed) trong luc cho.
   if(g_tbMissing > 0)
   {
      g_tbSnapshotReady = false; g_tbSnapshotBar = 0;
      g_tbSnapshotLabel = "CHO DU LIEU 9 KHUNG";
      g_syncReady = false; g_syncDir = 0; g_syncBar = 0;
      g_syncText = StringFormat("CHO DU LIEU 9 KHUNG (thieu %d khung): DUNG NGOAI", g_tbMissing);
      return;
   }
   int nine = 0;
   // 6+ of 9 AND all three higher frames H1/H4/D1 must agree.
   // Minor M1-M5 pullbacks are shown but cannot reverse the final vote.
   if(up >= 6 && votes[6] == 1 && votes[7] == 1 && votes[8] == 1) nine = 1;
   if(dn >= 6 && votes[6] == -1 && votes[7] == -1 && votes[8] == -1) nine = -1;
   g_syncNineUp = up; g_syncNineDn = dn; g_syncNineDir = nine;
   g_syncDir = SyncCombine(nine, g_dirLastVote, g_dirLastDow);
   g_syncBar = lastClosed; g_syncReady = true;
   g_tbSnapshotBar = lastClosed; g_tbSnapshotReady = true;
   g_tbSnapshotLabel = g_syncDir > 0 ? "KET LUAN: CHI XET MUA" :
                       g_syncDir < 0 ? "KET LUAN: CHI XET BAN" :
                       "KET LUAN: CHO DONG THUAN";
   string reason = g_syncDir != 0 ? "DONG THUAN - MOI XET SETUP" :
                   nine == 0 ? "9 KHUNG CHUA DU 6/9 + H1/H4/D1" :
                   g_dirLastVote == 0 ? "4 NGUON CHUA DU 3/4 HOAC CO PHIEU NGUOC" :
                   g_dirLastDow == 0 ? "DOW D1 CHUA XAC NHAN" : "XUNG DOT HUONG";
   g_syncText = StringFormat("HUONG CHUNG %s | 9KHUNG %s (%d tang/%d giam) | 4NGUON %s (%d/4, nguoc %d) | DOW %s | %s",
                             g_syncDir == 0 ? "DUNG NGOAI" : SyncSide(g_syncDir),
                             SyncSide(nine), up, dn, SyncSide(g_dirLastVote),
                             g_dirLastAgree, g_dirLastDisagree, SyncSide(g_dirLastDow), reason);
}

// Re-evaluated at order time; never use a stale consensus from another M15.
// This is the ONLY authority for new automated SMART orders, including
// delayed entries, re-entries and pyramids. No new signals are created.
bool SyncEntryAllowed(const bool buy)
{
   if(P_Strategy != STRAT_SMART) return true;
   datetime currentClosed = iTime(_Symbol, PERIOD_M15, 1);
   return g_syncReady && currentClosed > 0 && currentClosed == g_syncBar &&
          currentClosed == g_dirLastBar && g_syncDir == (buy ? 1 : -1);
}
