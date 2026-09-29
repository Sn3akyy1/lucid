import QtQuick
import Quickshell
import Quickshell.Io
import qs

// the dominant colours matugen finds in the wallpaper, each shown as the
// accent it would give with the current style and contrast (and the colour it
// came from, as a dot). wallpaper-colours.sh reads them; picking one is the
// page's to apply
Column {
    id: colours

    property string image: ""
    // the index in use for this image
    property int current: 0
    property bool active: true
    property var candidates: []
    property bool loading: false
    readonly property var ordinals: ["1st", "2nd", "3rd", "4th"]

    signal chosen(int index)

    function refresh() {
        // only Matugen starts from these, so there is nothing to read for the rest
        if (!colours.active)
            return ;

        if (colours.image === "") {
            colours.candidates = [];
            return ;
        }
        colours.loading = true;
        reader.running = false;
        // the style and contrast ride along: prefs.json lags a moment behind
        reader.command = ["env", "LUCID_MATUGEN_SCHEME=" + Prefs.matugenScheme, "LUCID_MATUGEN_CONTRAST=" + Prefs.matugenContrast, Quickshell.env("HOME") + "/.config/lucid/wallpaper-colours.sh", colours.image, Prefs.colorMode];
        reader.running = true;
    }

    spacing: 10
    onImageChanged: requery.restart()
    onActiveChanged: requery.restart()
    Component.onCompleted: requery.restart()

    Connections {
        function onMatugenSchemeChanged() {
            requery.restart();
        }

        function onMatugenContrastChanged() {
            requery.restart();
        }

        function onColorModeChanged() {
            requery.restart();
        }

        target: Prefs
    }

    Timer {
        id: requery

        interval: 450
        onTriggered: colours.refresh()
    }

    Text {
        width: colours.width
        // only while there is nothing to show: a re-read just dims the swatches
        visible: colours.active && colours.candidates.length === 0
        text: colours.loading ? "Reading the wallpaper..." : "No wallpaper to read colours from."
        color: Theme.subtext
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontBody
    }

    Row {
        spacing: 12
        visible: colours.candidates.length > 0
        opacity: !colours.active ? 0.38 : (colours.loading ? 0.5 : 1)

        Repeater {
            model: colours.candidates

            delegate: Column {
                id: cand

                required property var modelData
                readonly property bool selected: colours.current === cand.modelData.index

                spacing: 6

                Rectangle {
                    width: 72
                    height: 52
                    radius: Theme.radiusMd
                    color: cand.modelData.primary
                    border.width: cand.selected ? 3 : (candArea.containsMouse ? 2 : 0)
                    border.color: Theme.text

                    // the wallpaper colour the accent was built from
                    Rectangle {
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: 6
                        width: 14
                        height: 14
                        radius: 7
                        color: cand.modelData.source
                        border.width: 1
                        border.color: Theme.alpha("#000000", 0.25)
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: cand.selected
                        text: "✓"
                        color: Theme.toneOf(Qt.color(cand.modelData.primary)) > 60 ? "#000000" : "#ffffff"
                        font.pixelSize: 20
                        font.bold: true
                    }

                    MouseArea {
                        id: candArea

                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: colours.active
                        cursorShape: Qt.PointingHandCursor
                        onClicked: colours.chosen(cand.modelData.index)
                    }

                }

                Text {
                    width: 72
                    horizontalAlignment: Text.AlignHCenter
                    text: colours.ordinals[cand.modelData.index] || ""
                    color: cand.selected ? Theme.text : Theme.subtext
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontLabel
                    elide: Text.ElideRight
                }

            }

        }

    }

    Process {
        id: reader

        stdout: StdioCollector {
            onStreamFinished: {
                colours.loading = false;
                try {
                    colours.candidates = JSON.parse(text);
                } catch (e) {
                    colours.candidates = [];
                }
            }
        }

    }

}
