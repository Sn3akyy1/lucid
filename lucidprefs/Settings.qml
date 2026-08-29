import QtQuick
import QtQuick.Controls.Basic
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs

FloatingWindow {
    id: win

    readonly property int wheelStep: 190
    readonly property int flickDecel: 6000
    readonly property int maxFlick: 9000

    property string page: "general"
    readonly property var pages: [
        { "key": "general", "label": "General", "title": "General", "blurb": "Shape, colour and motion across the whole shell" },
        { "key": "bar", "label": "Bar", "title": "Bar", "blurb": "The status bar, its modules and how they open", "toggle": "barEnabled" },
        { "key": "dock", "label": "Dock", "title": "Dock", "blurb": "The dock, its icons and how it behaves", "toggle": "dockEnabled" },
        { "key": "about", "label": "About", "title": "About", "blurb": "Lucid" }
    ]

    function show(p) {
        if (p !== "")
            win.page = p;

        win.visible = true;
    }

    onVisibleChanged: {
        if (win.visible)
            focusSink.forceActiveFocus();
        else
            confirmDialog.dismiss();
    }
    onClosed: win.visible = false

    visible: false
    title: "Lucid Settings"
    color: Theme.bg

    BackgroundEffect.blurRegion: (Theme.blurAmount > 0 && win.visible) ? settingsBlurRegion : null

    Region {
        id: settingsBlurRegion

        x: Math.ceil(surface.x - 0.002)
        y: Math.ceil(surface.y - 0.002)
        width: Math.max(0, Math.floor(surface.x + surface.width + 0.002) - Math.ceil(surface.x - 0.002))
        height: Math.max(0, Math.floor(surface.y + surface.height + 0.002) - Math.ceil(surface.y - 0.002))
    }
    implicitWidth: 1020
    implicitHeight: 700
    minimumSize.width: 720
    minimumSize.height: 480

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

        // qs ipc call settings show bar
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

        function font(): void {
            win.show("general");
            Prefs.fontPickerRequested();
        }

        function reset(): void {
            win.show("");
            Prefs.askReset("Reset every setting?", "Every setting on all three pages goes back to the value it ships with. Your theme, wallpaper and pinned applications are not touched.", Prefs.resetAllToken);
        }

    }

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

    Item {
        id: surface

        anchors.fill: parent
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
                        text: "Lucid"
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

        Rectangle {
            id: content

            anchors.left: nav.right
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            color: Theme.withBlur(Theme.bgSunken)
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

                M3Switch {
                    id: surfaceToggle

                    readonly property string key: {
                        var p = win.pages.find((x) => {
                            return x.key === win.page;
                        });
                        return (p && p.toggle) ? p.toggle : "";
                    }

                    anchors.right: closeBtn.left
                    anchors.rightMargin: 18
                    anchors.verticalCenter: parent.verticalCenter
                    visible: surfaceToggle.key !== ""
                    checked: surfaceToggle.key !== "" ? Prefs[surfaceToggle.key] : false
                    onToggled: (v) => {
                        return Prefs.setSurface(surfaceToggle.key, v);
                    }
                }

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
