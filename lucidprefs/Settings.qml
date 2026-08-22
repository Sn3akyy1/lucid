import QtQuick
import QtQuick.Controls.Basic
import Quickshell
import Quickshell.Io
import qs

// LucidShell's settings app. A real toplevel window rather than a layer-shell
// surface like the rest of this config - which is the point: the compositor
// then treats it as an ordinary window, so it drags with Super+drag, closes
// with the same Super+C bind as anything else, tiles or floats by window rule,
// and can be alt-tabbed to. A layer surface can do none of that.
//
// Opened from the command line:
//     qs ipc call settings open
//     qs ipc call settings toggle
//     qs ipc call settings bar
//
// Nothing in here owns any state. Every control reads and writes Prefs, which
// is also what the rest of the shell reads - so a setting changed here and the
// same setting changed anywhere else are one value, not two copies of it.
FloatingWindow {
    id: win

    // ---- scroll feel ----
    // Both of these are the knobs to turn if the scrolling feels wrong.
    // wheelStep is how far one notch of the wheel travels, in pixels;
    // flickDecel is how hard a touchpad flick is braked (higher = stops
    // sooner). Qt's defaults are roughly a 60px step and 1500 deceleration,
    // which read as sluggish in a list this short.
    readonly property int wheelStep: 190
    readonly property int flickDecel: 6000
    readonly property int maxFlick: 9000

    property string page: "general"
    readonly property var pages: [
        { "key": "general", "label": "General", "title": "General", "blurb": "Shape, colour and motion across the whole shell" },
        { "key": "bar", "label": "Bar", "title": "Bar", "blurb": "The status bar, its modules and how they open" },
        { "key": "dock", "label": "Dock", "title": "Dock", "blurb": "The dock, its icons and how it behaves" },
        { "key": "about", "label": "About", "title": "About", "blurb": "LucidShell" }
    ]

    function show(p) {
        if (p !== "")
            win.page = p;

        // assigned rather than bound: the compositor owns this too (Super+C
        // sets it false itself), and a binding would be destroyed the first
        // time that happened, leaving the window unable to reopen
        win.visible = true;
    }

    onVisibleChanged: {
        if (win.visible)
            focusSink.forceActiveFocus();
        else
            confirmDialog.dismiss();
    }
    // The compositor can close this window without going through `visible`
    // (Super+C, or any other close request), which leaves the property
    // reading true while the window is gone - after that, assigning true
    // again is a no-op and the app can never be reopened. Resyncing here is
    // what keeps `qs ipc call settings open` working afterwards.
    onClosed: win.visible = false

    visible: false
    title: "Lucid Settings"
    color: Theme.bg
    // sized once rather than clamped against the screen every frame - it is a
    // real window now, so the compositor is what decides where it goes and
    // how big it is allowed to be
    implicitWidth: 1020
    implicitHeight: 700
    minimumSize.width: 720
    minimumSize.height: 480

    // the launcher's >settings command reaches the app through Prefs rather
    // than either file importing the other
    Connections {
        function onSettingsRequested(page) {
            win.show(page);
        }

        target: Prefs
    }

    IpcHandler {
        target: "settings"

        function toggle(): void {
            if (win.visible)
                win.visible = false;
            else
                win.show("");
        }

        function open(): void {
            win.show("");
        }

        function close(): void {
            win.visible = false;
        }

        // `qs ipc call settings show bar` - jumps straight to one page
        function show(page: string): void {
            win.show(page);
        }

        function general(): void {
            win.show("general");
        }

        function bar(): void {
            win.show("bar");
        }

        function dock(): void {
            win.show("dock");
        }

        // straight to the font list - the one setting most likely to be
        // changed on a whim, and the slowest to reach by scrolling
        function font(): void {
            win.show("general");
            Prefs.fontPickerRequested();
        }

        // deliberately asks rather than acting: a command line that silently
        // wipes every setting is a worse version of the button that confirms
        function reset(): void {
            win.show("");
            Prefs.askReset("Reset every setting?", "Every setting on all three pages goes back to the value it ships with. Your theme, wallpaper and pinned applications are not touched.", Prefs.resetAllToken);
        }

    }

    // Every reset button in the app raises Prefs.resetConfirmRequested rather
    // than acting on its own; this is the single place that asks, and the
    // single place that carries the answer out.
    ConfirmDialog {
        id: confirmDialog

        z: 100
        onConfirmed: (action) => {
            if (action === Prefs.resetAllToken)
                Prefs.resetAll();
            else if (action === Prefs.resetDockToken)
                Prefs.pinnedResetRequested();
            else if (action === Prefs.resetBlurToken)
                Theme.setBlurAmount(0);
            else if (action.indexOf("wallpaper:") === 0)
                Prefs.wallpaperDeleteRequested(action.substring(10));
            else
                Prefs.set(action, Prefs.defaults[action]);
        }
    }

    FontPicker {
        id: fontPicker

        z: 100
    }

    Connections {
        function onResetConfirmRequested(title, body, confirmLabel, action) {
            confirmDialog.ask(title, body, confirmLabel, action);
        }

        function onFontPickerRequested() {
            fontPicker.open();
        }

        target: Prefs
    }

    Item {
        id: focusSink

        anchors.fill: parent
        focus: true
        // with a dialog up, Escape dismisses it rather than closing the whole
        // app out from under the question it just asked
        Keys.onEscapePressed: {
            if (fontPicker.shown)
                fontPicker.dismiss();
            else if (confirmDialog.shown)
                confirmDialog.dismiss();
            else
                win.visible = false;
        }
        Keys.onReturnPressed: confirmDialog.confirm()
        Keys.onEnterPressed: confirmDialog.confirm()
    }

    // fills the window edge to edge and stays square: the compositor draws
    // this window's rounded corners now, and a second radius inside them only
    // shows as a dark seam in each corner
    Item {
        id: surface

        anchors.fill: parent
        // ---------------- navigation ----------------
        Item {
            id: nav

            width: 228
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom

            Row {
                id: brand

                anchors.left: parent.left
                anchors.leftMargin: 24
                anchors.top: parent.top
                anchors.topMargin: 26
                spacing: 12

                LucidaMark {
                    width: 26
                    height: 26
                    anchors.verticalCenter: parent.verticalCenter
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 0

                    Text {
                        text: "LucidShell"
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontHeadline
                        font.bold: true
                    }

                    Text {
                        text: "Settings"
                        color: Theme.subtext
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontLabel
                    }

                }

            }

            Column {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                anchors.top: brand.bottom
                anchors.topMargin: 26
                spacing: 4

                Repeater {
                    model: win.pages

                    // M3 navigation drawer item: 56dp tall, fully rounded
                    // active indicator filled with the accent container
                    Item {
                        id: navItem

                        required property var modelData

                        readonly property bool selected: win.page === navItem.modelData.key

                        width: parent.width
                        height: 52

                        Rectangle {
                            anchors.fill: parent
                            radius: height / 2
                            color: navItem.selected ? Theme.accentContainer : (navArea.containsMouse ? Theme.alpha(Theme.text, Theme.stateHover) : "transparent")

                            Behavior on color {
                                ColorAnimation {
                                    duration: Theme.durShort
                                }

                            }

                        }

                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: 18
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 14

                            LucidaMark {
                                width: 22
                                height: 22
                                strokeWidth: 3.4
                                anchors.verticalCenter: parent.verticalCenter
                                visible: navItem.modelData.key === "about"
                                ringColor: navItem.selected ? Theme.accent : Theme.subtext
                                starColor: navItem.selected ? Theme.text : Theme.subtext
                            }

                            NavGlyph {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: navItem.modelData.key !== "about"
                                kind: navItem.modelData.key
                                color: navItem.selected ? Theme.text : Theme.subtext

                                Behavior on color {
                                    ColorAnimation {
                                        duration: Theme.durShort
                                    }

                                }

                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: navItem.modelData.label
                                color: navItem.selected ? Theme.text : Theme.subtext
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontTitle
                                font.bold: navItem.selected

                                Behavior on color {
                                    ColorAnimation {
                                        duration: Theme.durShort
                                    }

                                }

                            }

                        }

                        MouseArea {
                            id: navArea

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: win.page = navItem.modelData.key
                        }

                    }

                }

            }

            // reset lives at the bottom of the nav rather than on any one
            // page, because it resets all of them
            M3Button {
                anchors.left: parent.left
                anchors.leftMargin: 18
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 18
                variant: "text"
                destructive: true
                text: "Reset all"
                onClicked: Prefs.askReset("Reset every setting?", "Every setting on all three pages goes back to the value it ships with. Your theme, wallpaper and pinned applications are not touched.", Prefs.resetAllToken)
            }

        }

        // ---------------- content ----------------
        Rectangle {
            id: content

            anchors.left: nav.right
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            // withBlur, not the bare token: bgSunken has no alpha of its own,
            // so at any Glass level above Off this pane stayed solid while the
            // window behind it went translucent - which is why the nav rail
            // showed the desktop through it and the content did not.
            color: Theme.withBlur(Theme.bgSunken)
            // all four: the left pair is the inner curve away from the nav,
            // and the right pair has to match the window's own corner radius.
            // Without them this pane paints square corners over the surface's
            // rounded ones - `clip: true` on the surface clips to its
            // bounding rectangle, not to its rounded shape.
            topLeftRadius: Theme.radiusXl
            bottomLeftRadius: Theme.radiusXl
            topRightRadius: Theme.radiusXl
            bottomRightRadius: Theme.radiusXl
            clip: true

            Item {
                id: pageHeader

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: 84

                // The header doubles as a titlebar: this hands the drag to
                // the compositor via the real xdg_toplevel move request, so
                // it behaves exactly like dragging any other window rather
                // than being a home-made move that fights the window manager.
                MouseArea {
                    anchors.fill: parent
                    onPressed: win.startSystemMove()
                }

                Column {
                    anchors.left: parent.left
                    anchors.leftMargin: 32
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    Text {
                        text: win.pages.find((p) => {
                            return p.key === win.page;
                        }).title
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fs(22)
                        font.bold: true
                    }

                    Text {
                        text: win.pages.find((p) => {
                            return p.key === win.page;
                        }).blurb
                        color: Theme.subtext
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontBody
                    }

                }

                // close affordance - clicking away and Esc both work too, but a
                // visible control is what people reach for first
                Rectangle {
                    id: closeBtn

                    width: 36
                    height: 36
                    radius: 18
                    anchors.right: parent.right
                    anchors.rightMargin: 24
                    anchors.verticalCenter: parent.verticalCenter
                    color: closeArea.containsMouse ? Theme.alpha(Theme.text, Theme.stateHover) : "transparent"

                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.durQuick
                        }

                    }

                    Rectangle {
                        width: 15
                        height: 1.8
                        radius: 1
                        anchors.centerIn: parent
                        rotation: 45
                        color: Theme.subtext
                    }

                    Rectangle {
                        width: 15
                        height: 1.8
                        radius: 1
                        anchors.centerIn: parent
                        rotation: -45
                        color: Theme.subtext
                    }

                    MouseArea {
                        id: closeArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: win.visible = false
                    }

                }

            }

            // M3 fade-through between pages: the outgoing page leaves before
            // the incoming one arrives, and the incoming one rises slightly
            // as it fades in
            Repeater {
                model: win.pages

                Flickable {
                    id: pane

                    required property var modelData

                    readonly property bool active: win.page === pane.modelData.key

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: pageHeader.bottom
                    anchors.bottom: parent.bottom
                    contentWidth: width
                    contentHeight: paneLoader.height + 40
                    clip: true
                    interactive: pane.active
                    visible: pane.opacity > 0.01
                    opacity: pane.active ? 1 : 0
                    boundsBehavior: Flickable.StopAtBounds
                    flickDeceleration: win.flickDecel
                    maximumFlickVelocity: win.maxFlick

                    // Qt's built-in wheel handling moves a fixed ~60px per
                    // notch with no easing, which is what makes the default
                    // feel slow. This replaces it with a larger step that is
                    // animated, so a fast scroll covers ground without the
                    // jump reading as a teleport.
                    WheelHandler {
                        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                        onWheel: (event) => {
                            event.accepted = true;
                            var maxY = Math.max(0, pane.contentHeight - pane.height);
                            var base = paneScroll.running ? paneScroll.to : pane.contentY;
                            var target = Math.max(0, Math.min(maxY, base - (event.angleDelta.y / 120) * win.wheelStep));
                            if (target === base)
                                return ;

                            paneScroll.stop();
                            paneScroll.from = pane.contentY;
                            paneScroll.to = target;
                            paneScroll.start();
                        }
                    }

                    NumberAnimation {
                        id: paneScroll

                        target: pane
                        property: "contentY"
                        duration: Theme.ms(170)
                        easing.type: Easing.OutCubic
                    }

                    ScrollBar.vertical: ScrollBar {
                        id: paneBar

                        policy: pane.contentHeight > pane.height ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
                        width: 10

                        contentItem: Rectangle {
                            implicitWidth: paneBar.hovered || paneBar.pressed ? 8 : 5
                            radius: width / 2
                            color: paneBar.pressed ? Theme.accent : (paneBar.hovered ? Theme.alpha(Theme.text, 0.4) : Theme.alpha(Theme.text, 0.2))

                            Behavior on implicitWidth {
                                NumberAnimation {
                                    duration: Theme.durQuick
                                    easing.type: Theme.easeStandard
                                }

                            }

                            Behavior on color {
                                ColorAnimation {
                                    duration: Theme.durQuick
                                }

                            }

                        }

                        background: Rectangle {
                            color: "transparent"
                        }

                    }

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.durShort
                            easing.type: Theme.easeStandard
                        }

                    }

                    Loader {
                        id: paneLoader

                        // pages stay alive once built so scroll position and
                        // any scan results survive switching away and back
                        property bool everActive: false

                        width: pane.width - 74
                        x: 32
                        y: pane.active ? 4 : 16
                        active: paneLoader.everActive
                        source: pane.modelData.key === "general" ? "GeneralPage.qml" : (pane.modelData.key === "bar" ? "BarPage.qml" : (pane.modelData.key === "dock" ? "DockPage.qml" : "AboutPage.qml"))

                        Behavior on y {
                            NumberAnimation {
                                duration: Theme.durMedium
                                easing.type: Theme.easeStandard
                            }

                        }

                    }

                    onActiveChanged: {
                        if (pane.active)
                            paneLoader.everActive = true;

                    }
                    Component.onCompleted: {
                        if (pane.active)
                            paneLoader.everActive = true;

                    }
                }

            }

        }

    }

}
