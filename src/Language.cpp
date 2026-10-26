#include "Language.h"
#include <QCoreApplication>
#include <QQmlEngine>
#include <QSettings>
LanguageController::LanguageController(const QString &qmDirectory, QObject *parent)
    : QObject(parent), m_directory(qmDirectory) {
    QString code = QSettings().value("ui/language", DefaultLanguage).toString();
    if (!supported(code))
        code = DefaultLanguage;
    // A missing catalogue must not leave a half-translated UI: fall back to the source.
    m_language = install(code) ? code : QStringLiteral("ru");
}
LanguageController::~LanguageController() {
    if (m_installed)
        QCoreApplication::removeTranslator(&m_translator);
}
bool LanguageController::supported(const QString &code) { return code == "en" || code == "ru"; }
QString LanguageController::locale() const {
    return m_language == "ru" ? QStringLiteral("ru_RU") : QStringLiteral("en_US");
}
QVariantList LanguageController::languages() const {
    return {QVariantMap{{"code", "en"}, {"name", "English"}, {"sample", "Start clicking with F6"}},
            QVariantMap{{"code", "ru"}, {"name", "Русский"}, {"sample", "Запуск кликов по F6"}}};
}
bool LanguageController::install(const QString &code) {
    if (m_installed) {
        QCoreApplication::removeTranslator(&m_translator);
        m_installed = false;
    }
    if (code == "ru")
        return true;
    if (!m_translator.load("cclicker_" + code, m_directory))
        return false;
    m_installed = QCoreApplication::installTranslator(&m_translator);
    return m_installed;
}
bool LanguageController::setLanguage(const QString &code) {
    if (!supported(code))
        return false;
    if (code == m_language)
        return true;
    if (!install(code)) {
        install(m_language);
        return false;
    }
    m_language = code;
    QSettings().setValue("ui/language", code);
    if (m_engine)
        m_engine->retranslate();
    emit languageChanged();
    return true;
}
