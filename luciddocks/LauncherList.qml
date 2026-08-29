import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Widgets
import qs

Item {
    id: list

    property var model: null
    property int currentIndex: 0
    // what to embolden in each title
    property string query: ""
    property string emptyLabel: "No results"

    signal activated(int index)

    onCurrentIndexChanged: view.currentIndex = list.currentIndex

    readonly property bool needsScrollbar: view.contentHeight > view.height
    readonly property int rowWidth: Math.max(0, view.width - 14)
    readonly property Item currentItem: view.currentItem

    function rowAt(index) {
        return list.model && index >= 0 && index < list.model.count ? list.model.get(index) : null;
    }

    function isSelectable(index) {
        var r = list.rowAt(index);
        return r !== null && r.selectable && !r.disabled;
    }

    function step(delta) {
        if (!list.model || list.model.count === 0)
            return;

        var i = list.currentIndex;
        for (var n = 0; n < list.model.count; n++) {
            i += delta;
            if (i < 0 || i >= list.model.count)
                return;

            if (list.isSelectable(i)) {
                list.currentIndex = i;
                list.scrollToCurrent();
                return;
            }
        }
    }

    function firstSelectable() {
        if (!list.model)
            return 0;

        for (var i = 0; i < list.model.count; i++) {
            if (list.isSelectable(i))
                return i;
        }
        return 0;
    }

    function resetSelection() {
        list.currentIndex = list.firstSelectable();
        scrollAnim.stop();
        view.contentY = 0;
        view.positionViewAtBeginning();
    }

    function ensureSelectable() {
        if (list.model && list.model.count > 0 && !list.isSelectable(list.currentIndex))
            list.currentIndex = list.firstSelectable();

    }

    function scrollToCurrent() {
        var item = view.currentItem;
        if (!item) {
            view.positionViewAtIndex(list.currentIndex, ListView.Contain);
            return;
        }

        var cur = scrollAnim.running ? scrollAnim.to : view.contentY;
        var target = cur;
        if (item.y < cur)
            target = item.y;
        else if (item.y + item.height > cur + view.height)
            target = item.y + item.height - view.height;
        else
            return;

        var maxY = Math.max(0, view.contentHeight - view.height);
        target = Math.max(0, Math.min(maxY, target));
        scrollAnim.stop();
        scrollAnim.from = view.contentY;
        scrollAnim.to = target;
        scrollAnim.start();
    }

    function activateCurrent() {
        if (list.isSelectable(list.currentIndex))
            list.activated(list.currentIndex);

    }

    readonly property int hoveredIndex: {
        if (!listHover.hovered)
            return -1;

        var y = listHover.point.position.y + view.contentY;
        return view.indexAt(view.width / 2, y);
    }

    HoverHandler {
        id: listHover
    }

    Rectangle {
        id: selection

        property real slot: list.currentItem ? list.currentItem.y : 0
        property real slotHeight: list.currentItem ? list.currentItem.height : 0

        x: 0
        y: selection.slot - view.contentY
        width: list.rowWidth
        height: selection.slotHeight
        radius: Theme.radiusMd
        color: Theme.withBlur(Theme.bgActive)
        visible: list.currentItem !== null && view.count > 0
        z: 0

        Behavior on slot {
            NumberAnimation {
                duration: Theme.ms(220)
                easing.type: Easing.OutCubic
            }

        }

        Behavior on slotHeight {
            NumberAnimation {
                duration: Theme.ms(220)
                easing.type: Easing.OutCubic
            }

        }

    }

    ListView {
        id: view

        anchors.fill: parent
        clip: true
        spacing: 2
        bottomMargin: 8
        model: list.model
        currentIndex: list.currentIndex
        onCountChanged: {
            list.ensureSelectable();
            view.currentIndex = list.currentIndex;
        }
        highlightFollowsCurrentItem: false
        interactive: true
        boundsBehavior: Flickable.StopAtBounds
        z: 1

        NumberAnimation {
            id: scrollAnim

            target: view
            property: "contentY"
            duration: Theme.ms(220)
            easing.type: Easing.OutCubic
        }

        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: (event) => {
                event.accepted = true;
                var maxY = Math.max(0, view.contentHeight - view.height);
                var base = scrollAnim.running ? scrollAnim.to : view.contentY;
                var target = Math.max(0, Math.min(maxY, base - (event.angleDelta.y / 120) * 60));
                if (target === base)
                    return;

                scrollAnim.stop();
                scrollAnim.from = view.contentY;
                scrollAnim.to = target;
                scrollAnim.start();
            }
        }

        add: Transition {
            NumberAnimation {
                property: "opacity"
                from: 0
                to: 1
                duration: Theme.durQuick
                easing.type: Easing.OutCubic
            }

        }

        populate: Transition {
            NumberAnimation {
                properties: "opacity"
                from: 0
                to: 1
                duration: Theme.ms(200)
                easing.type: Easing.OutCubic
            }

            NumberAnimation {
                properties: "y"
                from: 10
                duration: Theme.durEnter
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.easeEmphasizedDecel
            }

        }

        remove: Transition {
            NumberAnimation {
                property: "opacity"
                from: 1
                to: 0
                duration: Theme.durExit
                easing.type: Easing.InCubic
            }

        }

        displaced: Transition {
            NumberAnimation {
                properties: "y"
                duration: Theme.durShort
                easing.type: Easing.OutCubic
            }

        }

        ScrollBar.vertical: ScrollBar {
            id: scrollBar

            policy: ScrollBar.AsNeeded
            visible: list.needsScrollbar
            width: 8

            contentItem: Rectangle {
                implicitWidth: scrollBar.hovered || scrollBar.pressed ? 8 : 5
                radius: width / 2
                color: scrollBar.pressed ? Theme.accent : Theme.alpha(Theme.text, scrollBar.hovered ? 0.4 : 0.2)

                Behavior on implicitWidth {
                    NumberAnimation {
                        duration: Theme.durQuick
                        easing.type: Easing.OutCubic
                    }

                }

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.durQuick
                    }

                }

            }

            background: Rectangle {
                color: "transparent"
            }

        }

        delegate: Item {
            id: rowItem

            // one shape, every mode; kind picks what's drawn
            required property string kind
            required property string title
            required property string subtitle
            required property string iconName
            required property string glyph
            required property string swatchBg
            required property string swatchAccent
            required property string trailing
            required property bool disabled
            required property bool selectable
            required property int index

            readonly property bool isHeader: rowItem.kind === "header"
            readonly property bool selected: list.currentIndex === rowItem.index && rowItem.selectable
            readonly property bool hovering: list.hoveredIndex === rowItem.index && rowItem.selectable && !rowItem.disabled

            width: list.rowWidth
            height: rowItem.isHeader ? 30 : (rowItem.subtitle !== "" ? 58 : 48)
            opacity: rowItem.disabled ? 0.4 : 1

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 14
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 6
                visible: rowItem.isHeader
                text: rowItem.title
                color: Theme.subtextDim
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontLabel
                font.weight: Font.DemiBold
            }

            Rectangle {
                anchors.fill: parent
                radius: Theme.radiusMd
                color: Theme.text
                opacity: rowItem.hovering ? Theme.stateHover : 0
                visible: !rowItem.isHeader

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.durQuick
                    }

                }

            }

            Row {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: 14
                anchors.right: parent.right
                anchors.rightMargin: 14
                spacing: 14
                visible: !rowItem.isHeader

                IconImage {
                    width: 28
                    height: 28
                    anchors.verticalCenter: parent.verticalCenter
                    visible: rowItem.iconName !== ""
                    source: rowItem.iconName !== "" ? Quickshell.iconPath(rowItem.iconName, true) : ""
                }

                DockGlyph {
                    width: 22
                    height: 22
                    anchors.verticalCenter: parent.verticalCenter
                    visible: rowItem.glyph !== ""
                    pathData: rowItem.glyph
                    glyphColor: rowItem.selected ? Theme.accent : Theme.accentMuted
                }

                Rectangle {
                    width: 24
                    height: 24
                    radius: 12
                    anchors.verticalCenter: parent.verticalCenter
                    visible: rowItem.swatchBg !== ""
                    color: rowItem.swatchBg !== "" ? rowItem.swatchBg : "transparent"
                    clip: true

                    Rectangle {
                        width: parent.width / 2
                        height: parent.height
                        anchors.right: parent.right
                        color: rowItem.swatchAccent !== "" ? rowItem.swatchAccent : "transparent"
                    }

                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    Text {
                        textFormat: Text.StyledText
                        text: list.highlight(rowItem.title)
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontBody
                        font.weight: Font.Medium
                    }

                    Text {
                        text: rowItem.subtitle
                        color: Theme.subtext
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontLabel
                        visible: rowItem.subtitle !== ""
                    }

                }

            }

            DockGlyph {
                width: 18
                height: 18
                anchors.right: parent.right
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                visible: rowItem.trailing === "check"
                pathData: DockIcons.check
                glyphColor: Theme.accent
            }

            TapHandler {
                enabled: rowItem.selectable && !rowItem.disabled
                onTapped: {
                    list.currentIndex = rowItem.index;
                    list.activated(rowItem.index);
                }
            }

        }

    }

    function highlight(title) {
        var q = list.query.trim();
        if (q === "")
            return title;

        var idx = title.toLowerCase().indexOf(q.toLowerCase());
        if (idx === -1)
            return title;

        return title.substring(0, idx) + "<font color=\"" + Theme.toHex(Theme.accent) + "\">" + title.substring(idx, idx + q.length) + "</font>" + title.substring(idx + q.length);
    }

    Column {
        anchors.centerIn: parent
        spacing: 10
        visible: view.count === 0
        opacity: visible ? 1 : 0

        DockGlyph {
            width: 26
            height: 26
            anchors.horizontalCenter: parent.horizontalCenter
            opacity: 0.5
            pathData: DockIcons.search
            glyphColor: Theme.subtext
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: list.emptyLabel
            color: Theme.subtext
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontBody
            font.weight: Font.Medium
        }

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.durQuick
            }

        }

    }

}
