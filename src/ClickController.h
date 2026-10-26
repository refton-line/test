#pragma once
#include "Configuration.h"
#include "Timing.h"
#include <QAbstractNativeEventFilter>
#include <QFuture>
#include <QObject>
#include <QQueue>
#include <QSet>
#include <QHash>
class QWindow;
#include <QTimer>
#include <QVariantList>
#include <atomic>
class ClickController final : public QObject, public QAbstractNativeEventFilter {
    Q_OBJECT
    Q_PROPERTY(QVariantList draftKeys READ draftKeys NOTIFY keyboardStateChanged)
    Q_PROPERTY(QString draftError READ draftError NOTIFY keyboardStateChanged)
    Q_PROPERTY(QVariantList pressedKeys READ pressedKeys NOTIFY keyboardStateChanged)
    Q_PROPERTY(bool numLockOn READ numLockOn NOTIFY keyboardStateChanged)
    Q_PROPERTY(bool captureCombination READ captureCombination WRITE setCaptureCombination NOTIFY keyboardStateChanged)
    Q_PROPERTY(QVariantList startBindings READ startBindings NOTIFY changed)
    Q_PROPERTY(QVariantList stopBindings READ stopBindings NOTIFY changed)
    Q_PROPERTY(int launchDelaySec READ launchDelaySec WRITE setLaunchDelaySec NOTIFY changed)
    Q_PROPERTY(double meanGapMs READ meanGapMs NOTIFY changed)
    Q_PROPERTY(double maxJitterMs READ maxJitterMs NOTIFY changed)
    Q_PROPERTY(int intervalMs READ intervalMs WRITE setIntervalMs NOTIFY changed)
    Q_PROPERTY(int durationSec READ durationSec WRITE setDurationSec NOTIFY changed)
    Q_PROPERTY(int mouseButton READ mouseButton WRITE setMouseButton NOTIFY changed)
    Q_PROPERTY(int holdMs READ holdMs WRITE setHoldMs NOTIFY changed)
    Q_PROPERTY(qulonglong countLimit READ countLimit WRITE setCountLimit NOTIFY changed)
    Q_PROPERTY(int startKey READ startKey NOTIFY changed)
    Q_PROPERTY(int stopKey READ stopKey NOTIFY changed)
    Q_PROPERTY(int startMods READ startMods NOTIFY changed)
    Q_PROPERTY(int stopMods READ stopMods NOTIFY changed)
    Q_PROPERTY(QString startLabel READ startLabel NOTIFY changed)
    Q_PROPERTY(QString stopLabel READ stopLabel NOTIFY changed)
    Q_PROPERTY(bool active READ active NOTIFY changed)
    Q_PROPERTY(bool available READ available NOTIFY changed)
    Q_PROPERTY(int countdown READ countdown NOTIFY changed)
    Q_PROPERTY(qulonglong clicks READ clicks NOTIFY changed)
    Q_PROPERTY(qulonglong skipped READ skipped NOTIFY changed)
    Q_PROPERTY(double elapsedSec READ elapsedSec NOTIFY changed)
    Q_PROPERTY(double measuredCps READ measuredCps NOTIFY changed)
    Q_PROPERTY(double averageCps READ averageCps NOTIFY changed)
    Q_PROPERTY(double maxLateMs READ maxLateMs NOTIFY changed)
    Q_PROPERTY(QString state READ state NOTIFY changed)
    Q_PROPERTY(QString error READ error NOTIFY changed)
    Q_PROPERTY(QStringList entries READ entries NOTIFY changed)
  public:
    explicit ClickController(QObject *parent = nullptr);
    ~ClickController() override;
    QVariantList pressedKeys() const;
    QVariantList draftKeys() const;
    QString draftError() const { return m_draftError; }
    Q_INVOKABLE void beginBindingDraft(const QVariantList &keys, bool combination);
    Q_INVOKABLE void selectDraftKey(int key);
    Q_INVOKABLE bool applyChordSlot(bool stop, int index, const QVariantList &keys);
    Q_INVOKABLE QString keyName(int key) const { return Configuration::keyName(key); }
    void processWindowsKey(int vk, unsigned scan, bool e0, bool e1, bool down,
                           bool numLock, quintptr device = 0);
    Q_INVOKABLE void dismissError();
    void processPhysicalKey(int key, bool down, bool numLock, quintptr device = 0);
    bool numLockOn() const { return m_numLockOn; }
    bool captureCombination() const { return m_captureCombination; }
    void setCaptureCombination(bool value);
    QVariantList bindingList(bool stop) const;
    QVariantList startBindings() const { return bindingList(false); }
    QVariantList stopBindings() const { return bindingList(true); }
    int launchDelaySec() const { return m_config.launchDelay; }
    void setLaunchDelaySec(int);
    double meanGapMs() const {
        return m_delivery.meanNs.load() < 0 ? -1 : m_delivery.meanNs.load() / 1e6;
    }
    double maxJitterMs() const {
        return m_delivery.maxJitterNs.load() < 0 ? -1 : m_delivery.maxJitterNs.load() / 1e6;
    }
    Q_INVOKABLE bool applyBindingSlot(bool stop, int index, int key, int mods);
    Q_INVOKABLE bool removeBinding(bool stop, int index);
    int intervalMs() const { return m_config.interval; }
    int durationSec() const { return m_config.duration; }
    int mouseButton() const { return m_config.button; }
    int holdMs() const { return m_config.hold; }
    qulonglong countLimit() const { return m_config.countLimit; }
    int startKey() const { return m_config.startKey; }
    int stopKey() const { return m_config.stopKey; }
    int startMods() const { return m_config.startMods; }
    int stopMods() const { return m_config.stopMods; }
    QString startLabel() const { return Configuration::chordName({startKey(), startMods(), m_config.startChord}); }
    QString stopLabel() const { return Configuration::chordName({stopKey(), stopMods(), m_config.stopChord}); }
    bool active() const { return m_active; }
    bool available() const { return m_available && m_ready && !m_editing; }
    int countdown() const { return m_countdown; }
    qulonglong clicks() const { return m_clicks.load(); }
    qulonglong skipped() const { return m_skipped.load(); }
    double elapsedSec() const;
    double averageCps() const;
    double measuredCps() const { return m_recentCps; }
    double maxLateMs() const { return m_maxLateNs.load() / 1e6; }
    QString state() const { return m_state; }
    QString error() const { return m_error; }
    QStringList entries() const { return m_entries; }
    void setIntervalMs(int);
    void setDurationSec(int);
    void setMouseButton(int);
    void setHoldMs(int);
    void setCountLimit(qulonglong);
    ClickConfig config() const { return m_config; }
    bool applyConfig(const ClickConfig &);
    Q_INVOKABLE bool applyBindings(int key, int mods, int stop, int stopMods);
    Q_INVOKABLE bool resetBindings();
    Q_INVOKABLE void setBindingEditor(bool enabled);
    Q_INVOKABLE bool keyAllowed(int key) const { return Configuration::validChordKey(key); }
    Q_INVOKABLE void setReady(bool);
    Q_INVOKABLE void toggle();
    Q_INVOKABLE void start();
    Q_INVOKABLE void stop();
    Q_INVOKABLE void clearLog();
    Q_INVOKABLE void copyLog();
    bool eventFilter(QObject *object, QEvent *event) override;
    bool nativeEventFilter(const QByteArray &, void *, qintptr *) override;
  signals:
    void changed();
    void keyboardStateChanged();
    void shortcutActivated(bool stopAction);

  private:
    QSet<int> m_pressedKeys;
    QList<int> m_draftKeys;
    QString m_draftError;
    QHash<quintptr, QSet<int>> m_deviceKeys;
    QSet<int> m_latchedBindings, m_blockedKeys;
    QWindow *m_inputWindow = nullptr;
    bool m_inputRegistered = false;
    void evaluateBindings(bool trigger);
    void clearKeyboardState();
    bool m_numLockOn = true, m_captureCombination = false;
    void launch();
    void complete(const QString &);
    void record(const QString &);
    void persist();
    void runWorker();
    void sample();
    bool registerBindings(const ClickConfig &);
    void unregisterBindings();
    QTimer m_countdownTimer, m_poll;
    QFuture<void> m_task;
    ClickConfig m_config;
    std::atomic_bool m_cancel{false};
    std::atomic<qulonglong> m_clicks{0}, m_skipped{0};
    std::atomic<qint64> m_beginNs{0}, m_endNs{0}, m_maxLateNs{0};
    Timing::Delivery m_delivery;
    QQueue<QPair<qint64, quint64>> m_samples;
    double m_recentCps = -1;
    int m_countdown = 0;
    bool m_active = false, m_available = false, m_ready = false, m_editing = false;
    QString m_state = QStringLiteral("Готов"), m_error;
    QStringList m_entries;
    void *m_stopEvent = nullptr;
};
