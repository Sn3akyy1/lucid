import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import qs
import qs.lucidui
import qs.luciddocks

// the dock's pinned apps on shapes of their own; a tap opens one, or brings it forward
WidgetBody {
    id: w

    property var pinned: []
    readonly property int first: Math.max(0, parseInt(w.opt("start")) || 0)
    readonly property var apps: w.pinned.slice(w.first, w.first + 4)
    readonly property var shapes: ["cookie9", "clover4", "sunny", "pentagon"]
    // auto checkers the containers with a second step of the same hues; a picked colour puts every shape in it
    readonly property bool mixed: (w.opt("tone") || "auto") === "auto"
    readonly property real step: Theme.isLight ? 80 : 42
    readonly property var mixFills: [Theme.primaryContainer, Theme.atTone(Theme.tertiary, w.step), Theme.atTone(Theme.primary, w.step), Theme.tertiaryContainer]
    readonly property var mixInks: [Theme.fgPrimaryContainer, Theme.atTone(Theme.tertiary, Theme.isLight ? 20 : 94), Theme.atTone(Theme.primary, Theme.isLight ? 20 : 94), Theme.fgTertiaryContainer]

    function iconFor(app) {
        return app && app.iconName ? IconTheme.resolve(app.iconName) : "";
    }

    function letterOf(app) {
        return app && app.name ? String(app.name).charAt(0).toUpperCase() : "?";
    }

    function launch(app) {
        if (!w.live || !app)
            return ;

        const names = [app.appId, app.iconName, app.name].filter((n) => {
            return !!n;
        }).map((n) => {
            return String(n).toLowerCase();
        });
        const open = ToplevelManager.toplevels.values.find((t) => {
            return names.indexOf(String(t.appId).toLowerCase()) !== -1;
        });
        if (open)
            open.activate();
        else
            Quickshell.execDetached(["sh", "-c", app.command]);
    }

    bare: w.variant === "shapes"
    pill: w.variant === "row"

    FileView {
        path: Qt.resolvedUrl("../luciddocks/pinned.json")
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                w.pinned = (JSON.parse(text()).pinnedApps || []).filter((a) => {
                    return a && a.command;
                });
            } catch (e) {
                w.pinned = [];
            }
        }
    }

    component AppGlyph: Item {
        id: glyph

        property string source: ""
        property string letter: ""
        property color ink: "white"
        property real size: 44

        width: glyph.size
        height: glyph.size

        IconImage {
            anchors.fill: parent
            source: glyph.source
            visible: glyph.source !== ""
            asynchronous: true
        }

        LText {
            anchors.centerIn: parent
            visible: glyph.source === ""
            size: Math.round(glyph.size * 0.56)
            weight: 640
            rounded: 100
            color: glyph.ink
            text: glyph.letter
        }

    }

    LText {
        visible: w.apps.length === 0
        anchors.centerIn: parent
        width: parent.width - Theme.dp(32)
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        role: "bodyMedium"
        color: w.bare ? "white" : w.inkDim
        text: I18n.tr("Pin apps to the dock and they show up here.")
    }

    // shapes: straight on the wallpaper, one shape per app
    Grid {
        id: shapeGrid

        readonly property int cell: Math.floor((w.width - shapeGrid.spacing) / 2)

        visible: w.variant === "shapes"
        anchors.centerIn: parent
        columns: 2
        spacing: Theme.dp(10)

        Repeater {
            model: w.variant === "shapes" ? w.apps : []

            Item {
                id: blob

                required property var modelData
                required property int index

                width: shapeGrid.cell
                height: shapeGrid.cell

                MaterialShape {
                    anchors.fill: parent
                    shape: w.shapes[blob.index % w.shapes.length]
                    color: w.mixed ? w.mixFills[blob.index % w.mixFills.length] : Theme.alpha(w.fill, 1)
                    rotation: blobTap.containsMouse ? 24 : 0
                    scale: blobTap.pressed ? 0.9 : (blobTap.containsMouse ? 1.04 : 1)

                    Behavior on rotation {
                        NumberAnimation {
                            duration: Theme.durSlowSpatial
                            easing.type: Easing.Bezier
                            easing.bezierCurve: Theme.curveSlowSpatial
                        }

                    }

                    Behavior on scale {
                        NumberAnimation {
                            duration: Theme.durFastSpatial
                            easing.type: Easing.Bezier
                            easing.bezierCurve: Theme.curveFastSpatial
                        }

                    }

                }

                AppGlyph {
                    anchors.centerIn: parent
                    size: Math.round(blob.width * 0.42)
                    source: w.iconFor(blob.modelData)
                    letter: w.letterOf(blob.modelData)
                    ink: w.mixed ? w.mixInks[blob.index % w.mixInks.length] : w.ink
                    scale: blobTap.pressed ? 0.9 : 1

                    Behavior on scale {
                        NumberAnimation {
                            duration: Theme.durFastSpatial
                            easing.type: Easing.Bezier
                            easing.bezierCurve: Theme.curveFastSpatial
                        }

                    }

                }

                WidgetTap {
                    id: blobTap

                    anchors.fill: parent
                    widget: w
                    onTapped: w.launch(blob.modelData)
                }

            }

        }

    }

    // row: a pill of apps, each circle blooming into a cookie under the pointer
    Row {
        visible: w.variant === "row"
        anchors.centerIn: parent
        spacing: Theme.dp(10)

        Repeater {
            model: w.variant === "row" ? w.apps : []

            Item {
                id: chip

                required property var modelData

                width: Theme.dp(60)
                height: Theme.dp(60)

                MaterialShape {
                    anchors.fill: parent
                    shape: "circle"
                    to: "cookie9"
                    morph: chipTap.containsMouse ? 1 : 0
                    color: Theme.alpha(w.inkAccent, chipTap.containsMouse ? 0.24 : 0.12)
                    rotation: chipTap.containsMouse ? 20 : 0
                    scale: chipTap.pressed ? 0.9 : 1

                    Behavior on morph {
                        NumberAnimation {
                            duration: Theme.durDefaultSpatial
                            easing.type: Easing.Bezier
                            easing.bezierCurve: Theme.curveStandard
                        }

                    }

                    Behavior on rotation {
                        NumberAnimation {
                            duration: Theme.durSlowSpatial
                            easing.type: Easing.Bezier
                            easing.bezierCurve: Theme.curveSlowSpatial
                        }

                    }

                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.durShort
                        }

                    }

                    Behavior on scale {
                        NumberAnimation {
                            duration: Theme.durFastSpatial
                            easing.type: Easing.Bezier
                            easing.bezierCurve: Theme.curveFastSpatial
                        }

                    }

                }

                AppGlyph {
                    anchors.centerIn: parent
                    size: Theme.dp(34)
                    source: w.iconFor(chip.modelData)
                    letter: w.letterOf(chip.modelData)
                    ink: w.ink
                }

                WidgetTap {
                    id: chipTap

                    anchors.fill: parent
                    widget: w
                    onTapped: w.launch(chip.modelData)
                }

            }

        }

    }

    // folder: the apps with their names, like a folder opened on a phone
    Grid {
        id: folder

        visible: w.variant === "folder"
        anchors.fill: parent
        anchors.margins: Theme.dp(12)
        columns: 2
        spacing: Theme.dp(4)

        Repeater {
            model: w.variant === "folder" ? w.apps : []

            Item {
                id: entry

                required property var modelData
                required property int index

                width: Math.floor((folder.width - folder.spacing) / 2)
                height: Math.floor((folder.height - folder.spacing) / 2)

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.rad(20)
                    color: w.ink
                    opacity: entryTap.pressed ? 0.12 : (entryTap.containsMouse ? 0.06 : 0)

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.durShort
                        }

                    }

                }

                Column {
                    anchors.centerIn: parent
                    spacing: Theme.dp(8)

                    Item {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: Theme.dp(62)
                        height: Theme.dp(62)

                        MaterialShape {
                            anchors.fill: parent
                            shape: w.shapes[entry.index % w.shapes.length]
                            color: Theme.alpha(w.inkAccent, 0.14)
                            rotation: entryTap.containsMouse ? 24 : 0

                            Behavior on rotation {
                                NumberAnimation {
                                    duration: Theme.durSlowSpatial
                                    easing.type: Easing.Bezier
                                    easing.bezierCurve: Theme.curveSlowSpatial
                                }

                            }

                        }

                        AppGlyph {
                            anchors.centerIn: parent
                            size: Theme.dp(36)
                            source: w.iconFor(entry.modelData)
                            letter: w.letterOf(entry.modelData)
                            ink: w.ink
                        }

                    }

                    LText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: entry.width - Theme.dp(12)
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        role: "labelLarge"
                        color: w.ink
                        text: entry.modelData.name || ""
                    }

                }

                WidgetTap {
                    id: entryTap

                    anchors.fill: parent
                    widget: w
                    onTapped: w.launch(entry.modelData)
                }

            }

        }

    }

}
