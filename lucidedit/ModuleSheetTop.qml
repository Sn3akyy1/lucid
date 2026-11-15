import QtQuick
import qs
import qs.lucidprefs

// the top of a module's sheet: open it to see what the looks below do, and join it
// to the module either side of it
SettingCard {
    id: modTop

    property string moduleId: ""

    readonly property var mod: Prefs.barModuleById[modTop.moduleId] || null
    readonly property bool inBar: !!modTop.mod && Prefs[modTop.mod.key] === true
    readonly property string zone: modTop.inBar ? Prefs.barZoneOf(modTop.moduleId) : ""
    readonly property var row: modTop.zone !== "" ? Prefs.barKeysOf(modTop.zone) : []
    readonly property int at: modTop.row.indexOf(modTop.moduleId)
    readonly property string leftKey: modTop.at > 0 ? modTop.row[modTop.at - 1] : ""
    readonly property string rightKey: modTop.at >= 0 && modTop.at + 1 < modTop.row.length ? modTop.row[modTop.at + 1] : ""

    function nameOf(id) {
        const m = Prefs.barModuleById[id];
        return m ? m.name : id;
    }

    SettingRow {
        title: I18n.tr("Try it")
        description: modTop.moduleId === "start" ? I18n.tr("Opens the launcher, as a click on it does.") : I18n.tr("Opens it the way a click on the bar does, so you can see the looks you pick below.")
        enabled: modTop.inBar
        disabledReason: I18n.tr("It is not in the bar. Switch it on below to try it.")
        showDivider: false

        M3Button {
            text: I18n.tr("Open")
            variant: "tonal"
            enabled: modTop.inBar
            onClicked: Edit.moduleOpenRequested(modTop.moduleId, Monitors.barEverywhere ? Edit.sheetScreen : "")
        }

    }

    SettingRow {
        visible: modTop.leftKey !== ""
        title: I18n.tr("Join to %1", modTop.nameOf(modTop.leftKey))
        description: Prefs.barFull ? I18n.tr("The full bar already joins every module on one strip.") : I18n.tr("The two share one island, the way the link between them on the bar joins them.")
        enabled: !Prefs.barFull
        showDivider: false

        M3Switch {
            enabled: !Prefs.barFull
            checked: modTop.leftKey !== "" && Prefs.barJoined(modTop.leftKey, modTop.moduleId)
            onToggled: (v) => {
                return Prefs.setBarJoined(modTop.leftKey, modTop.moduleId, v);
            }
        }

    }

    SettingRow {
        visible: modTop.rightKey !== ""
        title: I18n.tr("Join to %1", modTop.nameOf(modTop.rightKey))
        description: Prefs.barFull ? I18n.tr("The full bar already joins every module on one strip.") : I18n.tr("The two share one island, the way the link between them on the bar joins them.")
        enabled: !Prefs.barFull
        showDivider: false

        M3Switch {
            enabled: !Prefs.barFull
            checked: modTop.rightKey !== "" && Prefs.barJoined(modTop.moduleId, modTop.rightKey)
            onToggled: (v) => {
                return Prefs.setBarJoined(modTop.moduleId, modTop.rightKey, v);
            }
        }

    }

}
