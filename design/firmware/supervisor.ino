#include "controller.h"
#include "manual.h"
#include "supervisor.h"
#include "turbidoconc.h"
#include "turbidomix.h"
#include "turbidoschedule.h"
#include "turbidostat.h"

#define OUTBUF_LEN 512
const unsigned int Supervisor::outbufLen = OUTBUF_LEN;
char Supervisor::outbuf[OUTBUF_LEN] = "";

Supervisor::Supervisor(void):
  _neph(new Nephel()),
  _defaultController(ManualController(*this)),
  _runningController(&_defaultController),
  _nextController(&_defaultController),
  _configuredController(NULL)
{
  _nControllers = 12;
  _controllers = new Controller*[_nControllers];
  unsigned int cno = 0;
  _controllers[cno++] = &_defaultController;
  _controllers[cno++] = new Turbidostat(*this);
  _controllers[cno++] = new TurbidoRatioFixed(*this);
  _controllers[cno++] = new TurbidoInduce(*this);
//  _controllers[_] = new TurbidoGradient(*this);
//  _controllers[_] = new TurbidoCycle(*this);
//  _controllers[_] = new TurbidoConcFixed(*this);
  _controllers[cno++] = new TurbidoConcCycle(*this);
  _controllers[cno++] = new TurbidoConcGradient(*this);
  _controllers[cno++] = new TurbidoConcLogGradient(*this);
//  _controllers[10] = new TurbidoConcPulse(*this);
  _controllers[cno++] = new TurbidoDensityGradient(*this);
  _nControllers = cno;
  Serial.println("# Supervisor initialized");
}

void Supervisor::begin(void)
{
  _runningController = &defaultController();
  _nextController    = _runningController;
  Serial.print("# Supervisor beginning, with controller ");
  Serial.println(_runningController->name());
}

void Supervisor::loop(void)
{
  if (_nextController != _runningController) {
    _runningController->end();
    if (_nextController->begin()) {
      Serial.println(F("# Problem switching to new controller -- entering default mode"));
      _runningController = &defaultController();
    } else {
      _runningController = _nextController;
    }
  }
  
  if (_runningController->loop()) {
    _nextController = &defaultController();
  }  
}

void Supervisor::serialWriteControllers(void)
{
  snprintf(outbuf, outbufLen, "# CONFIGURED CONTROLLER: %s\r\n", 
           configuredControllerName());
  Serial.write(outbuf);
  if (_configuredController != NULL) {
    _configuredController->serialWriteParams();
  }
  Serial.println("# CONTROLLERS:");
  for (unsigned int i = 0; i < _nControllers; i++) {
    snprintf(outbuf, outbufLen, "#   %c %50s\r\n", _controllers[i]->letter(), _controllers[i]->name());
    Serial.write(outbuf);
  }
}

Controller *Supervisor::pickController(void)
{
  serialWriteControllers();

  Serial.print("# Pick a controller: ");

  int ch;
  while ((ch = Serial.read()) < 0) {
    delay(1);
  }
  Serial.write(ch);
  
  for (unsigned int i = 0; i < _nControllers; i++) {
    if (_controllers[i]->letter() == ch) {
      Serial.print("=");
      Serial.println(_controllers[i]->name());
      return _controllers[i];
    }
  }

  return NULL;
}

void Supervisor::manualSetupController(void)
{
  Serial.print(F("\r\n# Pick a controller to configure\r\n"));
  Controller *c;
  if ((c = pickController()) != NULL) {
    c->manualSetParams();
    _configuredController = c;
  } else {
    Serial.println();
    Serial.print(F("# Input does not match a known controller\r\n# No controller picked to configure\r\n"));
  }
}

void Supervisor::startConfiguredController(void)
{  
  if (_configuredController != NULL) {
    _nextController = _configuredController;
  } else {
    Serial.print(F("# No configured controller -- controller must be setup before starting\r\n"));
  }
}

void Supervisor::useTestNephel(void)
{
  Serial.println();
  Serial.print("# To enter Test Mode, press y. To exit Test Mode, press q.\r\n");
  
  int ch;
  while ((ch = Serial.read()) < 0) {
    delay(1);
  }

  Serial.print("# ");
  Serial.write(ch);

  if(ch=='y')
  {
    Serial.print("=");
    Serial.println("Test Mode");
    _neph = new TestNephel(_pumps[0], _pumps[1]);
 
    return;
  }
  
  if(ch=='q')
  {
    Serial.print("=");
    Serial.println("Normal Mode");
    _neph = new Nephel();

    return;
  }

  Serial.println("!= 'y' or 'q'");
  Serial.print(F("# Test Mode status remains unchanged\r\n"));

  return; 
}


/* Read a (long) integer from Serial
 * Read digits from serial until enter/return, store the result into *res, and return 1
 * If no digits are typed before enter/return, return 0 and leave *res unchanged
 * If a non-digit character is typed, return -1 immediately and leave *res unchanged
 */
int Supervisor::blockingReadLong(long *res)
{
  const int buflen = 16;
  char buffer[buflen];
  int bufpos = 0;

  int ch;
  
  do {
    ch = Serial.read();
    if (ch <= 0) {
       delay(1);
    } else if (ch == '\n' || ch == '\r') {
       Serial.println();
       break;
    } else if ((ch < '0' || ch > '9') && (bufpos != 0 || ch != '-')) {
       Serial.write('*');
       return -1;
    } else {
       buffer[bufpos] = (char) ch;
       Serial.write(ch);
       bufpos++;
       if (bufpos == (buflen - 1)) {
         break;
       } 
    }
  } while(1);
  
  if (bufpos > 0) {  
    buffer[bufpos] = '\0';
    *res = atol(buffer);
    return 1;
  } else {
    return 0;
  }
}

uint8_t Supervisor::pumpcharToNo(char pumpch) 
{ 
  uint8_t pno = (pumpch >= 'a') ? (pumpch - 'a') : (pumpch - 'A');
  return (pno < _nPumps) ? pno : 0xff;
}

int Supervisor::blockingReadPump(uint8_t *res)
{
  int ch;
  while ((ch = Serial.read()) <= 0) {
    delay(1);
  }

  uint8_t pno = pumpcharToNo(ch);
  if (pno < _nPumps) {
    Serial.write(ch);
    *res = pno;
    return 1;
  } else {
    Serial.write('*');
    return -1;
  }
}

int Supervisor::blockingReadFixed(long *res, int fractDigits)
{
  const int buflen = 16;
  char buffer[buflen];
  int bufpos = 0, seenpoint = 0;

  int ch;
  
  do {
    ch = Serial.read();
    if (ch <= 0) {
       delay(1);
    } else if (ch == '\n' || ch == '\r') {
       Serial.println();
       break;
    } else if ((ch < '0' || ch > '9') && (bufpos != 0 || ch != '-') && (seenpoint || ch != '.')) {
       Serial.write('*');
       return -1;
    } else {
      buffer[bufpos] = (char) ch;
      seenpoint |= (ch == '.');
      Serial.write(ch);
      bufpos++;
      if (bufpos == (buflen - 1)) {
        break;
      } 
    }
  } while(1);
  
  if (bufpos > 0) {  
    buffer[bufpos] = '\0';
    char *next;
    long x = strtol(buffer, &next, 10);

    int negate = (x < 0);
    x = x * (negate ? (-1) : (+1));
    
    if ( (*next) == '.') { 
      next++;
    }
    for (int i = 0; i < fractDigits; i++) {
      x *= 10;
      if ((*next) != 0) {
        x += ( (*next) - '0' );
        next++;
      } 
    }

    x = x * (negate ? (-1) : (+1));

    *res = x;
    
    return 1;
  } else {
    return 0;
  }
}


