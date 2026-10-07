import QtQuick
import qs
import qs.lucidui

// the launcher's face, on the m3 search anatomy: a head that carries the mark
// and the modes, the results under it, and a 56dp search bar at whichever end
// the settings put it
Item {
    id: face

    // "apps" | "commands" | "web" | "run" | "emoji" | "theme" | "wallpaper" | "clipboard"
    property string mode: "apps"
    property var model: null
    property var wallpaperModel: null
    property string appliedWallpaper: ""
    property int wallHeroW: Theme.dp(340)
    property int wallHeroH: Theme.dp(211)
    property int wallMidW: Theme.dp(238)
    property int wallMidH: Theme.dp(148)
    property int wallSmallW: Theme.dp(150)
    property int wallSmallH: Theme.dp(93)
    property int wallCardGap: Theme.dp(10)
    property alias searchText: searchInput.text
    property string highlightQuery: ""
    // how many rows can actually be picked, set by the dock as it builds them
    property int resultCount: 0
    readonly property string placeholder: ({
        "clipboard": "Search clipboard history",
        "web": "Search the web",
        "run": "Type a command line",
        "emoji": "Find an emoji",
        "commands": "Search commands",
        "theme": "Search themes",
        "wallpaper": "Search wallpapers"
    })[face.displayMode] || "Search apps and settings"
    readonly property string modeIcon: ({
        "commands": "keyboard_command_key",
        "clipboard": "content_paste",
        "wallpaper": "wallpaper",
        "theme": "palette",
        "web": "travel_explore",
        "run": "terminal_2",
        "emoji": "mood"
    })[face.displayMode] || "search"
    // the head's trailing readout: what the panel is holding right now
    readonly property string countLabel: {
        if (face.displayMode === "wallpaper" || face.resultCount === 0)
            return "";

        if (face.displayMode === "apps" && face.highlightQuery === "")
            return face.resultCount + (face.resultCount === 1 ? " app" : " apps");

        return face.resultCount + (face.resultCount === 1 ? " result" : " results");
    }
    property real targetWidth: width
    property real targetHeight: height
    // m3 metrics, shared with the dock's geometry through Prefs
    readonly property real cs: Prefs.launcherScale
    readonly property int searchHeight: Prefs.launcherSearchH
    readonly property int headHeight: Prefs.launcherHeadH
    readonly property bool headOn: Prefs.launcherModeBar
    readonly property bool searchTop: Prefs.launcherSearchTop
    readonly property int chromeHeight: Prefs.launcherChromeH
    readonly property int headBlock: face.headOn ? face.headHeight + Prefs.launcherHeadGap : 0
    // the launcher's modes, reachable by prefix, by pill or by Ctrl and a digit
    readonly property var modes: [{
        "key": "apps",
        "label": "Apps",
        "icon": "apps"
    }, {
        "key": "commands",
        "label": "Commands",
        "icon": "keyboard_command_key"
    }, {
        "key": "clipboard",
        "label": "Clipboard",
        "icon": "content_paste"
    }, {
        "key": "wallpaper",
        "label": "Wallpapers",
        "icon": "wallpaper"
    }, {
        "key": "theme",
        "label": "Themes",
        "icon": "palette"
    }, {
        "key": "widgets",
        "label": "Widgets",
        "icon": "widgets",
        "leaves": true
    }, {
        "key": "power",
        "label": "Power",
        "icon": "power_settings_new",
        "leaves": true
    }]
    readonly property real stableContentHeight: Math.max(0, face.targetHeight - face.chromeHeight)
    // what the empty state needs, so the dock never sizes the panel under it
    readonly property real emptyHeight: resultList.emptyExtent
    property string displayMode: "apps"
    readonly property bool listVisible: face.displayMode !== "wallpaper"
    // clipboard: the first Ctrl+Shift+Del arms clearing everything, a second within 3 s does it
    property bool clearArmed: false
    // bumped whenever the dock rewrites the results, so the preview re-reads the selected row
    property int resultsRevision: 0
    readonly property string clipEntryId: {
        face.resultsRevision;
        const r = face.displayMode === "clipboard" ? resultList.rowAt(resultList.currentIndex) : null;
        return r && r.selectable && r.kind === "clip" ? r.payload : "";
    }
    property bool justOpened: false
    // the power buttons at the end of the search field, while nothing is typed
    property bool showPowerChips: false
    property var powerButtons: []
    // the one waiting on a second press
    property string armedPower: ""

    signal powerChipTapped(string id)

    signal activated(int index)
    signal closeRequested()
    signal wallpaperChosen(string path)
    signal wallpaperPreviewed(string path)
    signal backRequested()
    signal modeRequested(string mode)
    signal deleteRequested(int index)
    signal hideRequested(int index)
    signal clearRequested()

    function setWallpaperIndex(i) {
        wallStrip.setIndexImmediate(i);
    }

    function resetSelection() {
        resultList.resetSelection();
    }

    function resultsChanged() {
        resultList.ensureSelectable();
        face.resultsRevision++;
    }

    function armOrClear() {
        if (face.clearArmed) {
            face.clearArmed = false;
            disarmTimer.stop();
            face.clearRequested();
        } else {
            face.clearArmed = true;
            disarmTimer.restart();
        }
    }

    function syncDisplayMode() {
        face.displayMode = face.mode;
        face.clearArmed = false;
        face.resetSelection();
    }

    function requestModeTransition() {
        if (!face.visible || face.justOpened) {
            face.syncDisplayMode();
            return ;
        }
        modeFade.restart();
    }

    // Tab walks the mode set, so every mode is one key away from the keyboard too.
    // the entries that leave the launcher for a panel of their own are skipped
    function cycleMode(delta) {
        var stops = face.modes.filter((m) => {
            return m.leaves !== true;
        });
        var at = -1;
        for (var i = 0; i < stops.length; i++) {
            if (stops[i].key === face.displayMode)
                at = i;

        }
        if (at === -1)
            at = 0;

        var next = stops[(at + delta + stops.length) % stops.length];
        face.modeRequested(next.key);
    }

    function submit() {
        if (face.displayMode === "wallpaper")
            wallStrip.activateCurrent();
        else
            resultList.activateCurrent();
    }

    onModeChanged: face.requestModeTransition()
    onVisibleChanged: {
        if (!face.visible)
            return ;

        face.justOpened = true;
        face.syncDisplayMode();
        searchInput.forceActiveFocus();
        face.justOpened = false;
        headBand.playEntrance();
    }

    Timer {
        id: disarmTimer

        interval: 3000
        onTriggered: face.clearArmed = false
    }

    // m3 fade through: the old mode leaves on the accelerating curve, the new
    // one grows back in rather than cross-fading over it
    SequentialAnimation {
        id: modeFade

        NumberAnimation {
            target: contentArea
            property: "opacity"
            to: 0
            duration: Theme.ms(90)
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.easeEmphasizedAccel
        }

        ScriptAction {
            script: {
                contentArea.scale = 0.94;
                face.syncDisplayMode();
            }
        }

        ParallelAnimation {
            NumberAnimation {
                target: contentArea
                property: "opacity"
                to: 1
                duration: Theme.ms(210)
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.easeEmphasizedDecel
            }

            NumberAnimation {
                target: contentArea
                property: "scale"
                to: 1
                duration: Theme.ms(210)
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.easeEmphasizedDecel
            }

        }

    }

    LauncherHead {
        id: headBand

        x: 0
        y: 0
        width: face.width
        height: face.headHeight
        visible: face.headOn
        modes: face.modes
        current: face.displayMode
        countLabel: face.countLabel
        onChosen: (key) => {
            face.modeRequested(key);
            searchInput.forceActiveFocus();
        }
        onHomeRequested: {
            face.modeRequested("apps");
            searchInput.forceActiveFocus();
        }
    }

    Rectangle {
        x: 0
        y: face.headHeight + Math.round(Prefs.launcherHeadGap / 2)
        width: face.width
        height: 1
        color: Theme.divider
        visible: face.headOn && !face.searchTop
        opacity: resultList.scrolled && resultList.visible ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.durFastEffects
            }

        }

    }

    Item {
        id: contentArea

        // explicit y, not a conditional anchor: an anchor once set never lets go
        x: 0
        y: face.headBlock + (face.searchTop ? face.searchHeight + Prefs.launcherContentGap : 0)
        width: face.width
        height: face.stableContentHeight
        transformOrigin: Item.Center
        clip: true

        LauncherList {
            id: resultList

            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            // the clipboard shares the width with its preview
            width: face.displayMode === "clipboard" ? Math.round(parent.width * 0.54) : parent.width
            visible: face.listVisible
            model: face.model
            query: face.highlightQuery
            stableHeight: face.stableContentHeight
            emptyLabel: {
                if (face.displayMode === "commands")
                    return "No commands found";

                if (face.displayMode === "theme")
                    return "No themes found";

                if (face.displayMode === "emoji")
                    return "No emoji match";

                if (face.displayMode === "clipboard")
                    return Clip.available ? "Nothing copied yet" : "Clipboard history is off";

                return "Nothing matches that";
            }
            emptyHint: {
                if (face.displayMode === "clipboard")
                    return Clip.available ? "Anything you copy from here on shows up in this list." : "Install cliphist and what you copy is kept for you.";

                if (face.displayMode === "apps")
                    return "Try a shorter word, or start with one of these:";

                return "";
            }
            // the prefixes, offered where an empty result is the moment they help
            showPrefixes: face.displayMode === "apps"
            onPrefixChosen: (p) => {
                searchInput.text = p;
                searchInput.forceActiveFocus();
            }
            onActivated: (index) => {
                return face.activated(index);
            }
            onDeleteRequested: (index) => {
                return face.deleteRequested(index);
            }
            onHideRequested: (index) => {
                return face.hideRequested(index);
            }
        }

        ClipPreview {
            anchors.left: resultList.right
            anchors.leftMargin: Theme.dp(12)
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            visible: face.displayMode === "clipboard"
            entryId: face.clipEntryId
            clearArmed: face.clearArmed
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
            onChosen: (path) => {
                return face.wallpaperChosen(path);
            }
            onPreviewed: (path) => {
                return face.wallpaperPreviewed(path);
            }
        }

    }

    // m3 search bar: 56dp tall, fully rounded, on surface container high
    Rectangle {
        id: searchBar

        readonly property bool typing: searchInput.text !== ""

        x: 0
        y: face.searchTop ? face.headBlock : face.height - face.searchHeight
        width: face.width
        height: face.searchHeight
        radius: Theme.shapeFull
        color: searchBar.typing ? Theme.withBlur(Theme.surfaceHighest) : Theme.withBlur(Theme.surfaceHigh)

        Behavior on color {
            ColorAnimation {
                duration: Theme.durDefaultEffects
            }

        }

        Item {
            id: leadingButton

            readonly property bool isBack: face.mode !== "apps"

            width: Math.round(40 * face.cs)
            height: Math.round(40 * face.cs)
            x: Theme.dp(8)
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

            Icon {
                anchors.centerIn: parent
                name: leadingButton.isBack ? "arrow_back" : face.modeIcon
                size: Math.round(24 * face.cs)
                color: Theme.primary
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

            // m3 InputTextFont: body large, on surface
            readonly property int typeSize: Math.round(Theme.typeSize("bodyLarge") * face.cs)

            anchors.left: leadingButton.right
            anchors.leftMargin: Theme.dp(8)
            anchors.right: powerChips.visible ? powerChips.left : clearButton.left
            anchors.rightMargin: Theme.dp(8)
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: searchInput.typeSize
            font.variableAxes: Theme.axes(searchInput.typeSize, Theme.typeWeight("bodyLarge"), 0)
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
                } else {
                    event.accepted = false;
                }
            }
            Keys.onRightPressed: (event) => {
                if (face.displayMode === "wallpaper" && face.wallpaperModel) {
                    wallStrip.currentIndex = Math.min(face.wallpaperModel.count - 1, wallStrip.currentIndex + 1);
                    event.accepted = true;
                } else {
                    event.accepted = false;
                }
            }
            Keys.onDeletePressed: (event) => {
                if (face.displayMode === "clipboard" && (event.modifiers & Qt.ControlModifier) && (event.modifiers & Qt.ShiftModifier)) {
                    face.armOrClear();
                    event.accepted = true;
                } else if (face.displayMode === "clipboard" && resultList.isSelectable(resultList.currentIndex)) {
                    face.deleteRequested(resultList.currentIndex);
                    event.accepted = true;
                } else {
                    event.accepted = false;
                }
            }
            Keys.onTabPressed: (event) => {
                face.cycleMode(event.modifiers & Qt.ShiftModifier ? -1 : 1);
                event.accepted = true;
            }
            // Ctrl and a digit jumps straight to a mode, in the order the head shows them
            Keys.onPressed: (event) => {
                if (!(event.modifiers & Qt.ControlModifier) || event.key < Qt.Key_1 || event.key > Qt.Key_9) {
                    event.accepted = false;
                    return ;
                }
                var at = event.key - Qt.Key_1;
                if (at < face.modes.length)
                    face.modeRequested(face.modes[at].key);

                event.accepted = true;
            }
            Keys.onEscapePressed: face.closeRequested()
            Keys.onReturnPressed: face.submit()
            Keys.onEnterPressed: face.submit()

            // the placeholder rolls over when the mode changes, rather than cutting
            LText {
                id: ghost

                anchors.verticalCenter: parent.verticalCenter
                x: Theme.dp(2)
                role: "bodyLarge"
                size: searchInput.typeSize
                text: face.placeholder
                color: Theme.subtext
                visible: searchInput.text === ""
                z: -1

                onTextChanged: rollIn.restart()

                SequentialAnimation {
                    id: rollIn

                    ParallelAnimation {
                        NumberAnimation {
                            target: ghost
                            property: "opacity"
                            from: 0
                            to: 1
                            duration: Theme.durEnter
                        }

                        NumberAnimation {
                            target: ghost
                            property: "anchors.verticalCenterOffset"
                            from: 7
                            to: 0
                            duration: Theme.durEnter
                            easing.type: Easing.Bezier
                            easing.bezierCurve: Theme.easeEmphasizedDecel
                        }

                    }

                }

            }

        }

        // in a fixed order whatever order they were picked in; restart, shut down
        // and log out turn to the error colour and want a second press
        Row {
            id: powerChips

            readonly property var shown: Power.actions.filter((a) => {
                return face.powerButtons.indexOf(a.id) !== -1;
            })

            visible: face.showPowerChips && !searchBar.typing && face.mode === "apps" && powerChips.shown.length > 0
            anchors.right: parent.right
            anchors.rightMargin: Theme.dp(8)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.dp(2)

            Repeater {
                model: powerChips.shown

                Item {
                    id: chip

                    required property var modelData
                    readonly property bool armed: face.armedPower === chip.modelData.id

                    width: Math.round(36 * face.cs)
                    height: Math.round(36 * face.cs)

                    Rectangle {
                        anchors.fill: parent
                        radius: chip.armed ? Math.round(10 * face.cs) : width / 2
                        color: chip.armed ? Theme.error : Theme.text
                        opacity: chip.armed ? 1 : (chipTap.pressed ? Theme.statePressed : (chipHover.hovered ? Theme.stateHover : 0))

                        Behavior on radius {
                            NumberAnimation {
                                duration: Theme.durFastSpatial
                                easing.type: Easing.Bezier
                                easing.bezierCurve: Theme.curveFastSpatial
                            }

                        }

                    }

                    Icon {
                        anchors.centerIn: parent
                        name: chip.modelData.icon
                        size: Math.round(20 * face.cs)
                        color: chip.armed ? Theme.fgError : (chipHover.hovered ? Theme.text : Theme.subtext)
                    }

                    HoverHandler {
                        id: chipHover
                    }

                    TapHandler {
                        id: chipTap

                        onTapped: face.powerChipTapped(chip.modelData.id)
                    }

                }

            }

        }

        Item {
            id: clearButton

            width: searchBar.typing ? Math.round(40 * face.cs) : 0
            height: Math.round(40 * face.cs)
            anchors.right: parent.right
            anchors.rightMargin: searchBar.typing ? Theme.dp(8) : 0
            anchors.verticalCenter: parent.verticalCenter
            visible: searchBar.typing

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

            Icon {
                anchors.centerIn: parent
                name: "close"
                size: Math.round(22 * face.cs)
                color: clearHover.hovered ? Theme.text : Theme.subtext
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

}
