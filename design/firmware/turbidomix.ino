#include "controller.h"
#include "pump.h"
#include "supervisor.h"
#include "turbidomix.h"

TurbidoMixBase::TurbidoMixBase(Supervisor &s):
  TurbidoBase(s),
  _pump1(0),
  _pump2(0)
{

}

void TurbidoMixBase::formatHeader(char *buf, unsigned int buflen)
{
  TurbidoBase::formatHeader(buf, buflen);
  strncpy(buf + strlen(buf), "\tpumpon\tpumptime.s\tpump1time.s\tpump2time.s", buflen);
}

void TurbidoMixBase::formatLine(char *buf, unsigned int buflen, long m)
{
  long time1 = pump1().totalOnMsec(), time2 = pump2().totalOnMsec();
  long timettl = time1 + time2;

  TurbidoBase::formatLine(buf, buflen, m);
  
  snprintf(buf + strlen(buf), buflen - strlen(buf), 
           "\t%d\t%ld.%03ld\t%ld.%03ld\t%ld.%03ld", 
           whichPumpOn(),
           timettl / ((long) 1000), timettl % ((long) 1000),
           time1 / ((long) 1000), time1 % ((long) 1000),
           time2 / ((long) 1000), time2 % ((long) 1000));
}

void TurbidoMixBase::formatParams(char *buf, unsigned int buflen)
{
  TurbidoBase::formatParams(buf, buflen);
  snprintf(buf + strlen(buf), buflen - strlen(buf),
           "# Pump #1 %c\r\n# Pump #2 %c\r\n", 
           Supervisor::pumpnoToChar(_pump1), Supervisor::pumpnoToChar(_pump2));
}

void TurbidoMixBase::manualReadParams(void)
{
  TurbidoBase::manualReadParams();
  manualReadPump("pump #1", _pump1);
  do {
    manualReadPump("pump #2", _pump2);
  } while (_pump2 == _pump1);
}

TurbidoRatioBase::TurbidoRatioBase(Supervisor &s):
  TurbidoMixBase(s),
  _cycleCount(0)
{
    
}

int TurbidoRatioBase::begin(void)
{
  _cycleCount = 0;
  return TurbidoBase::begin();
}

void TurbidoRatioBase::setPumpOn(void)
{
  uint8_t count = pumpCountIncr();

  if (schedulePercent(pump1Percent(), count)) {  
    setPump1On();
  } else {
    setPump2On();
  }
}

TurbidoRatioFixed::TurbidoRatioFixed(Supervisor &s):
  TurbidoRatioBase(s),
  _pump1Pct(50)
{

}

void TurbidoRatioFixed::formatHeader(char *buf, unsigned int buflen)
{
  buf[0] = 'R';
  TurbidoRatioBase::formatHeader(buf + 1, buflen - 1);
}

void TurbidoRatioFixed::formatLine(char *buf, unsigned int buflen, long m)
{
  buf[0] = 'R';
  TurbidoRatioBase::formatLine(buf + 1, buflen - 1, m);
}

void TurbidoRatioFixed::formatParams(char *buf, unsigned int buflen)
{
  TurbidoRatioBase::formatParams(buf, buflen);
  snprintf(buf + strlen(buf), buflen - strlen(buf),
           "# Pump #1 percentage %d%%\r\n", 
           _pump1Pct);
}

void TurbidoRatioFixed::manualReadParams(void)
{
  TurbidoRatioBase::manualReadParams();
  manualReadPercent("pump #1 percentage", _pump1Pct);
}

