#include "ClickPattern.h"
#include <cmath>
namespace ClickPattern {
namespace {
constexpr qint64 Ms = 1000000;
constexpr double Pi = 3.14159265358979323846;
// Legit model constants. Hold share and pause odds follow ordinary finger clicks:
// the button is down for roughly a third to a half of each cycle.
constexpr double LegitSpread = 0.09;    // log-normal per-click spread
constexpr double LegitReversion = 0.08; // pull of the rhythm back to the range centre
constexpr double PauseChance = 0.012;
constexpr double HoldShareMin = 0.32, HoldShareMax = 0.52;
} // namespace
Plan plan(const ClickConfig &c) {
    Plan p;
    p.mode = c.mode;
    p.intervalNs = qint64(c.interval) * Ms;
    p.holdNs = qint64(c.hold) * Ms;
    p.cpsMin = c.cpsMin;
    p.cpsMax = c.cpsMax;
    switch (c.mode) {
    case LegitMode:
        break;
    case BlatantMode:
        p.messages = true;
        p.fixed = true;
        break;
    default:
        p.messages = c.delivery == MessageDelivery;
        p.jitter = c.jitter / 100.0;
        p.drift = c.drift;
        p.fixed = c.jitter == 0 && !c.drift;
        break;
    }
    return p;
}
Generator::Generator(const Plan &plan, quint64 seed) : m_plan(plan), m_rng(seed) {
    const double mid = (plan.cpsMin + plan.cpsMax) / 2;
    m_cps = mid + (uniform() - 0.5) * (plan.cpsMax - plan.cpsMin) * 0.5;
    m_phase = uniform() * 2 * Pi;
}
double Generator::normal() {
    if (m_hasSpare) {
        m_hasSpare = false;
        return m_spare;
    }
    double u = 0;
    while (u <= 1e-12)
        u = uniform();
    const double r = std::sqrt(-2 * std::log(u)), t = 2 * Pi * uniform();
    m_spare = r * std::sin(t);
    m_hasSpare = true;
    return r * std::cos(t);
}
Step Generator::next() {
    if (m_plan.mode == LegitMode)
        return legit();
    if (m_plan.fixed)
        return {m_plan.intervalNs, qMin(m_plan.holdNs, m_plan.intervalNs - 1)};
    return custom();
}
Step Generator::legit() {
    const double lo = m_plan.cpsMin, hi = m_plan.cpsMax, mid = (lo + hi) / 2;
    // Mean-reverting walk: the tempo wanders inside the range instead of
    // jumping independently on every click.
    m_cps += LegitReversion * (mid - m_cps) + qMax(0.15, (hi - lo) * 0.1) * normal();
    if (m_cps < lo)
        m_cps = qMin(hi, 2 * lo - m_cps);
    if (m_cps > hi)
        m_cps = qMax(lo, 2 * hi - m_cps);
    double gap = 1000.0 / m_cps * std::exp(LegitSpread * normal());
    gap = qBound(1000.0 / (hi * 1.2), gap, 1000.0 / (lo * 0.8));
    if (uniform() < PauseChance)
        gap += 35 + uniform() * 75;
    double hold = gap * (HoldShareMin + uniform() * (HoldShareMax - HoldShareMin));
    hold = gap - 8 >= 10 ? qBound(10.0, hold, gap - 8) : gap / 2;
    return {qint64(gap * Ms), qint64(hold * Ms)};
}
Step Generator::custom() {
    double factor = 1;
    if (m_plan.drift) {
        // One slow wave every ~30–50 clicks, ±12 %.
        m_phase += 2 * Pi / (30 + uniform() * 20);
        factor += 0.12 * std::sin(m_phase);
    }
    const double base = double(m_plan.intervalNs) * factor;
    const qint64 gap = qMax<qint64>(Ms, qint64(base * (1 + m_plan.jitter * (2 * uniform() - 1))));
    qint64 hold = qint64(double(m_plan.holdNs) * (1 + m_plan.jitter * (2 * uniform() - 1)));
    hold = qBound<qint64>(0, hold, gap - Ms / 2);
    return {gap, hold};
}
QList<double> preview(const ClickConfig &config, int count, quint64 seed) {
    Generator g(plan(config), seed);
    QList<double> gaps;
    for (int i = 0; i < count; ++i)
        gaps.append(double(g.next().gapNs) / Ms);
    return gaps;
}
double expectedCps(const ClickConfig &c) {
    if (c.mode == LegitMode)
        return (c.cpsMin + c.cpsMax) / 2.0;
    return 1000.0 / c.interval;
}
QString modeName(int mode) {
    switch (mode) {
    case LegitMode:
        return "Легит";
    case BlatantMode:
        return "Блатант";
    default:
        return "Свой";
    }
}
QString describe(const ClickConfig &c) {
    if (c.mode == LegitMode)
        return modeName(c.mode) + " · " +
               (c.cpsMin == c.cpsMax ? QString::number(c.cpsMin)
                                     : QString::number(c.cpsMin) + "–" + QString::number(c.cpsMax)) +
               " КПС";
    QString text = modeName(c.mode) + " · " + QString::number(c.interval) + " мс";
    if (c.mode == CustomMode) {
        if (c.jitter)
            text += " ±" + QString::number(c.jitter) + " %";
        if (c.drift)
            text += " · волна";
        text += c.delivery == MessageDelivery ? " · сообщения" : " · эмуляция";
    }
    return text;
}
} // namespace ClickPattern
