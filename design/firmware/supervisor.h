#ifndef _supervisor_h
#define _supervisor_h 1

class Supervisor;

#include "controller.h"
#include "hardware.h"
#include "manual.h"
#include "nephelometer.h"
#include "pump.h"
#include "settings.h"

class Supervisor : protected ParamSettings
{
  public:
    Supervisor(void);

    static const unsigned int outbufLen;
    static char outbuf[];

    /* Delay until a specified time in microseconds
     * Return the number of microseconds delayed
     * If the current time is at or after `until` do not delay and return 0.
     */
    static inline unsigned long delayIfNeeded(unsigned long until)
    {
      unsigned long now = micros();
      if (now < until) {
        delayMicroseconds(until - now);
        return until - now;
      } else {
        return 0;
      }
    }

    static int blockingReadLong(long *res);
    static int blockingReadPump(uint8_t *res);
    static int blockingReadFixed(long *res, int fractDigits);
    
    static char pumpnoToChar(uint8_t pumpno) { return 'A' + ((char) pumpno); }
    static uint8_t pumpcharToNo(char pumpch);
    
    inline Nephel &nephelometer(void) { return *_neph; }
    inline int nPumps(void) { return _nPumps; }
    inline Pump &pump(unsigned int pumpno) { if (pumpno >= _nPumps) { return _pumps[0]; } else { return _pumps[pumpno]; } }

    void begin(void);
    void loop(void);

    void serialWriteControllers(void);    
    void startConfiguredController(void);
    void manualSetupController(void);

    const char *configuredControllerName(void) { if (_configuredController != NULL) { return _configuredController->name(); } else { return "NONE"; } }

    void useTestNephel(void);
  protected:
    Controller &defaultController(void) { return _defaultController; }
    Controller &runningController(void) { return *_runningController; }
    Controller *pickController(void);

    void manualReadParams(void) { /* No parameters */ }
    void formatParams(char *buf, unsigned int buflen) { *buf = 0; /* No parameters */ }

  private:
    Nephel *_neph;

    static const unsigned int _nPumps = 4;
    Pump _pumps[_nPumps] = { Pump(motAPin, 0), Pump(motBPin, 0), Pump(motCPin, 0), Pump(motDPin, 0) };

    unsigned int _nControllers;
    Controller **_controllers;       

//    TrivialController _defaultController;
    ManualController _defaultController;
    
    Controller *_runningController;
    Controller *_nextController;

    Controller *_configuredController;

    void manualLoop(void);

    static const long version = 10000;
    static const unsigned int versionSlot = 0;
    static const unsigned int runningControllerSlot = 1;
    static const unsigned int nephelBase = 0x10;
    static const unsigned int controllerBase = 0x30;
};


#endif /* !defined(_supervisor) */
