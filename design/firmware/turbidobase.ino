#include "controller.h"
#include "pump.h"
#include "supervisor.h"
#include "turbidobase.h"

#define LINEBUF_LEN 256
const unsigned int TurbidoBase::linebufLen = LINEBUF_LEN;
char TurbidoBase::linebuf[LINEBUF_LEN];

TurbidoBase::TurbidoBase(Supervisor &s):
  _s(s),
  _mTarget(Nephel::maxMeasure + 1),
  _startSec(0)
{

}

int TurbidoBase::begin(void)
{
  _startSec = rtcSeconds();

  setPumpOff();

  formatHeader(linebuf, linebufLen);
  Serial.println(linebuf);

  for (int i = 0; i < _nMeasure; i++) {
    _measures[i] = 0;
  }
  _currMeasure = 0;

  return 0;
}

int TurbidoBase::loop(void)
{
  long m = measure();

  _currMeasure++;
  if (_currMeasure > _nMeasure) {
    _currMeasure = 0;
  }
  _measures[_currMeasure] = m;

  if (pumpMeasureOverride()) {
    // Density-dependent pumping overridden
  } else if (isHigh()) {
    setPumpOn();
  } else {
    setPumpOff();
  }

  formatLine(linebuf, linebufLen, m);
  Serial.println(linebuf);

  delayOneSecond();

  int ch;
  while ((ch = Serial.read()) >= 0) {
    if (ch == 'q') {
      setPumpOff();
      return 1;
      while (Serial.read() >= 0) {
        /* DISCARD */ 
      }
    } 
  }

  return 0;
}

int TurbidoBase::isHigh(void)
{
  int nHigh = 0;
  for (int i = 0; i < _nMeasure; i++) {
    if (_measures[i] > mTarget()) {
      nHigh++;      
    }
  }
  return (nHigh * 2) > _nMeasure;
}

void TurbidoBase::formatHeader(char *buf, unsigned int buflen)
{
  strncpy(buf, "\ttime.s\tneph\tgain\ttarget", buflen);    
}

void TurbidoBase::formatLine(char *buf, unsigned int buflen, long m)
{
  long sec = rtcSeconds();

  // Handle fixed-point display of negative measurements
  const long mmodulo = m % ((long) 1000);
  const long mint = (mmodulo < 0) ? (-(m / ((long) 1000))) : (m / ((long) 1000));
  const unsigned long mdec = abs(mmodulo);

  snprintf(buf, buflen, 
           "\t%lu\t%ld.%03lu\t%ld\t%ld.%03ld", 
           sec - startSec(), mint, mdec, s().nephelometer().pgaScale(), _mTarget/1000, _mTarget%1000);
}

long TurbidoBase::measure(void) { return _s.nephelometer().measure(); }

void TurbidoBase::formatParams(char *buf, unsigned int buflen)
{
  snprintf(buf, buflen, "# Target neph %ld.%03ld\r\n", 
           _mTarget/1000, _mTarget%1000);
}

void TurbidoBase::manualReadParams(void)
{
  do {
    manualReadMeasure("target neph measurement", _mTarget);
  } while (_mTarget < 0);
}

