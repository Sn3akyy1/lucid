import QtQuick
import qs
import qs.lucidui

// the kit switch under the name every settings page already uses
Switch {
    id: sw

    property bool enabled: true
    readonly property real contentOpacity: sw.enabled ? 1 : Theme.disabledContent

    disabled: !sw.enabled
}
