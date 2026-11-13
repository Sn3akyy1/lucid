import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import qs
import qs.lucidui

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
    readonly property string modeHint: page.currentTheme === "matugen" || page.currentTheme === "pywal" ? "Re-derives the palette from your wallpaper in the mode you pick. Applications are asked to match." : (page.currentTheme === "colour" ? "Builds the palette from your colour again in the mode you pick. Applications are asked to match." : "Builds a light palette from this theme's own colours. Applications are asked to match.")
    property string appliedWallpaper: ""
    // same folder the dock's wallpaper strip browses
    readonly property string wallpaperDir: Prefs.wallpaperDir
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

    spacing: Theme.dp(26)

    onWallpaperDirChanged: wallpaperScan.restart()

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

    // the dock's own listing: its small copies, and the videos with live wallpapers on
    Process {
        id: wallpaperScan

        readonly property string script: Qt.resolvedUrl("../luciddocks/wallpaper-thumbs.sh").toString().replace("file://", "")
        // a scan asked for while one runs waits for it
        property bool again: false

        function restart() {
            if (wallpaperScan.running) {
                wallpaperScan.again = true;
                return;
            }
            wallpaperScan.command = [wallpaperScan.script, page.wallpaperDir].concat(Prefs.liveWallpapers ? ["live"] : []);
            wallpaperScan.running = true;
        }

        // the same files keep their tiles; a rescan only hands on new thumbnails
        function fill(model, rows) {
            var same = rows.length === model.count;
            for (var j = 0; same && j < rows.length; j++)
                same = model.get(j).path === rows[j].path;
            if (same) {
                for (var m = 0; m < rows.length; m++) {
                    if (model.get(m).thumb !== rows[m].thumb)
                        model.setProperty(m, "thumb", rows[m].thumb);

                }
                return;
            }
            model.clear();
            for (var r = 0; r < rows.length; r++) {
                var base = rows[r].path.substring(rows[r].path.lastIndexOf("/") + 1);
                var dot = base.lastIndexOf(".");
                model.append({
                    "path": rows[r].path,
                    "name": dot > 0 ? base.substring(0, dot) : base,
                    "thumb": rows[r].thumb
                });
            }
        }

        onExited: {
            if (!wallpaperScan.again)
                return;

            wallpaperScan.again = false;
            wallpaperScan.restart();
        }

        stdout: StdioCollector {
            onStreamFinished: {
                // path, its small copy ("" until cut), and "video" for a live wallpaper
                var pictures = [];
                var videos = [];
                var lines = text.split("\n");
                for (var i = 0; i < lines.length; i++) {
                    var cols = lines[i].split("\t");
                    var p = cols[0].trim();
                    if (p !== "")
                        (cols.length > 2 && cols[2].trim() === "video" ? videos : pictures).push({
                        "path": p,
                        "thumb": cols.length > 1 ? cols[1].trim() : ""
                    });

                }
                wallpaperScan.fill(wallpapers, pictures);
                wallpaperScan.fill(liveWalls, videos);
                // a video shows nothing until its frame is cut: look again meanwhile
                if (videos.some((v) => {
                    return v.thumb === "";
                }) && thumbRetry.tries < 10) {
                    thumbRetry.tries++;
                    thumbRetry.restart();
                } else {
                    thumbRetry.tries = 0;
                }
            }
        }

    }

    Timer {
        id: thumbRetry

        property int tries: 0

        interval: 1500
        onTriggered: wallpaperScan.restart()
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

        function onLiveWallpapersChanged() {
            wallpaperScan.restart();
        }

        target: Prefs
    }

    ListModel {
        id: wallpapers
    }

    // the videos in the same folder, with live wallpapers on
    ListModel {
        id: liveWalls
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
                "isUser": c[i].user === true,
                "removable": c[i].user === true || c[i].removable === true
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
                width: Theme.dp(200)
                current: Prefs.colorMode
                options: page.modeOptions
                onChosen: (key) => {
                    return Prefs.setColorMode(key);
                }
            }

        }

        SettingRow {
            title: "Follow the wallpaper"
            description: "Picks light for a bright wallpaper and dark for a dark one, every time the wallpaper changes. A hand-picked mode holds until the wallpaper changes next."

            M3Switch {
                checked: Prefs.autoColorMode
                onToggled: (v) => {
                    return Prefs.setAutoColorMode(v);
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

                readonly property int tileW: Theme.dp(150)
                readonly property int tileH: Theme.dp(60)
                readonly property int gap: Theme.dp(10)
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
                        required property bool removable
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
                            anchors.leftMargin: Theme.dp(12)
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.dp(10)

                            Rectangle {
                                width: Theme.dp(28)
                                height: Theme.dp(28)
                                radius: Theme.dp(14)
                                anchors.verticalCenter: parent.verticalCenter
                                color: swatch.tileBg

                                Rectangle {
                                    width: Theme.dp(12)
                                    height: Theme.dp(12)
                                    radius: Theme.dp(6)
                                    anchors.centerIn: parent
                                    color: swatch.tileAccent
                                }

                            }

                            Text {
                                width: Theme.dp(90)
                                anchors.verticalCenter: parent.verticalCenter
                                text: swatch.themeName
                                color: swatch.selected ? Theme.text : Theme.subtext
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontLabel
                                font.variableAxes: Theme.axes(Theme.fontLabel, (swatch.selected) ? 640 : 420, 0)
                                font.bold: swatch.selected
                                wrapMode: Text.WordWrap
                            }

                        }

                        HoverHandler {
                            id: swatchHover

                            cursorShape: themeDrag.active ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                        }

                        HeldPointer {
                            held: themeDrag.active
                            cursor: Qt.ClosedHandCursor
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

                            readonly property bool shown: swatch.removable && swatchHover.hovered && !themeDrag.active

                            width: Theme.dp(22)
                            height: Theme.dp(22)
                            radius: Theme.dp(11)
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: Theme.dp(6)
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

                            Icon {
                                anchors.centerIn: parent
                                name: "close"
                                size: Theme.dp(16)
                                color: delHover.hovered ? Theme.fgError : "white"
                            }

                            HoverHandler {
                                id: delHover

                                cursorShape: Qt.PointingHandCursor
                            }

                            TapHandler {
                                gesturePolicy: TapHandler.ReleaseWithinBounds
                                onTapped: {
                                    // a built-in theme has nothing on disk to delete, it only leaves the list
                                    if (!swatch.isUser)
                                        Prefs.askConfirm("Remove this theme?", "\"" + swatch.themeName + "\" leaves the theme list and the launcher." + (swatch.selected ? " The palette switches to Matugen." : "") + " Use it again from Colours to bring it back.", "Remove", "theme-hide:" + swatch.themeId);
                                    else
                                        Prefs.askConfirm("Remove this theme?", "\"" + swatch.themeName + "\" and its generated palette are deleted. The wallpaper folder is left alone.", "Remove", "theme:" + swatch.themeId);
                                }
                            }

                        }

                    }

                }

            }

        }

    }

    SettingCard {
        title: "MORE ON COLOUR"

        SettingRow {
            title: "Palettes and applications"
            description: "How Matugen and Your colour build a palette, which applications follow it, and templates of your own."

            M3Button {
                text: "Colours"
                variant: "tonal"
                onClicked: Prefs.settingsRequested("colours")
            }

        }

        SettingRow {
            title: "More themes"
            description: "A gallery of hundreds of schemes, and importing one from a repo or a file."
            showDivider: false

            M3Button {
                text: "Palettes"
                variant: "tonal"
                onClicked: Prefs.settingsRequested("palettes")
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
                spacing: Theme.dp(14)

                Flow {
                    width: parent.width
                    spacing: Theme.dp(10)

                    Repeater {
                        model: wallpapers

                        WallpaperTile {
                            id: pictureTile

                            selected: page.appliedWallpaper === pictureTile.path
                            onPicked: page.applyWallpaper(pictureTile.path)
                        }

                    }

                }

                Text {
                    text: "No images in this folder yet - add one below."
                    color: Theme.subtext
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontBody
                    font.variableAxes: Theme.axes(Theme.fontBody, 420, 0)
                    visible: wallpapers.count === 0
                }

                Row {
                    spacing: Theme.dp(10)

                    M3Button {
                        text: "Add wallpaper..."
                        variant: "filled"
                        iconPath: "add"
                        onClicked: {
                            wallpaperPicker.command = ["python3", Qt.resolvedUrl("pickfile.py").toString().replace("file://", ""), "--title", "Add wallpaper", "--filter", "Images=image/jpeg,image/png,image/webp"];
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
            title: "Live wallpapers"
            description: liveWalls.count + (liveWalls.count === 1 ? " video" : " videos") + " in the same folder, played behind the desktop"
            visible: Prefs.liveWallpapers
            stacked: true

            Column {
                width: parent.width
                spacing: Theme.dp(14)

                Flow {
                    width: parent.width
                    spacing: Theme.dp(10)

                    Repeater {
                        model: liveWalls

                        WallpaperTile {
                            id: liveTile

                            live: true
                            selected: LiveWall.video === liveTile.path
                            onPicked: page.applyWallpaper(liveTile.path)
                        }

                    }

                }

                Text {
                    text: "No videos in this folder yet - add an mp4, webm or mkv below."
                    color: Theme.subtext
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontBody
                    font.variableAxes: Theme.axes(Theme.fontBody, 420, 0)
                    visible: liveWalls.count === 0
                }

                M3Button {
                    text: "Add live wallpaper..."
                    variant: "filled"
                    iconPath: "add"
                    onClicked: {
                        wallpaperPicker.command = ["python3", Qt.resolvedUrl("pickfile.py").toString().replace("file://", ""), "--title", "Add wallpaper", "--filter", "Videos=video/mp4,video/webm,video/x-matroska,video/quicktime,video/x-m4v"];
                        wallpaperPicker.running = true;
                    }
                }

            }

        }

        SettingRow {
            title: "Custom folder"
            description: "Leave empty to follow the current theme's own wallpaper folder."
            showDivider: false

            M3TextField {
                width: Theme.dp(260)
                text: Prefs.wallpaperFolder
                placeholder: "~/Pictures/wallpapers/" + page.currentTheme
                onAccepted: (v) => {
                    return Prefs.wallpaperFolder = v.trim().replace("~", page.home);
                }
            }

        }

    }

    SettingCard {
        title: "LIVE WALLPAPERS"

        SettingRow {
            title: "Live wallpapers"
            description: "Videos in the wallpaper folder (mp4, webm, mkv) get a Live tab in the launcher and play behind the desktop. The colours come from the first frame."
            showDivider: Prefs.liveWallpapers

            M3Switch {
                checked: Prefs.liveWallpapers
                onToggled: (v) => {
                    return Prefs.liveWallpapers = v;
                }
            }

        }

        SettingRow {
            title: "Decoder"
            description: "What decodes the video. Automatic tries the integrated GPU first, so a laptop does not wake its graphics card for a wallpaper, then NVIDIA. The CPU always works, and costs the most."
            visible: Prefs.liveWallpapers
            stacked: true

            M3Segmented {
                width: Math.min(parent.width, Theme.dp(560))
                current: Prefs.liveDecoder
                options: [{
                    "key": "auto",
                    "label": "Automatic"
                }, {
                    "key": "vaapi",
                    "label": "VA-API"
                }, {
                    "key": "cuda",
                    "label": "NVIDIA"
                }, {
                    "key": "cpu",
                    "label": "CPU"
                }]
                onChosen: (key) => Prefs.liveDecoder = key
            }

        }

        SettingRow {
            title: "Pause under windows"
            description: "Hold the video still on a screen whose workspace has windows, or only behind a fullscreen one."
            visible: Prefs.liveWallpapers
            stacked: true

            M3Segmented {
                width: Math.min(parent.width, Theme.dp(480))
                current: Prefs.livePauseUnder
                options: [{
                    "key": "any",
                    "label": "Any window"
                }, {
                    "key": "fullscreen",
                    "label": "Fullscreen"
                }, {
                    "key": "never",
                    "label": "Never"
                }]
                onChosen: (key) => Prefs.livePauseUnder = key
            }

        }

        SettingRow {
            title: "In game mode"
            description: "Keep playing, pause, or stop the player and leave the first frame, which frees what the video was using."
            visible: Prefs.liveWallpapers
            showDivider: false
            stacked: true

            M3Segmented {
                width: Math.min(parent.width, Theme.dp(480))
                current: Prefs.liveGameMode
                options: [{
                    "key": "play",
                    "label": "Keep playing"
                }, {
                    "key": "pause",
                    "label": "Pause"
                }, {
                    "key": "still",
                    "label": "Still frame"
                }]
                onChosen: (key) => Prefs.liveGameMode = key
            }

        }

    }

    SettingCard {
        title: "WALLPAPER PICKER"

        SettingRow {
            title: "Picker style"
            description: "How the wallpapers are laid out when you open the picker from the launcher."
            stacked: true

            Flow {
                width: parent.width
                spacing: Theme.dp(10)

                WallpaperStyleThumb {
                    styleId: "strip"
                    label: "Strip"
                }

                WallpaperStyleThumb {
                    styleId: "pills"
                    label: "Pills"
                }

                WallpaperStyleThumb {
                    styleId: "tiles"
                    label: "Tiles"
                }

                WallpaperStyleThumb {
                    styleId: "bento"
                    label: "Bento"
                }

            }

        }

        SettingRow {
            title: "Arrow keys"
            description: Prefs.wallpaperPickerStyle === "tiles" ? "Tiles is a grid, so it takes all four arrows. In the other styles, which pair changes the wallpaper; the other pair moves through the search field." : "Which pair changes the wallpaper. The other pair moves through the search field, to edit what you typed."
            stacked: true

            M3Segmented {
                width: Math.min(parent.width, Theme.dp(360))
                current: Prefs.wallpaperPickerKeys
                options: [{
                    "key": "sides",
                    "label": "Left and right"
                }, {
                    "key": "updown",
                    "label": "Up and down"
                }]
                onChosen: (key) => Prefs.wallpaperPickerKeys = key
            }

        }

        SettingRow {
            title: "Pill shape"
            description: "How tall the pills are around the open one: all alike, the full height of the panel, or rising to a peak."
            visible: Prefs.wallpaperPickerStyle === "pills"
            showDivider: false
            stacked: true

            M3Segmented {
                width: Math.min(parent.width, Theme.dp(560))
                current: Prefs.wallpaperPillsShape
                options: [{
                    "key": "uniform",
                    "label": "Uniform"
                }, {
                    "key": "full",
                    "label": "Full height"
                }, {
                    "key": "wave",
                    "label": "Wave"
                }]
                onChosen: (key) => Prefs.wallpaperPillsShape = key
            }

        }

        SettingRow {
            title: "Step"
            description: "How quickly the cards shrink away from the middle one."
            visible: Prefs.wallpaperPickerStyle === "strip"
            stacked: true

            M3Segmented {
                width: Math.min(parent.width, Theme.dp(420))
                current: Prefs.wallpaperStripSteps
                options: [{
                    "key": "soft",
                    "label": "Soft"
                }, {
                    "key": "normal",
                    "label": "Normal"
                }, {
                    "key": "steep",
                    "label": "Marked"
                }]
                onChosen: (key) => Prefs.wallpaperStripSteps = key
            }

        }

        SettingRow {
            title: "Neighbours"
            description: "How many cards show on each side of the middle one."
            visible: Prefs.wallpaperPickerStyle === "strip"
            showDivider: false
            stacked: true

            M3Segmented {
                width: Math.min(parent.width, Theme.dp(240))
                current: Prefs.wallpaperStripSides
                options: [{
                    "key": 2,
                    "label": String(2)
                }, {
                    "key": 3,
                    "label": String(3)
                }]
                onChosen: (key) => Prefs.wallpaperStripSides = key
            }

        }

        SettingRow {
            title: "Rows"
            description: "How many rows of tiles the picker shows."
            visible: Prefs.wallpaperPickerStyle === "tiles"
            stacked: true

            M3Segmented {
                width: Math.min(parent.width, Theme.dp(360))
                current: Math.max(2, Math.min(5, Math.round(Prefs.wallpaperTilesRows) || 2))
                options: [{
                    "key": 2,
                    "label": String(2)
                }, {
                    "key": 3,
                    "label": String(3)
                }, {
                    "key": 4,
                    "label": String(4)
                }, {
                    "key": 5,
                    "label": String(5)
                }]
                onChosen: (key) => Prefs.wallpaperTilesRows = key
            }

        }

        SettingRow {
            title: "Tile shape"
            description: "Square tiles, or wide ones that show more of each picture."
            visible: Prefs.wallpaperPickerStyle === "tiles"
            showDivider: false
            stacked: true

            M3Segmented {
                width: Math.min(parent.width, Theme.dp(320))
                current: Prefs.wallpaperTilesAspect
                options: [{
                    "key": "square",
                    "label": "Square"
                }, {
                    "key": "wide",
                    "label": "Wide"
                }]
                onChosen: (key) => Prefs.wallpaperTilesAspect = key
            }

        }

        SettingRow {
            title: "Main wallpaper"
            description: "How much of the panel the selected wallpaper takes."
            visible: Prefs.wallpaperPickerStyle === "bento"
            stacked: true

            M3Segmented {
                width: Math.min(parent.width, Theme.dp(420))
                current: Prefs.wallpaperBentoHero
                options: [{
                    "key": "small",
                    "label": "Small"
                }, {
                    "key": "medium",
                    "label": "Medium"
                }, {
                    "key": "large",
                    "label": "Large"
                }]
                onChosen: (key) => Prefs.wallpaperBentoHero = key
            }

        }

        SettingRow {
            title: "Show previous"
            description: "Keep the two wallpapers before the selected one at the edge, or give their room to the rest."
            visible: Prefs.wallpaperPickerStyle === "bento"
            showDivider: false

            M3Switch {
                checked: Prefs.wallpaperBentoPrev
                onToggled: (v) => {
                    return Prefs.wallpaperBentoPrev = v;
                }
            }

        }

    }

    SettingCard {
        id: transCard

        readonly property string type: Prefs.wallTransType
        readonly property bool fades: transCard.type === "none" || transCard.type === "simple"

        title: "WALLPAPER TRANSITION"

        SettingRow {
            title: "Presets"
            description: "A starting point; changing anything below makes it your own."
            stacked: true

            Flow {
                width: parent.width
                spacing: Theme.dp(10)

                Repeater {
                    model: WallTransitions.all

                    WallTransitionTile {
                        required property var modelData

                        preset: modelData
                    }

                }

            }

        }

        SettingRow {
            title: "Effect"
            description: "Fade and Simple blend the two pictures; the others reveal the new one from a side, a line or a circle."
            stacked: true

            M3Chips {
                width: parent.width
                current: Prefs.wallTransType
                options: [{
                    "key": "fade",
                    "label": "Fade"
                }, {
                    "key": "simple",
                    "label": "Simple"
                }, {
                    "key": "none",
                    "label": "None"
                }, {
                    "key": "left",
                    "label": "From left"
                }, {
                    "key": "right",
                    "label": "From right"
                }, {
                    "key": "top",
                    "label": "From top"
                }, {
                    "key": "bottom",
                    "label": "From bottom"
                }, {
                    "key": "wipe",
                    "label": "Wipe"
                }, {
                    "key": "wave",
                    "label": "Wave"
                }, {
                    "key": "grow",
                    "label": "Grow"
                }, {
                    "key": "outer",
                    "label": "Shrink"
                }, {
                    "key": "random",
                    "label": "Random"
                }]
                onChosen: (key) => WallTransitions.set("type", key)
            }

        }

        SettingRow {
            title: "Duration"
            visible: !transCard.fades
            stacked: true

            M3Slider {
                width: parent.width
                from: 0.2
                to: 5
                stepSize: 0.1
                decimals: 1
                suffix: " s"
                value: Prefs.wallTransDuration
                onMoved: (v) => WallTransitions.set("duration", Math.round(v * 10) / 10)
            }

        }

        SettingRow {
            title: "Angle"
            description: "0° sweeps right to left, 90° top to bottom."
            visible: transCard.type === "wipe" || transCard.type === "wave"
            stacked: true

            M3Slider {
                width: parent.width
                from: 0
                to: 355
                stepSize: Theme.dp(5)
                suffix: "°"
                value: Prefs.wallTransAngle
                onMoved: (v) => WallTransitions.set("angle", Math.round(v))
            }

        }

        SettingRow {
            title: "Wave size"
            visible: transCard.type === "wave"
            stacked: true

            M3Slider {
                width: parent.width
                from: 8
                to: 80
                stepSize: Theme.dp(2)
                suffix: " px"
                value: parseInt(Prefs.wallTransWave.split(",")[0]) || 20
                onMoved: (v) => WallTransitions.set("wave", Math.round(v) + "," + Math.round(v))
            }

        }

        SettingRow {
            title: "Starts from"
            description: "Where the circle opens. \"Chosen card\" grows it from the wallpaper you are previewing in the picker."
            visible: transCard.type === "grow" || transCard.type === "outer"
            stacked: true

            M3Segmented {
                width: Math.min(parent.width, Theme.dp(560))
                current: Prefs.wallTransOrigin
                options: [{
                    "key": "center",
                    "label": "Centre"
                }, {
                    "key": "card",
                    "label": "Chosen card"
                }, {
                    "key": "cursor",
                    "label": "Pointer"
                }]
                onChosen: (key) => WallTransitions.set("origin", key)
            }

        }

        SettingRow {
            title: "Curve"
            description: "How the change speeds up and slows down."
            visible: !transCard.fades
            stacked: true

            M3Segmented {
                width: Math.min(parent.width, Theme.dp(560))
                current: Prefs.wallTransBezier
                options: [{
                    "key": ".54,0,.34,.99",
                    "label": "Smooth"
                }, {
                    "key": ".05,.7,.1,1",
                    "label": "Snappy"
                }, {
                    "key": ".4,0,.2,1",
                    "label": "Gentle"
                }, {
                    "key": "0,0,1,1",
                    "label": "Linear"
                }]
                onChosen: (key) => WallTransitions.set("bezier", key)
            }

        }

        SettingRow {
            title: "Save as preset"
            description: "Keep the settings above under a name of your own."

            Row {
                spacing: Theme.dp(10)

                M3TextField {
                    id: presetName

                    width: Theme.dp(200)
                    placeholder: "Preset name"
                    onAccepted: (v) => {
                        WallTransitions.saveCurrent(v);
                        presetName.text = "";
                    }
                }

                M3Button {
                    text: "Save"
                    variant: "tonal"
                    onClicked: {
                        WallTransitions.saveCurrent(presetName.text);
                        presetName.text = "";
                    }
                }

            }

        }

        SettingRow {
            title: "Try it"
            description: "Plays the transition from a flat colour taken from your wallpaper into it."
            showDivider: false

            M3Button {
                text: "Try transition"
                variant: "tonal"
                onClicked: {
                    if (page.appliedWallpaper !== "")
                        Quickshell.execDetached(["env", "WALL_DEMO=1", page.home + "/.config/hypr/scripts/wallpaper/set-wallpaper.sh", page.appliedWallpaper]);
                }
            }

        }

    }

}
