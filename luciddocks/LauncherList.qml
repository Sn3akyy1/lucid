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

    // typing rewrites the whole list at once. Per-row transitions on that many
    // inserts, moves and removals, cut short every keystroke, tangle: rows fly in
    // from far off, gaps open, text doubles. So while a query is changing the rows
    // land straight in place and the list settles as one; the row transitions come
    // back once typing pauses, for small changes like deleting a clipboard entry
    property bool filtering: false
    property real settleOpacity: 1
    property real settleOffset: 0

    function beginFilter() {
        list.filtering = true;
        filterQuiet.restart();
        settleAnim.stop();
        list.settleOpacity = Math.min(list.settleOpacity, 0.45);
        list.settleOffset = 5;
        settleAnim.start();
    }

    // outlives the layout pass that places the rows
    Timer {
        id: filterQuiet

        interval: 320
        onTriggered: list.filtering = false
    }

    ParallelAnimation {
        id: settleAnim

        NumberAnimation {
            target: list
            property: "settleOpacity"
            to: 1
            duration: Theme.ms(220)
            easing.type: Easing.OutCubic
        }

        NumberAnimation {
            target: list
            property: "settleOffset"
            to: 0
            duration: Theme.ms(260)
            easing.type: Easing.OutCubic
        }

    }

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

    // the one row-height rule: the delegate, the scroll maths and the dock's panel sizing all use it
    function heightFor(kind, subtitle) {
        if (kind === "header")
            return 30;

        // an app's own actions sit under it, a step down; the app name goes inline
        if (kind === "action")
            return 40;

        return subtitle !== "" ? 58 : 48;
    }

    // what Return does, on the selected row: a window has to read differently from a fresh launch
    function hintFor(kind) {
        switch (kind) {
        case "window":
            return "Switch";
        case "app":
        case "action":
        case "url":
            return "Open";
        case "command":
        case "power":
            return "Run";
        case "web":
            return "Search";
        }
        return "";
    }

    function rowHeight(index) {
        var r = list.rowAt(index);
        return r ? list.heightFor(r.kind, r.subtitle) : 0;
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
        if (!list.model || list.model.count === 0)
            return;

        // a deleted last row leaves the selection on the new last one, not the top
        if (list.currentIndex >= list.model.count)
            list.currentIndex = list.model.count - 1;

        if (!list.isSelectable(list.currentIndex))
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
        opacity: list.settleOpacity

        transform: Translate {
            y: list.settleOffset
        }

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
        opacity: list.settleOpacity

        transform: Translate {
            y: list.settleOffset
        }
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

        // typing re-sorts the list: rows that stay glide to their new slot, discarded
        // ones slip out underneath, and new ones wait until those are mostly gone —
        // before, moves jumped and landed on rows still fading, doubling the text
        add: Transition {
            enabled: !list.filtering

            SequentialAnimation {
                PropertyAction {
                    property: "opacity"
                    value: 0
                }

                PauseAnimation {
                    duration: Theme.ms(70)
                }

                NumberAnimation {
                    property: "opacity"
                    to: 1
                    duration: Theme.ms(180)
                    easing.type: Easing.OutCubic
                }

            }

        }

        move: Transition {
            enabled: !list.filtering

            NumberAnimation {
                properties: "y"
                duration: Theme.ms(240)
                easing.type: Easing.OutCubic
            }

            // a move can cut an add short; never leave a row half-faded
            NumberAnimation {
                property: "opacity"
                to: 1
                duration: Theme.durQuick
            }

        }

        moveDisplaced: Transition {
            enabled: !list.filtering

            NumberAnimation {
                properties: "y"
                duration: Theme.ms(240)
                easing.type: Easing.OutCubic
            }

            NumberAnimation {
                property: "opacity"
                to: 1
                duration: Theme.durQuick
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
            enabled: !list.filtering

            // under the rows that stay, and gone before they settle over it
            PropertyAction {
                property: "z"
                value: -1
            }

            NumberAnimation {
                property: "opacity"
                to: 0
                duration: Theme.ms(110)
                easing.type: Easing.OutCubic
            }

        }

        displaced: Transition {
            enabled: !list.filtering

            NumberAnimation {
                properties: "y"
                duration: Theme.ms(240)
                easing.type: Easing.OutCubic
            }

            NumberAnimation {
                property: "opacity"
                to: 1
                duration: Theme.durQuick
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
            required property string payload
            // an app action listed straight under its app
            required property bool nested
            readonly property bool isAction: rowItem.kind === "action"
            readonly property string hint: rowItem.selected && rowItem.trailing === "" ? list.hintFor(rowItem.kind) : ""

            readonly property bool isHeader: rowItem.kind === "header"
            readonly property bool selected: list.currentIndex === rowItem.index && rowItem.selectable
            readonly property bool hovering: list.hoveredIndex === rowItem.index && rowItem.selectable && !rowItem.disabled

            width: list.rowWidth
            height: list.heightFor(rowItem.kind, rowItem.subtitle)
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
                anchors.leftMargin: rowItem.nested ? 44 : 14
                anchors.right: parent.right
                anchors.rightMargin: 14
                spacing: 14
                visible: !rowItem.isHeader

                IconImage {
                    width: rowItem.isAction ? 22 : 28
                    height: rowItem.isAction ? 22 : 28
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
                    width: rowItem.isAction ? 16 : 22
                    height: rowItem.isAction ? 16 : 22
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
                    // leaves the check glyph, the Return hint and the delete button their room; long clipboard text elides instead of spilling
                    width: Math.max(0, parent.width - x - (rowItem.trailing !== "" ? 32 : 0) - (hintLabel.visible ? hintLabel.implicitWidth + 12 : 0) - (dropButton.visible ? 30 : 0))
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    Text {
                        width: parent.width
                        elide: Text.ElideRight
                        textFormat: Text.StyledText
                        // an action found on its own names its app on the same line
                        text: list.highlight(rowItem.title) + (rowItem.isAction && rowItem.subtitle !== "" ? "<font color=\"" + Theme.toHex(Theme.subtextDim) + "\">&nbsp;&nbsp;·&nbsp;&nbsp;" + list.escapeMarkup(rowItem.subtitle) + "</font>" : "")
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontBody
                        font.weight: Font.Medium
                    }

                    Text {
                        width: parent.width
                        elide: Text.ElideRight
                        text: rowItem.subtitle
                        color: Theme.subtext
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontLabel
                        visible: rowItem.subtitle !== "" && !rowItem.isAction
                    }

                }

            }

            Text {
                id: hintLabel

                anchors.right: parent.right
                anchors.rightMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                visible: rowItem.hint !== "" && !rowItem.isHeader
                text: rowItem.hint
                color: Theme.subtextDim
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontLabel
                font.weight: Font.Medium
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

    // titles are StyledText and clipboard rows can hold anything, so escape before tagging
    function escapeMarkup(s) {
        return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
    }

    function highlight(title) {
        var q = list.query.trim();
        var idx = q === "" ? -1 : title.toLowerCase().indexOf(q.toLowerCase());
        if (idx === -1)
            return list.escapeMarkup(title);

        return list.escapeMarkup(title.substring(0, idx)) + "<font color=\"" + Theme.toHex(Theme.accent) + "\">" + list.escapeMarkup(title.substring(idx, idx + q.length)) + "</font>" + list.escapeMarkup(title.substring(idx + q.length));
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
