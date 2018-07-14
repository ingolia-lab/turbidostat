#include "nephelometer.h"
#include "supervisor.h"
#include "hardware.h"
 
Supervisor *sv;

void setup() {
  pinMode(irLedPin, OUTPUT);
  digitalWrite(irLedPin, HIGH); // high = off

  pinMode(pgaCSPin, OUTPUT);
  digitalWrite(pgaCSPin, HIGH);

  pinMode(adcCSPin, OUTPUT);
  digitalWrite(adcCSPin, HIGH);

  pinMode(sckPin, OUTPUT);
  pinMode(mosiPin, OUTPUT);
  pinMode(misoPin, INPUT);

  pinMode(motAPin, OUTPUT);
  digitalWrite(motAPin, HIGH); // high = off
  pinMode(motBPin, OUTPUT);
  digitalWrite(motBPin, HIGH); // high = off
  pinMode(motCPin, OUTPUT);
  digitalWrite(motCPin, HIGH); // high = off
  pinMode(motDPin, OUTPUT);
  digitalWrite(motDPin, HIGH); // high = off
  
  Serial.begin(9600);
  SPI.begin();

  Serial.print("Preparing...");
  
  for (int i = 9; i >= 0; i--) {
    delay(500);
    if (i == 9) {
      Serial.print("# ");
    }
    Serial.print(i);
    Serial.write(' ');
  }
  Serial.println();

  sv = new Supervisor();

  sv->begin();
}

void loop() {
  sv->loop();
}

