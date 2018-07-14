#include "controller.h"
#include "manual.h"
#include "supervisor.h"

ManualController::ManualController(Supervisor &s)
{
  _nCommands = 8;
  _commands = new ManualCommand*[_nCommands];
  _commands[0] = new ManualAnnotate(s);
  _commands[1] = new ManualStartController(s);
  _commands[2] = new ManualGain(s);
  _commands[3] = new ManualHelp(s, *this);
  _commands[4] = new ManualMeasure(s);
  _commands[5] = new ManualPump(s);
  _commands[6] = new ManualSetup(s);
  _commands[7] = new ManualTestNephel(s);

  _commandChars = new char[_nCommands + 1];
  for (unsigned int i = 0; i < _nCommands; i++) {
    _commandChars[i] = _commands[i]->letter();
  }
  _commandChars[_nCommands] = 0;

  Serial.println("# ManualController initialized");
}

int ManualController::loop(void)
{
  snprintf(Supervisor::outbuf, Supervisor::outbufLen, "# %s manual [%s] > ", _name, _commandChars);
  Serial.write(Supervisor::outbuf);

  int cmd;  
  while ((cmd = Serial.read()) < 0) {
    delay(1);
  }
  
  Serial.write(cmd);

  for (unsigned int i = 0; i < _nCommands; i++) {
    if (cmd == _commands[i]->letter()) {
      _commands[i]->run();
      return 0;
    }
  }
  
  Serial.print(F("\r\n# Unknown command: "));
  Serial.write((char) cmd);
  Serial.println();

  return 0;
}

void ManualController::serialWriteCommands(void)
{
  Serial.println("# COMMANDS:");
  for (unsigned int i = 0; i < _nCommands; i++) {
    snprintf(Supervisor::outbuf, Supervisor::outbufLen, "#   %c %22s   %s\r\n", _commands[i]->letter(), _commands[i]->name(), _commands[i]->help());
    Serial.write(Supervisor::outbuf);
  }
}

void ManualAnnotate::run(void)
{
  int ch;
  
  Serial.print(F("\r\n# NOTE: "));
 
  while (1) {
    while ((ch = Serial.read()) < 0) {
      delay(1);
    }
    
    if (ch == '\n' || ch == '\r') {
      Serial.println();
      break; 
    }
    
    Serial.write(ch);
  } 
}

#define HELPBUF_LEN 128
const unsigned int ManualStartController::buflen = HELPBUF_LEN;
char ManualStartController::buf[HELPBUF_LEN];

const char *ManualStartController::help(void)
{
  snprintf(buf, buflen, "Start configured controller: %s",
           supervisor().configuredControllerName());
  return buf;
}

void ManualStartController::run(void)
{
  Serial.println();
  supervisor().startConfiguredController();
}

void ManualGain::run(void)
{
  Serial.println();
  supervisor().nephelometer().manualSetParams();
}

void ManualHelp::run(void) 
{
  Serial.println();
  _manualCtrl.serialWriteCommands();
  supervisor().serialWriteControllers();  
}

void ManualMeasure::run(void)
{
  Serial.println();
  Serial.println("M\ttime.s\tneph\tgain");

  while (1) {
    unsigned long startMsec = millis();

    long avg10 = supervisor().nephelometer().measure();

    long mmodulo = avg10 % ((long) 1000);
    long mint = (mmodulo < 0) ?  (-(avg10 / ((long) 1000))) : (avg10 / ((long) 1000));
    const unsigned long mdec = abs(mmodulo);
    
    snprintf(Supervisor::outbuf, Supervisor::outbufLen, 
             "M\t%lu.%01lu\t%2ld.%03ld\t%ld",
             startMsec / ((unsigned long) 1000), 
             (startMsec / ((unsigned long) 100)) % ((unsigned long) 10),
             mint, mdec,
             supervisor().nephelometer().pgaScale());
    Serial.println(Supervisor::outbuf);

    if (Serial.read() > 0) {
      break; 
    }

    Supervisor::delayIfNeeded(((long) 1000) * (startMsec + intervalMsec));
  }

  while (Serial.read() > 0) { /* Drain the buffer */ }
}

void ManualPump::run(void)
{
  Serial.print(F("\r\n# Which pump ["));
  for (int pno = 0; pno < supervisor().nPumps(); pno++) {
    if (pno > 0) {
      Serial.print(",");
    }
    Serial.print((char) ('A' + pno));
  }
  Serial.print(F("]: "));

  int ch;
  while ((ch = Serial.read()) < 0) {
    delay(1);
  }
  Serial.write(ch);
  int pno = (ch >= 'a') ? (ch - 'a') : (ch - 'A');
  if (pno >= 0 && pno < supervisor().nPumps()) {
    Pump &p = supervisor().pump(pno);

    Serial.print(F("\r\n# Enter pump duration (sec): "));
    long pumpDurationRequested;
    if (Supervisor::blockingReadLong(&pumpDurationRequested) > 0) {
      Serial.print(F("# Planned pumping time: "));
      Serial.print(pumpDurationRequested);
      Serial.print(F(" sec (any key to interrupt)"));

      long totalOnBefore = p.totalOnMsec();
      unsigned long tstart = millis();
      unsigned long tend = tstart + pumpDurationRequested * 1000;
      p.setPumping(1);

      while (millis() < tend) {
        if (Serial.read() > 0) {
          break; 
        }
        delay(1);
      }

      p.setPumping(0);

      long pumpDurationActual = p.totalOnMsec() - totalOnBefore;

      snprintf(Supervisor::outbuf, Supervisor::outbufLen, 
               "\r\n# Pumped %ld.%03ld seconds\r\n", 
               pumpDurationActual / 1000, pumpDurationActual % 1000);
      Serial.write(Supervisor::outbuf);  
    } else {
      Serial.print(F("\r\n# Manual pump cancelled\r\n"));
    }
  } else {
    Serial.print(F("\r\n# Manual pump cancelled\r\n"));
  }
}

void ManualSetup::run(void)
{
  supervisor().manualSetupController();
}

void ManualTestNephel::run(void)
{
  supervisor().useTestNephel();
}

