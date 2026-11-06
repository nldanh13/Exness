//+------------------------------------------------------------------+
//| TrendBot/Notify.mqh: Thong bao push MT5 / Telegram
//+------------------------------------------------------------------+
//--- Thong bao -----------------------------------------------------
string UrlEncode(const string s)
{
   uchar b[];
   int n = StringToCharArray(s, b, 0, WHOLE_ARRAY, CP_UTF8);
   string out = "";
   for(int i = 0; i < n - 1; i++)
   {
      uchar c = b[i];
      if((c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z') || (c >= '0' && c <= '9') ||
         c == '-' || c == '_' || c == '.' || c == '~')
         out += CharToString(c);
      else
         out += StringFormat("%%%02X", c);
   }
   return out;
}

void SendTelegram(const string msg)
{
   if(InpTgToken == "" || InpTgChatId == "") return;
   string url  = "https://api.telegram.org/bot" + InpTgToken + "/sendMessage";
   string body = "chat_id=" + UrlEncode(InpTgChatId) + "&text=" + UrlEncode(msg);
   char data[];
   int n = StringToCharArray(body, data, 0, WHOLE_ARRAY, CP_UTF8);
   if(n > 0) ArrayResize(data, n - 1);           // bo ky tu ket thuc chuoi
   char   result[];
   string resultHeaders;
   ResetLastError();
   int code = WebRequest("POST", url, "Content-Type: application/x-www-form-urlencoded\r\n",
                         5000, data, result, resultHeaders);
   if(code == -1)
      PrintFormat("Telegram loi %d. Them https://api.telegram.org vao Tools > Options > Expert Advisors > Allow WebRequest",
                  GetLastError());
   else if(code != 200)
      PrintFormat("Telegram tra ve HTTP %d: %s", code, CharArrayToString(result));
}

void Notify(const string msg)
{
   Print(msg);
   if(MQLInfoInteger(MQL_TESTER)) return;          // khong gui khi backtest
   if(InpPushNotify) SendNotification(msg);
   if(InpTelegram)   SendTelegram(msg);
}
