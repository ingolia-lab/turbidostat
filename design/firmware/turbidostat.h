#ifndef _turbidostat_h
#define _turbidostat_h 1

#include "controller.h"
#include "turbidobase.h"

class Turbidostat : public TurbidoBase
{
  public:
    Turbidostat(Supervisor &s);

    void formatHeader(char *buf, unsigned int buflen);
    void formatLine(char *buf, unsigned int buflen, long currMeasure);

    void formatParams(char *buf, unsigned int buflen);
    void manualReadParams(void);

    const char *name(void) { return "Turbidostat"; }
    char letter(void) { return 't'; }
  protected:
    Pump &pump(void);
    void setPumpOn(void);
    void setPumpOff(void);
  private:
    uint8_t _pumpno;
};

#endif /* !defined(_turbidostat_h) */
