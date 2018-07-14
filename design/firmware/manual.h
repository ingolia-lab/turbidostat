#ifndef _manual_h
#define _manual_h 1

/*
 * Manual commands that can be run from the supervisor
 */

#include "supervisor.h"
#include "controller.h"

class ManualCommand
{
  public:
    // Create a manual command linked to the supervisor
    ManualCommand(Supervisor &s) : _supervisor(s) { }

    // Name of the manual command
    virtual const char *name(void);

    // One-letter command character to invoke the command
    virtual char letter(void);

    // Help information for the manual command
    virtual const char *help(void);

    // Execute the manual command (may block indefinitely pending user input, etc.)
    virtual void run(void);
  protected:
    Supervisor &supervisor(void) { return _supervisor; }
  private:
    Supervisor &_supervisor;
};

class ManualController : public Controller {
  public:
    ManualController(Supervisor &s);
    int begin(void) { return 0; }
    int loop(void);
    void end(void) { }
    const char *name(void) { return "Manual"; }
    char letter(void) { return 'm'; }

    void serialWriteCommands(void);

    void manualReadParams(void) { /* No parameters */ }
    void formatParams(char *buf, unsigned int buflen) { buf[0] = 0; }

  private:
    unsigned int _nCommands;
    ManualCommand **_commands;
    char *_commandChars;

    const char *_name = "band-dsp-teensy";
};


class ManualAnnotate : public ManualCommand
{
  public:
    ManualAnnotate(Supervisor &s) : ManualCommand(s) { }
    const char *name(void) { return "Annotate"; }
    char letter(void) { return 'a'; }
    const char *help(void) { return "Type a note into the log file"; }
    void run(void);
};

class ManualStartController : public ManualCommand
{
  public:
    ManualStartController(Supervisor &s) : ManualCommand(s) { }
    const char *name(void) { return "Start Controller"; }
    char letter(void) { return 'c'; }
    const char *help(void);
    void run(void);
  private:
    static const unsigned int buflen;
    static char buf[];
};

class ManualGain : public ManualCommand
{
  public:
    ManualGain(Supervisor &s) : ManualCommand(s) { }
    const char *name(void) { return "Set Gain"; }
    char letter(void) { return 'g'; }
    const char *help(void) { return "Set nephelometer gain"; }
    void run(void);
};

class ManualHelp : public ManualCommand
{
  public:
    ManualHelp(Supervisor &s, ManualController &m) : ManualCommand(s), _manualCtrl(m) { }
    const char *name(void) { return "Help"; }
    char letter(void) { return 'h'; }
    const char *help(void) { return "Print help information"; }
    void run(void);
  private:
    ManualController &_manualCtrl;
};

class ManualMeasure : public ManualCommand
{
  public:
    ManualMeasure(Supervisor &s) : ManualCommand(s) { }
    const char *name(void) { return "Measure"; }
    char letter(void) { return 'm'; }
    const char *help(void) { return "Take online measurements"; }
    void run(void);

    static const unsigned long intervalMsec = 500;
};

class ManualPump : public ManualCommand
{
  public:
    ManualPump(Supervisor &s) : ManualCommand(s) { }
    const char *name(void) { return "Pump"; }
    char letter(void) { return 'p'; }
    const char *help(void) { return "Manually switch on a pump"; }
    void run(void);  
};

class ManualSetup : public ManualCommand
{
  public:
    ManualSetup(Supervisor &s) : ManualCommand(s) { }
    const char *name(void) { return "Setup"; }
    char letter(void) { return 's'; }
    const char *help(void) { return "Set parameters for a controller"; }
    void run(void);  
};

class ManualTestNephel : public ManualCommand
{
  public:
    ManualTestNephel(Supervisor &s) : ManualCommand(s) { }
    const char *name(void) { return "Test Nephelometer"; }
    char letter(void) { return 'z'; }
    const char *help(void) { return "Switch to test nephelometer stub"; }
    void run(void);
};

#endif /* !defined(_manual_h) */
