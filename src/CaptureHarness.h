#pragma once
#include <QString>
class QQuickWindow;
class ClickController;
class ConfigStore;
class LanguageController;
void runCaptureHarness(QQuickWindow *window, const QString &output, ClickController *engine,
                       ConfigStore *configs, LanguageController *language);
