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
    // a single character a script sent in place of an icon
    property string iconGlyph: ""
    property string label: ""
    // a quieter second part, after the label
    property string detail: ""
    property bool warn: false
    property color swatch: "transparent"
    property bool hasSwatch: false

    // m3 snackbar metrics: 48dp container, 16dp leading pad, 12dp icon gap
    readonly property int pillHeight: Theme.dp(48)
    readonly property int pillPad: Theme.dp(16)
    readonly property int iconGap: Theme.dp(12)
    readonly property int glyphSize: Theme.dp(20)
    readonly property int labelMax: Theme.dp(340)
    readonly property int detailMax: Theme.dp(260)

    // system events wait their turn here instead of cutting each other off
    property var queue: []
    // how many may wait; a burst past it sheds the oldest plain entry
    property int queueCap: 8
    // what is on screen, so a newer event of the same kind updates it in place
    property string currentKey: ""

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
    // the same surface as the osd and the panels, so it follows the mode like they do
    readonly property color warnTone: Theme.error

    // entry: { icon, label, detail, warn, swatch, key, ms }. icon is a name from
    // the list above, raw svg path data, or a single glyph
    function present(entry) {
        const icon = entry.icon || "";
        // a short name from the list, or any material symbol by its own name
        const named = toastWindow.icons[icon] || (/^[a-z0-9_]{3,}$/.test(icon) ? icon : undefined);
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
    implicitWidth: Math.max(Theme.dp(160), pill.width + Theme.dp(40))
    implicitHeight: Theme.dp(88)
    margins.top: Theme.dp(10)
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
        y: toastWindow.shown ? Theme.dp(20) : Theme.dp(2)
        height: toastWindow.pillHeight
        width: leadIcon.width + toastWindow.iconGap + labelText.width + (detailText.visible ? toastWindow.iconGap + detailText.width : 0) + toastWindow.pillPad * 2
        radius: Theme.shapeFull
        color: Theme.bg
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
                radius: Theme.shapeFull
                color: toastWindow.swatch
                // a pick close to the pill's own colour would vanish without this
                border.color: Theme.alpha(Theme.text, 0.3)
                border.width: 1
            }

            Icon {
                visible: !toastWindow.hasSwatch && /^[a-z0-9_]+$/.test(toastWindow.iconPath)
                anchors.centerIn: parent
                name: visible ? toastWindow.iconPath : ""
                size: toastWindow.glyphSize + Theme.dp(2)
                fill: 1
                color: toastWindow.warn ? toastWindow.warnTone : Theme.accent
            }

            Text {
                visible: !toastWindow.hasSwatch && toastWindow.iconGlyph !== ""
                anchors.centerIn: parent
                text: toastWindow.iconGlyph
                color: toastWindow.warn ? toastWindow.warnTone : Theme.accent
                font.family: Theme.fontFamily
                font.pixelSize: toastWindow.glyphSize
            }

            Shape {
                visible: !toastWindow.hasSwatch && toastWindow.iconGlyph === "" && !/^[a-z0-9_]+$/.test(toastWindow.iconPath)
                width: 24
                height: 24
                scale: toastWindow.glyphSize / 24
                anchors.centerIn: parent
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    fillColor: toastWindow.warn ? toastWindow.warnTone : Theme.accent
                    strokeWidth: 0

                    PathSvg {
                        path: /^[a-z0-9_]+$/.test(toastWindow.iconPath) ? "" : toastWindow.iconPath
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
            font.variableAxes: Theme.axes(Theme.fontBodyMd, 640, 0)
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
