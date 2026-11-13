import QtQuick
import qs
import qs.lucidui

// an app's tray menu, drawn the desktop menu's way: the app's own icons on its
// rows, a chosen option on the secondary container, and a submenu pushing in
// from the right over a row that leads back. it takes the height of the page
// in view, easing to it as pages change
Item {
    id: tm

    property var handle: null
    property real rowH: Theme.dp(38)
    property real pad: Theme.dp(6)
    property real dividerH: Theme.dp(9)
    property real minW: Theme.dp(200)
    property real maxW: Theme.dp(320)
    // the submenus opened on the way down, the app's own menu above them all
    property var trail: []
    // the page in view; 0 is the app's own menu
    property int shown: 0
    // a page on its way in or out: the pages slide, and the height eases with them
    property bool sliding: false
    readonly property Item page: tm.pageAt(tm.shown, pagesRep.count)
    readonly property real pageHeight: tm.page ? tm.page.contentHeight : 0
    readonly property real wantWidth: tm.page ? tm.page.wantWidth : tm.minW
    readonly property int entryCount: tm.page ? tm.page.count : 0
    // what the one row says when the app has no menu, or one with nothing in it
    property string openLabel: "Open"
    // an app's menu arrives a moment after it is asked for; only one still empty
    // after that is taken for none
    property bool graceOver: false
    readonly property bool bare: tm.handle === null || (tm.graceOver && tm.shown === 0 && tm.entryCount === 0)

    // a row was chosen: the host puts the menu away
    signal chosen()
    // the one row of a menu with nothing in it: the host opens the app
    signal openRequested()

    function pageAt(i, n) {
        return i < n ? pagesRep.itemAt(i) : null;
    }

    // a separator, or a row with nothing to show, which apps send as one
    function isSep(e) {
        return !e || e.isSeparator || (String(e.text || "") === "" && String(e.icon || "") === "");
    }

    function reset() {
        slideEnd.stop();
        tm.sliding = false;
        tm.graceOver = false;
        grace.restart();
        tm.shown = 0;
        tm.trail = [];
        pages.clear();
        pages.append({
            "d": 0
        });
    }

    function push(entry) {
        if (!entry)
            return ;

        // a page still leaving goes now: the new one takes its place
        while (pages.count > tm.shown + 1)
            pages.remove(pages.count - 1);
        tm.trail = tm.trail.slice(0, tm.shown).concat([entry]);
        // made beside the one in view, then slid in; the flag first, so the
        // height's behaviour reads it before the page changes
        pages.append({
            "d": 0
        });
        tm.sliding = true;
        slideEnd.restart();
        tm.shown = tm.trail.length;
    }

    function back() {
        if (tm.shown === 0)
            return ;

        tm.sliding = true;
        slideEnd.restart();
        tm.shown = tm.shown - 1;
    }

    implicitWidth: Math.round(Math.max(tm.minW, Math.min(tm.maxW, tm.bare ? openMetrics.width + Theme.dp(10) + Theme.dp(20) + Theme.dp(12) + Theme.dp(16) + 2 * tm.pad : tm.wantWidth)))
    implicitHeight: tm.bare ? tm.rowH + 2 * tm.pad : tm.pageHeight
    clip: true
    onHandleChanged: tm.reset()
    Component.onCompleted: tm.reset()

    Timer {
        id: grace

        interval: 300
        onTriggered: tm.graceOver = true
    }

    // the slide over, the pages it left behind go, closing their submenus
    Timer {
        id: slideEnd

        interval: Theme.barDurEnter + 40
        onTriggered: {
            tm.sliding = false;
            while (pages.count > tm.shown + 1)
                pages.remove(pages.count - 1);
            tm.trail = tm.trail.slice(0, tm.shown);
        }
    }

    // a placeholder per page: a list by count would rebuild every page, the one
    // in view too, each time a submenu came or went
    ListModel {
        id: pages
    }

    Repeater {
        id: pagesRep

        model: pages

        TrayMenuPage {
            menu: tm
            opacity: tm.bare ? 0 : 1
        }

    }

    // nothing to show from the app: one row that opens it
    Item {
        id: openRow

        readonly property bool lit: openHover.hovered

        visible: tm.bare
        x: tm.pad
        y: tm.pad
        width: tm.width - 2 * tm.pad
        height: tm.rowH

        TextMetrics {
            id: openMetrics

            font: openText.font
            text: tm.openLabel
        }

        Rectangle {
            anchors.fill: parent
            anchors.topMargin: Theme.dp(2)
            anchors.bottomMargin: Theme.dp(2)
            radius: openRow.lit ? Theme.radiusSm : Theme.radiusXs
            color: Theme.text
            opacity: openTap.pressed ? Theme.statePressed : (openRow.lit ? Theme.stateHover + 0.02 : 0)

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.durQuick
                }

            }

            Behavior on radius {
                NumberAnimation {
                    duration: Theme.durShort
                    easing.type: Easing.OutCubic
                }

            }

        }

        Icon {
            x: Theme.dp(10) + Theme.dp(1)
            anchors.verticalCenter: parent.verticalCenter
            name: "open_in_new"
            size: Theme.dp(18)
            color: Theme.subtext
        }

        Text {
            id: openText

            anchors.left: parent.left
            anchors.leftMargin: Theme.dp(10) + Theme.dp(20) + Theme.dp(12)
            anchors.right: parent.right
            anchors.rightMargin: Theme.dp(10)
            anchors.verticalCenter: parent.verticalCenter
            text: tm.openLabel
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontBody
            font.variableAxes: Theme.axes(Theme.fontBody, 520, 0)
            font.weight: Font.Medium
            elide: Text.ElideRight
        }

        HoverHandler {
            id: openHover

            cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
            id: openTap

            onTapped: tm.openRequested()
        }

    }

    Behavior on implicitHeight {
        NumberAnimation {
            duration: tm.sliding ? Theme.barDurEnter : Theme.durShort
            easing.type: Easing.Bezier
            easing.bezierCurve: tm.sliding ? Theme.easeEmphasizedDecel : Theme.curveStandard
        }

    }

}
