import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs

Variants {
    id: variants

    model: Quickshell.screens

    PanelWindow {
        id: layer

        required property var modelData

        readonly property bool suppressed: Prefs.widgetHideFullscreen && layer.fullscreenUp
        readonly property bool fullscreenUp: {
            var t = Hyprland.activeToplevel;
            if (!t || !t.lastIpcObject)
                return false;

            return (t.lastIpcObject.fullscreen || 0) > 0;
        }

        screen: layer.modelData
        visible: Prefs.loaded && Widgets.loaded && Prefs.widgetsEnabled && Widgets.count > 0 && !layer.suppressed
        color: "transparent"
        // reserves nothing and refuses to be shrunk into the bar and dock's strips,
        // so a card can be dragged to a true screen edge and sit under the dock.
        // setting exclusiveZone at all would silently undo this
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: Prefs.widgetOnTop ? WlrLayer.Top : WlrLayer.Bottom
        WlrLayershell.keyboardFocus: deck.wantsKeyboard ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        // lastIpcObject only moves when something asks it to, so nudge it on the
        // events that can change whether a window is fullscreen
        Connections {
            function onRawEvent(event) {
                if (event.name === "fullscreen" || event.name === "activewindowv2" || event.name === "closewindow")
                    fullscreenPoll.restart();

            }

            enabled: Prefs.widgetHideFullscreen
            target: Hyprland
        }

        Timer {
            id: fullscreenPoll

            interval: 120
            onTriggered: Hyprland.refreshToplevels()
        }

        Item {
            id: deck

            // bumped whenever the repeater's children change, so frameAt() bindings re-run
            property int rev: 0
            property Item dragFrame: null

            readonly property string screenName: layer.screen ? layer.screen.name : ""
            readonly property bool isPrimary: layer.screen !== null && layer.screen === Monitors.mainScreen
            readonly property int frameCount: rep.count
            readonly property bool editing: Widgets.editUid !== "" && deck.editFrame !== null
            // only ask for keys at all once something you can type into is placed;
            // on-demand hands focus back the moment a window is clicked, which
            // exclusive would not
            readonly property bool wantsKeyboard: {
                for (var i = 0; i < Widgets.model.count; i++) {
                    var e = Widgets.model.get(i);
                    if (!e.closing && (e.wtype === "notes" || e.wtype === "todo"))
                        return true;

                }
                return false;
            }
            readonly property bool grabbing: Widgets.dragUid !== "" || Widgets.menuUid !== "" || deck.editing
            readonly property Item menuFrame: {
                var _ = deck.rev;
                for (var i = 0; i < rep.count; i++) {
                    var f = rep.itemAt(i);
                    if (f && f.uid === Widgets.menuUid && f.visible)
                        return f;

                }
                return null;
            }
            readonly property Item editFrame: {
                var _ = deck.rev;
                for (var i = 0; i < rep.count; i++) {
                    var f = rep.itemAt(i);
                    if (f && f.uid === Widgets.editUid && f.visible)
                        return f;

                }
                return null;
            }

            function frameAt(i) {
                var _ = deck.rev;
                return (i >= 0 && i < rep.count) ? rep.itemAt(i) : null;
            }

            anchors.fill: parent
            focus: true
            Keys.onEscapePressed: {
                Widgets.editUid = "";
                Widgets.menuUid = "";
            }
            onWidthChanged: deck.report()
            onHeightChanged: deck.report()
            Component.onCompleted: deck.report()

            function report() {
                if (deck.isPrimary && deck.width > 0) {
                    Widgets.canvasW = deck.width;
                    Widgets.canvasH = deck.height;
                }
            }

            // click-through everywhere except the cards, so this only fires for the open menu
            MouseArea {
                anchors.fill: parent
                enabled: deck.grabbing
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onPressed: {
                    Widgets.menuUid = "";
                    Widgets.editUid = "";
                }
            }

            Repeater {
                id: rep

                model: Widgets.model
                onItemAdded: deck.rev++
                onItemRemoved: deck.rev++

                WidgetFrame {
                    board: deck
                }

            }

            Rectangle {
                width: 1
                height: deck.height
                x: deck.dragFrame ? deck.dragFrame.guideX : -1
                color: Theme.accent
                opacity: (deck.dragFrame && deck.dragFrame.guideX >= 0) ? 0.65 : 0
                visible: opacity > 0.01
                z: 900

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.durQuick
                    }

                }

            }

            Rectangle {
                height: 1
                width: deck.width
                y: deck.dragFrame ? deck.dragFrame.guideY : -1
                color: Theme.accent
                opacity: (deck.dragFrame && deck.dragFrame.guideY >= 0) ? 0.65 : 0
                visible: opacity > 0.01
                z: 900

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.durQuick
                    }

                }

            }

        }

        mask: Region {
            x: 0
            y: 0
            width: deck.grabbing ? layer.width : 0
            height: deck.grabbing ? layer.height : 0

        WidgetRegion {
            frame: deck.frameAt(0)
        }

        WidgetRegion {
            frame: deck.frameAt(1)
        }

        WidgetRegion {
            frame: deck.frameAt(2)
        }

        WidgetRegion {
            frame: deck.frameAt(3)
        }

        WidgetRegion {
            frame: deck.frameAt(4)
        }

        WidgetRegion {
            frame: deck.frameAt(5)
        }

        WidgetRegion {
            frame: deck.frameAt(6)
        }

        WidgetRegion {
            frame: deck.frameAt(7)
        }

        WidgetRegion {
            frame: deck.frameAt(8)
        }

        WidgetRegion {
            frame: deck.frameAt(9)
        }

        WidgetRegion {
            frame: deck.frameAt(10)
        }

        WidgetRegion {
            frame: deck.frameAt(11)
        }

        WidgetRegion {
            frame: deck.frameAt(12)
        }

        WidgetRegion {
            frame: deck.frameAt(13)
        }

        WidgetRegion {
            frame: deck.frameAt(14)
        }

        WidgetRegion {
            frame: deck.frameAt(15)
        }

        WidgetRegion {
            frame: deck.frameAt(16)
        }

        WidgetRegion {
            frame: deck.frameAt(17)
        }

        WidgetRegion {
            frame: deck.frameAt(18)
        }

        WidgetRegion {
            frame: deck.frameAt(19)
        }

        }

        BackgroundEffect.blurRegion: Theme.blurAmount > 0 ? widgetBlur : null

        Region {
            id: widgetBlur

        WidgetRegion {
            blur: true
            part: "menu"
            frame: deck.menuFrame
        }

        WidgetRegion {
            blur: true
            frame: deck.frameAt(0)
        }

        WidgetRegion {
            blur: true
            frame: deck.frameAt(1)
        }

        WidgetRegion {
            blur: true
            frame: deck.frameAt(2)
        }

        WidgetRegion {
            blur: true
            frame: deck.frameAt(3)
        }

        WidgetRegion {
            blur: true
            frame: deck.frameAt(4)
        }

        WidgetRegion {
            blur: true
            frame: deck.frameAt(5)
        }

        WidgetRegion {
            blur: true
            frame: deck.frameAt(6)
        }

        WidgetRegion {
            blur: true
            frame: deck.frameAt(7)
        }

        WidgetRegion {
            blur: true
            frame: deck.frameAt(8)
        }

        WidgetRegion {
            blur: true
            frame: deck.frameAt(9)
        }

        WidgetRegion {
            blur: true
            frame: deck.frameAt(10)
        }

        WidgetRegion {
            blur: true
            frame: deck.frameAt(11)
        }

        WidgetRegion {
            blur: true
            frame: deck.frameAt(12)
        }

        WidgetRegion {
            blur: true
            frame: deck.frameAt(13)
        }

        WidgetRegion {
            blur: true
            frame: deck.frameAt(14)
        }

        WidgetRegion {
            blur: true
            frame: deck.frameAt(15)
        }

        WidgetRegion {
            blur: true
            frame: deck.frameAt(16)
        }

        WidgetRegion {
            blur: true
            frame: deck.frameAt(17)
        }

        WidgetRegion {
            blur: true
            frame: deck.frameAt(18)
        }

        WidgetRegion {
            blur: true
            frame: deck.frameAt(19)
        }

        }

    }

}
