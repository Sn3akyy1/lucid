import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs

PanelWindow {
    id: toastWindow

    property bool shown: false
    property string iconPath: ""
    // a nerd font glyph, for the icons that only exist as one (wi-fi)
    property string iconGlyph: ""
    property string label: ""
    // a quieter second part, after the label
    property string detail: ""
    property bool warn: false
    property color swatch: "transparent"
    property bool hasSwatch: false

    // m3 snackbar metrics: 48dp container, 16dp leading pad, 12dp icon gap
    readonly property int pillHeight: 48
    readonly property int pillPad: 16
    readonly property int iconGap: 12
    readonly property int glyphSize: 20
    readonly property int labelMax: 340
    readonly property int detailMax: 260

    // system events wait their turn here instead of cutting each other off
    property var queue: []
    // how many may wait; a burst past it sheds the oldest plain entry
    property int queueCap: 8
    // what is on screen, so a newer event of the same kind updates it in place
    property string currentKey: ""

    // named icons so a caller (or a shell script over ipc) need not pass svg
    readonly property var icons: ({
        "copy": "M19,21H8V7H19M19,5H8A2,2 0 0,0 6,7V21A2,2 0 0,0 8,23H19A2,2 0 0,0 21,21V7A2,2 0 0,0 19,5M16,1H4A2,2 0 0,0 2,3V17H4V3H16V1Z",
        "check": "M9,20.42L2.79,14.21L5.62,11.38L9,14.77L18.88,4.88L21.71,7.71L9,20.42Z",
        "alert": "M13,14H11V9H13M13,18H11V16H13M1,21H23L12,2L1,21Z",
        "info": "M13,9H11V7H13M13,17H11V11H13M12,2A10,10 0 0,0 2,12A10,10 0 0,0 12,22A10,10 0 0,0 22,12A10,10 0 0,0 12,2Z",
        "text": "M5,4V7H10.5V19H13.5V7H19V4H5Z",
        "game": "M7.97,16L5,19C4.67,19.3 4.23,19.5 3.75,19.5A1.75,1.75 0 0,1 2,17.75V17.5L3,10.12C3.21,8.35 4.73,7 6.5,7H17.5C19.27,7 20.79,8.35 21,10.12L22,17.5V17.75A1.75,1.75 0 0,1 20.25,19.5C19.77,19.5 19.33,19.3 19,19L16.03,16H7.97M7,9V11H5V13H7V15H9V13H11V11H9V9H7M16.5,9A1.5,1.5 0 0,0 15,10.5A1.5,1.5 0 0,0 16.5,12A1.5,1.5 0 0,0 18,10.5A1.5,1.5 0 0,0 16.5,9M19.5,12A1.5,1.5 0 0,0 18,13.5A1.5,1.5 0 0,0 19.5,15A1.5,1.5 0 0,0 21,13.5A1.5,1.5 0 0,0 19.5,12Z",
        "camera": "M9,2L7.17,4H4A2,2 0 0,0 2,6V18A2,2 0 0,0 4,20H20A2,2 0 0,0 22,18V6A2,2 0 0,0 20,4H16.83L15,2H9M12,7A5,5 0 0,1 17,12A5,5 0 0,1 12,17A5,5 0 0,1 7,12A5,5 0 0,1 12,7M12,9A3,3 0 0,0 9,12A3,3 0 0,0 12,15A3,3 0 0,0 15,12A3,3 0 0,0 12,9Z"
    })

    // entry: { icon, label, detail, warn, swatch, key, ms }. icon is a name from
    // the list above, raw svg path data, or a single glyph
    function present(entry) {
        const icon = entry.icon || "";
        const named = toastWindow.icons[icon];
        const isPath = named !== undefined || /^[Mm][\d\s.,-]/.test(icon);
        const isGlyph = !isPath && icon.length > 0 && icon.length <= 2;
        toastWindow.currentKey = entry.key || "";
        toastWindow.hasSwatch = entry.swatch !== undefined;
        if (entry.swatch !== undefined)
            toastWindow.swatch = entry.swatch;

        toastWindow.iconPath = named || (isPath ? icon : (isGlyph ? "" : toastWindow.icons["info"]));
        toastWindow.iconGlyph = isGlyph ? icon : "";
        toastWindow.label = entry.label || "";
        toastWindow.detail = entry.detail || "";
        toastWindow.warn = entry.warn === true;
        hideTimer.interval = entry.ms > 0 ? entry.ms : (toastWindow.queue.length > 0 ? 1700 : 2200);
        toastWindow.popIn();
    }

    // a picked colour shows as itself rather than as an icon
    function popupSwatch(hex, text) {
        toastWindow.present({
            "swatch": hex,
            "label": text
        });
    }

    // feedback for something the user just did: shown at once, over anything
    function popup(icon, text, isWarn) {
        toastWindow.present({
            "icon": icon,
            "label": text,
            "warn": isWarn === true
        });
    }

    // something that happened on its own: waits behind whatever is showing
    function enqueue(entry) {
        if (toastWindow.shown && entry.key && entry.key === toastWindow.currentKey) {
            toastWindow.present(entry);
            return ;
        }
        const q = toastWindow.queue.filter((e) => {
            return !(entry.key && e.key === entry.key);
        });
        q.push(entry);
        // a burst past the cap sheds the oldest plain entry; warnings stay
        if (q.length > toastWindow.queueCap) {
            const drop = q.findIndex((e) => {
                return !e.warn;
            });
            q.splice(drop >= 0 ? drop : 0, 1);
        }
        toastWindow.queue = q;
        if (!toastWindow.shown && !nextTimer.running)
            toastWindow.showNext();

    }

    function showNext() {
        if (toastWindow.queue.length === 0)
            return ;

        const q = toastWindow.queue.slice();
        const entry = q.shift();
        toastWindow.queue = q;
        toastWindow.present(entry);
    }

    // the params have to be set before the flag flips: a Behavior reads the
    // previous value of anything its animation binds to
    function popIn() {
        pillFade.duration = Theme.durEnter;
        pillFade.easing.bezierCurve = Theme.easeEmphasizedDecel;
        pillDrop.duration = Theme.durEnter;
        pillDrop.easing.bezierCurve = Theme.easeEmphasizedDecel;
        pillPop.duration = Theme.durEnter;
        pillPop.easing.type = Easing.OutBack;
        pillPop.easing.overshoot = Theme.emphasizedOvershoot;
        toastWindow.shown = true;
        hideTimer.restart();
    }

    function popOut() {
        pillFade.duration = Theme.durExit;
        pillFade.easing.bezierCurve = Theme.easeEmphasizedAccel;
        pillDrop.duration = Theme.durExit;
        pillDrop.easing.bezierCurve = Theme.easeEmphasizedAccel;
        pillPop.duration = Theme.durExit;
        pillPop.easing.bezierCurve = Theme.easeEmphasizedAccel;
        pillPop.easing.type = Easing.Bezier;
        toastWindow.shown = false;
    }

    color: "transparent"
    exclusiveZone: 0
    visible: pill.opacity > 0.01 && Monitors.surfacesUp
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    implicitWidth: Math.max(160, pill.width + 40)
    implicitHeight: 88
    margins.top: 10
    BackgroundEffect.blurRegion: (Theme.blurAmount > 0 && toastWindow.visible) ? toastBlur : null

    anchors {
        top: true
    }

    // a toast is not a target; clicks belong to whatever is under it
    mask: Region {}

    Timer {
        id: hideTimer

        interval: 2200
        onTriggered: {
            toastWindow.popOut();
            if (toastWindow.queue.length > 0)
                nextTimer.start();

        }
    }

    // lets the last one finish leaving before the next comes in
    Timer {
        id: nextTimer

        interval: Theme.durExit + 90
        onTriggered: toastWindow.showNext()
    }

    Region {
        id: toastBlur

        readonly property real paintedX: pill.x + pill.width * (1 - pill.scale) / 2
        readonly property real paintedY: pill.y + pill.height * (1 - pill.scale) / 2
        readonly property real paintedWidth: pill.width * pill.scale
        readonly property real paintedHeight: pill.height * pill.scale

        // stadium pills need the 1px horizontal inset or the hard mask edge shows
        x: Math.ceil(toastBlur.paintedX) + 1
        y: Math.ceil(toastBlur.paintedY)
        width: Math.max(0, Math.floor(toastBlur.paintedX + toastBlur.paintedWidth) - Math.ceil(toastBlur.paintedX) - 2)
        height: Math.max(0, Math.floor(toastBlur.paintedY + toastBlur.paintedHeight) - Math.ceil(toastBlur.paintedY))
        radius: Math.round(pill.radius * pill.scale)
    }

    Rectangle {
        id: pill

        anchors.horizontalCenter: parent.horizontalCenter
        y: toastWindow.shown ? 20 : 2
        height: toastWindow.pillHeight
        width: leadIcon.width + toastWindow.iconGap + labelText.width + (detailText.visible ? toastWindow.iconGap + detailText.width : 0) + toastWindow.pillPad * 2
        radius: Theme.pill(height)
        color: Theme.bg
        opacity: toastWindow.shown ? 1 : 0
        scale: toastWindow.shown ? 1 : 0.92

        TextMetrics {
            id: labelMetrics

            text: toastWindow.label
            font.family: Theme.fontFamily
            font.bold: true
            font.pixelSize: Theme.fontBodyMd
        }

        TextMetrics {
            id: detailMetrics

            text: toastWindow.detail
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontBodyMd
        }

        Behavior on y {
            NumberAnimation {
                id: pillDrop

                duration: Theme.durEnter
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.easeEmphasizedDecel
            }

        }

        Behavior on opacity {
            NumberAnimation {
                id: pillFade

                duration: Theme.durEnter
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.easeEmphasizedDecel
            }

        }

        Behavior on scale {
            NumberAnimation {
                id: pillPop

                duration: Theme.durEnter
                easing.type: Easing.OutBack
                easing.overshoot: Theme.emphasizedOvershoot
            }

        }

        Item {
            id: leadIcon

            anchors.left: parent.left
            anchors.leftMargin: toastWindow.pillPad
            anchors.verticalCenter: parent.verticalCenter
            width: toastWindow.glyphSize
            height: toastWindow.glyphSize

            Rectangle {
                visible: toastWindow.hasSwatch
                anchors.centerIn: parent
                width: parent.width
                height: parent.height
                radius: Theme.pill(width)
                color: toastWindow.swatch
                // a near-black pick would vanish into the pill without this
                border.color: Theme.alpha(Theme.text, 0.25)
                border.width: 1
            }

            Text {
                visible: !toastWindow.hasSwatch && toastWindow.iconGlyph !== ""
                anchors.centerIn: parent
                text: toastWindow.iconGlyph
                color: toastWindow.warn ? Theme.error : Theme.accent
                font.family: Theme.fontFamily
                font.pixelSize: toastWindow.glyphSize
            }

            Shape {
                visible: !toastWindow.hasSwatch && toastWindow.iconGlyph === ""
                width: 24
                height: 24
                scale: toastWindow.glyphSize / 24
                anchors.centerIn: parent
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    fillColor: toastWindow.warn ? Theme.error : Theme.accent
                    strokeWidth: 0

                    PathSvg {
                        path: toastWindow.iconPath
                    }

                }

            }

        }

        Text {
            id: labelText

            anchors.left: leadIcon.right
            anchors.leftMargin: toastWindow.iconGap
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(Math.ceil(labelMetrics.advanceWidth), toastWindow.labelMax)
            elide: Text.ElideRight
            text: toastWindow.label
            color: Theme.text
            font.family: Theme.fontFamily
            font.bold: true
            font.pixelSize: Theme.fontBodyMd
        }

        Text {
            id: detailText

            anchors.left: labelText.right
            anchors.leftMargin: toastWindow.iconGap
            anchors.verticalCenter: parent.verticalCenter
            visible: toastWindow.detail !== ""
            width: Math.min(Math.ceil(detailMetrics.advanceWidth), toastWindow.detailMax)
            elide: Text.ElideRight
            text: toastWindow.detail
            color: Theme.subtext
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontBodyMd
        }

    }

    IpcHandler {
        target: "toast"

        function show(icon: string, label: string): void {
            toastWindow.popup(icon, label, false);
        }

        function warn(icon: string, label: string): void {
            toastWindow.popup(icon, label, true);
        }
    }
}
