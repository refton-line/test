#pragma once
#include "Configuration.h"
#include <QList>
#include <QRandomGenerator64>
#include <QString>
// Timing model for the three click modes. Pure and seedable, so the worker and
// the tests share the exact same generator.
namespace ClickPattern {
struct Plan {
    int mode = LegitMode;
    bool messages = false; // window messages instead of SendInput
    bool fixed = false;    // constant gap: the worker keeps the drift-free QPC grid
    double cpsMin = 9, cpsMax = 13;
    qint64 intervalNs = 100000000, holdNs = 1000000;
    double jitter = 0; // fraction, Custom only
    bool drift = false;
};
struct Step {
    qint64 gapNs;  // from this press to the next press
    qint64 holdNs; // down → up for this press, always shorter than gapNs
};
Plan plan(const ClickConfig &config);
class Generator {
  public:
    Generator(const Plan &plan, quint64 seed);
    Step next();

  private:
    double uniform() { return m_rng.generateDouble(); }
    double normal();
    Step legit();
    Step custom();
    Plan m_plan;
    QRandomGenerator64 m_rng;
    double m_cps = 0, m_phase = 0, m_spare = 0;
    bool m_hasSpare = false;
};
// Deterministic sample of upcoming gaps in milliseconds for the UI rhythm preview.
QList<double> preview(const ClickConfig &config, int count, quint64 seed = 0xC11C4E5ULL);
// Expected long-run clicks per second, before scheduling losses.
double expectedCps(const ClickConfig &config);
QString modeName(int mode);
QString describe(const ClickConfig &config);
} // namespace ClickPattern
