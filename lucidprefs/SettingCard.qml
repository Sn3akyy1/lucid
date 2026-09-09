import QtQuick
import qs

// m3 grouped list: a section label over items that carry their own containers,
// separated by a hairline gap and rounded large only on the group's outer edges
Item {
    id: card

    readonly property bool isSettingGroup: true
    property string title: ""
    property string subtitle: ""
    property int gap: 3
    default property alias content: inner.data
    // pages shout their section titles; m3 wants sentence case
    readonly property var _keep: ({
        "VPN": "VPN",
        "WI-FI": "Wi-Fi",
        "KDE": "KDE",
        "DNS": "DNS",
        "IP": "IP",
        "IPV4": "IPv4",
        "IPV6": "IPv6",
        "MAC": "MAC",
        "OSD": "OSD"
    })
    readonly property string prettyTitle: {
        if (card.title === "" || card.title !== card.title.toUpperCase())
            return card.title;

        var words = card.title.split(" ");
        var out = [];
        for (var i = 0; i < words.length; i++) {
            var w = words[i];
            if (card._keep[w] !== undefined) {
                out.push(card._keep[w]);
                continue;
            }
            var lower = w.toLowerCase();
            out.push(i === 0 ? lower.charAt(0).toUpperCase() + lower.slice(1) : lower);
        }
        return out.join(" ");
    }

    // tells each item where it sits so it can round its outer corners
    function regroup() {
        var items = [];
        var kids = inner.children;
        for (var i = 0; i < kids.length; i++) {
            var c = kids[i];
            if (c && c.isGroupItem === true && c.visible)
                items.push(c);

        }
        for (var j = 0; j < items.length; j++) {
            items[j].groupFirst = j === 0;
            items[j].groupLast = j === items.length - 1;
        }
    }

    function regroupLater() {
        Qt.callLater(card.regroup);
    }

    implicitWidth: parent ? parent.width : 400
    implicitHeight: header.implicitHeight + inner.implicitHeight
    Component.onCompleted: card.regroupLater()

    Column {
        id: header

        width: parent.width
        spacing: 1

        Text {
            text: card.prettyTitle
            color: Theme.accent
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontTitleSm
            font.weight: Font.DemiBold
            font.letterSpacing: 0.1
            leftPadding: 22
            bottomPadding: card.subtitle === "" ? 12 : 0
            visible: card.prettyTitle !== ""
        }

        Text {
            width: parent.width - 44
            text: card.subtitle
            color: Theme.subtext
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontBodyMd
            wrapMode: Text.WordWrap
            leftPadding: 22
            bottomPadding: 12
            visible: card.subtitle !== ""
        }

    }

    Column {
        id: inner

        anchors.top: header.bottom
        width: parent.width
        spacing: card.gap
        onChildrenChanged: card.regroupLater()
    }

}
