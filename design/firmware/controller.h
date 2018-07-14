#ifndef _controller_h
#define _controller_h 1

#include "settings.h"

/*
 * A Controller provides an event loop to monitor and manage growth automatically.
 */

class Controller : public ParamSettings {
  public:
    Controller() : _rtcPrevious(0) { }

    // Called once when a controller begins to monitor and manage.
    // Return 0 if all is well and non-zero for a problem indicating that the controller cannot run
    virtual int begin(void) = 0;

    // Called once per second to allow the controller to monitor and manage.
    // Return 0 to continue control and non-zero when control should return to manual
    virtual int loop(void) = 0;

    // Called when control is switched to a different controller while this is running
    // This IS called after loop() returns non-zero on the next loop
    virtual void end(void) = 0;

    // Name of the controller algorithm
    virtual const char *name(void) = 0;

    // One-letter character for selecting the controller
    virtual char letter(void) = 0;

  protected:
    // Returns the time in real-time clock seconds
    static unsigned long rtcSeconds(void) { return millis() / ((unsigned long) 1000); }

    int delayOneSecond(void);

    // Schedule "on" intervals within a [0,99] cycle roughly evenly
    // percentOn is the percentage of on time, i.e., number of cycle values getting "1"
    static int schedulePercent(uint8_t percentOn, uint8_t cycle)
    {
      cycle = cycle % 100;
      uint8_t per50 = (percentOn / 2) + ( ((percentOn % 2) > (cycle / 50)) ? 1 : 0);
      uint8_t per25 = (per50 / 2) + ( ((per50 % 2) > ( (cycle % 50) / 25)) ? 1 : 0);
      uint8_t per5  = (per25 / 5) + ( ((per25 % 5) > ( (cycle % 25) /  5)) ? 1 : 0);

      return (per5 > (cycle % 5) );
    }
  private:
    unsigned long _rtcPrevious;
};

class TrivialController : public Controller
{
  public:
    TrivialController(void) { Serial.println("TrivialController::TrivialController()"); }
    int begin(void) { Serial.println("TrivialController::begin()"); return 0; }
    int loop(void) { delayOneSecond(); Serial.println("TrivialController::loop()"); return 0; }
    void end(void) { Serial.println("TrivialController::loop()"); }
    const char *name(void) { return "Trivial Controller"; }
    char letter(void) { return 'z'; }
    void manualSetParams(void) { /* No parameters */ }
    void formatParams(char *buf, unsigned int buflen) { buf[0] = 0; }

};

#endif /* !defined(_controller_h) */
