import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import qs

Column {
    id: page

    readonly property string home: Quickshell.env("HOME")
    readonly property var blurSteps: [0, 0.2, 0.5, 0.8, 1]
    readonly property var blurLabels: ["Off", "Light", "Balanced", "Heavy", "Full"]
    readonly property int blurIndex: {
        var best = 0, dist = 999;
        for (var i = 0; i < page.blurSteps.length; i++) {
            var d = Math.abs(page.blurSteps[i] - Theme.blurAmount);
            if (d < dist) {
                dist = d;
                best = i;
            }
        }
        return best;
    }
    property string currentTheme: "matugen"
    property string appliedWallpaper: ""
    readonly property string wallpaperDir: Prefs.wallpaperFolder !== "" ? Prefs.wallpaperFolder : (page.home + "/Pictures/wallpapers/" + page.currentTheme)

    function applyTheme(id) {
        if (id === page.currentTheme)
            return ;

        Prefs.themeChangeRequested(id);
    }

    function applyWallpaper(path) {
        if (path === "")
            return;

        Quickshell.execDetached([page.home + "/.config/hypr/scripts/wallpaper/set-wallpaper.sh", path]);
    }

    spacing: 26

    FileView {
        path: page.home + "/.cache/current_theme"
        blockLoading: true
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            var t = text().trim();
            page.currentTheme = t !== "" ? t : "matugen";
        }
    }

    onWallpaperDirChanged: wallpaperScan.restart()

    Process {
        id: wallpaperScan

        function restart() {
            wallpaperScan.running = false;
            wallpaperScan.command = ["sh", "-c", "d=\"" + page.wallpaperDir + "\"; [ -d \"$d\" ] || exit 0; find \"$d\" -maxdepth 1 -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \\) | sort"];
            wallpaperScan.running = true;
        }

        stdout: StdioCollector {
            onStreamFinished: {
                wallpapers.clear();
                var lines = text.split("\n");
                for (var i = 0; i < lines.length; i++) {
                    var p = lines[i].trim();
                    if (p === "")
                        continue;

                    var base = p.substring(p.lastIndexOf("/") + 1);
                    var dot = base.lastIndexOf(".");
                    wallpapers.append({
                        "path": p,
                        "name": dot > 0 ? base.substring(0, dot) : base
                    });
                }
            }
        }

    }

    Process {
        id: wallpaperPicker

        stdout: StdioCollector {
            onStreamFinished: {
                var chosen = text.trim();
                if (chosen === "")
                    return;

                wallpaperImport.command = ["sh", "-c", "mkdir -p \"" + page.wallpaperDir + "\" && cp -n \"" + chosen + "\" \"" + page.wallpaperDir + "/\" && echo \"" + page.wallpaperDir + "/$(basename \"" + chosen + "\")\""];
                wallpaperImport.running = true;
            }
        }

    }

    Process {
        id: wallpaperImport

        stdout: StdioCollector {
            onStreamFinished: {
                var added = text.trim();
                wallpaperScan.restart();
                Prefs.wallpapersChanged();
                if (added !== "")
                    page.applyWallpaper(added);

            }
        }

    }

    FileView {
        path: page.home + "/.cache/current_wallpaper"
        blockLoading: true
        watchChanges: true
        onFileChanged: reload()
        onLoaded: page.appliedWallpaper = text().trim()
    }

    Process {
        id: wallpaperDelete

        stdout: StdioCollector {
            onStreamFinished: {
                wallpaperScan.restart();
                Prefs.wallpapersChanged();
            }
        }

    }

    Connections {
        function onWallpaperDeleteRequested(path) {
            wallpaperDelete.running = false;
            wallpaperDelete.command = ["sh", "-c", "gio trash \"" + path + "\" 2>/dev/null || rm -f \"" + path + "\"; echo done"];
            wallpaperDelete.running = true;
        }

        target: Prefs
    }

    ListModel {
        id: wallpapers
    }

    Component.onCompleted: wallpaperScan.restart()

    SettingCard {
        title: "SHAPE"

        SettingRow {
            title: "Bar style"
            description: "Islands float free of the screen edge. Notches sit flush against it, squaring off the corners that meet it."

            M3Segmented {
                width: 260
                current: Prefs.barStyle
                options: [{
                    "key": "island",
                    "label": "Islands"
                }, {
                    "key": "notch",
                    "label": "Notches"
                }]
                onChosen: (key) => {
                    return Prefs.barStyle = key;
                }
            }

        }

        SettingRow {
            title: "Dock style"
            description: "The same choice for the dock, against the bottom edge."
            showDivider: false

            M3Segmented {
                width: 260
                current: Prefs.dockStyle
                options: [{
                    "key": "island",
                    "label": "Islands"
                }, {
                    "key": "notch",
                    "label": "Notches"
                }]
                onChosen: (key) => {
                    return Prefs.dockStyle = key;
                }
            }

        }

    }

    SettingCard {
        title: "SURFACES"

        SettingRow {
            title: "Glass"
            resetAction: Prefs.resetBlurToken
            resetVisible: Theme.blurAmount !== 0
            description: "How far the compositor blurs the desktop through the shell's surfaces. This replaced the launcher's old >blur strip, which now opens this page instead."
            warning: "Frosting is handled by the compositor, not the shell, and is buggy \u2014 expect visual artefacts. Set this to Off to avoid them."
            stacked: true

            M3Slider {
                width: parent.width
                from: 0
                to: 4
                stepSize: 1
                stepLabels: page.blurLabels
                value: page.blurIndex
                onMoved: (v) => {
                    return Theme.setBlurAmount(page.blurSteps[Math.round(v)]);
                }
            }

        }

        SettingRow {
            title: "Accent intensity"
            resetKey: "accentPunch"
            description: "Lifts the accent colour away from the wallpaper-derived original. 1.0 uses it exactly as generated."
            stacked: true

            M3Slider {
                width: parent.width
                from: 1
                to: 2
                stepSize: 0.05
                decimals: 2
                value: Prefs.accentPunch
                onMoved: (v) => {
                    return Prefs.accentPunch = v;
                }
            }

        }

        SettingRow {
            title: "Surface darkness"
            resetKey: "surfaceDarkness"
            description: "How far every panel is darkened beneath the theme's own surface colour. Auto follows the theme."
            showDivider: false
            stacked: true

            Row {
                spacing: 16
                width: parent.width

                M3Slider {
                    width: parent.width - resetDark.width - 16
                    enabled: Prefs.surfaceDarkness >= 0
                    from: 0
                    to: 0.8
                    stepSize: 0.05
                    decimals: 2
                    value: Prefs.surfaceDarkness >= 0 ? Prefs.surfaceDarkness : 0.45
                    onMoved: (v) => {
                        return Prefs.surfaceDarkness = v;
                    }
                }

                M3Button {
                    id: resetDark

                    anchors.verticalCenter: parent.verticalCenter
                    text: Prefs.surfaceDarkness >= 0 ? "Auto" : "Manual"
                    variant: Prefs.surfaceDarkness >= 0 ? "tonal" : "filled"
                    onClicked: Prefs.surfaceDarkness = Prefs.surfaceDarkness >= 0 ? -1 : 0.45
                }

            }

        }

    }

    SettingCard {
        title: "MOTION & TYPE"

        SettingRow {
            title: "Animation speed"
            resetKey: "motionScale"
            description: "Scales every transition in the shell. 1.00x is the shipped speed; drag to 0 for no animation at all."
            stacked: true

            M3Slider {
                width: parent.width
                from: 0
                to: 2
                stepSize: 0.25
                decimals: 2
                suffix: "x"
                value: Prefs.motionScale
                onMoved: (v) => {
                    return Prefs.motionScale = v;
                }
            }

        }

        SettingRow {
            title: "Interface font"
            resetKey: "fontFamily"
            description: "Applied everywhere the shell draws text. Chosen from the fonts installed on this machine."

            M3Button {
                text: Prefs.fontFamily
                variant: "tonal"
                onClicked: Prefs.fontPickerRequested()
            }

        }

        SettingRow {
            title: "Text size"
            resetKey: "fontScale"
            description: "Scales the shell's whole type ramp at once."
            showDivider: false
            stacked: true

            M3Slider {
                width: parent.width
                from: 0.8
                to: 1.4
                stepSize: 0.05
                decimals: 2
                suffix: "x"
                value: Prefs.fontScale
                onMoved: (v) => {
                    return Prefs.fontScale = v;
                }
            }

        }

    }

    SettingCard {
        title: "THEME"

        SettingRow {
            title: "Colour scheme"
            description: "Switching also swaps the wallpaper folder below to that theme's own."
            showDivider: false
            stacked: true

            Flow {
                width: parent.width
                spacing: 10

                Repeater {
                    model: Prefs.themeCatalogue

                    Rectangle {
                        id: swatch

                        required property var modelData

                        readonly property bool selected: page.currentTheme === swatch.modelData.id

                        width: 150
                        height: 60
                        radius: Theme.radiusMd
                        color: swatch.selected ? Theme.accentContainer : (swatchArea.containsMouse ? Theme.bgHover : Theme.bgSunken)

                        Behavior on color {
                            ColorAnimation {
                                duration: Theme.durShort
                            }

                        }

                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 10

                            Rectangle {
                                width: 28
                                height: 28
                                radius: 14
                                anchors.verticalCenter: parent.verticalCenter
                                color: swatch.modelData.swatchBg

                                Rectangle {
                                    width: 12
                                    height: 12
                                    radius: 6
                                    anchors.centerIn: parent
                                    color: swatch.modelData.swatchAccent
                                }

                            }

                            Text {
                                width: 90
                                anchors.verticalCenter: parent.verticalCenter
                                text: swatch.modelData.name
                                color: swatch.selected ? Theme.text : Theme.subtext
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontLabel
                                font.bold: swatch.selected
                                wrapMode: Text.WordWrap
                            }

                        }

                        MouseArea {
                            id: swatchArea

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: page.applyTheme(swatch.modelData.id)
                        }

                    }

                }

            }

        }

    }

    SettingCard {
        title: "WALLPAPER"

        SettingRow {
            title: "Wallpaper strip"
            description: wallpapers.count + " in " + page.wallpaperDir.replace(page.home, "~")
            stacked: true

            Column {
                width: parent.width
                spacing: 14

                Flow {
                    width: parent.width
                    spacing: 10

                    Repeater {
                        model: wallpapers

                        Rectangle {
                            id: tile

                            required property string path
                            required property string name

                            readonly property bool selected: page.appliedWallpaper === tile.path

                            width: 150
                            height: 88
                            radius: Theme.radiusSm
                            color: Theme.bgSunken

                            Image {
                                id: thumb

                                anchors.fill: parent
                                source: "file://" + tile.path
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                cache: true
                                sourceSize.width: 300
                                sourceSize.height: 176
                                visible: false
                            }

                            Rectangle {
                                id: thumbMask

                                anchors.fill: parent
                                radius: tile.radius
                                visible: false
                                layer.enabled: true
                            }

                            OpacityMask {
                                anchors.fill: parent
                                source: thumb
                                maskSource: thumbMask
                                visible: thumb.status === Image.Ready
                            }

                            Rectangle {
                                anchors.fill: parent
                                radius: parent.radius
                                color: "transparent"
                                border.width: tile.selected ? 3 : (tileArea.containsMouse ? 2 : 0)
                                border.color: tile.selected ? Theme.accent : Theme.alpha(Theme.text, 0.5)

                                Behavior on border.width {
                                    NumberAnimation {
                                        duration: Theme.durQuick
                                    }

                                }

                            }

                            MouseArea {
                                id: tileArea

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: page.applyWallpaper(tile.path)
                            }

                            Rectangle {
                                id: delBtn

                                readonly property bool active: tileArea.containsMouse || delArea.containsMouse

                                width: 28
                                height: 28
                                radius: 14
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.margins: 6
                                color: delArea.containsMouse ? Theme.error : Theme.alpha(Theme.cShadow, 0.65)
                                opacity: delBtn.active ? 1 : 0
                                visible: opacity > 0.01
                                scale: delBtn.active ? 1 : 0.7

                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: Theme.durQuick
                                    }

                                }

                                Behavior on scale {
                                    NumberAnimation {
                                        duration: Theme.durShort
                                        easing.type: Theme.easeEmphasized
                                        easing.overshoot: Theme.emphasizedOvershoot
                                    }

                                }

                                Behavior on color {
                                    ColorAnimation {
                                        duration: Theme.durQuick
                                    }

                                }

                                Item {
                                    id: bin

                                    readonly property color glyph: delArea.containsMouse ? Theme.onError : "white"
                                    // authored on a 24x24 grid, drawn at 16
                                    readonly property real unit: 16 / 24
                                    readonly property real stroke: 2.4
                                    property real lidAngle: delArea.containsMouse ? 32 : 0
                                    property real lidLift: delArea.containsMouse ? -1.4 : 0

                                    anchors.centerIn: parent
                                    width: 16
                                    height: 16

                                    Behavior on lidAngle {
                                        NumberAnimation {
                                            duration: Theme.durMedium
                                            easing.type: Theme.easeEmphasized
                                            easing.overshoot: 1.5
                                        }

                                    }

                                    Behavior on lidLift {
                                        NumberAnimation {
                                            duration: Theme.durMedium
                                            easing.type: Theme.easeEmphasized
                                            easing.overshoot: 1.5
                                        }

                                    }

                                    Shape {
                                        anchors.fill: parent
                                        preferredRendererType: Shape.CurveRenderer

                                        ShapePath {
                                            strokeColor: bin.glyph
                                            strokeWidth: bin.stroke
                                            fillColor: "transparent"
                                            capStyle: ShapePath.RoundCap
                                            joinStyle: ShapePath.RoundJoin

                                            PathSvg {
                                                path: "M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6"
                                            }

                                        }

                                        ShapePath {
                                            strokeColor: bin.glyph
                                            strokeWidth: bin.stroke
                                            fillColor: "transparent"
                                            capStyle: ShapePath.RoundCap

                                            PathSvg {
                                                path: "M10 11v6"
                                            }

                                        }

                                        ShapePath {
                                            strokeColor: bin.glyph
                                            strokeWidth: bin.stroke
                                            fillColor: "transparent"
                                            capStyle: ShapePath.RoundCap

                                            PathSvg {
                                                path: "M14 11v6"
                                            }

                                        }

                                        transform: Scale {
                                            xScale: bin.unit
                                            yScale: bin.unit
                                        }

                                    }

                                    Item {
                                        anchors.fill: parent

                                        transform: Rotation {
                                            origin.x: 21 * bin.unit
                                            origin.y: 6 * bin.unit
                                            angle: bin.lidAngle
                                        }

                                        Shape {
                                            anchors.fill: parent
                                            y: bin.lidLift
                                            preferredRendererType: Shape.CurveRenderer

                                            ShapePath {
                                                strokeColor: bin.glyph
                                                strokeWidth: bin.stroke
                                                fillColor: "transparent"
                                                capStyle: ShapePath.RoundCap

                                                PathSvg {
                                                    path: "M3 6h18"
                                                }

                                            }

                                            ShapePath {
                                                strokeColor: bin.glyph
                                                strokeWidth: bin.stroke
                                                fillColor: "transparent"
                                                capStyle: ShapePath.RoundCap
                                                joinStyle: ShapePath.RoundJoin

                                                PathSvg {
                                                    path: "M8 6V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"
                                                }

                                            }

                                            transform: Scale {
                                                xScale: bin.unit
                                                yScale: bin.unit
                                            }

                                        }

                                    }

                                }

                                MouseArea {
                                    id: delArea

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Prefs.askConfirm("Delete this wallpaper?", "\"" + tile.name + "\" is moved to the trash, so it can be restored from there if you change your mind.", "Delete", "wallpaper:" + tile.path)
                                }

                            }

                        }

                    }

                }

                Text {
                    text: "No images in this folder yet - add one below."
                    color: Theme.subtext
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontBody
                    visible: wallpapers.count === 0
                }

                Row {
                    spacing: 10

                    M3Button {
                        text: "Add wallpaper..."
                        variant: "filled"
                        iconPath: "M19 13h-6v6h-2v-6H5v-2h6V5h2v6h6v2Z"
                        onClicked: {
                            wallpaperPicker.command = ["sh", "-c", "zenity --file-selection --title='Add wallpaper' --file-filter='Images | *.jpg *.jpeg *.png *.webp *.JPG *.PNG' 2>/dev/null || true"];
                            wallpaperPicker.running = true;
                        }
                    }

                    M3Button {
                        text: "Open folder"
                        onClicked: Quickshell.execDetached(["sh", "-c", "xdg-open '" + page.wallpaperDir + "'"])
                    }

                    M3Button {
                        text: "Rescan"
                        variant: "text"
                        onClicked: wallpaperScan.restart()
                    }

                }

            }

        }

        SettingRow {
            title: "Custom folder"
            description: "Leave empty to follow the current theme's own wallpaper folder."
            showDivider: false

            M3TextField {
                width: 260
                text: Prefs.wallpaperFolder
                placeholder: "~/Pictures/wallpapers/" + page.currentTheme
                onAccepted: (v) => {
                    return Prefs.wallpaperFolder = v.trim().replace("~", page.home);
                }
            }

        }

    }

}
