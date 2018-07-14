#include <SPI.h>

#include "hardware.h"
#include "nephelometer.h"
#include "supervisor.h"

const long Nephel::pgaScales[] = { 1, 2, 4, 5, 8, 10, 16, 32 };

// PGA SPI MODE3 = 1,1 is better so device select pin doesn't clock
// ADC SPI MODE0 = 0,0 begin transaction before select pin low
//  => external clock (i.e., SCK clocks ADC)

Nephel::Nephel(uint8_t pgaSetting):
  _pgaSetting(pgaSetting),
  _pgaSPISettings(4000000 /* 4 MHz */, MSBFIRST, SPI_MODE3),
  _adcSPISettings(2000000 /* 2 MHz */, MSBFIRST, SPI_MODE0)
{
  pinMode(irLedPin, OUTPUT);
  digitalWrite(irLedPin, HIGH); // high = off

  pinMode(pgaCSPin, OUTPUT);
  digitalWrite(pgaCSPin, HIGH);

  pinMode(adcCSPin, OUTPUT);
  digitalWrite(adcCSPin, HIGH);
  
  Serial.println("# Nephelometer initialized");
}                

void Nephel::manualReadParams(void)
{
  unsigned long newsetting = _pgaSetting;
  manualReadULong("Nephelometer setting ", newsetting);
  if (newsetting < nPgaScales) {
    _pgaSetting = (uint8_t) newsetting;
  } else {
    Serial.print(F("# (not updated)\r\n"));      
  }
}

void Nephel::formatParams(char *buf, unsigned int buflen)
{
  snprintf(buf, buflen, "# Gain setting %ldx (%u)\r\n", pgaScale(), pgaSetting());
}


/* Set the gain on the programmable gain amplifier (PGA)
 * Use SPI to set the gain
 */
int Nephel::setPga(uint8_t setting)
{
  if (setting < nPgaScales) {
    SPI.beginTransaction(_pgaSPISettings);
    digitalWrite(pgaCSPin, LOW);
    SPI.transfer(0x40);
    SPI.transfer(setting);
    digitalWrite(pgaCSPin, HIGH);
    SPI.endTransaction();
    
    return 0;
  } else {
    return -1;
  }
}

long Nephel::measure(void)
{
  long ttlon = 0, ttloff = 0;

  setPga(_pgaSetting);
  
  unsigned long startUsec = micros();
  for (int i = 0; i < nEquil + nMeasure; i++) {
    digitalWrite(irLedPin, LOW);
    Supervisor::delayIfNeeded(startUsec + i*usecTtl + usecAdcOn);
    SPI.beginTransaction(_adcSPISettings);
    digitalWrite(adcCSPin, LOW);
    Supervisor::delayIfNeeded(startUsec + i*usecTtl + usecSpiOn);
    long sample = SPI.transfer16(0x0000);
    if (i >= nEquil) {
      ttlon += (sample & 0xfff);
    }
    digitalWrite(adcCSPin, HIGH);
    SPI.endTransaction();

    Supervisor::delayIfNeeded(startUsec + i*usecTtl + usecLedOff);    
    digitalWrite(irLedPin, HIGH);

    Supervisor::delayIfNeeded(startUsec + i*usecTtl + usecAdcOff);
    SPI.beginTransaction(_adcSPISettings);
    digitalWrite(adcCSPin, LOW);
    Supervisor::delayIfNeeded(startUsec + i*usecTtl + usecSpiOff);
    sample = SPI.transfer16(0x0000);
    if (i >= nEquil) {
      ttloff += sample & 0xfff;
    }
    digitalWrite(adcCSPin, HIGH);
    SPI.endTransaction();    
    
    Supervisor::delayIfNeeded(startUsec + (i+1)*usecTtl);
  }

  return (((long) 10) * (ttloff - ttlon)) / ((long) nMeasure);
}

TestNephel::TestNephel(const Pump &goodPump, const Pump &badPump, unsigned long turbidity, unsigned long goodness, unsigned long doubleSeconds, unsigned long fillSeconds):
  _doubleSeconds(doubleSeconds),
  _fillSeconds(fillSeconds),
  _goodPump(goodPump),
  _badPump(badPump),
  _turbidity(turbidity),
  _goodness(goodness),
  _lastUpdateMsec(millis()),
  _lastUpdateGoodMsec(goodPump.totalOnMsec()),
  _lastUpdateBadMsec(badPump.totalOnMsec())
{
  Serial.println(F("# TestNephel() initialized"));
}

long TestNephel::measure(void)
{
  update();

  long rawMeasure = ((long) _turbidity) * pgaScale() / _measureFactor;
  rawMeasure += nephelNoise();
  return (rawMeasure > _maxMeasure) ? _maxMeasure : rawMeasure;
}

long TestNephel::nephelNoise(void)
{
  uint16_t x = random(micros());
  return -5 + ((x & 0x0001) ? 1 : 0) + ((x & 0x0002) ? 1 : 0)
    + ((x & 0x0004) ? 1 : 0) + ((x & 0x0008) ? 1 : 0)
    + ((x & 0x0010) ? 1 : 0) + ((x & 0x0020) ? 1 : 0)
    + ((x & 0x0040) ? 1 : 0) + ((x & 0x0080) ? 1 : 0)
    + ((x & 0x0100) ? 1 : 0) + ((x & 0x0200) ? 1 : 0)
    + ((x & 0x0400) ? 1 : 0);
}
    
void TestNephel::update(void)
{
  unsigned long nowMsec = millis(), goodMsec = _goodPump.totalOnMsec(), badMsec = _badPump.totalOnMsec();

  unsigned long dtMsec = nowMsec - _lastUpdateMsec;
  _lastUpdateMsec = nowMsec;

  unsigned long dgoodMsec = goodMsec - _lastUpdateGoodMsec;
  _lastUpdateGoodMsec = goodMsec;

  unsigned long dbadMsec = badMsec - _lastUpdateBadMsec;
  _lastUpdateBadMsec = badMsec;

  unsigned long dpumpMsec = dgoodMsec + dbadMsec;

  // tdouble ~ 1k to 10k, dt ~1k, gf1M ~ 70 - 700
  // N.B. 693 ~ 1000 log(2)
  unsigned long growthFactor1M = (dtMsec * ((unsigned long) 693)) / doubleSeconds();
  unsigned long goodnessFactor1k = growthGoodness1k(_goodness);
  unsigned long goodGrowthFactor1M = growthFactor1M * goodnessFactor1k / 1000;
  unsigned long dg = goodGrowthFactor1M * _turbidity / 1000000;

  unsigned long dilutionFactor1M = (dpumpMsec * 1000) / fillSeconds();
  unsigned long df = dilutionFactor1M * _turbidity / 1000000;

  unsigned long newTurbidity = _turbidity + dg - df;

  snprintf(Supervisor::outbuf, Supervisor::outbufLen, 
           "# Test: T(0) = %lu, dt = %lu.%03lu, dpump = %lu.%03lu, gf = %lu.%06lu, gg = %lu.%03lu, ggf = %lu.%06lu, df = %lu.%06lu, dg = %lu, df = %lu, T(f) = %lu",
           _turbidity, dtMsec/1000, dtMsec%1000, dpumpMsec/1000, dpumpMsec%1000, 
           growthFactor1M/1000000, growthFactor1M%1000000,
           goodnessFactor1k/1000, goodnessFactor1k%1000,
           goodGrowthFactor1M/1000000, goodGrowthFactor1M%1000000,
           dilutionFactor1M/1000000, dilutionFactor1M%1000000,
           dg, df, newTurbidity);
  Serial.println(Supervisor::outbuf);

  unsigned long goodAdded100k = (dgoodMsec * 100) / fillSeconds();
  unsigned long totalAdded100k = ((dgoodMsec + dbadMsec) * 100) / fillSeconds();

  unsigned long newGoodness = (_goodness * 100000 + 10000 * goodAdded100k) / (100000 + totalAdded100k);

  snprintf(Supervisor::outbuf, Supervisor::outbufLen, 
           "# Test: G(0) = %lu, g+ = %lu.%05lu, t+ = %lu.%05lu, G(f) = %lu",
           _goodness, goodAdded100k/100000, goodAdded100k%100000, 
           totalAdded100k/100000, totalAdded100k%100000, newGoodness);
  Serial.println(Supervisor::outbuf);

  _turbidity = (newTurbidity > _maxTurbidity) ? _maxTurbidity : newTurbidity;
  _goodness = (newGoodness > _maxGoodness) ? _maxGoodness : newGoodness;
}

unsigned long TestNephel::growthGoodness1k(unsigned long goodness)
{
  return (_goodnessVmax1k * goodness) / (goodness + _goodnessKM);
}


