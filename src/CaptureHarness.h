#pragma once
#include <QString>
class QQuickWindow;
class ClickController;
class ConfigStore;
void runCaptureHarness(QQuickWindow *window, const QString &output, ClickController *engine,
                       ConfigStore *configs);
