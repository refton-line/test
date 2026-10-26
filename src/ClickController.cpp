#include "ClickController.h"
#include "Timing.h"
#include "ClickPattern.h"
#include <QClipboard>
#include <QDateTime>
#include <QGuiApplication>
#include <QSettings>
#include <QWindow>
#include <QtConcurrent>
#ifdef Q_OS_WIN
#define WIN32_LEAN_AND_MEAN
#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <windows.h>
#endif
ClickController::ClickController(QObject *parent) : QObject(parent) {
    qGuiApp->installEventFilter(this);
    QSettings s;
    QString error;
    ClickConfig loaded;
    if (s.contains("click/config")) {
        if (Configuration::decode(s.value("click/config").toJsonObject(), loaded, error))
            m_config = loaded;
        else
            m_error = "Сохранённые параметры отклонены: " + error;
    } else {
        // Pre-JSON settings were the fixed-interval engine; keep it for those users.
        if (s.contains("click/interval"))
            m_config.mode = CustomMode;
        m_config.interval = qBound(5, s.value("click/interval", 100).toInt(), 10000);
        m_config.duration = qBound(0, s.value("click/duration", 0).toInt(), 3600);
        m_config.button = qBound(0, s.value("click/button", 0).toInt(), 1);
        int f = s.value("click/key", 6).toInt();
        if (QList<int>{6, 7, 9, 10}.contains(f))
            m_config.startKey = 0x6f + f;
    }
#ifdef Q_OS_WIN
    m_stopEvent = CreateEventW(nullptr, TRUE, FALSE, nullptr);
    m_available = m_stopEvent && registerBindings(m_config);
    if (!m_available)
        m_error = "Не удалось подключить ввод клавиатуры.";
    qGuiApp->installNativeEventFilter(this);
#endif
    m_countdownTimer.setInterval(1000);
    connect(&m_countdownTimer, &QTimer::timeout, this, [this] {
        --m_countdown;
        if (m_countdown == 0) {
            m_countdownTimer.stop();
            launch();
        }
        emit changed();
    });
    m_poll.setInterval(100);
    connect(&m_poll, &QTimer::timeout, this, &ClickController::sample);
    record("Приложение открыто");
}
ClickController::~ClickController() {
    qGuiApp->removeEventFilter(this);
    stop();
    m_task.waitForFinished();
#ifdef Q_OS_WIN
    qGuiApp->removeNativeEventFilter(this);
    unregisterBindings();
    delete m_inputWindow;
    if (m_stopEvent)
        CloseHandle(m_stopEvent);
#endif
}
void ClickController::persist() {
    QSettings().setValue("click/config", QVariant::fromValue(Configuration::encode(m_config)));
}
bool ClickController::applyConfig(const ClickConfig &c) {
    if (m_active) {
        m_error = "Остановите клики перед изменением параметров.";
        emit changed();
        return false;
    }
    auto error = Configuration::validate(c);
    if (!error.isEmpty()) {
        m_error = error;
        emit changed();
        return false;
    }
    const bool changedKeys = c.startKey != startKey() || c.stopKey != stopKey() ||
                             c.startMods != startMods() || c.stopMods != stopMods() ||
                             c.startChord != m_config.startChord || c.stopChord != m_config.stopChord ||
                             c.startExtra != m_config.startExtra ||
                             c.stopExtra != m_config.stopExtra;
#ifdef Q_OS_WIN
    if (changedKeys || m_editing || !m_available) {
        unregisterBindings();
        if (!m_stopEvent || !registerBindings(c)) {
            unregisterBindings();
            m_available = !m_editing && m_stopEvent && registerBindings(m_config);
            m_error = "Не удалось подключить ввод клавиатуры. Настройки не изменены.";
            emit changed();
            return false;
        }
        m_available = true;
    }
#else
    Q_UNUSED(changedKeys)
#endif
    m_config = c;
    m_draftError.clear();
    m_editing = false;
    m_pressedKeys.clear();
    emit keyboardStateChanged();
    m_error.clear();
    persist();
    emit changed();
    return true;
}
void ClickController::setLaunchDelaySec(int v) {
    auto c = m_config;
    c.launchDelay = v;
    applyConfig(c);
}
void ClickController::setIntervalMs(int v) {
    auto c = m_config;
    c.interval = v;
    if (v >= Configuration::minInterval(c.mode) && v <= 10000)
        c.hold = qMin(c.hold, v - 1);
    applyConfig(c);
}
void ClickController::setDurationSec(int v) {
    auto c = m_config;
    c.duration = v;
    applyConfig(c);
}
void ClickController::setMouseButton(int v) {
    auto c = m_config;
    c.button = v;
    applyConfig(c);
}
void ClickController::setHoldMs(int v) {
    auto c = m_config;
    c.hold = v;
    applyConfig(c);
}
void ClickController::setCountLimit(qulonglong v) {
    auto c = m_config;
    c.countLimit = v;
    applyConfig(c);
}
void ClickController::setClickMode(int v) {
    auto c = m_config;
    c.mode = v;
    // Leaving Blatant may strand a sub-5 ms interval; snap it to the new floor.
    if (v >= LegitMode && v <= CustomMode && c.interval < Configuration::minInterval(v)) {
        c.interval = Configuration::minInterval(v);
        c.hold = qMin(c.hold, c.interval - 1);
    }
    applyConfig(c);
}
void ClickController::setCpsMin(int v) {
    setCpsRange(v, qMax(v, m_config.cpsMax));
}
void ClickController::setCpsMax(int v) {
    setCpsRange(qMin(v, m_config.cpsMin), v);
}
bool ClickController::setCpsRange(int min, int max) {
    auto c = m_config;
    c.cpsMin = min;
    c.cpsMax = max;
    return applyConfig(c);
}
void ClickController::setJitterPct(int v) {
    auto c = m_config;
    c.jitter = v;
    applyConfig(c);
}
void ClickController::setDelivery(int v) {
    auto c = m_config;
    c.delivery = v;
    applyConfig(c);
}
void ClickController::setDrift(bool v) {
    auto c = m_config;
    c.drift = v;
    applyConfig(c);
}
double ClickController::expectedCps() const { return ClickPattern::expectedCps(m_config); }
QString ClickController::modeSummary() const { return ClickPattern::describe(m_config); }
QVariantList ClickController::rhythmPreview() const {
    QVariantList list;
    for (double gap : ClickPattern::preview(m_config, 48))
        list.append(gap);
    return list;
}
double ClickController::elapsedSec() const {
    const auto b = m_beginNs.load();
    if (!b)
        return 0;
    const auto e = m_endNs.load();
    return qMax<qint64>(0, (e ? e : Timing::nowNs()) - b) / 1e9;
}
double ClickController::averageCps() const {
    auto seconds = elapsedSec();
    return seconds >= 0.25 ? double(clicks()) / seconds : -1;
}
void ClickController::sample() {
    const qint64 b = m_beginNs.load();
    if (!b) {
        emit changed();
        return;
    }
    const qint64 now = m_endNs.load() ? m_endNs.load() : Timing::nowNs();
    const quint64 count = clicks();
    if (m_samples.isEmpty())
        m_samples.enqueue({b, 0});
    m_samples.enqueue({now, count});
    while (m_samples.size() > 2 && m_samples.at(1).first <= now - 1000000000LL)
        m_samples.dequeue();
    m_recentCps = Timing::rate(count - m_samples.head().second, now - m_samples.head().first);
    emit changed();
}
void ClickController::record(const QString &t) {
    m_entries.prepend(QDateTime::currentDateTime().toString("HH:mm:ss") + "   " + t);
    while (m_entries.size() > 100)
        m_entries.removeLast();
}
void ClickController::setReady(bool v) {
    m_ready = v;
    emit changed();
}
void ClickController::toggle() {
    if (m_active)
        stop();
    else
        start();
}
void ClickController::start() {
    if (m_active || !available())
        return;
    m_error.clear();
    m_clicks = 0;
    m_skipped = 0;
    m_maxLateNs = 0;
    m_beginNs = 0;
    m_endNs = 0;
    m_recentCps = -1;
    m_samples.clear();
    m_active = true;
    m_countdown = m_config.launchDelay;
    m_delivery.meanNs = -1;
    m_delivery.maxJitterNs = -1;
    m_state = "Подготовка";
    m_cancel = false;
#ifdef Q_OS_WIN
    ResetEvent(m_stopEvent);
#endif
    record("Подготовка к запуску");
    m_countdownTimer.start();
    emit changed();
}
void ClickController::launch() {
    if (!m_active)
        return;
    m_state = "Работает";
    m_poll.start();
    record("Запуск: " + ClickPattern::describe(m_config));
    m_task = QtConcurrent::run([this] { runWorker(); });
}
void ClickController::stop() {
    if (!m_active)
        return;
    m_countdownTimer.stop();
    m_cancel = true;
#ifdef Q_OS_WIN
    if (m_stopEvent)
        SetEvent(m_stopEvent);
#endif
    if (m_countdown > 0) {
        m_countdown = 0;
        complete("Запуск отменён");
        return;
    }
    m_state = "Остановка";
    emit changed();
}
void ClickController::complete(const QString &reason) {
    m_poll.stop();
    sample();
    m_active = false;
    m_state = "Готов";
    if (!reason.isEmpty()) {
        if (reason != "Запуск отменён")
            m_error = reason;
        record(reason);
    }
    record("Отправлено пар: " + QString::number(clicks()) +
           " · Пропущено слотов: " + QString::number(skipped()));
    emit changed();
}
void ClickController::clearLog() {
    m_entries.clear();
    emit changed();
}
void ClickController::copyLog() {
    QGuiApplication::clipboard()->setText(m_entries.join('\n'));
}
