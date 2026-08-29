import QtQuick
import qs

Item {
    id: face

    // "apps" | "commands" | "theme" | "wallpaper" | "power"
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
    property string placeholder: "Search apps, or type > for commands"
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

    function setWallpaperIndex(i) {
        wallStrip.setIndexImmediate(i);
    }

    function resetSelection() {
        resultList.resetSelection();
        powerRow.currentIndex = 0;
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
            emptyLabel: face.displayMode === "commands" ? "No commands found" : (face.displayMode === "theme" ? "No themes found" : "No apps found")
            onActivated: (index) => face.activated(index)
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
        anchors.right: parent.right
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

    function submit() {
        if (face.displayMode === "wallpaper")
            wallStrip.activateCurrent();
        else if (face.displayMode === "power")
            powerRow.activateCurrent();
        else
            resultList.activateCurrent();
    }

}
