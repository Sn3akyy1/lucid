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
    // the settled view height; view.height is mid-animation while the panel resizes
    property real stableHeight: 0
    signal activated(int index)
    signal deleteRequested(int index)

    // the view consumes these; reading them back off `view` re-entered the layout
    readonly property int rowSpacing: 2
    readonly property int bottomPad: 8
    readonly property real viewport: list.stableHeight > 0 ? list.stableHeight : list.height
    // summed from the model, so it never depends on the layout it feeds
    readonly property real contentExtent: {
        if (!list.model || list.model.count === 0)
            return 0;

        var h = 0;
        for (var i = 0; i < list.model.count; i++) h += list.rowHeight(i) + list.rowSpacing;
        return h - list.rowSpacing + list.bottomPad;
    }
    readonly property real maxScroll: Math.max(0, list.contentExtent - list.viewport)
    // reading view.contentHeight here fed rowWidth back into the layout and looped
    readonly property bool needsScrollbar: list.contentExtent > list.viewport
    // only give up the gutter when the scrollbar is actually there
    readonly property int rowWidth: Math.max(0, view.width - (list.needsScrollbar ? 14 : 0))
    readonly property real selectionY: list.rowY(list.currentIndex)
    readonly property real selectionHeight: list.rowHeight(list.currentIndex)

    function rowAt(index) {
        return list.model && index >= 0 && index < list.model.count ? list.model.get(index) : null;
    }

    // must match the delegate's height expression below
    function rowHeight(index) {
        var r = list.rowAt(index);
        if (!r)
            return 0;

        return r.kind === "header" ? 30 : (r.subtitle !== "" ? 58 : 48);
    }

    function rowY(index) {
        var y = 0;
        for (var i = 0; i < index; i++) y += list.rowHeight(i) + list.rowSpacing;
        return y;
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
    }

    function ensureSelectable() {
        if (list.model && list.model.count > 0 && !list.isSelectable(list.currentIndex))
            list.currentIndex = list.firstSelectable();

    }

    function scrollToCurrent() {
        var top = list.rowY(list.currentIndex);
        var bottom = top + list.rowHeight(list.currentIndex);
        var cur = scrollAnim.running ? scrollAnim.to : view.contentY;
        var target = cur;
        if (top < cur)
            target = top;
        else if (bottom > cur + list.viewport)
            target = bottom - list.viewport;
        else
            return;

        target = Math.max(0, Math.min(list.maxScroll, target));
        if (Math.abs(target - cur) < 0.5)
            return;

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

        property real slot: list.selectionY
        property real slotHeight: list.selectionHeight

        x: 0
        y: selection.slot - view.contentY
        width: list.rowWidth
        height: selection.slotHeight
        radius: Theme.radiusMd
        color: Theme.withBlur(Theme.bgActive)
        visible: view.count > 0 && list.isSelectable(list.currentIndex)
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
        spacing: list.rowSpacing
        bottomMargin: list.bottomPad
        model: list.model
        currentIndex: list.currentIndex
        onCountChanged: list.ensureSelectable()
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
                var base = scrollAnim.running ? scrollAnim.to : view.contentY;
                var target = Math.max(0, Math.min(list.maxScroll, base - (event.angleDelta.y / 120) * 60));
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
            required property string thumb
            required property bool disabled
            required property bool selectable
            required property int index

            readonly property bool isHeader: rowItem.kind === "header"
            readonly property bool selected: list.currentIndex === rowItem.index && rowItem.selectable
            readonly property bool hovering: list.hoveredIndex === rowItem.index && rowItem.selectable && !rowItem.disabled

            width: list.rowWidth
            height: rowItem.isHeader ? 30 : (rowItem.subtitle !== "" ? 58 : 48)
            opacity: rowItem.disabled ? 0.4 : 1

            function askThumb() {
                if (rowItem.thumb !== "")
                    Clip.requestThumb(rowItem.thumb);

            }

            onThumbChanged: rowItem.askThumb()
            Component.onCompleted: rowItem.askThumb()

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
                    source: rowItem.iconName === "" ? "" : (IconTheme.generation >= 0 && IconTheme.pathFor(rowItem.iconName) !== "" ? IconTheme.pathFor(rowItem.iconName) : Quickshell.iconPath(rowItem.iconName, true))
                }

                Rectangle {
                    width: 40
                    height: 30
                    anchors.verticalCenter: parent.verticalCenter
                    visible: rowItem.thumb !== ""
                    radius: Theme.radiusSm
                    color: Theme.bgTile
                    clip: true

                    Image {
                        id: thumbImage

                        anchors.fill: parent
                        source: rowItem.thumb === "" ? "" : (Clip.thumbs[rowItem.thumb] || "")
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: false
                        sourceSize.width: 80
                        sourceSize.height: 60
                        visible: thumbImage.status === Image.Ready
                        // the file went away under the cached path; drop it so
                        // the next request decodes again
                        onStatusChanged: {
                            if (thumbImage.status !== Image.Error)
                                return;

                            // a failed decode caches "" instead, so this
                            // settles rather than loops
                            Clip.invalidateThumb(rowItem.thumb);
                            Clip.requestThumb(rowItem.thumb);
                        }
                    }

                    DockGlyph {
                        anchors.centerIn: parent
                        width: 16
                        height: 16
                        visible: !thumbImage.visible
                        pathData: DockIcons.brokenImage
                        glyphColor: Theme.subtextDim
                    }

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
                    radius: Theme.rad(12)
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

            Item {
                id: dropButton

                width: 30
                height: 30
                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                visible: rowItem.kind === "clip" && (rowItem.hovering || rowItem.selected)

                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: dropHover.hovered ? Theme.error : Theme.text
                    opacity: dropTap.pressed ? Theme.statePressed : (dropHover.hovered ? Theme.stateHover : 0)

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
                    pathData: DockIcons.trash
                    glyphColor: dropHover.hovered ? Theme.error : Theme.subtext
                }

                HoverHandler {
                    id: dropHover
                }

                TapHandler {
                    id: dropTap

                    onTapped: list.deleteRequested(rowItem.index)
                }

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
