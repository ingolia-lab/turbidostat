#ifndef _settings_h
#define _settings_h 1


class ParamSettings
{
  public:
    // Display current parameter values using `serialWriteParams()`,
    //   interactively read new values with `manualReadParams()`, and
    //   display the new values. Blocking.
    virtual void manualSetParams(void);

    // Interactively read parameter values over Serial. Blocking.
    virtual void manualReadParams(void) = 0;

    // Write current parameter values into a character buffer.
    virtual void formatParams(char *buf, unsigned int buflen) = 0;

    // 
    virtual void serialWriteParams(void);

  protected:
    static void manualReadLong(const char *desc, long &pval);
    static void manualReadULong(const char *desc, unsigned long &pval);

    static void manualReadPercent(const char *desc, uint8_t &pval);

    static void manualReadPump(const char *desc, uint8_t &pval);

    static void manualReadMeasure(const char *desc, long &mval);
};

#endif /* !defined(_settings_h) */
