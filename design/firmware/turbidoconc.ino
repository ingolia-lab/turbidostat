#include "turbidoconc.h"

TurbidoConcBase::TurbidoConcBase(Supervisor &s) :
  TurbidoMixBase(s),
  _currentPpm1(1000000),
  _fillSeconds(1000)
{
      
}

int TurbidoConcBase::begin(void)
{
  int err = TurbidoMixBase::begin();
  if (!err) {
    _lastTotalMsec1 = pump1().totalOnMsec();
    _lastTotalMsec2 = pump2().totalOnMsec();
  }
  return err;
}

#define DEBUG_PPM 0

int TurbidoConcBase::loop(void)
{
  long currMsec1 = pump1().totalOnMsec();
  long currMsec2 = pump2().totalOnMsec();

#if DEBUG_PPM
  long oldPpm = _currentPpm1;
#endif

  long newPpm = updatePpm1(currMsec1 - _lastTotalMsec1, currMsec2 - _lastTotalMsec2);

  if (newPpm < 0) {
    Serial.println("# ERROR updating ppm estimate!");
  }

#if DEBUG_PPM
  snprintf(Supervisor::outbuf, Supervisor::outbufLen,
           "# _lastTotalMsec1 = %ld currMsec1 = %ld Diff = %ld\r\n",
           _lastTotalMsec1, currMsec1, currMsec1 - _lastTotalMsec1);
  snprintf(Supervisor::outbuf + strlen(Supervisor::outbuf), 
           Supervisor::outbufLen - strlen(Supervisor::outbuf),
           "# _lastTotalMsec2 = %ld currMsec2 = %ld Diff = %ld\r\n",
           _lastTotalMsec2, currMsec2, currMsec2 - _lastTotalMsec2);
  snprintf(Supervisor::outbuf + strlen(Supervisor::outbuf), 
           Supervisor::outbufLen - strlen(Supervisor::outbuf),
           "# oldPpm = %ld newPpm = %ld", oldPpm, newPpm);
  Serial.println(Supervisor::outbuf);
#endif

  _lastTotalMsec1 = currMsec1;
  _lastTotalMsec2 = currMsec2;

  return TurbidoMixBase::loop();
}

void TurbidoConcBase::setPumpOn(void)
{
  if ( (currentPpm1() > targetPpm1()) || (targetPpm1() == 0) ) {
    setPump2On();
  } else {
    setPump1On();
  }
}


void TurbidoConcBase::formatHeader(char *buf, unsigned int buflen)
{
  TurbidoMixBase::formatHeader(buf, buflen);
  strncpy(buf + strlen(buf), "\tcurrPpm\ttargPpm", buflen - strlen(buf));  
}

void TurbidoConcBase::formatLine(char *buf, unsigned int buflen, long currMeasure)
{
  TurbidoMixBase::formatLine(buf, buflen, currMeasure);
  
  snprintf(buf + strlen(buf), buflen - strlen(buf), 
           "\t%07lu\t%07lu", 
           currentPpm1(), targetPpm1());
}

void TurbidoConcBase::formatParams(char *buf, unsigned int buflen)
{
  TurbidoMixBase::formatParams(buf, buflen);
  snprintf(buf + strlen(buf), buflen - strlen(buf), 
           "# Fill time: %lu seconds (%07lu ppm per second)\r\n# Current fraction of media #1: %07lu ppm\r\n",
           _fillSeconds, ppmPerSecond(), _currentPpm1);
}
  
void TurbidoConcBase::manualReadParams(void)
{
  TurbidoMixBase::manualReadParams();
  manualReadULong("fill time [seconds] ", _fillSeconds);

  manualReadULong("current fraction media #1 (parts per million) ", _currentPpm1);
  if (_currentPpm1 > 1000000) {
    _currentPpm1 = 1000000;
  }
}

// f = fraction per second [ in ppm / second ]
// f * t = fraction exchanged in t seconds [ in ppm; must be >2000 = 0.2%]
// cnew = cold * (1 - (f * (t1 + t2))) + 1 * f * t1 + 0 * f * t2
//      = cold * (1 - (f * t1) - (f * t2)) + f * t1
//      = cold - cold * f * t1 - cold * f * t2 + f * t1
//      = cold + (1 - cold) * f * t1 - cold * f * t2
// e.g. ((conc * 1e6) / 20) * ((fract * 1e6) / 25) = (conc * 5e4) * (fract * 4e4) = conc * 2e9
long TurbidoConcBase::updatePpm1(unsigned int msec1, unsigned int msec2)
{
  unsigned long ppmPerSec = ppmPerSecond();
  if ((msec1 + msec2 > 2000) || (ppmPerSec > 1000000) || (_currentPpm1 > 1000000)) {    
    // ERROR -- MAY OVERFLOW
    return -1;
  }

  // (f * 1e6) * (t * 1e3) / 1e3 = (f * t) * 1e6
  unsigned long newPpmAdded = (msec1 * ppmPerSec) / 1000;
  // (f * 1e6) * (t * 1e3) / 1e3 = (f * t) * 1e6
  unsigned long oldFractRemovedPpm = ( (msec1 + msec2) * ppmPerSec ) / 1000;

  // ( ( ( conc * 1e6) / 20 ) * ( ( fract * 1e6) / 25 ) ) ) = conc * 2e9 = ( conc  * 1e6 ) * 2000
  unsigned long oldPpmRemoved = ( (_currentPpm1 / 20) * (oldFractRemovedPpm / 25) ) / 2000;
  
  if (_currentPpm1 + newPpmAdded < oldPpmRemoved) {
    _currentPpm1 = 0;
  } else {
    _currentPpm1 = (_currentPpm1 + newPpmAdded) - oldPpmRemoved;
    if (_currentPpm1 > 1000000) {
      _currentPpm1 = 1000000;
    }
  }
  return (long) _currentPpm1;  
}


TurbidoConcFixed::TurbidoConcFixed(Supervisor &s):
  TurbidoConcBase(s),
  _targetPpm1(500000)
{

}

void TurbidoConcFixed::formatHeader(char *buf, unsigned int buflen)
{
  buf[0] = 'C';
  TurbidoConcBase::formatHeader(buf + 1, buflen - 1);
}

void TurbidoConcFixed::formatLine(char *buf, unsigned int buflen, long m)
{
  buf[0] = 'C';
  TurbidoConcBase::formatLine(buf + 1, buflen - 1, m);
}

void TurbidoConcFixed::formatParams(char *buf, unsigned int buflen)
{
  TurbidoConcBase::formatParams(buf, buflen);
  snprintf(buf + strlen(buf), buflen - strlen(buf),
           "# Target fraction media #1 %07lu ppm\r\n", 
           _targetPpm1);
}

void TurbidoConcFixed::manualReadParams(void)
{
  TurbidoConcBase::manualReadParams();
  manualReadULong("Target fraction media #1 (parts per million) ", _targetPpm1);
  if (_targetPpm1 > 1000000) {
    _targetPpm1 = 1000000;
  }
}

