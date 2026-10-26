#pragma once
#include <QtGlobal>
#include <atomic>
#include <chrono>
namespace Timing {
inline qint64 nowNs() {
    return std::chrono::duration_cast<std::chrono::nanoseconds>(
               std::chrono::steady_clock::now().time_since_epoch())
        .count();
}
struct Next {
    qint64 deadline;
    quint64 skipped;
};
inline Next advance(qint64 deadline, qint64 after, qint64 period) {
    qint64 next = deadline + period;
    const quint64 skips = next <= after ? quint64((after - next) / period + 1) : 0;
    return {next + qint64(skips) * period, skips};
}
inline double rate(quint64 count, qint64 spanNs) {
    return spanNs >= 250000000 ? double(count) * 1e9 / double(spanNs) : -1;
}
} // namespace Timing

// Absolute rational QPC grid: fractional ticks never accumulate as truncation drift.
namespace Timing {
class TickGrid {
    qint64 m_origin, m_whole, m_remainder;

  public:
    TickGrid(qint64 origin, qint64 frequency, int intervalMs)
        : m_origin(origin), m_whole(frequency * intervalMs / 1000),
          m_remainder(frequency * intervalMs % 1000) {}
    qint64 at(quint64 slot) const {
        return m_origin + qint64(slot) * m_whole + qint64(slot / 1000) * m_remainder +
               qint64(slot % 1000) * m_remainder / 1000;
    }
    quint64 nextSlot(quint64 current, qint64 after) const {
        quint64 lo = current + 1, hi = lo;
        while (at(hi) <= after)
            hi = hi * 2 + 1;
        while (lo < hi) {
            const auto mid = lo + (hi - lo) / 2;
            if (at(mid) <= after)
                lo = mid + 1;
            else
                hi = mid;
        }
        return lo;
    }
};
struct GapStats {
    qint64 previous = -1, span = 0, maxJitter = 0;
    quint64 gaps = 0;
    void accept(qint64 timestamp, qint64 requestedNs) {
        if (previous >= 0) {
            const auto gap = timestamp - previous;
            span += gap;
            ++gaps;
            maxJitter = qMax(maxJitter, qAbs(gap - requestedNs));
        }
        previous = timestamp;
    }
    qint64 mean() const { return gaps ? span / qint64(gaps) : -1; }
};
struct Delivery {
    std::atomic<qint64> meanNs{-1}, maxJitterNs{-1};
};
} // namespace Timing
