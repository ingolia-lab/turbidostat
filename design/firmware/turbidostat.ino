#include "controller.h"
#include "pump.h"
#include "supervisor.h"
#include "turbidobase.h"
#include "turbidostat.h"

Turbidostat::Turbidostat(Supervisor &s):
  TurbidoBase(s),
  _pumpno(0)
{

}

void Turbidostat::formatHeader(char *buf, unsigned int buflen)
{
  strncpy(buf, "T", buflen);
  TurbidoBase::formatHeader(buf + strlen(buf), buflen - strlen(buf));
  strncpy(buf + strlen(buf), "\tpumpon\tpumptime.s", buflen - strlen(buf));
}

void Turbidostat::formatLine(char *buf, unsigned int buflen, long m)
{
  long ptime = pump().totalOnMsec();

  strncpy(buf, "T", buflen);
  TurbidoBase::formatLine(buf + strlen(buf), buflen - strlen(buf), m);
  snprintf(buf + strlen(buf), buflen - strlen(buf), "\t%d\t%ld.%03ld", 
           pump().isPumping(),
           ptime / ((long) 1000), ptime % ((long) 1000));
}

Pump &Turbidostat::pump(void) { return s().pump(_pumpno); }

void Turbidostat::setPumpOn(void)  { pump().setPumping(1); }

void Turbidostat::setPumpOff(void) { pump().setPumping(0); }

void Turbidostat::formatParams(char *buf, unsigned int buflen)
{
  TurbidoBase::formatParams(buf, buflen);
  snprintf(buf + strlen(buf), buflen - strlen(buf),
           "# Pump %c\r\n", 
           Supervisor::pumpnoToChar(_pumpno));
}

void Turbidostat::manualReadParams(void)
{
  TurbidoBase::manualReadParams();
  manualReadPump("media pump", _pumpno);
}

