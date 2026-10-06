import QtQuick
import qs
import "../lucidwidgets"

// the day outside, read off the same source the bar and the widgets use
Item {
    id: wx

    readonly property var report: WeatherSource.report
    readonly property bool night: {
        var h = Lockscreen.now.getHours();
        return h < 6 || h >= 20;
    }

    implicitWidth: row.implicitWidth
    implicitHeight: Theme.dp(60)
    visible: wx.report !== null

    Row {
        id: row

        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.dp(14)

        WeatherIcon {
            anchors.verticalCenter: parent.verticalCenter
            kind: wx.report ? WeatherSource.kindFor(wx.report.code, wx.night) : "cloud"
            size: Theme.dp(52)
            tint: Theme.accent
            cloudColor: Theme.text
        }

        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.dp(14)

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: wx.report ? wx.report.tempC + "°" : "—"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontHeadlineMd
                font.variableAxes: Theme.axes(Theme.fontHeadlineMd, 520, 0)
                font.weight: Font.Medium
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 1
                height: Theme.dp(26)
                color: Lockscreen.hairline
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.dp(2)

                Text {
                    text: wx.report ? WeatherSource.descFor(wx.report.code) : ""
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontBodyMd
                    font.variableAxes: Theme.axes(Theme.fontBodyMd, 420, 0)
                }

                Text {
                    text: {
                        if (!wx.report || !wx.report.days || wx.report.days.length === 0)
                            return Loc.place;

                        return "H " + wx.report.days[0].maxC + "°  L " + wx.report.days[0].minC + "°  ·  feels " + wx.report.feelsC + "°";
                    }
                    color: Theme.subtextDim
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontLabelMd
                    font.variableAxes: Theme.axes(Theme.fontLabelMd, 420, 0)
                }

            }

        }

    }

}
