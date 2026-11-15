import QtQuick
import QtQuick.Effects
import qs
import qs.lucidui

// get info: a file's details on a sheet that grows out of its icon, the way a mac's
// info window does. its tags can be set here, and a file allowed to run
Item {
    id: sheet

    readonly property var item: DesktopIcons.byKey[DesktopIcons.infoKey] || null
    // held through the closing animation
    property var shown: null
    readonly property var d: DesktopIcons.info
    readonly property var spot: sheet.shown ? (DesktopIcons.placed[sheet.shown.key] || null) : null
    property real t: 0
    readonly property bool isDir: sheet.shown !== null && (sheet.shown.kind === "dir" || sheet.shown.kind === "home" || sheet.shown.kind === "drive")
    readonly property bool hasDisk: sheet.shown !== null && (sheet.shown.kind === "drive" || sheet.shown.kind === "home") && sheet.d && sheet.d.fsSize > 0
    readonly property rect from: sheet.spot ? Qt.rect(DesktopIcons.tileX(sheet.spot.c) + (DesktopIcons.tileW - DesktopIcons.iconPx) / 2, DesktopIcons.tileY(sheet.spot.r) + DesktopIcons.iconTop, DesktopIcons.iconPx, DesktopIcons.iconPx) : Qt.rect(sheet.width / 2, sheet.height / 2, 0, 0)
    readonly property real cardW: Theme.dp(400)
    readonly property real cardH: Math.min(sheet.height - Theme.dp(80), content.implicitHeight + Theme.dp(48))
    readonly property rect to: Qt.rect(Math.round((sheet.width - sheet.cardW) / 2), Math.round((sheet.height - sheet.cardH) / 2), sheet.cardW, sheet.cardH)
    readonly property var rows: {
        var it = sheet.shown;
        var d = sheet.d;
        if (!it)
            return [];

        var out = [];
        var size = "";
        if (!d)
            size = "…";
        else if (sheet.isDir && !d.counted)
            size = "Counting…";
        else if (sheet.isDir)
            size = (d.partial ? I18n.tr("At least ") : "") + DesktopIcons.human(d.size) + "  ·  " + (d.items === 1 ? I18n.tr("1 item") : I18n.tr("%1 items", d.items));
        else
            size = DesktopIcons.human(it.size || (d ? d.size : 0));
        if (it.kind !== "drive")
            out.push([I18n.tr("Size"), size]);

        if (d && d.where)
            out.push(["Where", d.where.replace(DesktopIcons.home, "~")]);

        if (d && d.target)
            out.push(["Links to", d.target.replace(DesktopIcons.home, "~")]);

        if (d && d.app)
            out.push([sheet.isDir ? I18n.tr("Opens in") : I18n.tr("Opens with"), d.app]);

        if (d && d.created)
            out.push([I18n.tr("Created"), DesktopIcons.when(d.created)]);

        if (d && d.modified)
            out.push([I18n.tr("Modified"), DesktopIcons.when(d.modified)]);

        if (d && d.accessed)
            out.push([I18n.tr("Opened"), DesktopIcons.when(d.accessed)]);

        if (d && d.owner)
            out.push([I18n.tr("Owner"), d.owner + (d.group && d.group !== d.owner ? " (" + d.group + ")" : "")]);

        if (d && d.mode)
            out.push([I18n.tr("Permissions"), d.mode]);

        return out;
    }

    // shrunk all the way back: the loader can let go
    signal closed()

    function lerp(a, b) {
        return a + (b - a) * sheet.t;
    }

    function take() {
        if (sheet.item) {
            sheet.shown = sheet.item;
            closing.stop();
            if (sheet.t < 1)
                opening.restart();

        } else {
            opening.stop();
            closing.restart();
        }
    }

    anchors.fill: parent
    visible: sheet.t > 0.001
    onItemChanged: sheet.take()
    Component.onCompleted: sheet.take()

    NumberAnimation {
        id: opening

        target: sheet
        property: "t"
        to: 1
        duration: Theme.durEnter + 60
        easing.type: Easing.Bezier
        easing.bezierCurve: Theme.easeEmphasizedDecel
    }

    NumberAnimation {
        id: closing

        target: sheet
        property: "t"
        to: 0
        duration: Theme.durExit + 40
        easing.type: Easing.Bezier
        easing.bezierCurve: Theme.easeEmphasizedAccel
        onFinished: {
            sheet.shown = null;
            sheet.closed();
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.alpha(Theme.cShadow, 0.42 * sheet.t)

        MouseArea {
            anchors.fill: parent
            enabled: DesktopIcons.infoKey !== ""
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onPressed: DesktopIcons.closeInfo()
        }

    }

    Rectangle {
        id: card

        x: sheet.lerp(sheet.from.x, sheet.to.x)
        y: sheet.lerp(sheet.from.y, sheet.to.y)
        width: sheet.lerp(sheet.from.width, sheet.to.width)
        height: sheet.lerp(sheet.from.height, sheet.to.height)
        radius: sheet.lerp(Theme.radiusSm, Theme.radiusXl)
        color: Theme.surfaceHigh
        clip: true
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowBlur: 1
            shadowColor: Qt.rgba(0, 0, 0, 0.45)
            shadowVerticalOffset: Theme.dp(8)
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
        }

        Column {
            id: content

            x: Theme.dp(24)
            y: Theme.dp(24)
            width: sheet.cardW - Theme.dp(48)
            spacing: Theme.dp(16)
            opacity: Math.max(0, (sheet.t - 0.4) / 0.6)

            // the picture in a tonal well, its name and kind beside it
            Row {
                width: parent.width
                spacing: Theme.dp(16)

                Rectangle {
                    width: Theme.dp(76)
                    height: Theme.dp(76)
                    radius: Theme.radiusLg
                    color: Theme.secondaryContainer

                    Image {
                        anchors.centerIn: parent
                        width: Theme.dp(56)
                        height: Theme.dp(56)
                        source: !sheet.shown ? "" : (sheet.shown.thumb ? "file://" + sheet.shown.thumb : (sheet.shown.icon ? "file://" + sheet.shown.icon : ""))
                        sourceSize.width: Math.round(width * DesktopIcons.dpr)
                        sourceSize.height: Math.round(height * DesktopIcons.dpr)
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                    }

                }

                Column {
                    width: parent.width - Theme.dp(92)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.dp(2)

                    Text {
                        width: parent.width
                        text: sheet.shown ? sheet.shown.label : ""
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontTitleMd
                        font.weight: Font.DemiBold
                        wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                        maximumLineCount: 3
                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width
                        text: sheet.d && sheet.d.desc ? sheet.d.desc : (sheet.shown ? sheet.shown.desc : "")
                        color: Theme.subtext
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontBodyMd
                        elide: Text.ElideRight
                    }

                }

            }

            // tags: tap a colour to put it on or take it off
            Row {
                visible: sheet.shown !== null && DesktopIcons.filesOf([sheet.shown.key]).length > 0
                spacing: Theme.dp(10)

                Repeater {
                    model: DesktopIcons.tagNames

                    Rectangle {
                        id: swatch

                        required property string modelData
                        readonly property bool on: sheet.item !== null && sheet.item.tags.indexOf(swatch.modelData) >= 0

                        width: Theme.dp(26)
                        height: Theme.dp(26)
                        radius: width / 2
                        color: DesktopIcons.tagColor(swatch.modelData)
                        border.width: swatch.on ? Theme.dp(2) : 0
                        border.color: Theme.text
                        scale: swatchHover.hovered ? 1.12 : 1

                        Icon {
                            anchors.centerIn: parent
                            visible: swatch.on
                            size: Theme.dp(16)
                            name: "check"
                            color: Theme.isLight ? "#ffffff" : "#000000"
                        }

                        HoverHandler {
                            id: swatchHover
                        }

                        TapHandler {
                            onTapped: DesktopIcons.toggleTag(swatch.modelData, [sheet.shown.key])
                        }

                        Behavior on scale {
                            NumberAnimation {
                                duration: Theme.durQuick
                            }

                        }

                    }

                }

            }

            // a drive's (or home's) space, used and free
            Column {
                visible: sheet.hasDisk
                width: parent.width
                spacing: Theme.dp(6)

                LinearProgress {
                    width: parent.width
                    thickness: Theme.dp(8)
                    value: sheet.hasDisk ? 1 - sheet.d.fsFree / sheet.d.fsSize : 0
                    color: Theme.accent
                }

                Text {
                    text: sheet.hasDisk ? I18n.tr("%1 free of %2", DesktopIcons.human(sheet.d.fsFree), DesktopIcons.human(sheet.d.fsSize)) + (sheet.d.fsType ? "  ·  " + sheet.d.fsType : "") : ""
                    color: Theme.subtext
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontLabelLg
                }

            }

            // the details, two columns on a tonal block
            Rectangle {
                width: parent.width
                height: details.implicitHeight + Theme.dp(20)
                radius: Theme.radiusLg
                color: Theme.alpha(Theme.text, 0.04)

                Column {
                    id: details

                    x: Theme.dp(16)
                    y: Theme.dp(10)
                    width: parent.width - Theme.dp(32)
                    spacing: Theme.dp(8)

                    Repeater {
                        model: sheet.rows

                        Row {
                            required property var modelData

                            width: details.width
                            spacing: Theme.dp(12)

                            Text {
                                width: Theme.dp(96)
                                text: parent.modelData[0]
                                color: Theme.subtext
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontLabelLg
                            }

                            Text {
                                width: details.width - Theme.dp(108)
                                text: parent.modelData[1]
                                color: Theme.text
                                font.family: parent.modelData[0] === I18n.tr("Permissions") ? (Prefs.envMonoFont !== "" ? Prefs.envMonoFont : "monospace") : Theme.fontFamily
                                font.pixelSize: Theme.fontLabelLg
                                font.weight: Font.Medium
                                wrapMode: Text.WrapAnywhere
                                maximumLineCount: 3
                                elide: Text.ElideRight
                            }

                        }

                    }

                }

            }

            // a file allowed to run as a program, or not
            Item {
                width: parent.width
                height: Theme.dp(40)
                visible: sheet.d !== null && !sheet.isDir && sheet.d.writable && sheet.shown && sheet.shown.kind !== "drive"

                Text {
                    anchors.left: parent.left
                    anchors.right: execSwitch.left
                    anchors.rightMargin: Theme.dp(12)
                    anchors.verticalCenter: parent.verticalCenter
                    text: I18n.tr("Allow running as a program")
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontBodyMd
                    elide: Text.ElideRight
                }

                Switch {
                    id: execSwitch

                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    checked: sheet.d ? sheet.d.exec : false
                    onToggled: (v) => {
                        return DesktopIcons.setExecutable(sheet.shown.key, v);
                    }
                }

            }

            Row {
                anchors.right: parent.right
                spacing: Theme.dp(8)

                Button {
                    variant: "text"
                    text: I18n.tr("Close")
                    onClicked: DesktopIcons.closeInfo()
                }

                Button {
                    variant: "tonal"
                    text: I18n.tr("Open")
                    icon: "open_in_new"
                    onClicked: {
                        var k = sheet.shown ? sheet.shown.key : "";
                        DesktopIcons.closeInfo();
                        if (k !== "")
                            DesktopIcons.open(k);

                    }
                }

            }

        }

    }

}
