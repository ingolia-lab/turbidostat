#ifndef _turbidobase_h
#define _turbidobase_h 1

#include "controller.h"

class TurbidoBase : public Controller
{
  public:
    TurbidoBase(Supervisor &s);

    int begin(void);
    int loop(void);
    void end(void) { }

    virtual void formatHeader(char *buf, unsigned int buflen);
    virtual void formatLine(char *buf, unsigned int buflen, long currMeasure);

    void formatParams(char *buf, unsigned int buflen);
    void manualReadParams(void);
  protected:
    virtual long mTarget(void) { return _mTarget; }
    
    long startSec(void) { return _startSec; }
    
    long measure(void);

    // Returns `true` when measurement-dependent pump control is overridden.
    virtual int pumpMeasureOverride(void) { return false; }

    virtual void setPumpOn(void) = 0;
    virtual void setPumpOff(void) = 0;

    Supervisor &s(void) { return _s; }
  private:
    Supervisor &_s;
  
    long _mTarget; 

    long _startSec;

    static const unsigned int linebufLen;
    static char linebuf[];

    // 11-entry ring buffer for measurements
    static const int _nMeasure = 11;
    long _measures[_nMeasure];
    int _currMeasure;

    int isHigh(void); 
};

#endif /* !defined(_turbidobase_h) */
