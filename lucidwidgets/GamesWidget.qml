import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import qs

WidgetBody {
    id: w

    property bool scanned: false
    property bool found: true
    property var games: []
    property var launch: []
    property string lastRaw: ""
    // the cover under the pointer, and the game just asked to start
    property string hoverId: ""
    property string launchingId: ""

    readonly property var samples: {
        var t = Date.now() / 1000;
        return [{
            "id": "s1",
            "name": "Hollow Knight",
            "lastPlayed": t - 3600 * 5,
            "playtime": 2830
        }, {
            "id": "s2",
            "name": "Hades II",
            "lastPlayed": t - 86400 * 2,
            "playtime": 1260
        }, {
            "id": "s3",
            "name": "Celeste",
            "lastPlayed": t - 86400 * 9,
            "playtime": 540
        }, {
            "id": "s4",
            "name": "Outer Wilds",
            "lastPlayed": t - 86400 * 40,
            "playtime": 1900
        }, {
            "id": "s5",
            "name": "Balatro",
            "lastPlayed": 0,
            "playtime": 0
        }];
    }
    // the script already sorts by last played
    readonly property var library: w.preview ? w.samples : w.games
    readonly property var shown: {
        if (w.opt("order") !== "name")
            return w.library;

        return w.library.slice().sort((a, b) => {
            return a.name.localeCompare(b.name);
        });
    }
    readonly property var latest: w.library.length > 0 ? w.library[0] : null
    readonly property var hoverGame: w.shown.find((g) => {
        return g.id === w.hoverId;
    }) || null
    readonly property string emptyText: !w.scanned && !w.preview ? "" : (!w.found ? "Steam is not installed" : "No games installed yet")

    function ago(ts) {
        if (!ts)
            return "Not played yet";

        var s = Date.now() / 1000 - ts;
        if (s < 3600)
            return "Played just now";

        if (s < 86400)
            return "Played " + Math.floor(s / 3600) + " h ago";

        var d = Math.floor(s / 86400);
        if (d === 1)
            return "Played yesterday";

        if (d < 14)
            return "Played " + d + " days ago";

        if (d < 60)
            return "Played " + Math.floor(d / 7) + " weeks ago";

        if (d < 730)
            return "Played " + Math.floor(d / 30) + " months ago";

        return "Played " + Math.floor(d / 365) + " years ago";
    }

    function hours(minutes) {
        if (!minutes)
            return "";

        if (minutes < 60)
            return minutes + " min";

        var h = minutes / 60;
        return (h < 10 ? h.toFixed(1) : Math.round(h)) + " h";
    }

    function detail(g) {
        if (!g)
            return "";

        var h = w.hours(g.playtime);
        return w.ago(g.lastPlayed) + (h !== "" ? " · " + h : "");
    }

    // a stable colour per title, for the covers Steam has no artwork cached for
    function tint(name) {
        var n = 0;
        for (var i = 0; i < name.length; i++) n = (n * 31 + name.charCodeAt(i)) % 997
        return [Theme.accent, Theme.cSecondary, Theme.cTertiary][n % 3];
    }

    function start(g) {
        if (w.preview || !g || w.launch.length === 0)
            return ;

        if (w.opt("gameModeOnLaunch") === true && Prefs.gameModeOnCmd.trim() !== "")
            Quickshell.execDetached(["bash", "-c", Prefs.gameModeOnCmd]);

        Quickshell.execDetached(w.launch.concat(["steam://rungameid/" + g.id]));
        w.launchingId = g.id;
        launchingTimer.restart();
        // Steam writes the new play time once the game is up
        rescanSoon.restart();
    }

    Timer {
        interval: 60000
        repeat: true
        running: w.live
        triggeredOnStart: true
        onTriggered: scan.running = true
    }

    Timer {
        id: rescanSoon

        interval: 20000
        onTriggered: scan.running = true
    }

    Timer {
        id: launchingTimer

        interval: 6000
        onTriggered: w.launchingId = ""
    }

    Process {
        id: scan

        command: ["python3", Qt.resolvedUrl("steam-library.py").toString().replace("file://", "")]

        stdout: StdioCollector {
            onStreamFinished: {
                // an unchanged library keeps its delegates, so covers do not reload
                if (this.text !== w.lastRaw) {
                    try {
                        var d = JSON.parse(this.text);
                        w.found = d.found === true;
                        w.launch = d.launch || [];
                        w.games = d.games || [];
                        w.lastRaw = this.text;
                    } catch (e) {
                        w.games = [];
                    }
                }
                w.scanned = true;
            }
        }

    }

    Text {
        anchors.centerIn: parent
        width: parent.width - 40
        visible: w.library.length === 0 && w.variant !== "hero"
        horizontalAlignment: Text.AlignHCenter
        text: w.emptyText
        color: Theme.subtextDim
        font.family: Theme.fontFamily
        font.pixelSize: 13
        wrapMode: Text.WordWrap
    }

    Item {
        id: shelf

        readonly property real gap: 10
        readonly property real coverH: Math.max(60, shelf.height - shelfHead.height - shelfFoot.height - 22)
        readonly property real coverW: Math.round(shelf.coverH * 2 / 3)
        readonly property int fits: Math.max(1, Math.floor((shelf.width + shelf.gap) / (shelf.coverW + shelf.gap)))
        readonly property var focusGame: w.hoverGame || (w.shown.length > 0 ? w.shown[0] : null)

        visible: w.variant === "shelf"
        anchors.fill: parent
        anchors.margins: 16

        Text {
            id: shelfHead

            anchors.left: parent.left
            anchors.top: parent.top
            text: w.opt("order") === "name" ? "LIBRARY" : "RECENTLY PLAYED"
            color: Theme.accent
            font.family: Theme.fontFamily
            font.pixelSize: 10
            font.bold: true
            font.letterSpacing: 1.4
        }

        Text {
            anchors.right: parent.right
            anchors.baseline: shelfHead.baseline
            text: w.library.length === 0 ? "" : w.library.length + (w.library.length === 1 ? " game" : " games")
            color: Theme.subtextDim
            font.family: Theme.fontFamily
            font.pixelSize: 10
            font.bold: true
        }

        Row {
            anchors.top: shelfHead.bottom
            anchors.topMargin: 11
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: shelf.gap

            Repeater {
                model: w.shown.slice(0, shelf.fits)

                Item {
                    id: tile

                    required property var modelData
                    readonly property bool hot: tileArea.containsMouse
                    readonly property bool starting: w.launchingId === tile.modelData.id

                    width: shelf.coverW
                    height: shelf.coverH
                    scale: tileArea.pressed ? 0.96 : (tile.hot ? 1.04 : 1)

                    Cover {
                        anchors.fill: parent
                        game: tile.modelData
                    }

                    Rectangle {
                        anchors.centerIn: parent
                        width: 42
                        height: 42
                        radius: Theme.rad(21)
                        color: Theme.accent
                        opacity: (tile.hot || tile.starting) ? 1 : 0

                        WidgetGlyph {
                            anchors.centerIn: parent
                            anchors.horizontalCenterOffset: 1
                            name: "play"
                            size: 22
                            color: Theme.fgAccent
                        }

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Theme.durShort
                            }

                        }

                    }

                    MouseArea {
                        id: tileArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onContainsMouseChanged: {
                            if (tileArea.containsMouse)
                                w.hoverId = tile.modelData.id;
                            else if (w.hoverId === tile.modelData.id)
                                w.hoverId = "";
                        }
                        onClicked: w.start(tile.modelData)
                    }

                    Behavior on scale {
                        NumberAnimation {
                            duration: Theme.durQuick
                            easing.type: Theme.easeStandard
                        }

                    }

                }

            }

        }

        Column {
            id: shelfFoot

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            visible: shelf.focusGame !== null
            spacing: 1

            Text {
                width: parent.width
                text: shelf.focusGame ? (w.launchingId === shelf.focusGame.id ? "Starting " + shelf.focusGame.name + "…" : shelf.focusGame.name) : ""
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 13
                font.bold: true
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                text: w.detail(shelf.focusGame)
                color: Theme.subtextDim
                font.family: Theme.fontFamily
                font.pixelSize: 11
                elide: Text.ElideRight
            }

        }

    }

    ClippingRectangle {
        id: hero

        readonly property var game: w.latest
        readonly property string file: hero.game ? (hero.game.hero || hero.game.header || hero.game.capsule || "") : ""

        visible: w.variant === "hero"
        anchors.fill: parent
        radius: w.corner
        color: hero.game ? Theme.alpha(w.tint(hero.game.name), 0.22) : "transparent"

        Image {
            anchors.fill: parent
            source: hero.file !== "" ? "file://" + hero.file : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            sourceSize.width: 960
            visible: status === Image.Ready
        }

        // the artwork fades out under the text so the title reads on any cover
        Rectangle {
            anchors.fill: parent
            visible: hero.game !== null

            gradient: Gradient {
                orientation: Gradient.Horizontal

                GradientStop {
                    position: 0
                    color: Theme.alpha(Theme.bg, 0.94)
                }

                GradientStop {
                    position: 0.55
                    color: Theme.alpha(Theme.bg, 0.72)
                }

                GradientStop {
                    position: 1
                    color: Theme.alpha(Theme.bg, 0.12)
                }

            }

        }

        Column {
            anchors.left: parent.left
            anchors.leftMargin: 20
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width * 0.62
            visible: hero.game !== null
            spacing: 6

            Text {
                text: "LAST PLAYED"
                color: Theme.accent
                font.family: Theme.fontFamily
                font.pixelSize: 10
                font.bold: true
                font.letterSpacing: 1.4
            }

            Image {
                id: heroLogo

                width: parent.width
                height: 44
                source: (hero.game && hero.game.logo) ? "file://" + hero.game.logo : ""
                fillMode: Image.PreserveAspectFit
                horizontalAlignment: Image.AlignLeft
                asynchronous: true
                sourceSize.height: 88
                visible: status === Image.Ready
            }

            Text {
                width: parent.width
                visible: !heroLogo.visible
                text: hero.game ? hero.game.name : ""
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 20
                font.bold: true
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                text: w.detail(hero.game)
                color: Theme.subtext
                font.family: Theme.fontFamily
                font.pixelSize: 12
                elide: Text.ElideRight
            }

            Item {
                width: 1
                height: 2
            }

            Rectangle {
                id: playChip

                implicitWidth: playRow.implicitWidth + 28
                implicitHeight: 32
                radius: Theme.pill(height)
                color: playArea.containsMouse ? Theme.accentHover : Theme.accent

                Row {
                    id: playRow

                    anchors.centerIn: parent
                    spacing: 6

                    WidgetGlyph {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "play"
                        size: 16
                        color: Theme.fgAccent
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: (hero.game && w.launchingId === hero.game.id) ? "Starting…" : "Play"
                        color: Theme.fgAccent
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        font.bold: true
                    }

                }

                MouseArea {
                    id: playArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: w.start(hero.game)
                }

            }

        }

        Text {
            anchors.centerIn: parent
            visible: hero.game === null
            text: w.emptyText
            color: Theme.subtextDim
            font.family: Theme.fontFamily
            font.pixelSize: 13
        }

    }

    Item {
        id: listFace

        visible: w.variant === "list"
        anchors.fill: parent

        Item {
            id: listHead

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.leftMargin: 18
            anchors.rightMargin: 16
            anchors.topMargin: 15
            height: 22

            Text {
                id: listTitle

                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "GAMES"
                color: Theme.accent
                font.family: Theme.fontFamily
                font.pixelSize: 10
                font.bold: true
                font.letterSpacing: 1.4
            }

            Text {
                anchors.left: listTitle.right
                anchors.leftMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                text: w.library.length === 0 ? "" : w.library.length + " installed"
                color: Theme.subtextDim
                font.family: Theme.fontFamily
                font.pixelSize: 10
                font.bold: true
            }

        }

        Flickable {
            id: listScroll

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: listHead.bottom
            anchors.topMargin: 4
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 8
            contentWidth: width
            contentHeight: listColumn.height
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            interactive: contentHeight > height

            Column {
                id: listColumn

                width: listScroll.width

                Repeater {
                    model: w.shown

                    Item {
                        id: row

                        required property var modelData

                        width: listColumn.width
                        height: 52

                        Rectangle {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            radius: Theme.radiusXs
                            color: rowArea.containsMouse ? Theme.alpha(Theme.text, 0.06) : "transparent"
                        }

                        Cover {
                            id: rowCover

                            anchors.left: parent.left
                            anchors.leftMargin: 18
                            anchors.verticalCenter: parent.verticalCenter
                            width: 76
                            height: 36
                            radius: Theme.rad(7)
                            wide: true
                            game: row.modelData
                        }

                        Column {
                            anchors.left: rowCover.right
                            anchors.leftMargin: 12
                            anchors.right: rowPlay.left
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 1

                            Text {
                                width: parent.width
                                text: row.modelData.name
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: 13
                                font.bold: true
                                elide: Text.ElideRight
                            }

                            Text {
                                width: parent.width
                                text: w.launchingId === row.modelData.id ? "Starting…" : w.detail(row.modelData)
                                color: w.launchingId === row.modelData.id ? Theme.accent : Theme.subtextDim
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                elide: Text.ElideRight
                            }

                        }

                        WidgetGlyph {
                            id: rowPlay

                            anchors.right: parent.right
                            anchors.rightMargin: 20
                            anchors.verticalCenter: parent.verticalCenter
                            name: "play"
                            size: 18
                            color: Theme.accent
                            opacity: rowArea.containsMouse ? 1 : 0
                        }

                        MouseArea {
                            id: rowArea

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: w.start(row.modelData)
                        }

                    }

                }

            }

        }

    }

    component Cover: ClippingRectangle {
        id: cover

        property var game: null
        // the landscape header instead of the portrait capsule
        property bool wide: false
        readonly property string file: cover.game ? (cover.wide ? (cover.game.header || cover.game.capsule || "") : (cover.game.capsule || cover.game.header || "")) : ""

        radius: Theme.rad(10)
        color: cover.game ? Theme.alpha(w.tint(cover.game.name), 0.24) : Theme.alpha(Theme.text, 0.07)

        Text {
            anchors.fill: parent
            anchors.margins: cover.wide ? 4 : 8
            visible: art.status !== Image.Ready
            text: cover.game ? cover.game.name : ""
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: cover.wide ? 9 : 12
            font.bold: true
            wrapMode: Text.WordWrap
            maximumLineCount: 3
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        Image {
            id: art

            anchors.fill: parent
            source: cover.file !== "" ? "file://" + cover.file : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            sourceSize.width: cover.wide ? 230 : 300
            visible: status === Image.Ready
        }

    }

}
