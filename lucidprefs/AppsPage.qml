import "../luciddocks"
import QtQuick
import Quickshell
import qs

// what the launcher lists: stars put an app under Favourites, the eye takes it out for good
Column {
    id: page

    property string query: ""
    // "all" | "fav" | "hidden"
    property string view: "all"

    readonly property var sorted: Apps.list.slice().sort((a, b) => {
        return a.name.toLowerCase().localeCompare(b.name.toLowerCase());
    })
    readonly property int favCount: page.sorted.filter((a) => {
        return Apps.isFav(a);
    }).length
    readonly property int hiddenCount: page.sorted.filter((a) => {
        return Apps.isHidden(a);
    }).length
    readonly property var shown: {
        var q = page.query.trim().toLowerCase();
        return page.sorted.filter((a) => {
            if (page.view === "fav" && !Apps.isFav(a))
                return false;

            if (page.view === "hidden" && !Apps.isHidden(a))
                return false;

            return q === "" || a.name.toLowerCase().indexOf(q) !== -1 || a.base.toLowerCase().indexOf(q) !== -1;
        });
    }

    spacing: 26

    SettingCard {
        subtitle: "Everything the launcher can open. A starred app is listed first, under Favourites, and wins a search against an equally good match. A hidden one never shows up, not even when you search for it. You can also right-click an app in the launcher to star it."

        SettingRow {
            title: "Find an application"
            description: page.sorted.length + " applications  ·  " + page.favCount + " starred  ·  " + page.hiddenCount + " hidden"
            stacked: true

            Column {
                width: parent.width
                spacing: 12

                M3TextField {
                    width: parent.width
                    placeholder: "Name or desktop entry"
                    commitOnBlur: false
                    onEdited: (v) => {
                        return page.query = v;
                    }
                }

                M3Chips {
                    width: parent.width
                    current: page.view
                    options: [{
                        "key": "all",
                        "label": "All"
                    }, {
                        "key": "fav",
                        "label": "Favourites"
                    }, {
                        "key": "hidden",
                        "label": "Hidden"
                    }]
                    onChosen: (k) => {
                        return page.view = k;
                    }
                }

            }

        }

    }

    Column {
        width: parent.width
        spacing: 2

        Repeater {
            model: page.shown

            AppRow {
            }

        }

        Text {
            width: parent.width
            visible: page.shown.length === 0
            text: {
                if (Apps.list.length === 0)
                    return "Looking for applications…";

                if (page.query.trim() !== "")
                    return "Nothing here matches “" + page.query.trim() + "”.";

                if (page.view === "fav")
                    return "No favourites yet. Star an application to list it first in the launcher.";

                if (page.view === "hidden")
                    return "Nothing is hidden. Every application shows up in the launcher.";

                return "";
            }
            color: Theme.subtext
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontBodyMd
            wrapMode: Text.WordWrap
            leftPadding: 22
            rightPadding: 22
            topPadding: 8
        }

    }

    component AppRow: Item {
        id: row

        required property var modelData
        readonly property bool fav: Apps.isFav(row.modelData)
        readonly property bool hidden: Apps.isHidden(row.modelData)

        width: parent ? parent.width : 400
        height: 58

        Image {
            id: icon

            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            width: 32
            height: 32
            // resolved like the launcher's rows, so a changed icon theme shows here too
            source: row.modelData.iconName === "" ? "" : (IconTheme.generation >= 0 && IconTheme.pathFor(row.modelData.iconName) !== "" ? IconTheme.pathFor(row.modelData.iconName) : Quickshell.iconPath(row.modelData.iconName, true))
            sourceSize.width: 64
            sourceSize.height: 64
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            smooth: true
            mipmap: true
            opacity: row.hidden ? 0.4 : 1

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.durShort
                }

            }

        }

        Column {
            anchors.left: icon.right
            anchors.leftMargin: 14
            anchors.right: buttons.left
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Text {
                width: parent.width
                text: row.modelData.name
                color: row.hidden ? Theme.subtext : Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontBodyLg
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                text: row.hidden ? "Hidden from the launcher" : (row.modelData.desc !== "" ? row.modelData.desc : row.modelData.base)
                color: row.hidden ? Theme.accentMuted : Theme.subtextDim
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontLabelSm
                elide: Text.ElideRight
            }

        }

        Row {
            id: buttons

            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            M3IconButton {
                anchors.verticalCenter: parent.verticalCenter
                size: 36
                iconSize: 19
                variant: row.fav ? "tonal" : "standard"
                iconPath: row.fav ? DockIcons.star : DockIcons.starOutline
                onClicked: Apps.setFav(row.modelData.base, !row.fav)
            }

            M3IconButton {
                anchors.verticalCenter: parent.verticalCenter
                size: 36
                iconSize: 19
                variant: row.hidden ? "tonal" : "standard"
                iconPath: row.hidden ? DockIcons.hidden : DockIcons.visible
                onClicked: Apps.setHidden(row.modelData.base, !row.hidden)
            }

        }

    }

}
