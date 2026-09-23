import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs
import qs.lucidui

PanelWindow {
    id: toastWindow

    property bool shown: false
    property string iconPath: ""
    property string label: ""
    property bool warn: false
    property color swatch: "transparent"
    property bool hasSwatch: false

    // m3 snackbar metrics: 48dp container, 16dp leading pad, 12dp icon gap
    readonly property int pillHeight: 48
    readonly property int pillPad: 16
    readonly property int iconGap: 12
    readonly property int glyphSize: 20

    // named icons so a caller (or a shell script over ipc) need not pass svg
    readonly property var icons: ({
        "copy": "content_copy",
        "check": "check_circle",
        "alert": "warning",
        "info": "info",
        "text": "text_fields",
        "game": "sports_esports",
        "camera": "photo_camera"
    })
    // m3 snackbars sit on the inverse surface, so they read apart from every panel
    readonly property color warnTone: Theme.atTone(Theme.cError, Theme.isLight ? 80 : 40)

    // a picked colour shows as itself rather than as an icon
    function popupSwatch(hex, text) {
        toastWindow.swatch = hex;
        toastWindow.hasSwatch = true;
        toastWindow.label = text;
        toastWindow.warn = false;
        toastWindow.popIn();
    }

    function popup(icon, text, isWarn) {
        toastWindow.hasSwatch = false;
        toastWindow.iconPath = toastWindow.icons[icon] || icon || toastWindow.icons["info"];
        toastWindow.label = text;
        toastWindow.warn = isWarn === true;
        toastWindow.popIn();
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
        onTriggered: toastWindow.popOut()
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
        width: leadIcon.width + toastWindow.iconGap + Math.ceil(labelMetrics.advanceWidth) + toastWindow.pillPad * 2
        radius: Theme.shapeFull
        color: Theme.inverseSurface
        opacity: toastWindow.shown ? 1 : 0
        scale: toastWindow.shown ? 1 : 0.92

        TextMetrics {
            id: labelMetrics

            text: toastWindow.label
            font.family: Theme.fontFamily
            font.bold: true
            font.pixelSize: Theme.fontBodyMd
            font.variableAxes: Theme.axes(Theme.fontBodyMd, 640, 0)
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
                radius: Theme.shapeFull
                color: toastWindow.swatch
                // a pick close to the pill's own colour would vanish without this
                border.color: Theme.alpha(Theme.fgInverseSurface, 0.3)
                border.width: 1
            }

            Icon {
                visible: !toastWindow.hasSwatch && /^[a-z0-9_]+$/.test(toastWindow.iconPath)
                anchors.centerIn: parent
                name: visible ? toastWindow.iconPath : ""
                size: toastWindow.glyphSize + 2
                fill: 1
                color: toastWindow.warn ? toastWindow.warnTone : Theme.inversePrimary
            }

            Shape {
                visible: !toastWindow.hasSwatch && !/^[a-z0-9_]+$/.test(toastWindow.iconPath)
                width: 24
                height: 24
                scale: toastWindow.glyphSize / 24
                anchors.centerIn: parent
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    fillColor: toastWindow.warn ? toastWindow.warnTone : Theme.inversePrimary
                    strokeWidth: 0

                    PathSvg {
                        path: /^[a-z0-9_]+$/.test(toastWindow.iconPath) ? "" : toastWindow.iconPath
                    }

                }

            }

        }

        Text {
            anchors.left: leadIcon.right
            anchors.leftMargin: toastWindow.iconGap
            anchors.verticalCenter: parent.verticalCenter
            text: toastWindow.label
            color: Theme.fgInverseSurface
            font.family: Theme.fontFamily
            font.bold: true
            font.pixelSize: Theme.fontBodyMd
            font.variableAxes: Theme.axes(Theme.fontBodyMd, 640, 0)
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
