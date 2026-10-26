#include "StartupController.h"
#include <QDir>
#include <QElapsedTimer>
#include <QFile>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSaveFile>
#include <QStandardPaths>
#include <QSvgRenderer>
#include <QtConcurrent>
#ifdef Q_OS_WIN
#define WIN32_LEAN_AND_MEAN
#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <windows.h>
#endif
StartupController::StartupController(QObject *p) : QObject(p) {}
StartupController::~StartupController() { m_task.waitForFinished(); }
void StartupController::start() {
    if (m_running || m_done)
        return;
    m_running = true;
    m_error.clear();
    m_progress = 0;
    emit changed();
    m_task = QtConcurrent::run([this] {
        auto report = [this](int percent, QString text, bool final = false, bool failure = false) {
            QMetaObject::invokeMethod(
                this,
                [this, percent, text, final, failure] {
                    m_progress = percent;
                    if (failure)
                        m_error = text;
                    else
                        m_message = text;
                    if (final || failure)
                        m_running = false;
                    m_done = final;
                    emit changed();
                },
                Qt::QueuedConnection);
        };
        const QString dir = QStandardPaths::writableLocation(QStandardPaths::AppConfigLocation);
        if (dir.isEmpty() || !QDir().mkpath(dir)) {
            report(0, "Нет доступа к папке настроек", false, true);
            return;
        }
        report(20, "Папка настроек доступна");
        const QString filePath = dir + "/workspace.json";
        if (!QFile::exists(filePath)) {
            QSaveFile out(filePath);
            const QByteArray defaults = "{\"schemaVersion\":1,\"profiles\":[]}";
            if (!out.open(QIODevice::WriteOnly) || out.write(defaults) != defaults.size() ||
                !out.commit()) {
                report(20, "Не удалось сохранить настройки", false, true);
                return;
            }
        }
        QFile in(filePath);
        if (!in.open(QIODevice::ReadOnly) || in.size() > 1024 * 1024) {
            report(20, "Не удалось прочитать настройки: файл недоступен или слишком велик", false,
                   true);
            return;
        }
        const auto bytes = in.read(1024 * 1024 + 1);
        if (bytes.size() > 1024 * 1024 || !in.atEnd()) {
            report(20, "Файл настроек слишком велик", false, true);
            return;
        }
        QJsonParseError parseError;
        const auto document = QJsonDocument::fromJson(bytes, &parseError);
        if (parseError.error != QJsonParseError::NoError || !document.isObject() ||
            document.object().value("schemaVersion").toInt() != 1 ||
            !document.object().value("profiles").isArray()) {
            report(20,
                   "Файл workspace.json повреждён или другой версии. Восстановите его из копии и "
                   "нажмите «Повторить».",
                   false, true);
            return;
        }
        report(50, "Настройки проверены");
        const QStringList icons = {"c-mark",   "keyboard", "folder", "activity",
                                   "settings", "x",        "minus",  "cursor"};
        for (const auto &icon : icons) {
            QSvgRenderer renderer(":/qt/qml/CClicker/assets/" + icon + ".svg");
            if (!renderer.isValid()) {
                report(50, "Не удалось загрузить SVG: " + icon, false, true);
                return;
            }
        }
        report(80, "Ресурсы интерфейса готовы");
#ifdef Q_OS_WIN
        LARGE_INTEGER frequency;
        if (!QueryPerformanceFrequency(&frequency) || frequency.QuadPart <= 0) {
            report(80, "Высокоточный счётчик Windows недоступен", false, true);
            return;
        }
#else
        if (!QElapsedTimer::isMonotonic()) {
            report(80, "Монотонный счётчик недоступен", false, true);
            return;
        }
#endif
        report(100, "Интерфейс готов", true);
    });
}
