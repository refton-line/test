#include "ClickController.h"
#include "Timing.h"
#include "ClickPattern.h"
#include <QRandomGenerator>
#ifdef Q_OS_WIN
#define WIN32_LEAN_AND_MEAN
#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <algorithm>
#include <windows.h>
namespace {
struct TimerHandle {
    HANDLE value =
        CreateWaitableTimerExW(nullptr, nullptr, 0x00000002, TIMER_MODIFY_STATE | SYNCHRONIZE);
    TimerHandle() {
        if (!value)
            value = CreateWaitableTimerW(nullptr, TRUE, nullptr);
    }
    ~TimerHandle() {
        if (value)
            CloseHandle(value);
    }
};
qint64 tick() {
    LARGE_INTEGER q;
    QueryPerformanceCounter(&q);
    return q.QuadPart;
}
bool ours(HWND w) {
    DWORD pid = 0;
    GetWindowThreadProcessId(w, &pid);
    return pid == GetCurrentProcessId();
}
// 0=deadline reached, 1=cancel, 2=error. Recheck QPC after waking: no early sends.
int waitUntil(qint64 deadline, qint64 freq, HANDLE stop, HANDLE timer) {
    HANDLE h[]{stop, timer};
    for (;;) {
        if (WaitForSingleObject(stop, 0) == WAIT_OBJECT_0)
            return 1;
        auto now = tick();
        if (now >= deadline)
            return 0;
        LARGE_INTEGER due;
        due.QuadPart = -std::max<qint64>(1, (deadline - now) * 10000000 / freq);
        if (!SetWaitableTimer(timer, &due, 0, nullptr, nullptr, FALSE))
            return 2;
        DWORD r = WaitForMultipleObjects(2, h, FALSE, INFINITE);
        if (r == WAIT_OBJECT_0)
            return 1;
        if (r != WAIT_OBJECT_0 + 1)
            return 2;
    }
}
struct LoopState {
    HANDLE stop;
    std::atomic_bool &cancel;
    std::atomic<qulonglong> &count, &skips;
    std::atomic<qint64> &maxLate;
    Timing::Delivery &delivery;
};
QString loop(const ClickConfig &c, LoopState &state) {
    auto &[stop, cancel, count, skips, maxLate, delivery] = state;
    const auto pattern = ClickPattern::plan(c);
    ClickPattern::Generator generator(pattern, QRandomGenerator::system()->generate64());
    Timing::GapStats gaps;
    HWND target = GetForegroundWindow();
    if (!target || ours(target))
        return "Выберите целевое окно до конца отсчёта.";
    LARGE_INTEGER f;
    if (!QueryPerformanceFrequency(&f) || f.QuadPart <= 0)
        return "Счётчик Windows недоступен.";
    TimerHandle timer;
    if (!timer.value)
        return "Не удалось создать таймер Windows.";
    const qint64 begin = tick(), limit = c.duration ? begin + f.QuadPart * c.duration : 0;
    const Timing::TickGrid grid(begin, f.QuadPart, c.interval);
    const auto ticks = [&](qint64 ns) {
        return std::max<qint64>(1, qint64(double(ns) * double(f.QuadPart) / 1e9));
    };
    quint64 slot = 0;
    qint64 deadline = begin, plannedNs = pattern.intervalNs;
    DWORD targetPid = 0;
    const DWORD targetThread = GetWindowThreadProcessId(target, &targetPid);
    const DWORD down[]{MOUSEEVENTF_LEFTDOWN, MOUSEEVENTF_RIGHTDOWN, MOUSEEVENTF_MIDDLEDOWN};
    const DWORD up[]{MOUSEEVENTF_LEFTUP, MOUSEEVENTF_RIGHTUP, MOUSEEVENTF_MIDDLEUP};
    const UINT downMessage[]{WM_LBUTTONDOWN, WM_RBUTTONDOWN, WM_MBUTTONDOWN};
    const UINT upMessage[]{WM_LBUTTONUP, WM_RBUTTONUP, WM_MBUTTONUP};
    const WPARAM heldFlag[]{MK_LBUTTON, MK_RBUTTON, MK_MBUTTON};
    INPUT input[2]{};
    for (auto &i : input) {
        i.type = INPUT_MOUSE;
        i.mi.dwExtraInfo = 0x43434c4b;
    }
    input[0].mi.dwFlags = down[c.button];
    input[1].mi.dwFlags = up[c.button];
    const QString pressRejected = pattern.messages ? "Окно отклонило сообщение клика."
                                                   : "Windows отклонила нажатие.";
    const QString releaseRejected = pattern.messages
                                        ? "Окно отклонило отпускание кнопки. Отправка остановлена."
                                        : "Windows отклонила отпускание кнопки. Отправка остановлена.";
    while (!cancel.load()) {
        int waited =
            waitUntil(limit ? std::min(deadline, limit) : deadline, f.QuadPart, stop, timer.value);
        if (waited == 1)
            return {};
        if (waited == 2)
            return "Ошибка таймера Windows.";
        qint64 now = tick();
        if (limit && now >= limit)
            return {};
        DWORD pid = 0;
        const auto thread = GetWindowThreadProcessId(target, &pid);
        if (!IsWindow(target) || GetForegroundWindow() != target || pid != targetPid ||
            thread != targetThread)
            return "Остановлено: целевое окно потеряло фокус.";
        POINT point;
        if (!GetCursorPos(&point))
            return "Не удалось получить позицию курсора.";
        HWND under = WindowFromPoint(point);
        if (!under || GetAncestor(under, GA_ROOT) != target)
            return "Остановлено: курсор вне целевого окна.";
        // Reject an already-held button at start. Do not confuse our own injected
        // async button state with a new physical press during subsequent clicks.
        const int vk[]{VK_LBUTTON, VK_RBUTTON, VK_MBUTTON};
        if (count.load() == 0 && (GetAsyncKeyState(vk[c.button]) & 0x8000))
            return "Остановлено: кнопка мыши уже удерживается.";
        if (cancel.load())
            return {};
        const auto step = generator.next();
        maxLate.store(
            std::max(maxLate.load(), qint64(double(now - deadline) * 1e9 / double(f.QuadPart))));
        const auto insertionTick = tick();
        auto acceptPair = [&] {
            gaps.accept(qint64(double(insertionTick - begin) * 1e9 / double(f.QuadPart)),
                        plannedNs);
            delivery.meanNs = gaps.mean();
            delivery.maxJitterNs = gaps.gaps ? gaps.maxJitter : -1;
            return count.fetch_add(1) + 1;
        };
        // Blatant/message delivery posts straight to the window under the cursor:
        // no synthetic device input, no cursor or async button state change.
        POINT client = point;
        ScreenToClient(under, &client);
        const LPARAM where = MAKELPARAM(client.x, client.y);
        auto press = [&](bool isDown) {
            if (pattern.messages)
                return PostMessageW(under, isDown ? downMessage[c.button] : upMessage[c.button],
                                    isDown ? heldFlag[c.button] : 0, where) != 0;
            return SendInput(1, input + (isDown ? 0 : 1), sizeof(INPUT)) == 1;
        };
        bool cancelled = false;
        if (step.holdNs == 0 && !pattern.messages) {
            UINT sent = SendInput(2, input, sizeof(INPUT));
            if (sent != 2) {
                if (sent == 1 && SendInput(1, input + 1, sizeof(INPUT)) == 1)
                    acceptPair();
                return "Windows отклонила ввод. Проверьте права целевого окна.";
            }
        } else {
            if (!press(true))
                return pressRejected;
            int held = step.holdNs == 0 ? 0
                                        : waitUntil(tick() + ticks(step.holdNs), f.QuadPart, stop,
                                                    timer.value);
            // Release our button even on cancellation or loss of focus; never count a down without
            // up.
            if (!press(false)) {
                // Count a recovered completed pair too, but stop after any insertion error.
                if (press(false))
                    acceptPair();
                return releaseRejected;
            }
            cancelled = held == 1;
            if (held == 2) {
                acceptPair();
                return "Ошибка таймера удержания.";
            }
        }
        const auto accepted = acceptPair();
        if (cancelled || cancel.load() || (c.countLimit && accepted >= c.countLimit))
            return {};
        if (pattern.fixed) {
            const auto next = grid.nextSlot(slot, tick());
            skips.fetch_add(next - slot - 1);
            slot = next;
            deadline = grid.at(slot);
        } else {
            // Variable rhythm: a late press drops whole planned gaps instead of bursting.
            const auto next = Timing::advance(deadline, tick(), ticks(step.gapNs));
            skips.fetch_add(next.skipped);
            deadline = next.deadline;
        }
        plannedNs = step.gapNs;
    }
    return {};
}
} // namespace
#endif
void ClickController::runWorker() {
    m_beginNs = Timing::nowNs();
    QString reason;
#ifdef Q_OS_WIN
    LoopState state{
        static_cast<HANDLE>(m_stopEvent), m_cancel, m_clicks, m_skipped, m_maxLateNs, m_delivery};
    reason = loop(m_config, state);
#else
    reason = "Движок ввода доступен только в Windows.";
#endif
    m_endNs = Timing::nowNs();
    QMetaObject::invokeMethod(this, [this, reason] { complete(reason); }, Qt::QueuedConnection);
}
