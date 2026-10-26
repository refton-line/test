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
struct ClickConfig {
    int interval = 100, duration = 0, button = 0, hold = 1;
    int startKey = 0x75, startMods = 0, stopKey = 0x77, stopMods = 0;
    quint64 countLimit = 0;
    int launchDelay = 3;
    QList<KeyBinding> startExtra, stopExtra;
    QList<int> startChord, stopChord;
};
namespace Configuration {
QList<KeyBinding> bindings(const ClickConfig &, bool stop);
bool validKey(int key);
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
