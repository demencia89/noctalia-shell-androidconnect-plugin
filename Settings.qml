import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
  id: root

  property var pluginApi: null

  property var cfg: pluginApi?.pluginSettings || ({})
  property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

  property string iconColor: cfg.iconColor ?? defaults.iconColor ?? "none"
  property string panelPosition: cfg.panelPosition ?? defaults.panelPosition ?? "top_right"
  property bool panelFloating: cfg.panelFloating ?? defaults.panelFloating ?? false

  spacing: Style.marginL

  NColorChoice {
    Layout.fillWidth: true
    label: pluginApi?.tr("settings.iconColor.label") || "Widget Icon Color"
    description: pluginApi?.tr("settings.iconColor.desc") || "Color of the AndroidConnect bar widget icon"
    currentKey: root.iconColor
    onSelected: key => root.iconColor = key
  }

  NComboBox {
    Layout.fillWidth: true
    label: "Panel Position"
    description: "Choose which corner or side-center the AndroidConnect drawer opens from."
    model: [
      {
        "key": "top_left",
        "name": I18n.tr("positions.top-left")
      },
      {
        "key": "top_center",
        "name": I18n.tr("positions.top-center")
      },
      {
        "key": "top_right",
        "name": I18n.tr("positions.top-right")
      },
      {
        "key": "center_left",
        "name": I18n.tr("positions.center-left")
      },
      {
        "key": "center",
        "name": I18n.tr("positions.center")
      },
      {
        "key": "center_right",
        "name": I18n.tr("positions.center-right")
      },
      {
        "key": "bottom_left",
        "name": I18n.tr("positions.bottom-left")
      },
      {
        "key": "bottom_center",
        "name": I18n.tr("positions.bottom-center")
      },
      {
        "key": "bottom_right",
        "name": I18n.tr("positions.bottom-right")
      }
    ]
    currentKey: root.panelPosition
    onSelected: key => root.panelPosition = key
    defaultValue: defaults.panelPosition ?? "top_right"
  }

  NToggle {
    Layout.fillWidth: true
    label: "Floating Panel"
    description: "Detach the drawer from the bar and screen edge. It still opens from the chosen position, but with floating margins instead of being attached."
    checked: root.panelFloating
    onToggled: checked => root.panelFloating = checked
    defaultValue: defaults.panelFloating ?? false
  }

  function saveSettings() {
    if (!pluginApi) {
      Logger.e("KDEConnect", "Cannot save settings: pluginApi is null");
      return;
    }

    pluginApi.pluginSettings.iconColor = root.iconColor;
    pluginApi.pluginSettings.panelPosition = root.panelPosition;
    pluginApi.pluginSettings.panelFloating = root.panelFloating;
    pluginApi.saveSettings();
  }
}
