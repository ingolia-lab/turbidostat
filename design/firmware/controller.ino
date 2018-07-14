#include "controller.h"
#include "supervisor.h"

int Controller::delayOneSecond(void)
{
  int delayed = 0;

  while (rtcSeconds() <= _rtcPrevious) {
    delayed++;
    delay(1);
  }

  _rtcPrevious = rtcSeconds();
  return delayed;
}

