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
                text: wx.report ? Units.deg(wx.report.tempC, wx.report.tempF) : "—"
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

                        return I18n.tr("H %1  L %2  ·  feels %3", Units.deg(wx.report.days[0].maxC, wx.report.days[0].maxF), Units.deg(wx.report.days[0].minC, wx.report.days[0].minF), Units.deg(wx.report.feelsC, wx.report.feelsF));
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
