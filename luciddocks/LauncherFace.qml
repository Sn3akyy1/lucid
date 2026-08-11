import QtQuick
import QtQuick.Controls
import QtQuick.Shapes
import Quickshell
import Quickshell.Widgets
import qs

Item {
    id: launcherFace

    property bool displayThemeMode: false
    property bool powerMode: false
    property var model: null
    property bool commandMode: false
    property bool themeMode: false
    property string activeThemeId: ""
    property bool wallpaperMode: false
    property var wallpaperModel: null
    property bool blurMode: false
    property alias searchText: searchInput.text
    property string initialSearchText: ""
    // arrow-key selection, drives the ListView's currentIndex + highlight
    property int arrowIndex: 0
    property var displayModel: null
    property bool displayCommandMode: false
    property bool displayWallpaperMode: false
    property bool displayPowerMode: false
    property bool displayBlurMode: false
    // settling values for content that should measure against the resize target,
    // not the animating width/height above
    property real targetWidth: width
    property real targetHeight: height
    readonly property real stableListHeight: targetHeight - searchBar.height - 16
    property int rowH: (displayCommandMode || displayThemeMode) ? 56 : 46
    property int rowUnit: rowH + appList.spacing
    property bool needsScrollbar: appList.contentHeight > appList.height
    // purely visual hover highlight, never touches arrowIndex - a fully
    // reactive binding (self-corrects on mode/count/scroll changes with no
    // manual state to go stale) rather than an imperative event-driven one
    property int hoveredIndex: {
        if (!listHover.hovered)
            return -1;

        var idx = Math.floor((listHover.point.position.y + appList.contentY) / rowUnit);
        if (idx < 0 || idx >= appList.count)
            return -1;

        return idx;
    }
    // holds the last hover position while it fades out on mouse-leave
    property int lastHoveredIndex: 0

    signal appLaunched(string name)
    signal commandActivated(string commandId)
    signal wallpaperChosen(string path)
    signal wallpaperPreviewed(string path)
    signal closeRequested()
    signal themeChosen(string id)
    signal powerActionChosen(string id)
    signal blurLevelChosen(real level)

    function setWallpaperIndex(i) {
        wallStrip.setIndexImmediate(i);
    }

    function activateCurrent() {
        if (appList.currentIndex < 0)
            return ;

        var item = launcherFace.model.get(appList.currentIndex);
        if (!item)
            return ;

        if (launcherFace.themeMode) {
            if (item.disabled)
                return ;

            launcherFace.themeChosen(item.id);
            return ;
        }
        if (launcherFace.commandMode) {
            launcherFace.commandActivated(item.commandId);
            return ;
        }
        if (item.command !== "")
            Quickshell.execDetached(["sh", "-c", item.command]);

        launcherFace.appLaunched(item.name);
    }

    function highlightMatch(name, q) {
        q = q.trim();
        if (q === "")
            return name;

        var idx = name.toLowerCase().indexOf(q.toLowerCase());
        if (idx === -1)
            return name;

        return name.substring(0, idx) + "<font color=\"" + Theme.toHex(Theme.accent) + "\">" + name.substring(idx, idx + q.length) + "</font>" + name.substring(idx + q.length);
    }

    function scrollToCurrent() {
        var itemTop = appList.currentIndex * rowUnit;
        var itemBottom = itemTop + rowH;
        var cur = scrollAnim.running ? scrollAnim.to : appList.contentY;
        var target = cur;
        if (itemTop < cur)
            target = itemTop;
        else if (itemBottom > cur + appList.height)
            target = itemBottom - appList.height;
        else
            return ;
        var maxY = Math.max(0, appList.contentHeight - appList.height);
        target = Math.max(0, Math.min(maxY, target));
        scrollAnim.stop();
        scrollAnim.from = appList.contentY;
        scrollAnim.to = target;
        scrollAnim.start();
    }

    function syncDisplayState() {
        displayModel = model;
        displayCommandMode = commandMode;
        displayThemeMode = themeMode;
        displayWallpaperMode = wallpaperMode;
        displayPowerMode = powerMode;
        displayBlurMode = blurMode;
    }

    // any of these six changes what shows in listContainer - all go through
    // the same cross-fade so mode switches feel consistent
    function requestModeTransition() {
        if (!visible) {
            syncDisplayState();
            return ;
        }
        modeFade.restart();
    }

    onHoveredIndexChanged: {
        if (hoveredIndex >= 0)
            lastHoveredIndex = hoveredIndex;

    }
    onModelChanged: requestModeTransition()
    onWallpaperModeChanged: requestModeTransition()
    onPowerModeChanged: requestModeTransition()
    onBlurModeChanged: requestModeTransition()
    onVisibleChanged: {
        if (visible) {
            launcherFace.arrowIndex = 0;
            searchInput.text = launcherFace.initialSearchText;
            launcherFace.initialSearchText = "";
            appList.positionViewAtBeginning();
            searchInput.forceActiveFocus();
        }
    }

    SequentialAnimation {
        id: modeFade

        NumberAnimation {
            target: listContainer
            property: "opacity"
            to: 0
            duration: 140
            easing.type: Easing.InCubic
        }

        ScriptAction {
            script: {
                launcherFace.syncDisplayState();
                launcherFace.arrowIndex = 0;
                appList.positionViewAtBeginning();
            }
        }

        NumberAnimation {
            target: listContainer
            property: "opacity"
            to: 1
            duration: 260
            easing.type: Easing.OutCubic
        }

    }

    Component {
        id: appDelegate

        Item {
            id: appRow

            required property string name
            required property string iconName
            required property string command
            required property int index
            property bool selected: appList.currentIndex === index

            width: appList.width - (launcherFace.needsScrollbar ? 16 : 0)
            height: 46

            Rectangle {
                anchors.fill: parent
                radius: 12
                color: "transparent"

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    spacing: 12

                    IconImage {
                        width: 30
                        height: 30
                        source: appRow.iconName !== "" ? Quickshell.iconPath(appRow.iconName, "") : ""
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: appRow.name
                        color: appRow.selected ? Theme.text : Theme.alpha(Theme.text, 0.85)
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        font.bold: true
                    }

                }

            }

            TapHandler {
                onTapped: {
                    launcherFace.arrowIndex = appRow.index;
                    launcherFace.activateCurrent();
                }
            }

        }

    }

    Component {
        id: commandDelegate

        Item {
            id: cmdRow

            required property string name
            required property string desc
            required property string iconPath
            required property int index
            property bool selected: appList.currentIndex === index

            width: appList.width - (launcherFace.needsScrollbar ? 16 : 0)
            height: 56

            Rectangle {
                anchors.fill: parent
                radius: 12
                color: "transparent"

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    spacing: 12

                    Shape {
                        width: 22
                        height: 22
                        anchors.verticalCenter: parent.verticalCenter
                        preferredRendererType: Shape.CurveRenderer

                        ShapePath {
                            fillColor: cmdRow.selected ? Theme.accent : Theme.accentMuted
                            strokeWidth: 0

                            PathSvg {
                                path: cmdRow.iconPath
                            }

                        }

                        transform: Scale {
                            xScale: 22 / 24
                            yScale: 22 / 24
                        }

                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        Text {
                            textFormat: Text.StyledText
                            text: launcherFace.highlightMatch(cmdRow.name, launcherFace.searchText.substring(1))
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            font.bold: true
                        }

                        Text {
                            text: cmdRow.desc
                            color: Theme.subtext
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                        }

                    }

                }

            }

            TapHandler {
                onTapped: {
                    launcherFace.arrowIndex = cmdRow.index;
                    launcherFace.activateCurrent();
                }
            }

        }

    }

    Component {
        id: themeDelegate

        Item {
            id: themeRow

            required property string id
            required property string name
            required property string desc
            required property string swatchBg
            required property string swatchAccent
            required property bool disabled
            required property int index
            property bool selected: appList.currentIndex === index

            width: appList.width - (launcherFace.needsScrollbar ? 16 : 0)
            height: 56
            opacity: themeRow.disabled ? 0.45 : 1

            Rectangle {
                anchors.fill: parent
                radius: 12
                color: "transparent"

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    spacing: 12

                    Rectangle {
                        width: 22
                        height: 22
                        radius: 11
                        anchors.verticalCenter: parent.verticalCenter
                        color: themeRow.swatchBg
                        border.color: themeRow.selected ? Theme.text : Theme.outline
                        border.width: 1
                        clip: true

                        Rectangle {
                            width: parent.width / 2
                            height: parent.height
                            anchors.right: parent.right
                            color: themeRow.swatchAccent
                        }

                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        Text {
                            textFormat: Text.StyledText
                            text: launcherFace.highlightMatch(themeRow.name, launcherFace.searchText.substring(6))
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            font.bold: true
                        }

                        Text {
                            text: themeRow.desc
                            color: Theme.subtext
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                        }

                    }

                }

                Shape {
                    width: 16
                    height: 16
                    anchors.right: parent.right
                    anchors.rightMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    visible: themeRow.id === launcherFace.activeThemeId
                    preferredRendererType: Shape.CurveRenderer

                    ShapePath {
                        fillColor: Theme.accent
                        strokeWidth: 0

                        PathSvg {
                            path: "M9 16.17 4.83 12l-1.42 1.41L9 19 21 7l-1.41-1.41L9 16.17Z"
                        }

                    }

                    transform: Scale {
                        xScale: 16 / 24
                        yScale: 16 / 24
                    }

                }

            }

            TapHandler {
                enabled: !themeRow.disabled
                onTapped: {
                    launcherFace.arrowIndex = themeRow.index;
                    launcherFace.activateCurrent();
                }
            }

        }

    }

    Column {
        anchors.fill: parent
        spacing: 16

        Item {
            id: listContainer

            width: parent.width
            height: parent.height - searchBar.height - 16

            HoverHandler {
                id: listHover
            }

            ListView {
                id: appList

                anchors.fill: parent
                visible: !launcherFace.displayWallpaperMode && !launcherFace.displayPowerMode && !launcherFace.displayBlurMode
                clip: true
                spacing: 4
                bottomMargin: 8
                model: launcherFace.displayModel
                delegate: launcherFace.displayThemeMode ? themeDelegate : (launcherFace.displayCommandMode ? commandDelegate : appDelegate)
                currentIndex: launcherFace.arrowIndex
                // off, or it auto-scrolls on hover and causes a "menu shifts" glitch -
                // we manage the highlight's geometry ourselves below instead
                highlightFollowsCurrentItem: false
                interactive: true
                boundsBehavior: Flickable.StopAtBounds

                NumberAnimation {
                    id: scrollAnim

                    target: appList
                    property: "contentY"
                    duration: 220
                    easing.type: Easing.OutCubic
                }

                WheelHandler {
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    onWheel: (event) => {
                        // accept even at the bounds, or the native wheel handling
                        // rubber-bands independently of scrollAnim and snaps back
                        event.accepted = true;
                        var maxY = Math.max(0, appList.contentHeight - appList.height);
                        var base = scrollAnim.running ? scrollAnim.to : appList.contentY;
                        var target = Math.max(0, Math.min(maxY, base - (event.angleDelta.y / 120) * 60));
                        if (target === base)
                            return ;

                        scrollAnim.stop();
                        scrollAnim.from = appList.contentY;
                        scrollAnim.to = target;
                        scrollAnim.start();
                    }
                }

                add: Transition {
                    NumberAnimation {
                        property: "opacity"
                        from: 0
                        to: 1
                        duration: 160
                        easing.type: Easing.OutCubic
                    }

                }

                // plays once when the list first appears with rows already in
                // its model (menu just opened) - `add` above only covers rows
                // inserted into an already-visible list, so without this the
                // menu's first paint had no entrance motion at all
                populate: Transition {
                    NumberAnimation {
                        properties: "opacity"
                        from: 0
                        to: 1
                        duration: 200
                        easing.type: Easing.OutCubic
                    }

                    NumberAnimation {
                        properties: "y"
                        from: 8
                        duration: 220
                        easing.type: Easing.OutCubic
                    }

                }

                remove: Transition {
                    NumberAnimation {
                        property: "opacity"
                        from: 1
                        to: 0
                        duration: 140
                        easing.type: Easing.InCubic
                    }

                }

                displaced: Transition {
                    NumberAnimation {
                        properties: "y"
                        duration: 180
                        easing.type: Easing.OutCubic
                    }

                }

                highlight: Rectangle {
                    x: 3
                    y: appList.currentItem ? appList.currentItem.y : 0
                    width: appList.currentItem ? appList.currentItem.width : 0
                    height: appList.currentItem ? appList.currentItem.height : 0
                    radius: 12
                    color: Theme.withBlur(Theme.bgHover)
                    z: -1

                    Behavior on y {
                        NumberAnimation {
                            duration: 180
                            easing.type: Easing.OutCubic
                        }

                    }

                }

                ScrollBar.vertical: ScrollBar {
                    id: scrollBar

                    policy: ScrollBar.AsNeeded
                    visible: launcherFace.needsScrollbar
                    width: 8

                    contentItem: Rectangle {
                        implicitWidth: scrollBar.hovered || scrollBar.pressed ? 8 : 6
                        radius: width / 2
                        color: scrollBar.pressed ? Theme.accent : (scrollBar.hovered ? Theme.alpha(Theme.text, 0.4) : Theme.alpha(Theme.text, 0.2))

                        Behavior on implicitWidth {
                            NumberAnimation {
                                duration: 150
                                easing.type: Easing.OutCubic
                            }

                        }

                        Behavior on color {
                            ColorAnimation {
                                duration: 150
                            }

                        }

                    }

                    background: Rectangle {
                        color: "transparent"
                    }

                }

            }

            Rectangle {
                id: hoverHighlight

                x: 3
                y: launcherFace.lastHoveredIndex * launcherFace.rowUnit - appList.contentY
                width: appList.width - (launcherFace.needsScrollbar ? 16 : 0)
                height: launcherFace.rowH
                radius: 12
                color: Theme.alpha(Theme.accent, 0.12)
                z: -2
                opacity: appList.visible && launcherFace.hoveredIndex >= 0 ? 1 : 0
                visible: opacity > 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: 120
                        easing.type: Easing.OutCubic
                    }

                }

                Behavior on y {
                    NumberAnimation {
                        duration: 100
                        easing.type: Easing.OutCubic
                    }

                }

            }

            WallpaperStrip {
                id: wallStrip

                anchors.fill: parent
                visible: launcherFace.displayWallpaperMode
                model: launcherFace.wallpaperModel
                stableHeight: launcherFace.stableListHeight
                onChosen: (path) => {
                    return launcherFace.wallpaperChosen(path);
                }
                onPreviewed: (path) => {
                    return launcherFace.wallpaperPreviewed(path);
                }
            }

            PowerRow {
                id: powerRow

                anchors.fill: parent
                visible: launcherFace.displayPowerMode
                stableHeight: launcherFace.stableListHeight
                onActionChosen: (id) => {
                    return launcherFace.powerActionChosen(id);
                }
            }

            BlurRow {
                id: blurRow

                anchors.fill: parent
                visible: launcherFace.displayBlurMode
                stableHeight: launcherFace.stableListHeight
                value: Theme.blurAmount
                onLevelChosen: (v) => {
                    return launcherFace.blurLevelChosen(v);
                }
            }

            Column {
                id: emptyState

                anchors.centerIn: parent
                spacing: 8
                visible: appList.count === 0 && !launcherFace.displayWallpaperMode && !launcherFace.displayPowerMode && !launcherFace.displayBlurMode
                opacity: visible ? 1 : 0

                Shape {
                    width: 22
                    height: 22
                    anchors.horizontalCenter: parent.horizontalCenter
                    opacity: 0.5
                    preferredRendererType: Shape.CurveRenderer

                    ShapePath {
                        fillColor: Theme.subtext
                        strokeWidth: 0

                        PathSvg {
                            path: "M15.5 14h-.79l-.28-.27a6.5 6.5 0 1 0-.7.7l.27.28v.79l5 4.99L20.49 19l-4.99-5Zm-6 0a4.5 4.5 0 1 1 0-9 4.5 4.5 0 0 1 0 9Z"
                        }

                    }

                    transform: Scale {
                        xScale: 22 / 24
                        yScale: 22 / 24
                    }

                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: launcherFace.displayCommandMode ? "No commands found" : "No apps found"
                    color: Theme.subtext
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    font.bold: true
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: 150
                    }

                }

            }

        }

        Rectangle {
            id: searchBar

            width: parent.width
            height: 34
            radius: 999
            color: Theme.withBlur(Theme.bgTile)

            Row {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 8

                Item {
                    id: searchIcon

                    width: 15
                    height: 15
                    anchors.verticalCenter: parent.verticalCenter

                    Shape {
                        anchors.fill: parent
                        preferredRendererType: Shape.CurveRenderer

                        ShapePath {
                            fillColor: Theme.subtext
                            strokeWidth: 0

                            PathSvg {
                                path: "M15.5 14h-.79l-.28-.27a6.5 6.5 0 1 0-.7.7l.27.28v.79l5 4.99L20.49 19l-4.99-5Zm-6 0a4.5 4.5 0 1 1 0-9 4.5 4.5 0 0 1 0 9Z"
                            }

                        }

                        transform: Scale {
                            xScale: 15 / 24
                            yScale: 15 / 24
                        }

                    }

                }

                TextInput {
                    id: searchInput

                    width: parent.width - 30
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    font.bold: true
                    clip: true
                    focus: true
                    onTextChanged: {
                        launcherFace.arrowIndex = 0;
                        appList.positionViewAtBeginning();
                    }
                    Keys.onUpPressed: {
                        launcherFace.arrowIndex = Math.max(0, launcherFace.arrowIndex - 1);
                        launcherFace.scrollToCurrent();
                    }
                    Keys.onDownPressed: {
                        launcherFace.arrowIndex = Math.min(appList.count - 1, launcherFace.arrowIndex + 1);
                        launcherFace.scrollToCurrent();
                    }
                    Keys.onLeftPressed: {
                        if (launcherFace.wallpaperMode)
                            wallStrip.currentIndex = Math.max(0, wallStrip.currentIndex - 1);

                    }
                    Keys.onRightPressed: {
                        if (launcherFace.wallpaperMode && launcherFace.wallpaperModel)
                            wallStrip.currentIndex = Math.min(launcherFace.wallpaperModel.count - 1, wallStrip.currentIndex + 1);

                    }
                    Keys.onEscapePressed: launcherFace.closeRequested()
                    Keys.onReturnPressed: {
                        if (launcherFace.wallpaperMode)
                            wallStrip.activateCurrent();
                        else
                            launcherFace.activateCurrent();
                    }
                    Keys.onEnterPressed: {
                        if (launcherFace.wallpaperMode)
                            wallStrip.activateCurrent();
                        else
                            launcherFace.activateCurrent();
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        x: 2
                        text: "Type \">\" for commands"
                        color: Theme.subtextDim
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        font.bold: true
                        visible: searchInput.text === ""
                        z: -1
                    }

                }

            }

        }

    }

}
