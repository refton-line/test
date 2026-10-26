#pragma once
#include <QJsonObject>
#include <QList>
#include <QString>
#include <QSet>
struct KeyBinding {
    int key = 0, mods = 0;
    QList<int> keys = {};
    bool operator==(const KeyBinding &) const = default;
};
// Click modes. Legacy profiles without a pattern block decode as Custom, which
// reproduces the 0.4.7 fixed-interval SendInput engine exactly.
enum ClickMode { LegitMode = 0, BlatantMode = 1, CustomMode = 2 };
enum ClickDelivery { EmulatedDelivery = 0, MessageDelivery = 1 };
struct ClickConfig {
    int interval = 100, duration = 0, button = 0, hold = 1;
    int mode = LegitMode;
    int cpsMin = 9, cpsMax = 13; // Legit
    int jitter = 0;              // Custom, ±% of interval and hold
    int delivery = EmulatedDelivery;
    bool drift = false;          // Custom, slow rhythm wave
    int startKey = 0x75, startMods = 0, stopKey = 0x77, stopMods = 0;
    quint64 countLimit = 0;
    int launchDelay = 3;
    QList<KeyBinding> startExtra, stopExtra;
    QList<int> startChord, stopChord;
};
namespace Configuration {
QList<KeyBinding> bindings(const ClickConfig &, bool stop);
bool validKey(int key);
int minInterval(int mode);
bool validChordKey(int key);
QList<int> chordKeys(const KeyBinding &binding);
QString chordName(const KeyBinding &binding);
bool chordMatches(const KeyBinding &binding, const QSet<int> &held);
QString bindingError(int start, int sm, int stop, int tm);
QString validate(const ClickConfig &config);
QJsonObject encode(const ClickConfig &config);
bool decode(const QJsonObject &object, ClickConfig &out, QString &error);
QString keyName(int key);
QString shortcutName(int key, int mods);
} // namespace Configuration
