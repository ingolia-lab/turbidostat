#include "settings.h"
#include "supervisor.h"

void ParamSettings::manualSetParams(void)
{
  serialWriteParams();
  Serial.print(F("# Hit return to leave a parameter unchanged\r\n"));

  manualReadParams();

  serialWriteParams();
}

void ParamSettings::serialWriteParams(void)
{ 
  Serial.print(F("# Current settings:\r\n"));
  formatParams(Supervisor::outbuf, Supervisor::outbufLen);
  Serial.write(Supervisor::outbuf);
}

void ParamSettings::manualReadLong(const char *desc, long &pval)
{
  long vnew;
  Serial.print("# Enter ");
  Serial.print(desc);
  Serial.print("(");
  Serial.print(pval);
  Serial.print("): ");
  if (Supervisor::blockingReadLong(&vnew) > 0) {
    pval = vnew;
  } else {
    Serial.print(F("# (not updated)\r\n"));
  }
}

void ParamSettings::manualReadULong(const char *desc, unsigned long &pval)
{
  long vnew;
  Serial.print("# Enter ");
  Serial.print(desc);
  Serial.print("(");
  Serial.print(pval);
  Serial.print("): ");
  if ((Supervisor::blockingReadLong(&vnew) > 0) && (vnew >= 0)) {
    pval = vnew;
  } else {
    Serial.print(F("# (not updated)\r\n"));
  }
}

void ParamSettings::manualReadPercent(const char *desc, uint8_t &pval)
{
  long pnew;
  Serial.print("# Enter ");
  Serial.print(desc);
  Serial.print("(");
  Serial.print(pval);
  Serial.print("%): ");
  if ((Supervisor::blockingReadLong(&pnew) > 0) && (pnew >= 0) && (pnew <= 100)) {
    pval = pnew;
  } else {
    Serial.print(F("# (not updated)\r\n"));
  }
}

void ParamSettings::manualReadMeasure(const char *desc, long &mval)
{
  const int buflen = 16;
  char buf[buflen];

  long mnew;
  Serial.print("# Enter ");
  Serial.print(desc);
  Serial.print("(");
  snprintf(buf, buflen, "%ld.%03ld", mval / 1000, mval % 1000);
  Serial.print(buf);
  Serial.print("): ");
  
  if (Supervisor::blockingReadFixed(&mnew, 3) > 0) {
    mval = mnew;
  } else {
    Serial.print(F("# (not updated)\r\n"));
  }
}

void ParamSettings::manualReadPump(const char *desc, uint8_t &pval)
{
  uint8_t pnew;
  Serial.print("# Enter ");
  Serial.print(desc);
  Serial.print(" (");
  Serial.print((char) ('A' + pval));
  Serial.print("): ");

  if (Supervisor::blockingReadPump(&pnew) > 0) {
    pval = pnew;
    Serial.println();
  } else {
    Serial.print(F("\r\n# (not updated)\r\n"));
  }
}



