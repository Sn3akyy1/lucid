import QtQuick
import qs

Item {
    id: face

    // "apps" | "commands" | "theme" | "wallpaper" | "power" | "clipboard"
    property string mode: "apps"
    property var model: null
    property var wallpaperModel: null
    property string appliedWallpaper: ""
    property int wallHeroW: 340
    property int wallHeroH: 211
    property int wallMidW: 238
    property int wallMidH: 148
    property int wallSmallW: 150
    property int wallSmallH: 93
    property int wallCardGap: 10
    property alias searchText: searchInput.text
    property string highlightQuery: ""
    readonly property string placeholder: face.displayMode === "clipboard" ? "Search clipboard history" : "Search apps, windows and commands, or type >"
    // lock / suspend / restart / shut down, beside the search field
    property bool showPowerChips: false
    // the power action waiting on its second press, owned by the dock
    property string armedPower: ""
    readonly property var powerChips: [{
        "id": "lock",
        "label": "Lock",
        "confirm": "",
        "glyph": DockIcons.lock,
        "danger": false
    }, {
        "id": "suspend",
        "label": "Suspend",
        "confirm": "",
        "glyph": DockIcons.suspend,
        "danger": false
    }, {
        "id": "reboot",
        "label": "Restart",
        "confirm": "Restart?",
        "glyph": DockIcons.reboot,
        "danger": true
    }, {
        "id": "shutdown",
        "label": "Shut down",
        "confirm": "Shut down?",
        "glyph": DockIcons.power,
        "danger": true,
        // the one to find at a glance: filled with the palette's primary
        "accent": true
    }]
    property real targetWidth: width
    property real targetHeight: height

    readonly property int searchHeight: 44
    readonly property int chromeHeight: face.searchHeight + 12
    readonly property real stableContentHeight: Math.max(0, face.targetHeight - face.chromeHeight)

    property string displayMode: "apps"
    readonly property bool listVisible: face.displayMode !== "wallpaper" && face.displayMode !== "power"
    property bool justOpened: false

    signal activated(int index)
    signal closeRequested()
    signal wallpaperChosen(string path)
    signal wallpaperPreviewed(string path)
    signal powerActionChosen(string id)
    signal backRequested()
    signal deleteRequested(int index)
    signal powerChipTapped(string id)

    function rowHeightFor(kind, subtitle) {
        return resultList.heightFor(kind, subtitle);
    }

    function setWallpaperIndex(i) {
        wallStrip.setIndexImmediate(i);
    }

    function resetSelection() {
        resultList.resetSelection();
        powerRow.currentIndex = 0;
    }

    // call before a query rewrites the results, see LauncherList.filtering
    function beginFilter() {
        resultList.beginFilter();
    }

    function resultsChanged() {
        resultList.ensureSelectable();
    }

    function syncDisplayMode() {
        face.displayMode = face.mode;
        face.resetSelection();
    }

    function requestModeTransition() {
        if (!face.visible || face.justOpened) {
            face.syncDisplayMode();
            return;
        }
        modeFade.restart();
    }

    onModeChanged: face.requestModeTransition()
    onVisibleChanged: {
        if (!face.visible)
            return;

        face.justOpened = true;
        face.syncDisplayMode();
        searchInput.forceActiveFocus();
        face.justOpened = false;
    }

    SequentialAnimation {
        id: modeFade

        NumberAnimation {
            target: contentArea
            property: "opacity"
            to: 0
            duration: Theme.ms(120)
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.easeEmphasizedAccel
        }

        ScriptAction {
            script: face.syncDisplayMode()
        }

        NumberAnimation {
            target: contentArea
            property: "opacity"
            to: 1
            duration: Theme.ms(240)
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.easeEmphasizedDecel
        }

    }

    Item {
        id: contentArea

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: searchBar.top
        anchors.bottomMargin: 12
        clip: true

        LauncherList {
            id: resultList

            anchors.fill: parent
            visible: face.listVisible
            model: face.model
            query: face.highlightQuery
            stableHeight: face.stableContentHeight
            emptyLabel: {
                if (face.displayMode === "commands")
                    return "No commands found";

                if (face.displayMode === "theme")
                    return "No themes found";

                if (face.displayMode === "clipboard")
                    return Clip.available ? "Clipboard history is empty" : "Install cliphist to keep clipboard history";

                return "No apps found";
            }
            onActivated: (index) => face.activated(index)
            onDeleteRequested: (index) => face.deleteRequested(index)
        }

        WallpaperStrip {
            id: wallStrip

            anchors.fill: parent
            visible: face.displayMode === "wallpaper"
            model: face.wallpaperModel
            heroW: face.wallHeroW
            heroH: face.wallHeroH
            midW: face.wallMidW
            midH: face.wallMidH
            smallW: face.wallSmallW
            smallH: face.wallSmallH
            itemGap: face.wallCardGap
            appliedPath: face.appliedWallpaper
            stableHeight: face.stableContentHeight
            onChosen: (path) => face.wallpaperChosen(path)
            onPreviewed: (path) => face.wallpaperPreviewed(path)
        }

        PowerRow {
            id: powerRow

            anchors.fill: parent
            visible: face.displayMode === "power"
            stableHeight: face.stableContentHeight
            onActionChosen: (id) => face.powerActionChosen(id)
        }

    }

    Rectangle {
        id: searchBar

        anchors.left: parent.left
        anchors.right: powerChips.left
        anchors.bottom: parent.bottom
        height: face.searchHeight
        radius: Theme.radiusPill
        color: Theme.withBlur(Theme.bgTile)

        Item {
            id: leadingButton

            readonly property bool isBack: face.mode !== "apps"

            width: 34
            height: 34
            anchors.left: parent.left
            anchors.leftMargin: 5
            anchors.verticalCenter: parent.verticalCenter

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: Theme.text
                opacity: leadingButton.isBack ? (leadTap.pressed ? Theme.statePressed : (leadHover.hovered ? Theme.stateHover : 0)) : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.durQuick
                    }

                }

            }

            DockGlyph {
                anchors.centerIn: parent
                width: 17
                height: 17
                pathData: leadingButton.isBack ? DockIcons.arrowBack : DockIcons.search
                glyphColor: leadingButton.isBack ? Theme.accent : Theme.subtext
            }

            HoverHandler {
                id: leadHover

                enabled: leadingButton.isBack
            }

            TapHandler {
                id: leadTap

                enabled: leadingButton.isBack
                onTapped: face.backRequested()
            }

        }

        TextInput {
            id: searchInput

            anchors.left: leadingButton.right
            anchors.leftMargin: 6
            anchors.right: clearButton.left
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontBody
            font.weight: Font.Medium
            clip: true
            focus: true
            selectByMouse: true
            selectionColor: Theme.alpha(Theme.accent, 0.35)
            selectedTextColor: Theme.text

            onTextChanged: face.resetSelection()
            Keys.onUpPressed: {
                if (face.listVisible)
                    resultList.step(-1);

            }
            Keys.onDownPressed: {
                if (face.listVisible)
                    resultList.step(1);

            }
            Keys.onLeftPressed: (event) => {
                if (face.displayMode === "wallpaper") {
                    wallStrip.currentIndex = Math.max(0, wallStrip.currentIndex - 1);
                    event.accepted = true;
                } else if (face.displayMode === "power") {
                    powerRow.step(-1);
                    event.accepted = true;
                } else {
                    event.accepted = false;
                }
            }
            Keys.onRightPressed: (event) => {
                if (face.displayMode === "wallpaper" && face.wallpaperModel) {
                    wallStrip.currentIndex = Math.min(face.wallpaperModel.count - 1, wallStrip.currentIndex + 1);
                    event.accepted = true;
                } else if (face.displayMode === "power") {
                    powerRow.step(1);
                    event.accepted = true;
                } else {
                    event.accepted = false;
                }
            }
            Keys.onDeletePressed: (event) => {
if (face.displayMode === "clipboard" && resultList.isSelectable(resultList.currentIndex)) {
                    face.deleteRequested(resultList.currentIndex);
                    event.accepted = true;
                } else {
                    event.accepted = false;
                }
            }
            Keys.onEscapePressed: face.closeRequested()
            Keys.onReturnPressed: face.submit()
            Keys.onEnterPressed: face.submit()

            Text {
                anchors.verticalCenter: parent.verticalCenter
                x: 2
                text: face.placeholder
                color: Theme.subtextDim
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontBody
                font.weight: Font.Medium
                visible: searchInput.text === ""
                z: -1
            }

        }

        Item {
            id: clearButton

            width: searchInput.text !== "" ? 34 : 0
            height: 34
            anchors.right: parent.right
            anchors.rightMargin: searchInput.text !== "" ? 5 : 0
            anchors.verticalCenter: parent.verticalCenter
            visible: searchInput.text !== ""

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: Theme.text
                opacity: clearTap.pressed ? Theme.statePressed : (clearHover.hovered ? Theme.stateHover : 0)

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.durQuick
                    }

                }

            }

            DockGlyph {
                anchors.centerIn: parent
                width: 15
                height: 15
                pathData: DockIcons.close
                glyphColor: clearHover.hovered ? Theme.text : Theme.subtext
            }

            HoverHandler {
                id: clearHover
            }

            TapHandler {
                id: clearTap

                onTapped: {
                    searchInput.text = "";
                    searchInput.forceActiveFocus();
                }
            }

            Behavior on width {
                NumberAnimation {
                    duration: Theme.durShort
                    easing.type: Easing.OutCubic
                }

            }

        }

    }

    // beside the search field while it searches; the wider modes take the room back
    Item {
        id: powerChips

        readonly property bool shown: face.showPowerChips && (face.mode === "apps" || face.mode === "commands")
        property real reveal: powerChips.shown ? 1 : 0

        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: face.searchHeight
        // the gap to the search field folds away with the chips
        width: (chipRow.width + 8) * powerChips.reveal
        visible: powerChips.reveal > 0
        clip: true

        Row {
            id: chipRow

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6
            opacity: powerChips.reveal

            Repeater {
                model: face.powerChips

                delegate: Item {
                    id: chip

                    required property var modelData

                    readonly property bool armed: face.armedPower === chip.modelData.id
                    // the label slides out on hover, and stays out while it waits on a second click
                    readonly property bool open: chipHover.hovered || chip.armed
                    readonly property color tone: chip.modelData.danger ? Theme.error : Theme.accent
                    // armed, it drops the fill so the red confirmation still reads
                    readonly property bool filled: chip.modelData.accent === true && !chip.armed

                    width: face.searchHeight + (chip.open ? chipLabel.implicitWidth + 12 : 0)
                    height: face.searchHeight
                    clip: true

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.radiusPill
                        color: chip.filled ? Theme.accent : Theme.withBlur(Theme.bgTile)

                        Behavior on color {
                            ColorAnimation {
                                duration: Theme.durShort
                            }

                        }

                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.radiusPill
                        color: chip.armed ? chip.tone : (chip.filled ? Theme.fgAccent : Theme.text)
                        opacity: chip.armed ? Theme.stateFocus : (chipTap.pressed ? Theme.statePressed : (chipHover.hovered ? Theme.stateHover : 0))

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Theme.durQuick
                            }

                        }

                    }

                    DockGlyph {
                        x: Math.round((face.searchHeight - width) / 2)
                        anchors.verticalCenter: parent.verticalCenter
                        width: 18
                        height: 18
                        pathData: chip.modelData.glyph
                        glyphColor: chip.filled ? Theme.fgAccent : (chip.open ? chip.tone : Theme.subtext)

                        Behavior on glyphColor {
                            ColorAnimation {
                                duration: Theme.durShort
                            }

                        }

                    }

                    Text {
                        id: chipLabel

                        x: face.searchHeight - 6
                        anchors.verticalCenter: parent.verticalCenter
                        text: chip.armed ? chip.modelData.confirm : chip.modelData.label
                        color: chip.armed ? chip.tone : (chip.filled ? Theme.fgAccent : Theme.text)
                        opacity: chip.open ? 1 : 0
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontLabel
                        font.weight: Font.Medium

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Theme.durShort
                            }

                        }

                    }

                    HoverHandler {
                        id: chipHover
                    }

                    TapHandler {
                        id: chipTap

                        onTapped: face.powerChipTapped(chip.modelData.id)
                    }

                    Behavior on width {
                        NumberAnimation {
                            duration: Theme.durShort
                            easing.type: Easing.OutCubic
                        }

                    }

                }

            }

        }

        Behavior on reveal {
            NumberAnimation {
                duration: Theme.durShort
                easing.type: Easing.OutCubic
            }

        }

    }

    function submit() {
        if (face.displayMode === "wallpaper")
            wallStrip.activateCurrent();
        else if (face.displayMode === "power")
            powerRow.activateCurrent();
        else
            resultList.activateCurrent();
    }

}
