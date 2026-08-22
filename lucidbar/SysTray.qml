import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Hyprland._FocusGrab
import Quickshell.Io
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs

Item {
    id: root

    property var hostWindow: null
    property bool expanded: false
    // mirrors shell's own radius below - see the same note in Workspaces.qml
    // In pop-up mode the radius rides the panel's animated height, so the
    // surface leaves the pill wearing the pill's own round end and settles
    // into the panel's flatter corner as it grows - and shell.qml's blur
    // region, which reads this, keeps the same shape the whole way. The
    // collapsed 60 belongs to the morphing pill: left in the expression it
    // snapped the detached panel into a blob on the first frame of the exit.
    readonly property int cornerRadius: root.popupMode ? Math.min(20, Math.round(shell.height / 2)) : (root.expanded ? 20 : Prefs.barPillRadius)
    // blueman's own indicator is redundant with BluetoothWidget's own pill,
    // so it's filtered out here rather than shown twice on the bar
    readonly property var hiddenKeywords: ["blueman"]
    readonly property var trayItems: {
        const raw = SystemTray.items ? SystemTray.items.values : [];
        return raw.filter((i) => {
            const key = ((i.id || "") + " " + (i.title || "")).toLowerCase();
            return !root.hiddenKeywords.some((kw) => {
                return key.indexOf(kw) !== -1;
            });
        });
    }
    readonly property int trayCount: root.trayItems.length
    readonly property int horizontalPadding: 10
    // logical px shrink as the compositor scale goes up (a 1920 panel at 1.2
    // is only 1600 wide to lay out in), so every fixed panel dimension is
    // clamped against the screen rather than trusted as an absolute
    readonly property real screenW: root.hostWindow ? root.hostWindow.screen.width : 1600
    readonly property real screenH: root.hostWindow ? root.hostWindow.screen.height : 900
    // resting size, held by this widget's slot in the bar's Row so that
    // expanding never reflows its neighbours - see shell.qml
    readonly property int compactWidth: root.trayCount === 0 ? 0 : (compactRow.implicitWidth + root.horizontalPadding * 2)
    readonly property int compactHeight: root.trayCount === 0 ? 0 : Prefs.barHeight
    readonly property bool panelOpen: root.expanded
    readonly property int maxPanelHeight: Math.min(320, Math.max(160, root.screenH - 40))
    readonly property int expandedWidth: Math.min(260, root.screenW - 34)

    // some SNI items (pixmap-backed, not in an icon theme) report their icon
    // as "<name>?path=<dir>" instead of a URL Image can load directly - peel
    // that apart into a real file:// path, or every such icon just fails to
    // load and silently falls back to the generic glyph
    function resolveIconSource(raw) {
        if (!raw)
            return "";

        const qIdx = raw.indexOf("?path=");
        if (qIdx === -1)
            return raw;

        const name = raw.substring(0, qIdx);
        const dir = raw.substring(qIdx + 6);
        const fileName = name.substring(name.lastIndexOf("/") + 1);
        return "file://" + dir + "/" + fileName;
    }

    // nothing to show or manage - collapse away entirely instead of sitting
    // on the bar as an empty pill
    onTrayCountChanged: {
        if (root.trayCount === 0)
            root.expanded = false;

    }
    // ---------------- settings-driven behaviour ----------------
    // A hidden module collapses to zero size as well as going invisible, so
    // the bar's input mask and blur region collapse with it instead of
    // leaving a dead rectangle behind at its last position.
    readonly property bool shown: Prefs.showTray
    // Pop-up mode: the pill stops morphing into the panel and stays put in
    // the bar, with the panel becoming a detached surface below it. Inline
    // mode additionally drops the pill's own background, because in that mode
    // the bar behind it draws one continuous surface instead.
    readonly property bool popupMode: Prefs.barPopupMode
    // Reported up to shell.qml, which draws inline mode's hover for the whole
    // bar at once rather than letting each module light its own patch.
    readonly property bool compactHovered: compactFace.hovered
    // True in either mode that takes this module's own pill away and draws
    // a shared surface behind it instead: inline, which is one bar for the
    // whole shell, or connected rows, which is one per group.
    // the size this module takes when open - the original implicit sizes,
    // kept whole so morph mode behaves exactly as it did before
    readonly property int openWidth: root.trayCount === 0 ? 0 : (expanded ? root.expandedWidth : root.compactWidth)
    readonly property int openHeight: root.trayCount === 0 ? 0 : (expanded ? Math.min(root.maxPanelHeight, expandedColumn.implicitHeight + 28) : root.compactHeight)
    // a notch squares off only the edge that actually meets the screen; a
    // detached pop-up panel touches nothing and stays rounded all round
    readonly property int topRadius: Prefs.barNotch && !root.popupMode ? 0 : root.cornerRadius
    readonly property int pillTopRadius: Prefs.barNotch ? 0 : Prefs.barPillRadius
    // handed to shell.qml so the detached panel gets its own entry in the
    // window's input mask and blur region - the root item's own bounds stop
    // at the pill in pop-up mode
    // True only while the detached panel is actually on screen. shell.qml's
    // mask and blur regions key off this rather than popupItem alone: a Region
    // takes its item's geometry regardless of visibility, so the closed
    // panel's rectangle went on blurring the desktop under every pill - and,
    // less visibly, went on swallowing clicks there too.
    // Which edge of the pill the detached panel lines up with, set from
    // shell.qml - the only thing that knows whether this module sits in the
    // left group, the centre, or the right group. Left unset the panel grew
    // rightward from the pill's left edge, so every right-hand module's panel
    // ran straight off the side of the screen.
    property string popupAlign: "left"
    readonly property real popupX: {
        if (!root.popupMode)
            return 0;

        // popupWidth, not openWidth: openWidth folds back to the pill's width
        // the instant the panel closes, which slid the panel sideways mid-exit
        // - a 75px lurch on a centred module like the clock.
        if (root.popupAlign === "right")
            return root.compactWidth - root.popupWidth;

        if (root.popupAlign === "center")
            return (root.compactWidth - root.popupWidth) / 2;

        return 0;
    }
    // Intent: true from the moment the panel is asked to open. The enter
    // and exit animations read this to pick their duration and curve.
    readonly property bool popupExpanding: root.popupMode && root.expanded
    // Painted: true for as long as the panel actually has extent on
    // screen, which includes the whole of the exit animation. shell.qml's
    // input mask and blur region key off this, and it is read off the
    // drop rather than the size, because a closed pop-up still carries
    // the pill's footprint. Keyed off the intent flag instead, the blur
    // rectangle switched off on the first frame of the exit and left the
    // panel see-through the whole way out.
    // `shown` first: a switched-off module is not painted at all, but a blur
    // region is pure geometry and does not care - left ungated, a module that
    // was off still published its panel's rectangle the moment anything asked
    // it to open, and the compositor frosted a pane of desktop with nothing
    // drawn on top of it.
    readonly property bool popupOpen: root.shown && root.popupMode && shell.y > 0.5
    // The radii this module's own bounds are actually drawn with, so
    // shell.qml's mask and blur regions can mirror them exactly. A Region
    // supports per-corner radii just like a Rectangle; setting only `radius`
    // left the blurred backdrop a different shape from the surface on top of
    // it, which shows up as a hard edge peeking out around the corners.
    readonly property int barRadius: root.popupMode ? Prefs.barPillRadius : root.cornerRadius
    readonly property int barTopRadius: root.popupMode ? root.pillTopRadius : root.topRadius
    // The panel's own size, with no collapsed branch. openWidth/openHeight
    // fold back to the pill the instant the panel closes, so anything derived
    // from them raced that change - the panel snapped to a 35px stub and only
    // then faded, which is why closing read as vanishing rather than
    // retreating. These never collapse, so the panel holds its shape all the
    // way out and only opacity, scale and position animate.
    readonly property int popupWidth: root.expandedWidth
    readonly property int popupHeight: Math.min(root.maxPanelHeight, expandedColumn.implicitHeight + 28)
    readonly property Item popupItem: shell

    implicitWidth: !root.shown ? 0 : (root.popupMode ? root.compactWidth : root.openWidth)
    implicitHeight: !root.shown ? 0 : (root.popupMode ? root.compactHeight : root.openHeight)
    // Switching a module off used to take it out of the bar between frames.
    // It now scales down and fades while its width collapses, so the row
    // closes the gap behind something that is visibly leaving rather than
    // something that was simply deleted. `visible` follows the fade rather
    // than the setting - read straight from `shown` the module would be gone
    // before the animation had a single frame to run in, which is exactly what
    // made it disappear instantly.
    opacity: root.shown ? 1 : 0
    scale: root.shown ? 1 : 0.82
    transformOrigin: Item.Center
    visible: root.opacity > 0.01

    Behavior on opacity {
        NumberAnimation {
            duration: Theme.ms(180)
            easing.type: Easing.OutCubic
        }

    }

    Behavior on scale {
        NumberAnimation {
            duration: Theme.ms(260)
            // a little overshoot on the way in, so it reads as popping into
            // place rather than inflating
            easing.type: root.shown ? Easing.OutBack : Easing.InCubic
        }

    }
    // the pop-up has to be allowed out of the root's bounds; in morph mode
    // the root is the panel and still clips as before
    clip: !root.popupMode
    z: root.popupOpen ? 100 : 1

    HyprlandFocusGrab {
        active: root.expanded
        windows: root.hostWindow ? [root.hostWindow] : []
        onCleared: root.expanded = false
    }




    // In pop-up mode this is the pill that stays in the bar, and the compact
    // face reparents into it. In morph mode it is unused - the rectangle
    // below is both pill and panel, exactly as before.
    Rectangle {
        id: pillRect

        visible: root.popupMode
        width: root.compactWidth
        height: root.compactHeight
        // Fades out as shell.qml's united bar fades in, over the same
        // duration. Switched outright, the islands lost their backs in the
        // same frame the shared surface appeared behind them.
        color: Theme.bg

        Behavior on color {
            // not before the bar has laid out: inline mode reads false for the
            // frame before the config file lands, so at startup this would
            // always cross-fade in from an island that was never really there
            enabled: root.hostWindow ? root.hostWindow.laidOut : false

            ColorAnimation {
                duration: Theme.ms(260)
                easing.type: Easing.OutCubic
            }

        }

        clip: true
        radius: Prefs.barPillRadius
        topLeftRadius: root.pillTopRadius
        topRightRadius: root.pillTopRadius
    }


    Rectangle {
        id: shell

        // morph mode: fills the root, which is the thing that morphs.
        // pop-up mode: a detached panel hanging below the pill.
        // Pop-up mode expands the panel out of the pill the same way morph
        // mode expands the pill itself - small to big. It starts on the
        // pill's exact footprint and grows down and out to the panel's
        // size; the only difference from morph is that the pill stays
        // behind while the panel detaches from it.
        //
        // The growth has to be real geometry rather than opacity or scale.
        // The frosted backing behind a panel is a compositor blur region
        // (see shell.qml): a hard-edged rectangle that tracks this item's
        // bounds and cannot fade along with it. A cross-fade therefore
        // flashed a blurred empty pane for a frame before the panel had
        // drawn anything, and on the way out dropped the backing on the
        // very first frame, leaving the panel see-through for the rest of
        // the exit. Geometry is what the blur region follows, so growing
        // keeps the surface and its backing the same shape every frame.
        width: root.popupMode ? (root.expanded ? root.popupWidth : root.compactWidth) : root.width
        height: root.popupMode ? (root.expanded ? root.popupHeight : root.compactHeight) : root.height
        x: root.popupMode && root.expanded ? root.popupX : 0
        y: root.popupMode && root.expanded ? root.compactHeight + Prefs.barPopupGap : 0

        // popupExpanding rather than popupOpen: popupOpen now follows the
        // very geometry these animations drive, so reading it here would
        // have picked the exit duration for every enter. All four share one
        // duration and curve so the panel expands as a single movement.
        Behavior on x {
            enabled: root.popupMode

            NumberAnimation {
                duration: root.popupExpanding ? Theme.durEnter : Theme.durExit
                easing.type: Easing.Bezier
                easing.bezierCurve: root.popupExpanding ? Theme.easeEmphasizedDecel : Theme.easeEmphasizedAccel
            }

        }

        Behavior on y {
            enabled: root.popupMode

            NumberAnimation {
                duration: root.popupExpanding ? Theme.durEnter : Theme.durExit
                easing.type: Easing.Bezier
                easing.bezierCurve: root.popupExpanding ? Theme.easeEmphasizedDecel : Theme.easeEmphasizedAccel
            }

        }

        Behavior on width {
            enabled: root.popupMode

            NumberAnimation {
                duration: root.popupExpanding ? Theme.durEnter : Theme.durExit
                easing.type: Easing.Bezier
                easing.bezierCurve: root.popupExpanding ? Theme.easeEmphasizedDecel : Theme.easeEmphasizedAccel
            }

        }

        Behavior on height {
            enabled: root.popupMode

            NumberAnimation {
                duration: root.popupExpanding ? Theme.durEnter : Theme.durExit
                easing.type: Easing.Bezier
                easing.bezierCurve: root.popupExpanding ? Theme.easeEmphasizedDecel : Theme.easeEmphasizedAccel
            }

        }
        visible: !root.popupMode || shell.y > 0.5

        color: Theme.bg
        clip: true
        radius: root.cornerRadius
        topLeftRadius: root.topRadius
        topRightRadius: root.topRadius

        // COMPACT FACE
        Item {
            id: compactFace

            property bool hovered: false

            // in pop-up mode the compact face belongs to the pill that stays
            // in the bar, not to the panel that drops away below it
            parent: root.popupMode ? pillRect : shell

            anchors.fill: parent
            // in pop-up mode the pill is not the thing that opens, so its
            // face stays put and lit instead of fading out into a panel
            opacity: root.popupMode || !root.expanded ? 1 : 0
            scale: root.popupMode || !root.expanded ? 1 : 0.94
            visible: opacity > 0.01

            // compact icons are purely decorative - the whole face expands,
            // activation/close live in the expanded card list instead
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: compactFace.hovered = true
                onExited: compactFace.hovered = false
                onClicked: root.expanded = true
            }

            // One glyph and a count, not a row of app logos. Every other
            // thing in the bar is a flat Theme.text shape with the accent
            // reserved for live state, so a handful of full-colour icons at
            // 16px were the one foreign element in it - and tinting them did
            // not help, because colorization keeps each icon's own luminance
            // and dense logos just became blobs of uneven brightness. The
            // icons themselves are worth seeing when you are picking one out,
            // so they live in the expanded card list instead, at full colour.
            //
            // Deliberately built like the notification bell next to it: same
            // 16px glyph, same 4px gap, same accent pill for the count.
            Row {
                id: compactRow

                anchors.centerIn: parent
                spacing: 4

                Item {
                    width: 16
                    height: 16
                    anchors.verticalCenter: parent.verticalCenter

                    Shape {
                        width: 24
                        height: 24
                        scale: 16 / 24
                        anchors.centerIn: parent
                        preferredRendererType: Shape.CurveRenderer

                        ShapePath {
                            fillColor: Theme.text
                            strokeWidth: 0

                            PathSvg {
                                path: "M4 4h16v6H4V4Zm0 10h16v6H4v-6Zm2-8v2h2V6H6Zm0 10v2h2v-2H6Z"
                            }

                        }

                    }

                }

                Rectangle {
                    id: countBadge

                    anchors.verticalCenter: parent.verticalCenter
                    height: 16
                    width: root.trayCount > 0 ? Math.max(16, countText.implicitWidth + 8) : 0
                    radius: 999
                    color: Theme.accent
                    opacity: root.trayCount > 0 ? 1 : 0
                    scale: root.trayCount > 0 ? 1 : 0.4
                    clip: true

                    Text {
                        id: countText

                        anchors.centerIn: parent
                        // past 9 it just reads 9+, so the pill never has to
                        // grow to three digits
                        text: root.trayCount > 9 ? "9+" : String(root.trayCount)
                        color: Theme.bgOpaque
                        font.family: Theme.fontFamily
                        font.bold: true
                        font.pixelSize: Theme.fs(11)
                    }

                    Behavior on width {
                        NumberAnimation {
                            duration: Theme.ms(200)
                            easing.type: Easing.OutCubic
                        }

                    }

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.ms(200)
                            easing.type: Easing.OutCubic
                        }

                    }

                    Behavior on scale {
                        NumberAnimation {
                            duration: Theme.ms(200)
                            easing.type: Easing.OutCubic
                        }

                    }

                }

            }

            Rectangle {
                // Islands and notches only. The fill follows whatever surface
                // the compact face currently lives in - the shell in morph mode,
                // the pill in pop-up mode - corner overrides included. Copying
                // only `radius` left this fully rounded inside a squared-off
                // pill, so hovering a notch showed an island-shaped highlight
                // with dark wedges in the top corners. Inline does not use it at
                // all; see the rule below.
                anchors.fill: parent
                radius: parent.parent.radius
                topLeftRadius: parent.parent.topLeftRadius
                topRightRadius: parent.parent.topRightRadius
                color: Theme.text
                opacity: compactFace.hovered ? 0.08 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.ms(150)
                        easing.type: Easing.OutCubic
                    }

                }

            }

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.ms(220)
                    easing.type: Easing.OutCubic
                }

            }

            Behavior on scale {
                NumberAnimation {
                    duration: Theme.ms(220)
                    easing.type: Easing.OutCubic
                }

            }

        }

        // EXPANDED FACE
        Item {
            id: expandedFace

            anchors.fill: parent
            opacity: root.expanded ? 1 : 0
            scale: root.expanded ? 1 : 1.04
            visible: opacity > 0.01

            Column {
                id: expandedColumn

                anchors.fill: parent
                anchors.margins: 14
                spacing: 10

                // header
                Item {
                    width: parent.width
                    height: 28

                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: 1
                        color: Theme.outline
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Tray"
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.bold: true
                        font.pixelSize: Theme.fs(13)
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.trayCount === 1 ? "1 running" : root.trayCount + " running"
                        color: Theme.subtext
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fs(11)
                    }

                }

                ListView {
                    id: trayList

                    width: parent.width
                    clip: true
                    spacing: 6
                    model: root.trayItems
                    height: Math.min(contentHeight, root.maxPanelHeight - 60)
                    flickDeceleration: 6000
                    maximumFlickVelocity: 6000

                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.NoButton
                        onWheel: (wheel) => {
                            const maxY = Math.max(0, trayList.contentHeight - trayList.height);
                            trayList.contentY = Math.max(0, Math.min(maxY, trayList.contentY - (wheel.angleDelta.y / 120) * 90));
                            wheel.accepted = true;
                        }
                    }

                    delegate: TrayCard {
                    }

                    add: Transition {
                        NumberAnimation {
                            property: "opacity"
                            from: 0
                            to: 1
                            duration: Theme.ms(160)
                        }

                    }

                    remove: Transition {
                        NumberAnimation {
                            property: "opacity"
                            to: 0
                            duration: Theme.ms(120)
                        }

                    }

                }

            }

            Behavior on opacity {
                SequentialAnimation {
                    PauseAnimation {
                        duration: Theme.ms(root.expanded ? 140 : 0)
                    }

                    NumberAnimation {
                        duration: Theme.ms(220)
                        easing.type: Easing.OutCubic
                    }

                }

            }

            Behavior on scale {
                SequentialAnimation {
                    PauseAnimation {
                        duration: Theme.ms(root.expanded ? 140 : 0)
                    }

                    NumberAnimation {
                        duration: Theme.ms(220)
                        easing.type: Easing.OutCubic
                    }

                }

            }

        }

        Behavior on radius {
            NumberAnimation {
                duration: Theme.ms(380)
                easing.type: Easing.OutCubic
            }

        }

    }

    Behavior on implicitWidth {
        NumberAnimation {
            duration: Theme.ms(380)
            easing.type: Easing.OutCubic
        }

    }

    Behavior on implicitHeight {
        NumberAnimation {
            duration: Theme.ms(380)
            easing.type: Easing.OutCubic
        }

    }

    // one row per tray item: icon + name, with an X that kills the
    // underlying process outright - SNI has no "kill" concept, only polite
    // DBus signals the app can just ignore (which background daemons
    // routinely do), so this shells out to pkill instead of trusting the
    // app to cooperate
    component TrayCard: Rectangle {
        id: card

        required property var modelData
        readonly property var item: modelData
        readonly property bool isHovered: cardHover.hovered
        // title is the real SNI field, but some apps (Chromium/Vesktop
        // included) leave it blank and only set a tooltip title, with id
        // left as a meaningless generated string - see closeApp() below
        readonly property string displayName: card.item.title || card.item.tooltipTitle || card.item.id || "Unknown"
        // see the matching resolveIconSource() on root - inline components
        // can't reach outer scope, so this is duplicated rather than shared
        readonly property string resolvedIcon: {
            const raw = card.item.icon;
            if (!raw)
                return "";

            const qIdx = raw.indexOf("?path=");
            if (qIdx === -1)
                return raw;

            const name = raw.substring(0, qIdx);
            const dir = raw.substring(qIdx + 6);
            const fileName = name.substring(name.lastIndexOf("/") + 1);
            return "file://" + dir + "/" + fileName;
        }

        function closeApp() {
            // best-effort match: Quickshell's tray API doesn't expose a pid
            // for the item, so this is a substring match of displayName
            // against the full command line rather than a precise kill of
            // one exact process
            const target = card.displayName.trim();
            if (target.length >= 3 && target !== "Unknown")
                killProc.exec(["pkill", "-9", "-if", target]);

        }

        width: ListView.view.width
        height: 44
        radius: 14
        color: card.isHovered ? Theme.withBlur(Theme.bgActive) : Theme.withBlur(Theme.bgHover)
        clip: true

        HoverHandler {
            id: cardHover
        }

        Behavior on color {
            ColorAnimation {
                duration: Theme.ms(150)
                easing.type: Easing.OutCubic
            }

        }

        Process {
            id: killProc
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: card.item.activate()
        }

        Row {
            id: cardRow

            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 12
            spacing: 10

            Item {
                id: cardIconSlot

                width: 20
                height: 20
                anchors.verticalCenter: parent.verticalCenter

                IconImage {
                    id: cardIconImage

                    anchors.fill: parent
                    source: card.resolvedIcon
                    asynchronous: true
                    visible: status === Image.Ready
                }

                Rectangle {
                    visible: !cardIconImage.visible
                    anchors.fill: parent
                    radius: 999
                    color: Theme.bgTrack

                    Text {
                        anchors.centerIn: parent
                        text: card.displayName.charAt(0).toUpperCase()
                        color: Theme.subtext
                        font.family: Theme.fontFamily
                        font.bold: true
                        font.pixelSize: Theme.fs(9)
                    }

                }

            }

            Text {
                // capped so one very long app name can't blow the card out,
                // not stretched to fill the row - that's what left the ✕
                // stranded right after a short name instead of at the end
                width: Math.min(implicitWidth, 150)
                anchors.verticalCenter: parent.verticalCenter
                text: card.displayName
                color: Theme.text
                font.family: Theme.fontFamily
                font.bold: true
                font.pixelSize: Theme.fs(12)
                elide: Text.ElideRight
            }

        }

        // pinned to the card's own right edge, independent of the row above,
        // so it always sits at the end instead of trailing right after a
        // short name
        Item {
            id: closeBtn

            width: 20
            height: 20
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            anchors.rightMargin: 12

            Text {
                anchors.centerIn: parent
                text: "✕"
                color: closeArea.containsMouse ? Theme.error : Theme.subtextDim
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fs(11)
                opacity: card.isHovered ? 1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.ms(140)
                        easing.type: Easing.OutCubic
                    }

                }

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.ms(120)
                    }

                }

            }

            MouseArea {
                id: closeArea

                anchors.fill: parent
                anchors.margins: -4
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: card.closeApp()
            }

        }

    }

}
