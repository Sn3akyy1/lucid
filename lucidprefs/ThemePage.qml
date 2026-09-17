import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import qs

Column {
    id: page

    readonly property string home: Quickshell.env("HOME")
    readonly property string currentTheme: Prefs.currentTheme
    readonly property var modeOptions: [{
        "key": "dark",
        "label": "Dark"
    }, {
        "key": "light",
        "label": "Light"
    }]
    // the two wallpaper-derived themes re-extract; everything else is authored
    // dark and gets a light variant built from its own colours
    readonly property string modeHint: page.currentTheme === "matugen" || page.currentTheme === "pywal" ? "Re-derives the palette from your wallpaper in the mode you pick. Applications are asked to match." : "Builds a light palette from this theme's own colours. Applications are asked to match."
    property string appliedWallpaper: ""
    // same folder the dock's wallpaper strip browses
    readonly property string wallpaperDir: Prefs.wallpaperDir
    // idle | working | done | error
    property string addState: "idle"
    property string addMessage: ""
    property var addResult: null
    property string repoUrl: ""

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

    function importTheme() {
        var url = page.repoUrl.trim();
        if (url === "" || page.addState === "working")
            return;

        page.addState = "working";
        page.addMessage = "Cloning and reading the scheme...";
        page.addResult = null;
        themeImport.running = false;
        themeImport.command = ["python3", page.home + "/.config/lucid/add-theme.py", url];
        themeImport.running = true;
    }

    spacing: 26

    onWallpaperDirChanged: wallpaperScan.restart()

    Process {
        id: themeImport

        property string errText: ""

        stdout: StdioCollector {
            onStreamFinished: {
                var r = null;
                try {
                    r = JSON.parse(text.trim());
                } catch (e) {
                    r = null;
                }
                if (!r) {
                    page.addState = "error";
                    // a crash leaves stdout empty, so the traceback is the only clue
                    page.addMessage = themeImport.errText.trim().split("\n").pop() || "Import failed.";
                    return ;
                }
                if (!r.ok) {
                    page.addState = "error";
                    page.addMessage = r.error;
                    return ;
                }
                page.addState = "done";
                page.addResult = r;
                // the generated description is the point; the wallpaper count is an aside
                page.addMessage = r.desc + (r.wallpapers > 0 ? "  \u00b7  " + r.wallpapers + " wallpapers" : "  \u00b7  no wallpapers, fallback used");
                Prefs.rescanThemes();
            }
        }

        stderr: StdioCollector {
            onStreamFinished: themeImport.errText = text
        }

    }

    Process {
        id: themeDelete

        stdout: StdioCollector {
            onStreamFinished: Prefs.rescanThemes()
        }

    }

    Connections {
        function onThemeDeleteRequested(id) {
            themeDelete.running = false;
            themeDelete.command = ["sh", "-c", "rm -rf \"" + page.home + "/.config/lucid/themes/" + id + "\"; echo done"];
            themeDelete.running = true;
        }

        target: Prefs
    }

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

    // the grid reorders this in place, so it cannot just bind to the catalogue
    ListModel {
        id: themeTiles
    }

    function syncThemeTiles() {
        // never yank the tiles out from under a drag in progress
        if (themeGrid.dragging)
            return;

        themeTiles.clear();
        var c = Prefs.themeCatalogue;
        for (var i = 0; i < c.length; i++) {
            themeTiles.append({
                "themeId": c[i].id,
                "themeName": c[i].name,
                "tileBg": c[i].swatchBg,
                "tileAccent": c[i].swatchAccent,
                "isUser": c[i].user === true
            });
        }
    }

    Connections {
        function onThemeCatalogueChanged() {
            page.syncThemeTiles();
        }

        target: Prefs
    }

    Component.onCompleted: {
        wallpaperScan.restart();
        page.syncThemeTiles();
    }

    SettingCard {
        title: "THEME"

        SettingRow {
            title: "Light or dark"
            description: page.modeHint

            M3Segmented {
                width: 200
                current: Prefs.colorMode
                options: page.modeOptions
                onChosen: (key) => {
                    return Prefs.setColorMode(key);
                }
            }

        }

        SettingRow {
            title: "Colour scheme"
            description: "Switching also swaps the wallpaper folder below to that theme's own."
            showDivider: false
            stacked: true

            Item {
                id: themeGrid

                readonly property int tileW: 150
                readonly property int tileH: 60
                readonly property int gap: 10
                readonly property int perRow: Math.max(1, Math.floor((themeGrid.width + themeGrid.gap) / (themeGrid.tileW + themeGrid.gap)))
                property bool dragging: false

                width: parent.width
                height: Math.max(0, Math.ceil(themeTiles.count / themeGrid.perRow) * (themeGrid.tileH + themeGrid.gap) - themeGrid.gap)

                function commitOrder() {
                    var ids = [];
                    for (var i = 0; i < themeTiles.count; i++) ids.push(themeTiles.get(i).themeId);
                    Prefs.setThemeOrder(ids);
                }

                Repeater {
                    model: themeTiles

                    Rectangle {
                        id: swatch

                        required property string themeId
                        required property string themeName
                        required property string tileBg
                        required property string tileAccent
                        required property bool isUser
                        required property int index

                        readonly property bool selected: page.currentTheme === swatch.themeId
                        readonly property real targetX: (swatch.index % themeGrid.perRow) * (themeGrid.tileW + themeGrid.gap)
                        readonly property real targetY: Math.floor(swatch.index / themeGrid.perRow) * (themeGrid.tileH + themeGrid.gap)

                        // the tile owns x/y while dragging; the Binding takes them back after
                        function reindex() {
                            if (!themeDrag.active)
                                return;

                            var col = Math.round(swatch.x / (themeGrid.tileW + themeGrid.gap));
                            var rowIdx = Math.round(swatch.y / (themeGrid.tileH + themeGrid.gap));
                            col = Math.max(0, Math.min(themeGrid.perRow - 1, col));
                            var candidate = Math.max(0, Math.min(themeTiles.count - 1, rowIdx * themeGrid.perRow + col));
                            if (candidate !== swatch.index)
                                themeTiles.move(swatch.index, candidate, 1);

                        }

                        width: themeGrid.tileW
                        height: themeGrid.tileH
                        radius: Theme.radiusMd
                        z: themeDrag.active ? 10 : 1
                        scale: themeDrag.active ? 1.05 : 1
                        color: swatch.selected ? Theme.accentContainer : (swatchHover.hovered ? Theme.bgHover : Theme.bgSunken)
                        onXChanged: swatch.reindex()
                        onYChanged: swatch.reindex()

                        Binding {
                            target: swatch
                            property: "x"
                            value: swatch.targetX
                            when: !themeDrag.active
                        }

                        Binding {
                            target: swatch
                            property: "y"
                            value: swatch.targetY
                            when: !themeDrag.active
                        }

                        Behavior on x {
                            enabled: !themeDrag.active

                            NumberAnimation {
                                duration: Theme.ms(220)
                                easing.type: Easing.OutCubic
                            }

                        }

                        Behavior on y {
                            enabled: !themeDrag.active

                            NumberAnimation {
                                duration: Theme.ms(220)
                                easing.type: Easing.OutCubic
                            }

                        }

                        Behavior on scale {
                            NumberAnimation {
                                duration: Theme.durShort
                                easing.type: Easing.OutCubic
                            }

                        }

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
                                color: swatch.tileBg

                                Rectangle {
                                    width: 12
                                    height: 12
                                    radius: 6
                                    anchors.centerIn: parent
                                    color: swatch.tileAccent
                                }

                            }

                            Text {
                                width: 90
                                anchors.verticalCenter: parent.verticalCenter
                                text: swatch.themeName
                                color: swatch.selected ? Theme.text : Theme.subtext
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontLabel
                                font.bold: swatch.selected
                                wrapMode: Text.WordWrap
                            }

                        }

                        HoverHandler {
                            id: swatchHover

                            cursorShape: themeDrag.active ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                        }

                        DragHandler {
                            id: themeDrag

                            target: swatch
                            xAxis.minimum: 0
                            xAxis.maximum: Math.max(0, themeGrid.width - themeGrid.tileW)
                            yAxis.minimum: 0
                            yAxis.maximum: Math.max(0, themeGrid.height - themeGrid.tileH)
                            onActiveChanged: {
                                themeGrid.dragging = themeDrag.active;
                                if (!themeDrag.active)
                                    themeGrid.commitOrder();

                            }
                        }

                        TapHandler {
                            onTapped: page.applyTheme(swatch.themeId)
                        }

                        Rectangle {
                            id: themeDel

                            readonly property bool shown: swatch.isUser && swatchHover.hovered && !themeDrag.active

                            width: 22
                            height: 22
                            radius: 11
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 6
                            color: delHover.hovered ? Theme.error : Theme.alpha(Theme.cShadow, 0.65)
                            opacity: themeDel.shown ? 1 : 0
                            visible: themeDel.opacity > 0.01
                            scale: themeDel.shown ? 1 : 0.7

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

                            Repeater {
                                model: [45, -45]

                                Rectangle {
                                    required property int modelData

                                    width: 10
                                    height: 1.8
                                    radius: 0.9
                                    anchors.centerIn: parent
                                    color: delHover.hovered ? Theme.fgError : "white"
                                    rotation: modelData
                                }

                            }

                            HoverHandler {
                                id: delHover

                                cursorShape: Qt.PointingHandCursor
                            }

                            TapHandler {
                                gesturePolicy: TapHandler.ReleaseWithinBounds
                                onTapped: Prefs.askConfirm("Remove this theme?", "\"" + swatch.themeName + "\" and its generated palette are deleted. The wallpaper folder is left alone.", "Remove", "theme:" + swatch.themeId)
                            }

                        }

                    }

                }

            }

        }

    }

    SettingCard {
        title: "THEME ADDER"

        SettingRow {
            title: "Import from a repo"
            description: "Paste a colour-scheme repo. Its palette is read and mapped onto Lucid's roles, and a wallpaper folder is made for it."
            showDivider: false
            stacked: true

            Column {
                width: parent.width
                spacing: 14

                Row {
                    spacing: 10

                    M3TextField {
                        width: 330
                        text: page.repoUrl
                        placeholder: "https://github.com/catppuccin/palette"
                        enabled: page.addState !== "working"
                        onEdited: (v) => {
                            return page.repoUrl = v;
                        }
                        onAccepted: (v) => {
                            page.repoUrl = v;
                            page.importTheme();
                        }
                    }

                    M3Button {
                        text: page.addState === "working" ? "Importing..." : "Import"
                        variant: "filled"
                        enabled: page.repoUrl.trim() !== "" && page.addState !== "working"
                        iconPath: "M19 13h-6v6h-2v-6H5v-2h6V5h2v6h6v2Z"
                        onClicked: page.importTheme()
                    }

                }

                Rectangle {
                    width: parent.width
                    height: status.implicitHeight + 24
                    radius: Theme.radiusSm
                    color: Theme.bgSunken
                    visible: page.addState !== "idle"

                    Row {
                        id: status

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 12

                        Rectangle {
                            width: 34
                            height: 34
                            radius: 17
                            anchors.verticalCenter: parent.verticalCenter
                            visible: page.addState === "done" && page.addResult !== null
                            color: page.addResult ? page.addResult.swatchBg : "transparent"

                            Rectangle {
                                width: 14
                                height: 14
                                radius: 7
                                anchors.centerIn: parent
                                color: page.addResult ? page.addResult.swatchAccent : "transparent"
                            }

                        }

                        Rectangle {
                            width: 34
                            height: 34
                            radius: 17
                            anchors.verticalCenter: parent.verticalCenter
                            visible: page.addState !== "done"
                            color: page.addState === "error" ? Theme.alpha(Theme.error, 0.18) : Theme.alpha(Theme.accent, 0.18)

                            Text {
                                anchors.centerIn: parent
                                text: page.addState === "error" ? "!" : "..."
                                color: page.addState === "error" ? Theme.error : Theme.accent
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontTitle
                                font.bold: true
                            }

                        }

                        Column {
                            width: status.width - 180
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 3

                            Text {
                                text: {
                                    if (page.addState === "working")
                                        return "Importing...";

                                    if (page.addState === "error")
                                        return "Could not import that repo";

                                    return page.addResult ? page.addResult.name : "";
                                }
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontLabel
                                font.bold: true
                                elide: Text.ElideRight
                                width: parent.width
                            }

                            Text {
                                text: page.addMessage
                                color: page.addState === "error" ? Theme.error : Theme.subtext
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontBody
                                wrapMode: Text.WordWrap
                                width: parent.width
                            }

                        }

                        M3Button {
                            text: "Apply"
                            variant: "filled"
                            anchors.verticalCenter: parent.verticalCenter
                            visible: page.addState === "done" && page.addResult !== null
                            onClicked: {
                                page.applyTheme(page.addResult.id);
                                page.addState = "idle";
                                page.repoUrl = "";
                            }
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

                            ClippingRectangle {
                                anchors.fill: parent
                                radius: tile.radius
                                color: "transparent"

                                Image {
                                    id: thumb

                                    anchors.fill: parent
                                    source: "file://" + tile.path
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    cache: true
                                    sourceSize.width: 300
                                    sourceSize.height: 176
                                    visible: thumb.status === Image.Ready
                                }

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

                                    readonly property color glyph: delArea.containsMouse ? Theme.fgError : "white"
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
