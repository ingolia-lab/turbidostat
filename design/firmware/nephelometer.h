#ifndef _nephelometer_h
#define _nephelometer_h 1

/*
 * Control the nephelometer (turbidity measurement) circuits
 */

#include <SPI.h>

#include "pump.h"
#include "settings.h"

class Nephel : public ParamSettings
{
  public:
    Nephel(uint8_t pgaSetting = 0x01);

    // Measure turbidity and return the measurement
    // This function blocks and takes quite a while (~ nMeasure * 100 µs) to run
    // The returned value is 10x the difference between two 12-bit values
    //   It should generally be positive, but formally it can take any value between [-4096, 4095].
    virtual long measure();

    static const long maxMeasure = 4095 * 10;

    // The nephelometer has a programmable gain amplifier (PGA)
    // The PGA setting must fall in [0, nPgaScales-1]
    static const int nPgaScales = 8;

    // Look up the multiplicative scale factor for a PGA setting
    static long pgaScale(uint8_t setting) { return (setting < nPgaScales) ? pgaScales[setting] : -1; }

    // Return the  multiplicative scaling factor for the current PGA setting
    long pgaScale(void) { return pgaScale(_pgaSetting); }

    virtual void manualReadParams(void);
    virtual void formatParams(char *buf, unsigned int buflen);  
  protected:
    // Array of multiplicative scale factors for different PGA settings
    static const long pgaScales[];

    // Current PGA setting used for turbidity measurements
    uint8_t pgaSetting() { return _pgaSetting; }
  private:
    uint8_t _pgaSetting;

    SPISettings _pgaSPISettings;
    SPISettings _adcSPISettings;

    int setPga(uint8_t setting);

    static const int nMeasure = 512;
    static const int nEquil = 16;

    // Timing factors for one measurement cycle, all in microseconds
    // Calibrated based on asymmetric delays between pin switching and LED changing,
    //   group delays in the analog signal processing circuit, and
    //   ADC sampling time.
    static const unsigned long usecAdcOn = 25;
    static const unsigned long usecSpiOn = 30;
    static const unsigned long usecLedOff = 57;
    static const unsigned long usecAdcOff = 75;
    static const unsigned long usecSpiOff = 80;
    static const unsigned long usecTtl = 100;
};

class TestNephel : public Nephel
{
  public:
    TestNephel(const Pump &goodPump, const Pump &badPump, 
               unsigned long turbidity = 100000, unsigned long goodness = _maxGoodness, 
               unsigned long doubleSeconds = 45 * 60, unsigned long fillSeconds = 10 * 60);
    
    long measure(void);

  protected:
    unsigned long doubleSeconds(void) { return _doubleSeconds; }
    unsigned long fillSeconds(void) { return _fillSeconds; }

    void update(void);
    unsigned long growthGoodness1k(unsigned long goodness);

    long nephelNoise(void);
  private:
    unsigned long _doubleSeconds;
    unsigned long _fillSeconds;

    const Pump &_goodPump;
    const Pump &_badPump;

    unsigned long _turbidity;
    unsigned long _goodness;
    unsigned long _lastUpdateMsec;
    unsigned long _lastUpdateGoodMsec;
    unsigned long _lastUpdateBadMsec;

    static const unsigned long _maxTurbidity = 2000000;
    static const long _measureFactor = 1000;
    static const long _maxMeasure = 40000;

    static const unsigned long _maxGoodness  = 10000;
    static const unsigned long _goodnessKM   =  2000;
    static const unsigned long _goodnessVmax1k = (1000 * (_maxGoodness + _goodnessKM)) / _maxGoodness;
};

#endif /* defined(_nephelometer_h) */
