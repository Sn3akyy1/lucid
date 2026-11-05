import "../lucidwidgets" as LW
import QtQuick
import qs
import qs.lucidui

// the sky where you are, from the forecast the whole shell shares. its looks:
// the condition large with the day's high and low (card); that over the next
// hours (hours) or the next days (days); one line (line). a tap opens the
// clock's today page, which has the rest
Item {
    id: wc

    // card, hours, days or line
    property string look: "card"
    // while the panel is open: the forecast is fetched if stale, the sky moves
    property bool live: false

    signal opened()

    readonly property var wx: WeatherSource.report
    readonly property var today: wc.wx && wc.wx.days && wc.wx.days.length > 0 ? wc.wx.days[0] : null
    readonly property bool night: wc.wx ? !wc.wx.isDay : false
    readonly property bool line: wc.look === "line"
    readonly property bool strip: wc.look === "hours" || wc.look === "days"
    // what the strip under it holds: every third hour, or the days after today,
    // as many as fit
    readonly property int slots: Math.max(3, Math.min(6, Math.floor(wc.width / Theme.dp(52))))
    readonly property var cells: {
        if (!wc.wx || !wc.strip)
            return [];

        const out = [];
        if (wc.look === "hours") {
            const h = wc.wx.hours || [];
            for (let i = 0; i < h.length && out.length < wc.slots; i += 3)
                out.push({
                "top": i === 0 ? "Now" : new Date(h[i].time).toLocaleTimeString(Qt.locale(), Prefs.clock24h ? "HH" : "h AP").replace(":00", ""),
                "kind": WeatherSource.kindFor(h[i].code, !h[i].day),
                "temp": Units.deg(h[i].tempC, h[i].tempF),
                "low": ""
            });
        } else {
            const d = wc.wx.days || [];
            for (let i = 1; i < d.length && out.length < wc.slots; i++)
                out.push({
                "top": new Date(d[i].date + "T12:00").toLocaleDateString(Qt.locale(), "ddd"),
                "kind": WeatherSource.kindFor(d[i].code, false),
                "temp": Units.deg(d[i].maxC, d[i].maxF),
                "low": Units.deg(d[i].minC, d[i].minF)
            });
        }
        return out;
    }

    onLiveChanged: {
        if (wc.live)
            WeatherSource.ensure();

    }
    Component.onCompleted: {
        if (wc.live)
            WeatherSource.ensure();

    }
    implicitHeight: wc.line ? Theme.dp(40) : (wc.strip ? Theme.dp(152) : Theme.dp(76))

    StateLayer {
        anchors.fill: parent
        anchors.margins: -Theme.dp(6)
        radius: Theme.shapeLg
        onClicked: wc.opened()
    }

    // now: the sky, how warm, what it is like, and the day's high and low
    Item {
        id: now

        // alone, it keeps to the middle of a taller block
        y: wc.strip ? 0 : Math.max(0, Math.round((wc.height - height) / 2))
        width: parent.width
        height: wc.line ? parent.height : Theme.dp(76)

        // the reading and what it is like stacked as one, or in a line; placed by
        // hand, as a look can change under it
        readonly property real pairTop: Math.round((now.height - temp.height - desc.height + Theme.dp(2)) / 2)

        LW.WeatherIcon {
            id: sky

            y: Math.round((now.height - height) / 2)
            size: wc.line ? Theme.dp(26) : Theme.dp(52)
            animate: wc.live && !wc.line
            kind: wc.wx ? WeatherSource.kindFor(wc.wx.code, wc.night) : "cloud"
            tint: Theme.primary
            cloudColor: Theme.subtext
        }

        LText {
            id: temp

            x: sky.width + (wc.line ? Theme.dp(10) : Theme.dp(12))
            y: wc.line ? Math.round((now.height - height) / 2) : now.pairTop
            role: wc.line ? "titleMedium" : "headlineMedium"
            weight: 600
            rounded: 100
            tabular: true
            text: wc.wx ? Units.deg(wc.wx.tempC, wc.wx.tempF) : "—"
        }

        LText {
            id: desc

            x: wc.line ? temp.x + temp.width + Theme.dp(10) : temp.x
            y: wc.line ? Math.round((now.height - height) / 2) : now.pairTop + temp.height - Theme.dp(2)
            width: Math.max(0, (range.visible ? range.x : now.width) - x - Theme.dp(8))
            role: wc.line ? "bodyMedium" : "bodySmall"
            color: Theme.subtext
            elide: Text.ElideRight
            text: wc.wx ? WeatherSource.descFor(wc.wx.code) + (!wc.line && WeatherSource.place !== "" ? " · " + WeatherSource.place : "") : (WeatherSource.lastError !== "" ? "No forecast yet" : "Looking outside")
        }

        // the day's high over its low
        Column {
            id: range

            visible: !!wc.today
            x: now.width - width
            y: Math.round((now.height - height) / 2)
            spacing: wc.line ? 0 : Theme.dp(2)

            Row {
                anchors.right: parent.right
                spacing: Theme.dp(2)
                visible: !wc.line

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "arrow_upward"
                    size: Theme.dp(14)
                    color: Theme.subtext
                }

                LText {
                    anchors.verticalCenter: parent.verticalCenter
                    role: "labelLarge"
                    tabular: true
                    text: wc.today ? Units.deg(wc.today.maxC, wc.today.maxF) : ""
                }

            }

            Row {
                anchors.right: parent.right
                spacing: Theme.dp(2)
                visible: !wc.line

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "arrow_downward"
                    size: Theme.dp(14)
                    color: Theme.subtext
                }

                LText {
                    anchors.verticalCenter: parent.verticalCenter
                    role: "labelLarge"
                    color: Theme.subtext
                    tabular: true
                    text: wc.today ? Units.deg(wc.today.minC, wc.today.minF) : ""
                }

            }

            // on one line, high and low side by side
            LText {
                visible: wc.line
                anchors.right: parent.right
                role: "labelLarge"
                color: Theme.subtext
                tabular: true
                text: wc.today ? Units.deg(wc.today.maxC, wc.today.maxF) + " / " + Units.deg(wc.today.minC, wc.today.minF) : ""
            }

        }

    }

    // the next hours, or the next days
    Row {
        visible: wc.strip
        anchors.bottom: parent.bottom
        width: parent.width

        Repeater {
            model: wc.cells

            Column {
                required property var modelData
                required property int index

                width: parent.width / Math.max(1, wc.cells.length)
                spacing: Theme.dp(4)

                LText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    role: "labelSmall"
                    color: index === 0 && wc.look === "hours" ? Theme.primary : Theme.subtext
                    text: modelData.top
                }

                LW.WeatherIcon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    size: Theme.dp(24)
                    animate: false
                    kind: modelData.kind
                    tint: Theme.primary
                    cloudColor: Theme.subtext
                }

                LText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    role: "labelLarge"
                    rounded: 100
                    tabular: true
                    text: modelData.temp
                }

                LText {
                    visible: modelData.low !== ""
                    anchors.horizontalCenter: parent.horizontalCenter
                    role: "labelMedium"
                    color: Theme.subtext
                    tabular: true
                    text: modelData.low
                }

            }

        }

    }

}
