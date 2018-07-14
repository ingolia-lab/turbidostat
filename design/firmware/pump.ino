#include "pump.h"

Pump::Pump(int pin, int onIsHigh):
  _pin(pin), _onIsHigh(onIsHigh)
{
  pinMode(_pin, OUTPUT);
  _isPumping = 0;    
  _setPin();  

  _lastOnMsec = -1;
  _lastOffMsec = millis();
  _cumulativeMsec = 0;

  Serial.print("# Pump initialized on pin ");
  Serial.println(pin);
}

long Pump::totalOnMsec(void) const
{
  return _cumulativeMsec + (_isPumping ? (millis() - _lastOnMsec) : 0);
}

void Pump::setPumping(int newpump)
{
  int oldpump = _isPumping;
  _isPumping = newpump;
  _setPin();

  if (newpump && (!oldpump)) {
    _lastOnMsec = millis();
  } else if ((!newpump) && oldpump) {
    _lastOffMsec = millis();
    _cumulativeMsec += _lastOffMsec - _lastOnMsec;
  }
}

void Pump::reset(void)
{
  setPumping(0);
  _lastOnMsec = -1;
  _lastOffMsec = millis();
  _cumulativeMsec = 0;
}

SyringePump::SyringePump(int pinA, int pinB, long stepMsec):
  _pinA(pinA),
  _pinB(pinB),
  _stepMsec(stepMsec),
  _currStep(0)
{
  pinMode(_pinA, OUTPUT);
  pinMode(_pinB, OUTPUT);
  setPins();
  Serial.print("# Syringe pump initialized on pins A ");
  Serial.print(_pinA);
  Serial.print(", B ");
  Serial.println(_pinB);
}

void SyringePump::stepN(int nstep)
{
  if (nstep >= 0) {
    for (int j = 0; j < nstep; j++) {
      step1Forward();
    }
  } else {
    for (int j = 0; j > nstep; j--) {
      step1Backward();
    }
  }
}


