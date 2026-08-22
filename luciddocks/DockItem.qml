import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets
import qs

Item {
    id: dockItem

    property bool hovered: hoverHandler.hovered
    property bool pressed: tapHandler.pressed
    property string iconName: ""
    // when set, draws this as an inline Material-style path instead of
    // looking up iconName in the system icon theme - used for the launcher
    // toggle button, which isn't a real installed app
    property string svgPath: ""
    // optional second contour, stroked rather than filled, drawn over
    // svgPath - the launcher mark needs an outer ring that a single filled
    // path can't express
    property string svgRingPath: ""
    // where the svgPath fill's highlight sits, in the same 24x24 space the
    // path itself is authored in, and how far it reaches. Different marks put
    // their bright point in different places (a centred disc vs a light source
    // up at the top), so this stays on the caller.
    property real iconGlowX: 12
    property real iconGlowY: 11.4
    property real iconGlowRadius: 9.6
    // marks built from many overlapping subpaths (a branching network, say)
    // need nonzero winding - the default even-odd rule punches a hole
    // wherever two of them cross. Left off by default because the Material
    // paths rely on even-odd to cut their interior holes.
    property bool iconWindingFill: false
    // when set, this is drawn in place of both the icon image and the inline
    // svgPath shape. svgPath is a single filled contour in one colour, which
    // can't express a mark built from several strokes and fills in more than
    // one colour - this hands that case the whole 34x34 icon area instead.
    property Component iconContent: null
    property string command: ""
    property string appId: ""
    property bool isToggle: false
    property string displayName: ""
    property var clients: []
    property int activeWorkspaceId: -1
    property bool tooltipReady: false
    property bool active: appId !== "" && ToplevelManager.toplevels.values.some((t) => {
        return t.appId.toLowerCase() === appId.toLowerCase();
    })
    // was `active !== hovered` - meant a running app sat permanently lifted
    // at rest and hovering it *cancelled* the lift, which read as the hover
    // effect being backwards. Now hover always raises the icon; active apps
    // get a bigger lift/scale + a slightly springier motion, see below
    property bool highlighted: hovered
    property bool urgent: appId !== "" && Hyprland.toplevels.values.some((t) => {
        return t.wayland && t.wayland.appId && t.wayland.appId.toLowerCase() === appId.toLowerCase() && t.urgent;
    })
    // one pass over clients instead of three separate scans - matchingClient/
    // windowCount/distinctWorkspaceCount used to each filter the full list
    property var clientStats: {
        var stats = {
            "matching": null,
            "count": 0,
            "workspaces": ({})
        };
        if (appId === "")
            return stats;

        for (var i = 0; i < clients.length; i++) {
            var c = clients[i];
            if (!c.class || c.class.toLowerCase() !== appId.toLowerCase())
                continue;
            if (!stats.matching)
                stats.matching = c;
            stats.count++;
            if (c.workspace)
                stats.workspaces[c.workspace.id] = true;
        }
        return stats;
    }
    property var matchingClient: clientStats.matching
    property int windowCount: clientStats.count
    property int distinctWorkspaceCount: Object.keys(clientStats.workspaces).length
    // 0..~0.08 falloff applied by the parent row when a *neighboring* slot is
    // hovered, for the magnify-ripple effect - the hovered item itself still
    // uses `highlighted` above, this is only ever set on the items beside it
    property real magnifyBoost: 0

    signal requestToggle()
    signal requestStackPopup()
    signal requestContextMenu()
    // fired only when this actually spawns the app (not a toggle, and not a
    // focus-existing-window/stack-popup redirect) - the launcher's usage
    // counts key off this so "frequently used" reflects dock launches too
    signal launched()

    width: 46
    height: 46
    // active apps get a bigger lift/scale on hover than a regular icon -
    // reads as "click to jump back to me" rather than the generic pop
    scale: pressed ? 0.96 : (highlighted ? (dockItem.active ? 1.12 : 1.08) : 1 + dockItem.magnifyBoost)
    y: pressed ? -2 : (highlighted ? (dockItem.active ? -9 : -6) : 0)
    onHoveredChanged: {
        if (hovered) {
            tooltipDelay.restart();
        } else {
            tooltipDelay.stop();
            dockItem.tooltipReady = false;
        }
    }

    Timer {
        id: tooltipDelay

        interval: 400
        onTriggered: dockItem.tooltipReady = true
    }

    Rectangle {
        id: stackLayer

        width: 46
        height: 46
        x: 4
        y: 4
        radius: 9
        color: Theme.withBlur(Theme.bgTile)
        z: -1
        visible: dockItem.windowCount >= 2
    }

    Rectangle {
        id: countBadge

        visible: dockItem.windowCount >= 3
        width: 16
        height: 16
        radius: 8
        color: Theme.accent
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: -4
        anchors.topMargin: -4
        z: 20

        Text {
            anchors.centerIn: parent
            text: dockItem.windowCount
            color: Theme.onAccent
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fs(9)
            font.bold: true
        }

    }

    Item {
        id: iconWrap

        anchors.fill: parent

        Rectangle {
            id: iconBox

            anchors.fill: parent
            radius: 9
            color: Theme.withBlur(Theme.bgTile)
        }

        IconImage {
            id: iconImg

            anchors.fill: parent
            anchors.margins: 6
            visible: dockItem.svgPath === "" && dockItem.iconContent === null
            source: dockItem.svgPath === "" && dockItem.iconName !== "" ? Quickshell.iconPath(dockItem.iconName, "") : ""
        }

        Shape {
            id: iconShape

            anchors.fill: parent
            anchors.margins: 6
            visible: dockItem.svgPath !== ""
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                // Theme.accent tracks the Matugen-derived wallpaper color
                // (Theme.text would just be flat grey/white regardless of theme)
                fillColor: Theme.accent
                strokeWidth: 0
                fillRule: dockItem.iconWindingFill ? ShapePath.WindingFill : ShapePath.OddEvenFill

                // the launcher marks are all light-on-water figures, which a
                // flat accent fill collapses into featureless silhouettes, so
                // the fill is graded instead. Stops derive from Theme.accent
                // (via Qt.lighter/darker rather than Theme's own private
                // _lighten) so this still tracks the Matugen palette like
                // every other icon does.
                fillGradient: RadialGradient {
                    centerX: dockItem.iconGlowX
                    centerY: dockItem.iconGlowY
                    centerRadius: dockItem.iconGlowRadius
                    focalX: dockItem.iconGlowX
                    focalY: dockItem.iconGlowY

                    GradientStop {
                        position: 0
                        color: Qt.lighter(Theme.accent, 1.55)
                    }

                    GradientStop {
                        position: 0.55
                        color: Theme.accent
                    }

                    GradientStop {
                        position: 1
                        color: Qt.darker(Theme.accent, 1.45)
                    }

                }

                PathSvg {
                    path: dockItem.svgPath
                }

            }

            // the disturbed water surface ringing the window. strokeWidth
            // collapses to 0 when unset so every other svgPath consumer
            // renders exactly as before.
            ShapePath {
                fillColor: "transparent"
                strokeColor: Theme.alpha(Theme.accent, 0.5)
                strokeWidth: dockItem.svgRingPath === "" ? 0 : 1
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin

                PathSvg {
                    path: dockItem.svgRingPath
                }

            }

            transform: Scale {
                xScale: iconShape.width / 24
                yScale: iconShape.height / 24
            }

        }

        Loader {
            id: iconLoader

            anchors.fill: parent
            anchors.margins: 6
            active: dockItem.iconContent !== null
            sourceComponent: dockItem.iconContent
        }

    }

    // slight ambient glow, scoped to the inline-svg icon only (currently just
    // the launcher toggle) - regular app icons stay flat per the rest of the dock
    MultiEffect {
        source: iconShape
        anchors.fill: iconShape
        visible: dockItem.svgPath !== ""
        z: -1
        shadowEnabled: true
        shadowColor: Theme.accent
        shadowOpacity: 0.4
        shadowBlur: 0.7
        shadowHorizontalOffset: 0
        shadowVerticalOffset: 0
    }

    MultiEffect {
        source: iconWrap
        anchors.fill: iconWrap
        brightness: dockItem.highlighted ? (dockItem.active ? 0.16 : 0.12) : 0
        saturation: dockItem.highlighted ? (dockItem.active ? 0.16 : 0.1) : 0

        Behavior on brightness {
            NumberAnimation {
                duration: Theme.ms(220)
            }

        }

        Behavior on saturation {
            NumberAnimation {
                duration: Theme.ms(220)
            }

        }

    }

    Rectangle {
        id: indicatorDot

        width: dockItem.hovered ? 18 : 14
        height: 3
        radius: 1.5
        color: dockItem.urgent ? Theme.error : Theme.accent
        anchors.horizontalCenter: parent.horizontalCenter
        y: dockItem.height + 3 + (dockItem.hovered ? 3 : 0)
        // reflects "is this app actually running", full stop - it used to
        // piggyback on `highlighted` (active !== hovered) which meant hovering
        // a pinned-but-not-running icon lit the dot up too, falsely signaling
        // it was open
        opacity: dockItem.active && Prefs.dockShowIndicators ? 1 : 0

        SequentialAnimation on opacity {
            running: dockItem.urgent
            loops: Animation.Infinite

            NumberAnimation {
                to: 0.35
                duration: Theme.ms(500)
                easing.type: Easing.InOutSine
            }

            NumberAnimation {
                to: 1
                duration: Theme.ms(500)
                easing.type: Easing.InOutSine
            }

        }

        Behavior on opacity {
            enabled: !dockItem.urgent
            NumberAnimation {
                duration: Theme.ms(220)
            }

        }

        Behavior on y {
            NumberAnimation {
                duration: Theme.ms(220)
            }

        }

        Behavior on width {
            NumberAnimation {
                duration: Theme.ms(220)
                easing.type: Easing.OutCubic
            }

        }

    }

    Rectangle {
        id: tooltip

        visible: opacity > 0
        opacity: (Prefs.dockShowTooltips && dockItem.tooltipReady && dockItem.displayName !== "") ? 1 : 0
        radius: 6
        color: Theme.bg
        border.color: Theme.alpha(Theme.text, 0.25)
        border.width: 1
        width: tooltipText.implicitWidth + 16
        height: tooltipText.implicitHeight + 8
        anchors.horizontalCenter: parent.horizontalCenter
        y: -height - 10 - (dockItem.highlighted ? 6 : 0)
        z: 50

        Text {
            id: tooltipText

            anchors.centerIn: parent
            text: dockItem.displayName
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fs(12)
        }

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.ms(150)
            }

        }

    }

    HoverHandler {
        id: hoverHandler
    }

    TapHandler {
        id: tapHandler

        onTapped: {
            if (dockItem.isToggle) {
                dockItem.requestToggle();
                return ;
            }
            if (dockItem.active && dockItem.matchingClient) {
                var winWs = dockItem.matchingClient.workspace.id;
                if (dockItem.distinctWorkspaceCount >= 2 || winWs !== dockItem.activeWorkspaceId) {
                    dockItem.requestStackPopup();
                    return ;
                }
            }
            if (dockItem.command !== "") {
                Quickshell.execDetached(["sh", "-c", dockItem.command]);
                dockItem.launched();
            }

        }
    }

    TapHandler {
        id: contextTapHandler

        acceptedButtons: Qt.RightButton
        enabled: !dockItem.isToggle && dockItem.appId !== ""
        onTapped: dockItem.requestContextMenu()
    }

    Behavior on scale {
        NumberAnimation {
            duration: Theme.ms(220)
            // a bit of spring on the way in for active apps, plain ease
            // everywhere else - reinforces that hovering a running icon is a
            // different action (jump to it) than hovering one that isn't
            easing.type: dockItem.active && dockItem.highlighted ? Easing.OutBack : Easing.OutCubic
            easing.overshoot: 0.6
        }

    }

    Behavior on y {
        NumberAnimation {
            duration: Theme.ms(220)
            easing.type: dockItem.active && dockItem.highlighted ? Easing.OutBack : Easing.OutCubic
            easing.overshoot: 0.6
        }

    }

}
