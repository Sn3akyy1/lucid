import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Widgets
import qs
import qs.lucidui

// the launcher's results, on the m3 list item scale: a 40dp leading slot, 16dp
// of space either side and 12dp between, one line at 56dp and two at 72dp
Item {
    id: list

    property var model: null
    property int currentIndex: 0
    // what to embolden in each title
    property string query: ""
    property string emptyLabel: "No results"
    property string emptyHint: ""
    // an empty apps search is where the prefixes are worth teaching
    property bool showPrefixes: false
    // the settled view height; view.height is mid-animation while the panel resizes
    property real stableHeight: 0
    // the model's count, not the view's: the view only announces a count that
    // differs from its last layout, so 11 rows to none to 11 never reached us
    readonly property int count: list.model ? list.model.count : 0
    readonly property bool hasSelection: list.count > 0 && list.isSelectable(list.currentIndex)
    // where the pill is this frame; the rows light by it
    readonly property real pillY: selection.slot
    // what the empty state needs, for the dock to size the panel to
    readonly property real emptyExtent: empty.implicitHeight + 2 * Math.round(16 * list.cs)
    // the view consumes these; reading them back off `view` re-entered the layout
    readonly property int rowSpacing: Prefs.launcherRowGap
    readonly property int bottomPad: Prefs.launcherListPad
    // m3 list item metrics, taken through the launcher's content scale
    readonly property real cs: Prefs.launcherScale
    readonly property int leadSlot: Prefs.launcherLeadSlot
    readonly property int edgeSpace: Prefs.launcherEdgeSpace
    readonly property int betweenSpace: Prefs.launcherBetweenSpace
    readonly property real viewport: list.stableHeight > 0 ? list.stableHeight : list.height
    // summed from the model, so it never depends on the layout it feeds
    readonly property real contentExtent: {
        if (!list.model || list.model.count === 0)
            return 0;

        var h = 0;
        for (var i = 0; i < list.model.count; i++) h += list.rowHeight(i) + list.rowSpacing
        return h - list.rowSpacing + list.bottomPad;
    }
    readonly property real maxScroll: Math.max(0, list.contentExtent - list.viewport)
    // reading view.contentHeight here fed rowWidth back into the layout and looped
    readonly property bool needsScrollbar: list.contentExtent > list.viewport
    // only give up the gutter when the scrollbar is actually there
    readonly property int rowWidth: Math.max(0, view.width - (list.needsScrollbar ? Theme.dp(14) : 0))
    // the head only earns its rule once something is hidden above
    readonly property bool scrolled: view.contentY > 1
    readonly property real selectionY: list.rowY(list.currentIndex)
    readonly property real selectionHeight: list.rowHeight(list.currentIndex)
    readonly property int hoveredIndex: {
        if (!listHover.hovered)
            return -1;

        var y = listHover.point.position.y + view.contentY;
        return view.indexAt(view.width / 2, y);
    }

    signal activated(int index)
    signal deleteRequested(int index)
    signal hideRequested(int index)
    signal prefixChosen(string prefix)

    // a type role at the launcher's own size
    function ts(role) {
        return Math.round(Theme.typeSize(role) * list.cs);
    }

    // blended on premultiplied channels. straight rgba between an opaque fill
    // and a faint one passes through a colour brighter than either
    function mix(a, b, t) {
        var wa = a.a * (1 - t);
        var wb = b.a * t;
        var al = wa + wb;
        if (al <= 0)
            return Qt.rgba(0, 0, 0, 0);

        return Qt.rgba((a.r * wa + b.r * wb) / al, (a.g * wa + b.g * wb) / al, (a.b * wa + b.b * wb) / al, al);
    }

    function rowAt(index) {
        return list.model && index >= 0 && index < list.model.count ? list.model.get(index) : null;
    }

    // must match the delegate's height expression below, and Dock.measure()
    function rowHeight(index) {
        var r = list.rowAt(index);
        if (!r)
            return 0;

        if (r.kind === "header")
            return Prefs.launcherRowHeader;

        if (r.kind === "calc")
            return Prefs.launcherRowCalc;

        return r.subtitle !== "" ? Prefs.launcherRowTwo : Prefs.launcherRowOne;
    }

    // the m3 trailing supporting text: what Return will do with this row
    function actionFor(kind) {
        switch (kind) {
        case "app":
        case "command":
            return "Open";
        case "setting":
            return "Settings";
        case "web":
            return "Browser";
        case "run":
            return "Run";
        case "runterm":
            return "Terminal";
        case "calc":
        case "emoji":
        case "clip":
            return "Copy";
        case "theme":
            return "Apply";
        }
        return "";
    }

    function rowY(index) {
        var y = 0;
        for (var i = 0; i < index; i++) y += list.rowHeight(i) + list.rowSpacing
        return y;
    }

    function isSelectable(index) {
        var r = list.rowAt(index);
        return r !== null && r.selectable && !r.disabled;
    }

    function step(delta) {
        if (!list.model || list.model.count === 0)
            return ;

        var i = list.currentIndex;
        for (var n = 0; n < list.model.count; n++) {
            i += delta;
            if (i < 0 || i >= list.model.count)
                return ;

            if (list.isSelectable(i)) {
                list.currentIndex = i;
                list.scrollToCurrent();
                return ;
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
            return ;
        target = Math.max(0, Math.min(list.maxScroll, target));
        if (Math.abs(target - cur) < 0.5)
            return ;

        scrollAnim.stop();
        scrollAnim.from = view.contentY;
        scrollAnim.to = target;
        scrollAnim.start();
    }

    function activateCurrent() {
        if (list.isSelectable(list.currentIndex))
            list.activated(list.currentIndex);

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

    HoverHandler {
        id: listHover
    }

    // one shape that slides between rows, rather than a highlight blinking on
    // and off in place. m3 selects a list item with the secondary container
    Rectangle {
        id: selection

        property real slot: list.selectionY
        property real slotHeight: list.selectionHeight

        x: 0
        y: selection.slot - view.contentY
        width: list.rowWidth
        height: selection.slotHeight
        radius: Theme.shapeXl
        color: Theme.withBlur(Theme.primaryContainer)
        visible: list.hasSelection
        z: 0

        Behavior on slot {
            NumberAnimation {
                duration: Theme.ms(180)
                easing.type: Easing.OutCubic
            }

        }

        Behavior on slotHeight {
            NumberAnimation {
                duration: Theme.ms(180)
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
                    return ;

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
            SequentialAnimation {
                PauseAnimation {
                    duration: Theme.ms(Math.max(0, Math.min(view.ViewTransition.index, 9)) * 22)
                }

                ParallelAnimation {
                    NumberAnimation {
                        properties: "opacity"
                        from: 0
                        to: 1
                        duration: Theme.ms(200)
                        easing.type: Easing.OutCubic
                    }

                    NumberAnimation {
                        properties: "y"
                        from: view.ViewTransition.destination.y + 12
                        duration: Theme.durEnter
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Theme.easeEmphasizedDecel
                    }

                }

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
            width: Theme.dp(8)

            contentItem: Rectangle {
                implicitWidth: scrollBar.hovered || scrollBar.pressed ? Theme.dp(8) : Theme.dp(5)
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
            required property string emoji
            required property string swatchBg
            required property string swatchAccent
            required property string trailing
            required property string thumb
            required property bool running
            required property bool disabled
            required property bool selectable
            required property string payload
            required property int index
            readonly property bool isHeader: rowItem.kind === "header"
            readonly property bool isCalc: rowItem.kind === "calc"
            readonly property bool selected: list.currentIndex === rowItem.index && rowItem.selectable
            readonly property bool hovering: list.hoveredIndex === rowItem.index && rowItem.selectable && !rowItem.disabled
            readonly property bool hasLead: rowItem.iconName !== "" || rowItem.glyph !== "" || rowItem.emoji !== "" || rowItem.swatchBg !== "" || rowItem.thumb !== ""
            // how much of the pill is under this row this frame. everything that
            // marks the selection is coloured by it, so none of it leads or trails
            readonly property real lit: list.hasSelection && rowItem.selectable ? Math.max(0, 1 - Math.abs(list.pillY - rowItem.y) / Math.max(1, rowItem.height)) : 0
            readonly property color content: list.mix(Theme.text, Theme.fgPrimaryContainer, rowItem.lit)
            readonly property color support: list.mix(Theme.subtext, Theme.alpha(Theme.fgPrimaryContainer, 0.76), rowItem.lit)
            readonly property color mark: list.mix(Theme.primary, Theme.fgPrimaryContainer, rowItem.lit)
            // a symbol needs a container to sit on; an application icon brings its own
            readonly property bool needsTile: rowItem.glyph !== "" || rowItem.emoji !== ""
            readonly property color tile: list.mix(Theme.withBlur(Theme.bgTile), Theme.alpha(Theme.fgPrimaryContainer, 0.14), rowItem.lit)
            readonly property bool showsDrop: rowItem.kind === "clip" && (rowItem.hovering || rowItem.selected)
            // an application the pointer is on can be sent out of the launcher
            readonly property bool showsHide: rowItem.kind === "app" && rowItem.hovering
            readonly property bool showsHint: Prefs.launcherActionHints && rowItem.lit > 0 && !rowItem.isHeader && !rowItem.isCalc && rowItem.trailing === ""

            function askThumb() {
                if (rowItem.thumb !== "")
                    Clip.requestThumb(rowItem.thumb);

            }

            width: list.rowWidth
            height: rowItem.isHeader ? Prefs.launcherRowHeader : (rowItem.isCalc ? Prefs.launcherRowCalc : (rowItem.subtitle !== "" ? Prefs.launcherRowTwo : Prefs.launcherRowOne))
            opacity: rowItem.disabled ? Theme.disabledContent : 1
            onThumbChanged: rowItem.askThumb()
            Component.onCompleted: rowItem.askThumb()

            // m3 list subheader, with the group's rule carried out to the edge
            // so a run of results reads as one block rather than a loose stack
            Item {
                anchors.fill: parent
                visible: rowItem.isHeader

                LText {
                    id: headerLabel

                    x: list.edgeSpace
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: Math.round(9 * list.cs)
                    role: "labelLarge"
                    size: list.ts("labelLarge")
                    color: Theme.primary
                    text: rowItem.title
                }

                Rectangle {
                    anchors.left: headerLabel.right
                    anchors.leftMargin: Math.round(12 * list.cs)
                    anchors.right: parent.right
                    anchors.rightMargin: list.edgeSpace
                    anchors.verticalCenter: headerLabel.verticalCenter
                    height: 1
                    color: Theme.divider
                }

            }

            // the calculator answers in display type on its own card, rather
            // than passing for one more result row
            Rectangle {
                id: calcCard

                anchors.fill: parent
                visible: rowItem.isCalc
                radius: Theme.shapeXl
                color: list.mix(Theme.withBlur(Theme.surfaceHigh), Theme.withBlur(Theme.primaryContainer), rowItem.lit)

                Column {
                    x: list.edgeSpace + Math.round(4 * list.cs)
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - x - Math.round(72 * list.cs)
                    spacing: Math.round(2 * list.cs)

                    LText {
                        width: parent.width
                        elide: Text.ElideRight
                        role: "labelMedium"
                        size: list.ts("labelMedium")
                        text: rowItem.subtitle
                        color: list.mix(Theme.subtextDim, Theme.alpha(Theme.fgPrimaryContainer, 0.7), rowItem.lit)
                    }

                    LText {
                        width: parent.width
                        elide: Text.ElideRight
                        tabular: true
                        role: "headlineMedium"
                        size: list.ts("headlineMedium")
                        text: rowItem.title
                        color: rowItem.mark
                    }

                }

                Column {
                    anchors.right: parent.right
                    anchors.rightMargin: list.edgeSpace + Math.round(4 * list.cs)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Math.round(4 * list.cs)

                    Icon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        name: "content_paste"
                        size: Math.round(20 * list.cs)
                        color: list.mix(Theme.subtextDim, Theme.alpha(Theme.fgPrimaryContainer, 0.8), rowItem.lit)
                        animateColor: false
                    }

                    LText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        role: "labelSmall"
                        size: list.ts("labelSmall")
                        text: "Return"
                        color: list.mix(Theme.subtextDim, Theme.alpha(Theme.fgPrimaryContainer, 0.7), rowItem.lit)
                    }

                }

            }

            // m3 expressive state shapes: the container rounds further as the
            // pointer settles on it, from extra small at rest to large pressed
            Rectangle {
                id: stateShape

                anchors.fill: parent
                radius: rowTap.pressed ? Theme.shapeXl : (rowItem.hovering ? Theme.shapeLg : Theme.shapeSm)
                color: Theme.text
                opacity: rowItem.hovering ? (rowTap.pressed ? Theme.statePressed : Theme.stateHover) : 0
                visible: !rowItem.isHeader

                Behavior on radius {
                    NumberAnimation {
                        duration: Theme.durFastSpatial
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Theme.curveDefaultSpatial
                    }

                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.durFastEffects
                    }

                }

            }

            // the 40dp leading slot every kind of row shares, so titles line up
            // no matter what is standing in front of them
            Item {
                id: lead

                x: list.edgeSpace
                anchors.verticalCenter: parent.verticalCenter
                width: list.leadSlot
                height: list.leadSlot
                visible: !rowItem.isHeader && !rowItem.isCalc && rowItem.hasLead

                Rectangle {
                    anchors.fill: parent
                    radius: Math.round(parent.width * 0.35)
                    color: rowItem.tile
                    visible: rowItem.needsTile
                }

                // an application icon is already a shape and a colour of its
                // own; standing it on a tile only muddies both
                IconImage {
                    anchors.centerIn: parent
                    width: Math.round(list.leadSlot * 0.88)
                    height: Math.round(list.leadSlot * 0.88)
                    visible: rowItem.iconName !== ""
                    source: rowItem.iconName === "" ? "" : (IconTheme.generation >= 0 && IconTheme.pathFor(rowItem.iconName) !== "" ? IconTheme.pathFor(rowItem.iconName) : Quickshell.iconPath(rowItem.iconName, true))
                }

                Text {
                    anchors.centerIn: parent
                    visible: rowItem.emoji !== ""
                    text: rowItem.emoji
                    font.pixelSize: Math.round(list.leadSlot * 0.6)
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: list.leadSlot
                    height: Math.round(list.leadSlot * 0.75)
                    visible: rowItem.thumb !== ""
                    radius: Theme.shapeSm
                    color: Theme.bgTile
                    clip: true

                    Image {
                        id: thumbImage

                        anchors.fill: parent
                        source: rowItem.thumb === "" ? "" : (Clip.thumbs[rowItem.thumb] || "")
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: false
                        sourceSize.width: Theme.dp(80)
                        sourceSize.height: Theme.dp(60)
                        visible: thumbImage.status === Image.Ready
                        // the file went away under the cached path; drop it so
                        // the next request decodes again
                        onStatusChanged: {
                            if (thumbImage.status !== Image.Error)
                                return ;

                            // a failed decode caches "" instead, so this
                            // settles rather than loops
                            Clip.invalidateThumb(rowItem.thumb);
                            Clip.requestThumb(rowItem.thumb);
                        }
                    }

                    DockGlyph {
                        anchors.centerIn: parent
                        width: Theme.dp(16)
                        height: Theme.dp(16)
                        visible: !thumbImage.visible
                        pathData: DockIcons.brokenImage
                        glyphColor: Theme.subtextDim
                    }

                }

                DockGlyph {
                    anchors.centerIn: parent
                    width: Math.round(list.leadSlot * 0.58)
                    height: Math.round(list.leadSlot * 0.58)
                    visible: rowItem.glyph !== ""
                    pathData: rowItem.glyph
                    glyphColor: rowItem.mark
                    animateColor: false
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: Math.round(36 * list.cs)
                    height: Math.round(36 * list.cs)
                    radius: width / 2
                    visible: rowItem.swatchBg !== ""
                    color: rowItem.swatchBg !== "" ? rowItem.swatchBg : "transparent"
                    // a copied colour can be the panel's own; theme swatches never are
                    border.width: rowItem.kind === "clip" ? 1 : 2
                    border.color: rowItem.kind === "clip" ? Theme.alpha(Theme.text, 0.2) : Theme.alpha(Theme.text, 0.12)

                    Rectangle {
                        visible: rowItem.swatchAccent !== ""
                        anchors.centerIn: parent
                        width: Math.round(15 * list.cs)
                        height: Math.round(15 * list.cs)
                        radius: width / 2
                        color: rowItem.swatchAccent !== "" ? rowItem.swatchAccent : "transparent"
                    }

                }

            }

            Column {
                id: textCol

                x: rowItem.hasLead ? list.edgeSpace + list.leadSlot + list.betweenSpace : list.edgeSpace
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(0, parent.width - textCol.x - list.edgeSpace - trailRoom.width)
                visible: !rowItem.isHeader && !rowItem.isCalc
                spacing: Theme.dp(2)

                // an eliding Text reports its elided width, so the run the dot
                // follows has to be measured off the unelided string
                TextMetrics {
                    id: titleMetrics

                    font: titleText.font
                    text: rowItem.title
                }

                Row {
                    width: parent.width
                    spacing: Math.round(7 * list.cs)

                    LText {
                        id: titleText

                        width: Math.min(Math.ceil(titleMetrics.width) + Theme.dp(2), Math.max(0, parent.width - (dotMark.visible ? dotMark.width + parent.spacing : 0)))
                        elide: Text.ElideRight
                        textFormat: Text.StyledText
                        role: "bodyLarge"
                        size: list.ts("bodyLarge")
                        text: list.highlight(rowItem.title)
                        color: rowItem.content
                    }

                    // the dock's running mark, said once more where the app is found
                    Rectangle {
                        id: dotMark

                        anchors.verticalCenter: titleText.verticalCenter
                        width: Math.round(6 * list.cs)
                        height: dotMark.width
                        radius: dotMark.width / 2
                        visible: rowItem.running
                        color: rowItem.mark
                    }

                }

                LText {
                    width: parent.width
                    elide: Text.ElideRight
                    role: "bodyMedium"
                    size: list.ts("bodyMedium")
                    text: rowItem.subtitle
                    color: rowItem.support
                    visible: rowItem.subtitle !== ""
                }

            }

            // whatever the title has to keep clear of on the trailing edge
            Item {
                id: trailRoom

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: rowItem.showsDrop || rowItem.showsHide ? Math.round(38 * list.cs) : (rowItem.trailing !== "" ? Math.round(28 * list.cs) : (rowItem.showsHint ? hint.implicitWidth + Math.round(26 * list.cs) : 0))
                height: 1
            }

            // m3 trailing supporting text: what Return does with the row under it
            Row {
                id: hintRow

                anchors.right: parent.right
                anchors.rightMargin: list.edgeSpace
                anchors.verticalCenter: parent.verticalCenter
                spacing: Math.round(5 * list.cs)
                visible: rowItem.showsHint && !rowItem.showsDrop && !rowItem.showsHide
                opacity: rowItem.lit

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "keyboard_return"
                    size: Math.round(15 * list.cs)
                    color: Theme.alpha(Theme.fgPrimaryContainer, 0.65)
                }

                LText {
                    id: hint

                    anchors.verticalCenter: parent.verticalCenter
                    role: "labelSmall"
                    size: list.ts("labelSmall")
                    text: list.actionFor(rowItem.kind)
                    color: Theme.alpha(Theme.fgPrimaryContainer, 0.75)
                }

            }

            DockGlyph {
                width: Math.round(20 * list.cs)
                height: Math.round(20 * list.cs)
                anchors.right: parent.right
                anchors.rightMargin: list.edgeSpace
                anchors.verticalCenter: parent.verticalCenter
                visible: rowItem.trailing === "check"
                pathData: DockIcons.check
                glyphColor: rowItem.mark
                animateColor: false
            }

            // hide this application from the launcher. the settings page keeps
            // the list, so nothing here is one-way
            Item {
                id: hideButton

                width: Math.round(32 * list.cs)
                height: Math.round(32 * list.cs)
                anchors.right: parent.right
                anchors.rightMargin: Theme.dp(8)
                anchors.verticalCenter: parent.verticalCenter
                visible: rowItem.showsHide

                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: Theme.text
                    opacity: hideTap.pressed ? Theme.statePressed : (hideHover.hovered ? Theme.stateHover : 0)

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.durQuick
                        }

                    }

                }

                Icon {
                    anchors.centerIn: parent
                    name: "visibility_off"
                    size: Math.round(18 * list.cs)
                    color: hideHover.hovered ? Theme.text : Theme.subtext
                }

                HoverHandler {
                    id: hideHover
                }

                TapHandler {
                    id: hideTap

                    onTapped: list.hideRequested(rowItem.index)
                }

            }

            Item {
                id: dropButton

                width: Math.round(32 * list.cs)
                height: Math.round(32 * list.cs)
                anchors.right: parent.right
                anchors.rightMargin: Theme.dp(8)
                anchors.verticalCenter: parent.verticalCenter
                visible: rowItem.showsDrop

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
                    width: Theme.dp(16)
                    height: Theme.dp(16)
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
                id: rowTap

                enabled: rowItem.selectable && !rowItem.disabled
                onTapped: {
                    list.currentIndex = rowItem.index;
                    list.activated(rowItem.index);
                }
            }

        }

    }

    // nothing found: say so, then hand over the four prefixes that reach
    // everything the plain search does not
    Column {
        id: empty

        anchors.centerIn: parent
        width: Math.min(parent.width - Math.round(48 * list.cs), Math.round(360 * list.cs))
        spacing: Math.round(10 * list.cs)
        visible: list.count === 0
        opacity: empty.visible ? 1 : 0

        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.round(58 * list.cs)
            height: empty.width > 0 ? Math.round(58 * list.cs) : 0

            Rectangle {
                anchors.fill: parent
                radius: Theme.shapeXl
                color: Theme.withBlur(Theme.surfaceHigh)
            }

            Icon {
                anchors.centerIn: parent
                name: "search"
                size: Math.round(28 * list.cs)
                color: Theme.primary
            }

        }

        LText {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            role: "titleMedium"
            size: list.ts("titleMedium")
            text: list.emptyLabel
            color: Theme.text
        }

        LText {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            role: "bodyMedium"
            size: list.ts("bodyMedium")
            text: list.emptyHint
            color: Theme.subtextDim
            visible: list.emptyHint !== ""
        }

        Item {
            width: 1
            height: Math.round(4 * list.cs)
            visible: list.showPrefixes
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Math.round(8 * list.cs)
            visible: list.showPrefixes

            Repeater {
                model: [{
                    "prefix": ">",
                    "label": "Commands"
                }, {
                    "prefix": "?",
                    "label": "Web"
                }, {
                    "prefix": "$",
                    "label": "Run"
                }, {
                    "prefix": ":",
                    "label": "Emoji"
                }]

                Item {
                    id: prefixChip

                    required property var modelData

                    width: keyBox.width + gapPad.width + chipLabel.implicitWidth + Math.round(14 * list.cs)
                    height: Math.round(32 * list.cs)

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.shapeFull
                        color: Theme.withBlur(Theme.surfaceHigh)

                        StateLayer {
                            radius: Theme.shapeFull
                            tint: Theme.text
                            onClicked: list.prefixChosen(prefixChip.modelData.prefix)
                        }

                    }

                    Rectangle {
                        id: keyBox

                        x: Math.round(5 * list.cs)
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.round(22 * list.cs)
                        height: Math.round(22 * list.cs)
                        radius: Theme.shapeSm
                        color: Theme.alpha(Theme.accent, 0.18)

                        LText {
                            anchors.centerIn: parent
                            role: "labelLarge"
                            size: list.ts("labelLarge")
                            text: prefixChip.modelData.prefix
                            color: Theme.accent
                        }

                    }

                    Item {
                        id: gapPad

                        width: Math.round(7 * list.cs)
                        height: 1
                    }

                    LText {
                        id: chipLabel

                        anchors.left: keyBox.right
                        anchors.leftMargin: gapPad.width
                        anchors.verticalCenter: parent.verticalCenter
                        role: "labelMedium"
                        size: list.ts("labelMedium")
                        text: prefixChip.modelData.label
                        color: Theme.subtext
                    }

                }

            }

        }

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.durQuick
            }

        }

    }

}
