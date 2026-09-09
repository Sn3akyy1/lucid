import QtQuick
import qs

Column {
    id: page

    property int tick: 0

    readonly property string positionText: {
        page.tick;
        var bits = [];
        if (Loc.place !== "")
            bits.push(Loc.place);

        bits.push(Loc.coordText);
        if (Loc.fixedAt > 0)
            bits.push("found " + page.agoText(Date.now() - Loc.fixedAt));

        return bits.join("  ·  ");
    }

    function agoText(ms) {
        var mins = Math.floor(ms / 60000);
        if (mins < 1)
            return "just now";

        if (mins < 60)
            return mins + (mins === 1 ? " minute ago" : " minutes ago");

        var hrs = Math.round(mins / 60);
        if (hrs < 24)
            return hrs + (hrs === 1 ? " hour ago" : " hours ago");

        var days = Math.round(hrs / 24);
        return days + (days === 1 ? " day ago" : " days ago");
    }

    spacing: 26

    Timer {
        interval: 1000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: page.tick++
    }

    SettingCard {
        title: "LOCATION"

        SettingRow {
            title: "Auto-detect location"
            resetKey: "gpsEnabled"
            description: "Works out roughly where you are from your network connection, and keeps checking every few hours. This is the same switch as the GPS tile in the bar's system panel."
            warning: Prefs.gpsEnabled ? "Your address is sent to ipapi.co to be turned into a position." : ""

            M3Switch {
                checked: Prefs.gpsEnabled
                onToggled: (v) => {
                    return Prefs.gpsEnabled = v;
                }
            }

        }

        SettingRow {
            title: "Place"
            enabled: !Prefs.gpsEnabled
            disabledReason: "Auto-detect is choosing the place for you. Turn it off to name one yourself."
            description: "A town or city to sit the shell in. Press Enter to look it up."

            M3TextField {
                width: 260
                enabled: !Prefs.gpsEnabled
                placeholder: "Poznań"
                text: Prefs.locationName
                onAccepted: (v) => {
                    Prefs.locationName = v;
                    Loc.lookup(v);
                }
            }

        }

        SettingRow {
            title: "Position"
            description: page.positionText
            warning: Loc.lastError
            showDivider: false

            M3Button {
                text: Loc.busy ? "Looking…" : (Prefs.gpsEnabled ? "Detect now" : "Look up")
                variant: "tonal"
                enabled: !Loc.busy
                onClicked: Loc.refresh()
            }

        }

    }

    SettingCard {
        title: "TIME ZONE"

        SettingRow {
            title: "Time zone"
            description: "The machine's own zone, shared with every application on it. Changing it here is the same as running timedatectl, so it asks for your password."
            warning: Loc.zoneError !== "" ? "Unchanged \u2014 " + Loc.zoneError : ""

            Row {
                spacing: 14

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    Text {
                        text: Loc.zone !== "" ? Loc.zone.replace(/_/g, " ") : "Reading…"
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontTitle
                        font.bold: true
                    }

                    Text {
                        text: Loc.offsetText
                        color: Theme.subtextDim
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontLabel
                    }

                }

                M3Button {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Loc.zoneBusy ? "Setting…" : "Change…"
                    variant: "tonal"
                    enabled: !Loc.zoneBusy
                    onClicked: Prefs.timeZonePickerRequested()
                }

            }

        }

        SettingRow {
            title: "Set it from my location"
            resetKey: "timeZoneAuto"
            description: {
                if (Loc.zoneFromLocation === "")
                    return "Your location has not named a zone yet. Find a place above and the machine can follow it.";

                if (Loc.locationAgrees)
                    return "The machine already keeps the time of " + Loc.zoneFromLocation.replace(/_/g, " ") + ".";

                return "Your location sits in " + Loc.zoneFromLocation.replace(/_/g, " ") + ", which the machine is not on.";
            }
            showDivider: Loc.stale

            M3Switch {
                checked: Prefs.timeZoneAuto
                onToggled: (v) => {
                    return Prefs.timeZoneAuto = v;
                }
            }

        }

        SettingRow {
            title: "Applications opened before the change"
            visible: Loc.stale
            description: {
                page.tick;
                return "A program reads the time zone once, when it starts, so anything already running is still on the old one. Lucid corrects for that itself and shows " + Loc.now().toLocaleTimeString(Qt.locale(), "HH:mm") + " either way — restart the others, or log out, to bring them across.";
            }
            showDivider: false
        }

    }

    SettingCard {
        title: "CLOCK"

        SettingRow {
            title: "24-hour time"
            resetKey: "clock24h"
            description: "Show 14:30 instead of 02:30 PM."

            M3Switch {
                checked: Prefs.clock24h
                onToggled: (v) => {
                    return Prefs.clock24h = v;
                }
            }

        }

        SettingRow {
            title: "Show date"
            resetKey: "clockShowDate"
            description: "Keep the weekday and day-of-month beside the time in the bar."
            showDivider: false

            M3Switch {
                checked: Prefs.clockShowDate
                onToggled: (v) => {
                    return Prefs.clockShowDate = v;
                }
            }

        }

    }

}
