#pragma once
#include "Configuration.h"
#include <QObject>
#include <QUrl>
#include <QVariantList>
class ClickController;
class ConfigStore final : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantList profiles READ profiles NOTIFY profilesChanged)
    Q_PROPERTY(QString searchQuery READ searchQuery WRITE setSearchQuery NOTIFY changed)
    Q_PROPERTY(QString notice READ notice NOTIFY changed)
    Q_PROPERTY(bool failed READ failed NOTIFY changed)
    Q_PROPERTY(QString activeName READ activeName NOTIFY changed)
    Q_PROPERTY(bool modified READ modified NOTIFY changed)
  public:
    explicit ConfigStore(ClickController *engine, QObject *parent = nullptr);
    QVariantList profiles() const { return m_profiles; }
    QString searchQuery() const { return m_query; }
    void setSearchQuery(const QString &query) {
        if (m_query == query)
            return;
        m_query = query.left(64);
        refresh();
    }
    Q_INVOKABLE bool duplicate(const QString &id);
    QString notice() const { return m_notice; }
    bool failed() const { return m_failed; }
    QString activeName() const { return m_activeName; }
    bool modified() const;
    QString directory() const { return m_directory; }
    Q_INVOKABLE void refresh();
    Q_INVOKABLE bool saveNew(const QString &name);
    Q_INVOKABLE bool apply(const QString &id);
    Q_INVOKABLE bool remove(const QString &id);
    Q_INVOKABLE bool rename(const QString &id, const QString &name);
    Q_INVOKABLE bool importFile(const QUrl &file);
    Q_INVOKABLE bool exportFile(const QString &id, const QUrl &file);
    Q_INVOKABLE void openFolder();
  signals:
    void changed();
    void profilesChanged();

  private:
    QString safePath(const QString &id) const;
    bool read(const QString &path, QJsonObject &doc, ClickConfig &cfg, QString &error) const;
    bool write(const QString &path, const QJsonObject &doc);
    bool finish(bool ok, const QString &text);
    ClickController *m_engine;
    QString m_query;
    QString m_directory, m_notice, m_activeId, m_activeName = QStringLiteral("Без конфигурации");
    QJsonObject m_applied;
    QVariantList m_profiles;
    bool m_failed = false;
};
