#ifndef _turbidoschedule_h
#define _turbidoschedule_h 1

#include "controller.h"
#include "pump.h"
#include "turbidobase.h"
#include "turbidoconc.h"
#include "turbidomix.h"

/* IT
 *  Induce, at a specified Time
 */
class TurbidoInduce : public TurbidoRatioBase
{
  public:
    TurbidoInduce(Supervisor &s);

    void formatHeader(char *buf, unsigned int buflen);
    void formatLine(char *buf, unsigned int buflen, long currMeasure);

    void formatParams(char *buf, unsigned int buflen);
    void manualReadParams(void);

    const char *name(void) { return "Turbidostat Induce"; }
    char letter(void) { return 'i'; }
    
  protected:
    uint8_t pump1Percent();
    
  private:
    long _induceTime;
};

/* GTR
 * Gradient, steps by Time, for media Ratio
 */
class TurbidoGradient : public TurbidoRatioBase
{
  public:
    TurbidoGradient(Supervisor &s);

    void formatHeader(char *buf, unsigned int buflen);
    void formatLine(char *buf, unsigned int buflen, long currMeasure);

    void formatParams(char *buf, unsigned int buflen);
    void manualReadParams(void);

    const char *name(void) { return "Turbidostat Mix Gradient"; }
    char letter(void) { return 'h'; }
    
  protected:
    uint8_t pump1Percent();
    
  private:
    uint8_t _pump1StartPct;
    uint8_t _pump1StepPct;
    long _nSteps;
    long _stepTime;
};

/* GTD
 * Gradient, steps by Time, for cell Density
 */
class TurbidoDensityGradient: public TurbidoRatioBase
{
  public:
    TurbidoDensityGradient(Supervisor &s);

    void formatHeader(char *buf, unsigned int buflen);
    void formatLine(char *buf, unsigned int buflen, long currMeasure);

    void formatParams(char *buf, unsigned int buflen);
    void manualReadParams(void);

    const char *name(void) { return "Turbidostat Density Gradient"; }
    char letter(void) { return 'd'; }
    
  protected:
    uint8_t pump1Percent() { return _pump1Pct; }
    
    long mLower(void) { return mTarget(); }
    long mUpper(void) { return mTarget(); }

    long mTarget(void);
  private:
    long _mTargetStart;
    long _mTargetStep;
    long _nSteps;
    long _stepTime;

    uint8_t _pump1Pct;
};

/* CTR
 * Cycle, steps by Time, for media Ratio
 */

class TurbidoCycle : public TurbidoRatioBase
{
  public:
    TurbidoCycle(Supervisor &s);
    
    void formatHeader(char *buf, unsigned int buflen);
    void formatLine(char *buf, unsigned int buflen, long currMeasure);

    void formatParams(char *buf, unsigned int buflen);
    void manualReadParams(void);

    const char *name(void) { return "Turbidostat Ratio Cycle"; }
    char letter(void) { return 'b'; }
    
  protected:
    uint8_t pump1Percent();
    
  private:
    uint8_t _pump1FirstPct;
    uint8_t _pump1SecondPct;
    long _firstTime;
    long _secondTime;
};

/* GTC = Gradient, steps by Time, for media Concentration */
class TurbidoConcGradient : public TurbidoConcBase
{
  public:
    TurbidoConcGradient(Supervisor &s);

    void formatHeader(char *buf, unsigned int buflen);
    void formatLine(char *buf, unsigned int buflen, long currMeasure);

    void formatParams(char *buf, unsigned int buflen);
    void manualReadParams(void);

    const char *name(void) { return "Turbidostat Conc Gradient"; }
    char letter(void) { return 'g'; }
    
  protected:
    unsigned long targetPpm1();
    
  private:
    unsigned long _startTargetPpm1;
    long _stepTargetPpm1;
    long _nSteps;
    long _stepTime;
};

class TurbidoConcLogGradient : public TurbidoConcBase
{
    public:
    TurbidoConcLogGradient(Supervisor &s);

    void formatHeader(char *buf, unsigned int buflen);
    void formatLine(char *buf, unsigned int buflen, long currMeasure);

    void formatParams(char *buf, unsigned int buflen);
    void manualReadParams(void);

    const char *name(void) { return "Turbidostat Conc Gradient, Logarithmic"; }
    char letter(void) { return 'l'; }
    
  protected:
    unsigned long targetPpm1(void);
    
  private:
    unsigned long _startTargetPpm1;
    unsigned long _stepPct;
    long _nSteps;
    long _stepTime;
    long _initTime;
};

/* PTC = Pulse, steps by Time, for media Concentration */
class TurbidoConcPulse: public TurbidoConcBase
{
  public:
    TurbidoConcPulse(Supervisor &s);

    void formatHeader(char *buf, unsigned int buflen);
    void formatLine(char *buf, unsigned int buflen, long currMeasure);

    void formatParams(char *buf, unsigned int buflen);
    void manualReadParams(void);

    const char *name(void) { return "Turbidostat Conc Pulse"; }
    char letter(void) { return 'p'; }

  protected:
    unsigned long targetPpm1() { return _targetPpm1; }

    int pumpMeasureOverride(void);

    long cycleNo(void);
    uint8_t inPulse(void);

  private:
    unsigned long _targetPpm1;
    long _pulseTime;
    long _cycleTime;
};

/* CTC = Cycle, steps by Time, for media Concentration */
class TurbidoConcCycle: public TurbidoConcBase
{
  public:
    TurbidoConcCycle(Supervisor &s);

    void formatHeader(char *buf, unsigned int buflen);
    void formatLine(char *buf, unsigned int buflen, long currMeasure);

    void formatParams(char *buf, unsigned int buflen);
    void manualReadParams(void);

    const char *name(void) { return "Turbidostat Conc Cycle"; }
    char letter(void) { return 'c'; }
    
  protected:
    unsigned long targetPpm1();

  private:
    unsigned long _firstTargetPpm1;
    unsigned long _secondTargetPpm1;
    long _firstTime;
    long _secondTime;
};

#endif /* !defined(_turbidoschedule_h) */
