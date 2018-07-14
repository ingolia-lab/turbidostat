#ifndef _turbidomix_h
#define _turbidomix_h 1

#include "controller.h"
#include "pump.h"
#include "turbidobase.h"

class TurbidoMixBase : public TurbidoBase
{
  public:
    TurbidoMixBase(Supervisor &s);

    void formatHeader(char *buf, unsigned int buflen);
    void formatLine(char *buf, unsigned int buflen, long currMeasure);

    void formatParams(char *buf, unsigned int buflen);
    void manualReadParams(void);

  protected:
    Pump &pump1(void) { return s().pump(_pump1); }
    Pump &pump2(void) { return s().pump(_pump2); }

    void setPump1On(void) { pump1().setPumping(1); pump2().setPumping(0); }
    void setPump2On(void) { pump1().setPumping(0); pump2().setPumping(1); }
    void setPumpOff(void) { pump1().setPumping(0); pump2().setPumping(0); }

    int whichPumpOn(void) { return pump1().isPumping() ? 1 : (pump2().isPumping() ? 2 : 0); }
  private:
    uint8_t _pump1;
    uint8_t _pump2;
};

class TurbidoRatioBase : public TurbidoMixBase
{
  public:
    TurbidoRatioBase(Supervisor &s);

    int begin(void);
  protected:
    uint8_t pumpCountIncr(void) { unsigned long cycle = _cycleCount++; return (uint8_t) (cycle % 100); }

    virtual void setPumpOn(void);

    virtual uint8_t pump1Percent() = 0;
  private:
    unsigned long _cycleCount;
};

class TurbidoRatioFixed : public TurbidoRatioBase
{
  public:
    TurbidoRatioFixed(Supervisor &s);

    void formatHeader(char *buf, unsigned int buflen);
    void formatLine(char *buf, unsigned int buflen, long currMeasure);

    void formatParams(char *buf, unsigned int buflen);
    void manualReadParams(void);

    const char *name(void) { return "Turbidostat Ratio"; }
    char letter(void) { return 'r'; }
  protected:
    uint8_t pump1Percent() { return _pump1Pct; }

  private:
    uint8_t _pump1Pct;
};

#endif /* !defined(_turbidomix_h) */
