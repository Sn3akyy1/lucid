import QtQuick
import qs

// a row for one Hyprland option: its reset hands the option back to your
// Hyprland config, and one your config sets after Lucid says so and stays shut
SettingRow {
    id: row

    property string option: ""
    // Lucid's own choices behind the option, such as lucid.border, reset with it
    property var extraKeys: []
    // for a row that depends on another setting, as enabled would otherwise be
    property bool available: true
    property string unavailableReason: ""
    readonly property bool overridden: HyprConfig.isOverridden(row.option)

    resetVisible: HyprConfig.isMine(row.option) || row.extraKeys.some((k) => {
        return HyprConfig.isMine(k);
    })
    resetAction: "hypr:" + [row.option].concat(row.extraKeys).join(",")
    resetBody: "\"" + row.resetTitle + "\" goes back to whatever your Hyprland config sets."
    enabled: row.available && !row.overridden
    disabledReason: row.overridden ? HyprConfig.overrideText(row.option) : row.unavailableReason
    warning: HyprConfig.failedText(row.option)
}
