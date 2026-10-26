#pragma once
#include <QObject>
#include <QTranslator>
#include <QVariantList>
class QQmlEngine;
// Interface language. Russian is the source language of all strings; English is
// a compiled Qt translation and the default for a fresh install.
class LanguageController final : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString language READ language NOTIFY languageChanged)
    Q_PROPERTY(QString locale READ locale NOTIFY languageChanged)
    Q_PROPERTY(QVariantList languages READ languages CONSTANT)
  public:
    static constexpr auto DefaultLanguage = "en";
    explicit LanguageController(const QString &qmDirectory = QStringLiteral(":/i18n"),
                                QObject *parent = nullptr);
    ~LanguageController() override;
    QString language() const { return m_language; }
    QString locale() const;
    QVariantList languages() const;
    static bool supported(const QString &code);
    Q_INVOKABLE bool setLanguage(const QString &code);
    void setEngine(QQmlEngine *engine) { m_engine = engine; }
  signals:
    void languageChanged();

  private:
    bool install(const QString &code);
    QString m_directory, m_language;
    QTranslator m_translator;
    bool m_installed = false;
    QQmlEngine *m_engine = nullptr;
};
