import QtQuick
import QtQuick.Controls
import qs

Item {
    id: face

    property var host
    readonly property bool active: face.host ? face.host.open : false
    readonly property string tab: face.host ? face.host.tab : "emoji"
    property string query: ""
    // rail index: 0 recent, 1 favourites, 2+ groups
    property int catIndex: 0
    property int selIndex: 0
    property int hoverIndex: -1

    readonly property real pad: 18
    readonly property bool searching: face.query.trim() !== ""
    readonly property bool isEmoji: face.tab === "emoji"
    readonly property bool isKaomoji: face.tab === "kaomoji"
    readonly property bool isGif: face.tab === "gif"

    readonly property var emojiByChar: {
        var m = {};
        var data = face.host ? face.host.emojiData : [];
        for (var i = 0; i < data.length; i++) {
            var it = data[i];
            m[it.e] = it;
            if (it.t) {
                for (var j = 0; j < it.t.length; j++) {
                    if (it.t[j])
                        m[it.t[j]] = it;

                }
            }
        }
        return m;
    }
    readonly property var kaomojiByChar: {
        var m = {};
        var data = face.host ? face.host.kaomojiData : [];
        for (var i = 0; i < data.length; i++) m[data[i].e] = data[i];
        return m;
    }

    // one icon per group, in json group order
    readonly property var emojiGroupIcons: ["😀", "🧑", "🐻", "🍔", "✈️", "⚽", "💡", "❤️", "🏁"]
    readonly property var kaomojiGroupIcons: ["^▽^", "♡‿♡", "T_T", "ಠ_ಠ", "・_・", "⊙_⊙", "^-^ﾉ", "･ᴥ･", "ᕕᐛᕗ", "◕‿◕", "°ʖ°", "【】"]

    readonly property var rail: {
        var out = [{
            "icon": face.isKaomoji ? "↺" : "🕘",
            "name": "Recent"
        }, {
            "icon": face.isKaomoji ? "★" : "⭐",
            "name": "Favourites"
        }];
        if (!face.host)
            return out;

        var groups = face.isKaomoji ? face.host.kaomojiGroups : face.host.emojiGroups;
        var icons = face.isKaomoji ? face.kaomojiGroupIcons : face.emojiGroupIcons;
        for (var i = 0; i < groups.length; i++) {
            out.push({
                "icon": icons[i] || "•",
                "name": groups[i]
            });
        }
        return out;
    }

    // grid model: {d: glyph, n: name, k: keywords}
    readonly property var entries: {
        if (!face.host || face.isGif)
            return [];

        var data = face.isKaomoji ? face.host.kaomojiData : face.host.emojiData;
        if (data.length === 0)
            return [];

        if (face.searching)
            return face.searchEntries(data, face.query.trim().toLowerCase().replace(/^:+|:+$/g, ""));

        if (face.catIndex === 0)
            return face.listEntries(face.isKaomoji ? face.host.recentKaomojiView : face.host.recentEmojiView);

        if (face.catIndex === 1)
            return face.listEntries(face.isKaomoji ? face.host.favKaomoji : face.host.favEmoji);

        var out = [];
        var g = face.catIndex - 2;
        for (var i = 0; i < data.length; i++) {
            if (data[i].g === g)
                out.push(face.makeEntry(data[i]));

        }
        return out;
    }
    readonly property var current: {
        var i = face.hoverIndex >= 0 ? face.hoverIndex : face.selIndex;
        if (i < 0 || i >= face.entries.length)
            return null;

        return face.entries[i];
    }
    readonly property int cols: Math.max(1, Math.floor(grid.width / grid.cellWidth))
    readonly property string caption: {
        if (face.isGif)
            return "";

        if (face.searching)
            return face.entries.length + (face.entries.length === 1 ? " result" : " results");

        var name = face.catIndex < face.rail.length ? face.rail[face.catIndex].name : "";
        if (face.catIndex <= 1 && face.entries.length === 0)
            return name;

        return name + " · " + face.entries.length;
    }

    signal closeRequested()
    signal dragged(real dx, real dy)

    function makeEntry(it) {
        return {
            "d": face.isKaomoji ? it.e : face.host.toned(it),
            "n": it.n,
            "k": it.k || ""
        };
    }

    function listEntries(list) {
        var map = face.isKaomoji ? face.kaomojiByChar : face.emojiByChar;
        var out = [];
        for (var i = 0; i < list.length; i++) {
            var it = map[list[i]];
            out.push({
                "d": list[i],
                "n": it ? it.n : "",
                "k": it ? (it.k || "") : ""
            });
        }
        return out;
    }

    function searchEntries(data, q) {
        if (q === "")
            return [];

        var starts = [];
        var words = [];
        var rest = [];
        var anchored = " " + q;
        for (var i = 0; i < data.length; i++) {
            var it = data[i];
            if (it.n.indexOf(q) === 0)
                starts.push(face.makeEntry(it));
            else if ((" " + it.n).indexOf(anchored) !== -1)
                words.push(face.makeEntry(it));
            else if ((" " + it.s).indexOf(anchored) !== -1)
                rest.push(face.makeEntry(it));
        }
        return starts.concat(words, rest);
    }

    function isFav(d) {
        if (!face.host || d === "")
            return false;

        return face.isKaomoji ? face.host.isFavKaomoji(d) : face.host.isFavEmoji(d);
    }

    function toggleFav(d) {
        if (!face.host || d === "")
            return ;

        if (face.isKaomoji)
            face.host.toggleFavKaomoji(d);
        else
            face.host.toggleFavEmoji(d);
    }

    function activate(i) {
        if (i < 0 || i >= face.entries.length)
            return ;

        var d = face.entries[i].d;
        face.host.insert(d);
        if (face.isKaomoji)
            face.host.pushRecentKaomoji(d);
        else
            face.host.pushRecentEmoji(d);
    }

    function moveSel(delta) {
        var n = face.entries.length;
        if (n === 0)
            return ;

        face.selIndex = Math.max(0, Math.min(n - 1, face.selIndex + delta));
        face.hoverIndex = -1;
        grid.positionViewAtIndex(face.selIndex, GridView.Contain);
    }

    function defaultCat() {
        if (!face.host)
            return 2;

        var recents = face.isKaomoji ? face.host.recentKaomojiView : face.host.recentEmojiView;
        return recents.length > 0 ? 0 : 2;
    }

    function setTab(t) {
        if (!face.host || face.host.tab === t)
            return ;

        face.host.tab = t;
        face.query = "";
        face.selIndex = 0;
        face.hoverIndex = -1;
        face.catIndex = face.defaultCat();
    }

    onActiveChanged: {
        if (!face.active)
            return ;

        face.query = "";
        face.selIndex = 0;
        face.hoverIndex = -1;
        if (face.catIndex === 0)
            face.catIndex = face.defaultCat();

        grid.positionViewAtBeginning();
        searchInput.forceActiveFocus();
    }
    onEntriesChanged: {
        face.selIndex = 0;
        face.hoverIndex = -1;
    }
    onTabChanged: {
        if (face.active)
            searchInput.forceActiveFocus();

    }

    Rectangle {
        id: panel

        anchors.fill: parent
        radius: Theme.radiusXl
        color: Theme.bg

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
        }

        // everywhere but the tabs is the drag grip
        Item {
            id: header

            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.topMargin: face.pad - 4
            anchors.leftMargin: face.pad
            anchors.rightMargin: face.pad
            height: 30

            MouseArea {
                id: dragZone

                property real grabX: 0
                property real grabY: 0

                anchors.fill: parent
                cursorShape: Qt.SizeAllCursor
                onPressed: (m) => {
                    dragZone.grabX = m.x;
                    dragZone.grabY = m.y;
                }
                onPositionChanged: (m) => {
                    return face.dragged(m.x - dragZone.grabX, m.y - dragZone.grabY);
                }
            }

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 18

                Repeater {
                    model: [{
                        "id": "emoji",
                        "label": "Emoji"
                    }, {
                        "id": "kaomoji",
                        "label": "Kaomoji"
                    }, {
                        "id": "gif",
                        "label": "GIFs"
                    }]

                    delegate: Item {
                        id: tabItem

                        required property var modelData
                        readonly property bool selected: face.tab === tabItem.modelData.id

                        width: tabLabel.width
                        height: 24

                        Text {
                            id: tabLabel

                            anchors.top: parent.top
                            text: tabItem.modelData.label
                            color: tabItem.selected ? Theme.text : Theme.subtext
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontTitle
                            font.bold: true
                            opacity: tabItem.selected || tabHover.hovered ? 1 : 0.7

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: Theme.durQuick
                                }

                            }

                        }

                        Rectangle {
                            anchors.bottom: parent.bottom
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: tabItem.selected ? tabLabel.width : 0
                            height: 2
                            radius: 1
                            color: Theme.accent

                            Behavior on width {
                                NumberAnimation {
                                    duration: Theme.durShort
                                    easing.type: Theme.easeStandard
                                }

                            }

                        }

                        HoverHandler {
                            id: tabHover

                            cursorShape: Qt.PointingHandCursor
                        }

                        TapHandler {
                            onTapped: face.setTab(tabItem.modelData.id)
                        }

                    }

                }

            }

            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: face.host && face.host.lastCopied !== "" ? face.host.lastAction : ""
                color: Theme.accent
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontLabel
                font.bold: true
                opacity: text !== "" ? 1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.durQuick
                    }

                }

            }

        }

        Rectangle {
            id: searchBar

            anchors.top: header.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.topMargin: 10
            anchors.leftMargin: face.pad
            anchors.rightMargin: face.pad
            height: 34
            radius: Theme.radiusPill
            color: Theme.withBlur(Theme.bgTile)

            Row {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                spacing: 8

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "🔍"
                    font.family: "Noto Color Emoji"
                    font.pixelSize: Theme.fs(12)
                    opacity: 0.65
                }

                TextInput {
                    id: searchInput

                    width: parent.width - 30
                    anchors.verticalCenter: parent.verticalCenter
                    text: face.query
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontBody
                    font.bold: true
                    clip: true
                    focus: true
                    onTextChanged: face.query = text
                    Keys.onLeftPressed: face.moveSel(-1)
                    Keys.onRightPressed: face.moveSel(1)
                    Keys.onUpPressed: face.moveSel(-face.cols)
                    Keys.onDownPressed: face.moveSel(face.cols)
                    Keys.onEscapePressed: face.closeRequested()
                    Keys.onReturnPressed: face.activate(face.selIndex)
                    Keys.onEnterPressed: face.activate(face.selIndex)
                    Keys.onTabPressed: face.setTab(face.isEmoji ? "kaomoji" : (face.isKaomoji ? "gif" : "emoji"))
                    Keys.onPressed: (event) => {
                        if (event.key === Qt.Key_PageDown) {
                            face.moveSel(face.cols * 4);
                            event.accepted = true;
                        } else if (event.key === Qt.Key_PageUp) {
                            face.moveSel(-face.cols * 4);
                            event.accepted = true;
                        }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        x: 2
                        text: face.isGif ? "Search GIFs…" : (face.isKaomoji ? "Search text faces…" : "Search emoji…")
                        color: Theme.subtextDim
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontBody
                        font.bold: true
                        visible: searchInput.text === ""
                        z: -1
                    }

                }

            }

        }

        ListView {
            id: railView

            anchors.top: searchBar.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.topMargin: face.isGif ? 0 : 12
            anchors.leftMargin: face.pad - 4
            anchors.rightMargin: face.pad - 4
            height: face.isGif ? 0 : 30
            visible: !face.isGif
            orientation: ListView.Horizontal
            clip: true
            spacing: 2
            model: face.rail
            boundsBehavior: Flickable.StopAtBounds

            delegate: Item {
                id: railItem

                required property var modelData
                required property int index
                readonly property bool selected: !face.searching && face.catIndex === railItem.index

                width: 34
                height: 30

                Text {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: -2
                    text: railItem.modelData.icon
                    color: Theme.text
                    font.family: face.isKaomoji ? Theme.fontFamily : "Noto Color Emoji"
                    font.pixelSize: face.isKaomoji ? 13 : 15
                    font.bold: face.isKaomoji
                    opacity: railItem.selected ? 1 : (railHover.hovered ? 0.8 : 0.45)

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.durQuick
                        }

                    }

                }

                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: railItem.selected ? 16 : 0
                    height: 2
                    radius: 1
                    color: Theme.accent

                    Behavior on width {
                        NumberAnimation {
                            duration: Theme.durShort
                            easing.type: Theme.easeStandard
                        }

                    }

                }

                HoverHandler {
                    id: railHover

                    cursorShape: Qt.PointingHandCursor
                }

                TapHandler {
                    onTapped: {
                        face.query = "";
                        face.catIndex = railItem.index;
                        grid.positionViewAtBeginning();
                    }
                }

                TapHandler {
                    acceptedButtons: Qt.RightButton
                    enabled: railItem.index === 0
                    onTapped: face.host.clearRecents()
                }

            }

        }

        Text {
            id: caption

            anchors.top: railView.bottom
            anchors.left: parent.left
            anchors.topMargin: face.isGif ? 0 : 10
            anchors.leftMargin: face.pad + 2
            height: face.isGif ? 0 : caption.implicitHeight
            visible: !face.isGif
            text: face.caption
            color: Theme.subtext
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontLabel
            font.bold: true
        }

        Item {
            id: body

            anchors.top: caption.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: footer.top
            anchors.topMargin: 8
            anchors.leftMargin: face.pad - 4
            anchors.rightMargin: face.pad - 4
            anchors.bottomMargin: face.isGif ? face.pad - 6 : 8

            GridView {
                id: grid

                anchors.fill: parent
                visible: !face.isGif
                clip: true
                cellWidth: face.isKaomoji ? Math.floor(grid.width / 2) : 44
                cellHeight: face.isKaomoji ? 40 : 44
                model: face.entries
                boundsBehavior: Flickable.StopAtBounds
                cacheBuffer: 400

                delegate: Item {
                    id: cell

                    required property var modelData
                    required property int index
                    readonly property bool selected: face.selIndex === cell.index
                    readonly property bool hovered: face.hoverIndex === cell.index

                    width: grid.cellWidth
                    height: grid.cellHeight

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 2
                        radius: Theme.radiusSm
                        color: {
                            if (face.host && face.host.lastCopied === cell.modelData.d)
                                return Theme.alpha(Theme.accent, 0.45);

                            if (cell.hovered)
                                return Theme.alpha(Theme.accent, 0.2);

                            if (cell.selected)
                                return Theme.withBlur(Theme.bgActive);

                            return "transparent";
                        }

                        Behavior on color {
                            ColorAnimation {
                                duration: Theme.durQuick
                            }

                        }

                    }

                    Text {
                        anchors.centerIn: parent
                        width: face.isKaomoji ? cell.width - 12 : cell.width
                        text: cell.modelData.d
                        color: Theme.text
                        font.family: face.isKaomoji ? Theme.fontFamily : "Noto Color Emoji"
                        font.pixelSize: face.isKaomoji ? Theme.fontBody : 22
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                    }

                    Rectangle {
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.topMargin: 5
                        anchors.rightMargin: 5
                        width: 4
                        height: 4
                        radius: 2
                        color: Theme.accent
                        visible: face.isFav(cell.modelData.d)
                    }

                    HoverHandler {
                        id: cellHover

                        cursorShape: Qt.PointingHandCursor
                        onHoveredChanged: {
                            if (cellHover.hovered)
                                face.hoverIndex = cell.index;
                            else if (face.hoverIndex === cell.index)
                                face.hoverIndex = -1;
                        }
                    }

                    TapHandler {
                        onTapped: {
                            face.selIndex = cell.index;
                            face.activate(cell.index);
                        }
                    }

                    TapHandler {
                        acceptedButtons: Qt.RightButton
                        onTapped: face.toggleFav(cell.modelData.d)
                    }

                }

                NumberAnimation {
                    id: scrollAnim

                    target: grid
                    property: "contentY"
                    duration: Theme.ms(220)
                    easing.type: Theme.easeStandard
                }

                WheelHandler {
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    onWheel: (event) => {
                        event.accepted = true;
                        var maxY = Math.max(0, grid.contentHeight - grid.height);
                        var base = scrollAnim.running ? scrollAnim.to : grid.contentY;
                        var target = Math.max(0, Math.min(maxY, base - (event.angleDelta.y / 120) * 66));
                        if (target === base)
                            return ;

                        scrollAnim.stop();
                        scrollAnim.from = grid.contentY;
                        scrollAnim.to = target;
                        scrollAnim.start();
                    }
                }

                ScrollBar.vertical: ScrollBar {
                    id: scrollBar

                    policy: ScrollBar.AsNeeded
                    visible: grid.contentHeight > grid.height
                    width: 8

                    contentItem: Rectangle {
                        implicitWidth: scrollBar.hovered || scrollBar.pressed ? 8 : 6
                        radius: width / 2
                        color: scrollBar.pressed ? Theme.accent : (scrollBar.hovered ? Theme.alpha(Theme.text, 0.4) : Theme.alpha(Theme.text, 0.2))

                        Behavior on implicitWidth {
                            NumberAnimation {
                                duration: Theme.ms(150)
                                easing.type: Theme.easeStandard
                            }

                        }

                    }

                    background: Rectangle {
                        color: "transparent"
                    }

                }

            }

            Column {
                anchors.centerIn: parent
                spacing: 6
                visible: !face.isGif && face.entries.length === 0
                opacity: visible ? 1 : 0

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: {
                        if (face.searching)
                            return "🫥";

                        if (face.catIndex === 0)
                            return "🕘";

                        return "⭐";
                    }
                    font.family: "Noto Color Emoji"
                    font.pixelSize: Theme.fs(26)
                    opacity: 0.5
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: {
                        if (face.searching)
                            return "Nothing matches “" + face.query.trim() + "”";

                        if (face.catIndex === 0)
                            return "Nothing used yet";

                        return "Right-click anything to favourite it";
                    }
                    color: Theme.subtext
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontLabel
                    font.bold: true
                }

            }

            GifPane {
                id: gifPane

                anchors.fill: parent
                visible: face.isGif
                host: face.host
                query: face.query
                onQueryRequested: (q) => {
                    face.query = q;
                    searchInput.text = q;
                }
            }

        }

        Item {
            id: footer

            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottomMargin: face.isGif ? 0 : face.pad - 4
            anchors.leftMargin: face.pad
            anchors.rightMargin: face.pad
            height: face.isGif ? 0 : 40

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.SizeAllCursor
                onPressed: (m) => {
                    footerDrag.grabX = m.x;
                    footerDrag.grabY = m.y;
                }
                onPositionChanged: (m) => {
                    return face.dragged(m.x - footerDrag.grabX, m.y - footerDrag.grabY);
                }

                QtObject {
                    id: footerDrag

                    property real grabX: 0
                    property real grabY: 0
                }

            }

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 12
                visible: !face.isGif

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: face.current ? face.current.d : ""
                    color: Theme.text
                    font.family: face.isKaomoji ? Theme.fontFamily : "Noto Color Emoji"
                    font.pixelSize: face.isKaomoji ? Theme.fontBody : 22
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    width: footer.width - 190

                    Text {
                        width: parent.width
                        text: face.current ? (face.current.n !== "" ? face.current.n : "unnamed") : (face.host && face.host.wtypeAvailable ? "Click to type it into the focused window" : "Click to copy · stays open")
                        color: face.current ? Theme.text : Theme.subtext
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontBody
                        font.bold: true
                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width
                        text: face.current && face.current.k !== "" ? face.current.k : "Right-click to favourite · Esc to close"
                        color: Theme.subtextDim
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fs(10)
                        elide: Text.ElideRight
                    }

                }

            }

            Row {
                id: tonePicker

                anchors.right: starButton.left
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                spacing: 5
                visible: face.isEmoji

                Repeater {
                    model: ["#ffc83d", "#f7dece", "#f3d2a2", "#d5ab88", "#af7e57", "#7c533e"]

                    delegate: Rectangle {
                        id: toneDot

                        required property var modelData
                        required property int index
                        readonly property bool selected: face.host && face.host.skinTone === toneDot.index

                        width: toneDot.selected ? 13 : 9
                        height: width
                        radius: width / 2
                        color: toneDot.modelData
                        opacity: toneDot.selected || toneHover.hovered ? 1 : 0.55
                        anchors.verticalCenter: parent.verticalCenter

                        Behavior on width {
                            NumberAnimation {
                                duration: Theme.durQuick
                                easing.type: Theme.easeStandard
                            }

                        }

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Theme.durQuick
                            }

                        }

                        HoverHandler {
                            id: toneHover

                            cursorShape: Qt.PointingHandCursor
                        }

                        TapHandler {
                            onTapped: face.host.setSkinTone(toneDot.index)
                        }

                    }

                }

            }

            Text {
                id: starButton

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                visible: !face.isGif && face.current !== null
                text: face.current && face.isFav(face.current.d) ? "★" : "☆"
                color: face.current && face.isFav(face.current.d) ? Theme.accent : Theme.subtext
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fs(17)

                HoverHandler {
                    cursorShape: Qt.PointingHandCursor
                }

                TapHandler {
                    onTapped: face.toggleFav(face.current ? face.current.d : "")
                }

            }

        }

    }

}
