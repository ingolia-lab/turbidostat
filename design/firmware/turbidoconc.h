#ifndef _turbidoconc_h
#define _turbidoconc_h 1

#include "controller.h"
#include "pump.h"
#include "turbidobase.h"
#include "turbidomix.h"

class TurbidoConcBase : public TurbidoMixBase
{
  public:
    TurbidoConcBase(Supervisor &s);

    int begin(void);
    int loop(void);

    void formatHeader(char *buf, unsigned int buflen);
    void formatLine(char *buf, unsigned int buflen, long currMeasure);

    void formatParams(char *buf, unsigned int buflen);
    void manualReadParams(void);

  protected:
    void setPumpOn(void);

    virtual unsigned long targetPpm1() = 0;

    unsigned long currentPpm1(void) { return _currentPpm1; }
    unsigned long fillSeconds(void) { return _fillSeconds; }
    unsigned long ppmPerSecond(void) { return ((unsigned long) 1000000) / _fillSeconds; }

    long updatePpm1(unsigned int msec1, unsigned int msec2);
  private:
    unsigned long _currentPpm1;
    unsigned long _fillSeconds;

    long _lastTotalMsec1;
    long _lastTotalMsec2;
};

class TurbidoConcFixed : public TurbidoConcBase
{
  public:
    TurbidoConcFixed(Supervisor &s);

    void formatHeader(char *buf, unsigned int buflen);
    void formatLine(char *buf, unsigned int buflen, long currMeasure);

    void formatParams(char *buf, unsigned int buflen);
    void manualReadParams(void);

    const char *name(void) { return "Tstat Fixed Conc"; }
    char letter(void) { return 'c'; }
  protected:
    unsigned long targetPpm1() { return _targetPpm1; }

  private:
    unsigned long _targetPpm1;
};

#endif /* !defined(_turbidoconc_h) */
