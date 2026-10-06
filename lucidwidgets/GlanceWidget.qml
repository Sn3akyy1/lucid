import QtQuick
import Quickshell.Services.Mpris
import Quickshell.Services.UPower
import qs
import qs.lucidui

// the date and the weather, and under them the one thing worth knowing right now
WidgetBody {
    id: w

    property date now: Loc.now()
    readonly property bool metric: w.opt("units") !== "imperial"
    readonly property bool onWall: w.variant === "line"
    readonly property var report: WeatherSource.report
    readonly property bool night: w.report && w.report.isDay !== undefined ? !w.report.isDay : (w.now.getHours() < 6 || w.now.getHours() >= 20)
    readonly property color fg: w.onWall ? "white" : w.ink
    readonly property color fgDim: w.onWall ? Qt.rgba(1, 1, 1, 0.82) : w.inkDim
    readonly property color fgAccent: w.onWall ? "white" : w.inkAccent
    readonly property var playing: {
        var list = Mpris.players.values;
        for (var i = 0; i < list.length; i++) {
            if (list[i].isPlaying && list[i].trackTitle)
                return list[i];

        }
        return null;
    }
    // what the second line says, first match wins
    readonly property var context: {
        w.now;
        Chrono.now;
        if (w.preview)
            return {
            "icon": "event",
            "text": "Team call · in 25 min"
        };

        var h = Chrono.headline;
        if (h && h.running && h.kind !== "stopwatch")
            return {
            "icon": h.kind === "pomodoro" ? "self_improvement" : "timer",
            "text": h.label + " · " + Chrono.countdown(h.left)
        };

        Agenda.minuteKey;
        var next = Agenda.upcoming(1);
        if (next.length && next[0].at - w.now < 12 * 3600000) {
            var mins = Math.round((next[0].at - w.now) / 60000);
            return {
                "icon": "event",
                "text": next[0].item.name + " · " + (mins < 60 ? "in " + Math.max(1, mins) + " min" : Agenda.timeText(next[0].item))
            };
        }
        if (w.playing)
            return {
            "icon": "music_note",
            "text": w.playing.trackTitle + (w.playing.trackArtist ? " · " + w.playing.trackArtist : "")
        };

        var bat = UPower.displayDevice;
        if (bat && bat.isPresent && bat.percentage <= 0.2 && bat.state === UPowerDeviceState.Discharging)
            return {
            "icon": "battery_alert",
            "text": Math.round(bat.percentage * 100) + "% battery left"
        };

        if (w.report && w.report.sunset) {
            var set = new Date(w.report.sunset);
            var rise = new Date(w.report.sunrise);
            if (w.now < rise && rise - w.now < 6 * 3600000)
                return {
                "icon": "wb_twilight",
                "text": "Sunrise " + w.clock(rise)
            };

            if (w.now < set)
                return {
                "icon": "wb_twilight",
                "text": "Sunset " + w.clock(set)
            };

        }
        if (w.report && w.report.pop >= 40)
            return {
            "icon": "umbrella",
            "text": w.report.pop + "% chance of rain today"
        };

        return null;
    }

    function clock(d) {
        return d.toLocaleTimeString(Qt.locale(), Prefs.clock24h ? "HH:mm" : "h:mm AP");
    }

    defaultTone: "secondary"
    bare: w.onWall
    Component.onCompleted: {
        if (!w.preview)
            WeatherSource.ensure();

    }

    Timer {
        interval: 20000
        repeat: true
        running: !w.preview
        onTriggered: w.now = Loc.now()
    }

    Column {
        id: stack

        x: w.onWall ? Theme.dp(6) : (parent.width - width) / 2
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.dp(6)

        Row {
            x: w.onWall ? 0 : (stack.width - width) / 2
            spacing: Theme.dp(12)

            ShadowText {
                anchors.verticalCenter: parent.verticalCenter
                shadow: w.onWall
                pixelSize: Theme.dp(28)
                weight: 560
                rounded: 60
                color: w.fg
                text: w.now.toLocaleDateString(Qt.locale(), "dddd, d MMM")
            }

            Rectangle {
                visible: w.report !== null
                anchors.verticalCenter: parent.verticalCenter
                width: 1.5
                height: Theme.dp(22)
                radius: 1
                color: Theme.alpha(w.fg, 0.4)
            }

            Row {
                visible: w.report !== null
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.dp(6)

                WeatherIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    size: Theme.dp(30)
                    kind: w.report ? WeatherSource.kindFor(w.report.code, w.night) : "clear"
                    tint: w.onWall ? "white" : w.inkAccent
                    cloudColor: w.onWall ? Qt.rgba(1, 1, 1, 0.9) : w.inkDim
                    animate: !w.preview
                }

                ShadowText {
                    anchors.verticalCenter: parent.verticalCenter
                    shadow: w.onWall
                    pixelSize: Theme.dp(28)
                    weight: 560
                    rounded: 60
                    color: w.fg
                    text: w.report ? (w.metric ? w.report.tempC : w.report.tempF) + "°" : ""
                }

            }

        }

        Row {
            visible: w.context !== null
            x: w.onWall ? 0 : (stack.width - width) / 2
            spacing: Theme.dp(8)

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.dp(26)
                height: Theme.dp(26)
                radius: Theme.dp(13)
                color: w.onWall ? Qt.rgba(1, 1, 1, 0.2) : Theme.alpha(w.inkAccent, 0.18)

                Icon {
                    anchors.centerIn: parent
                    name: w.context ? w.context.icon : ""
                    size: Theme.dp(16)
                    fill: 1
                    color: w.fgAccent
                }

            }

            ShadowText {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, w.width - Theme.dp(60))
                elide: Text.ElideRight
                shadow: w.onWall
                pixelSize: Theme.dp(16)
                weight: 480
                color: w.fgDim
                text: w.context ? w.context.text : ""
            }

        }

    }

}
