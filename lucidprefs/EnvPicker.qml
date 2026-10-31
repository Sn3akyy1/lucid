import QtQuick
import QtQuick.Controls.Basic
import qs
import qs.lucidicons
import qs.lucidui

// the shared list behind every picker on the Environment page
Item {
    id: picker

    readonly property int wheelStep: 190
    property bool shown: false
    property string heading: ""
    property string noun: "themes"
    property var items: []
    property string current: ""
    // name -> icon path, only filled for the icon theme list
    property var previews: ({
    })
    property bool showPreviews: false
    // lucid's own icon sets rather than installed themes: each row draws a few of its icons
    property bool tonal: false
    property var tonalSets: []
    readonly property var tonalSlots: ["folder", "document", "image", "app-settings", "trash"]
    property string filter: ""
    readonly property var matches: {
        var q = picker.filter.trim().toLowerCase();
        if (q === "")
            return picker.items;

        var out = [];
        for (var i = 0; i < picker.items.length; i++) {
            if (String(picker.items[i]).toLowerCase().indexOf(q) !== -1)
                out.push(picker.items[i]);

        }
        return out;
    }

    signal chosen(string name)

    function open(heading, noun, items, current, withPreviews) {
        picker.tonal = false;
        picker.heading = heading;
        picker.noun = noun;
        picker.items = items;
        picker.current = current;
        picker.showPreviews = withPreviews === true;
        picker.filter = "";
        searchInput.text = "";
        picker.shown = true;
        searchInput.forceActiveFocus();
        var idx = picker.matches.indexOf(current);
        list.positionViewAtIndex(idx < 0 ? 0 : idx, ListView.Center);
    }

    // sets is LucidIcons.sets; the answer is a set's name, its id through LucidIcons.idOf
    function openSets(heading, sets, currentId) {
        picker.tonal = true;
        picker.tonalSets = sets;
        picker.heading = heading;
        picker.noun = "icon sets";
        picker.items = sets.map((t) => {
            return t.name;
        });
        picker.current = LucidIcons.nameOf(currentId);
        picker.showPreviews = false;
        picker.filter = "";
        searchInput.text = "";
        picker.shown = true;
        card.forceActiveFocus();
        list.positionViewAtBeginning();
    }

    function setNamed(name) {
        for (var i = 0; i < picker.tonalSets.length; i++) {
            if (picker.tonalSets[i].name === name)
                return picker.tonalSets[i];

        }
        return null;
    }

    function dismiss() {
        picker.shown = false;
    }

    function choose(name) {
        picker.chosen(name);
        picker.dismiss();
    }

    anchors.fill: parent
    visible: picker.shown || picker.opacity > 0.01
    opacity: picker.shown ? 1 : 0

    Rectangle {
        anchors.fill: parent
        color: Theme.alpha(Theme.cShadow, 0.55)

        MouseArea {
            anchors.fill: parent
            onClicked: picker.dismiss()
        }

        // the pane behind is still scrollable, so the dimmer has to eat these
        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: (event) => {
                return event.accepted = true;
            }
        }

    }

    Rectangle {
        id: card

        anchors.centerIn: parent
        width: Math.min(Theme.dp(460), picker.width - Theme.dp(80))
        // a short list of sets fits its rows; the installed themes scroll
        height: picker.tonal ? Math.min(picker.height - Theme.dp(80), searchBox.y + searchBox.height + Theme.dp(22) + list.contentHeight + Theme.dp(12)) : Math.min(Theme.dp(520), picker.height - Theme.dp(80))
        radius: Theme.radiusXl
        color: Theme.bgHigh
        clip: true
        scale: picker.shown ? 1 : 0.92
        Keys.onEscapePressed: picker.dismiss()

        MouseArea {
            anchors.fill: parent
        }

        Text {
            id: cardTitle

            anchors.left: parent.left
            anchors.top: parent.top
            anchors.margins: Theme.dp(22)
            text: picker.heading
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontHeadlineSm
            font.variableAxes: Theme.axes(Theme.fontHeadlineSm, 520, 0)
            font.weight: Font.Medium
        }

        Rectangle {
            id: searchBox

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: cardTitle.bottom
            anchors.leftMargin: Theme.dp(22)
            anchors.rightMargin: Theme.dp(22)
            anchors.topMargin: picker.tonal ? 0 : Theme.dp(14)
            height: picker.tonal ? 0 : Theme.dp(46)
            visible: !picker.tonal
            radius: Theme.shapeLg
            color: Theme.bgSunken
            border.width: searchInput.activeFocus ? 2 : 1
            border.color: searchInput.activeFocus ? Theme.accent : Theme.outlineStrong

            TextInput {
                id: searchInput

                anchors.fill: parent
                anchors.leftMargin: Theme.dp(12)
                anchors.rightMargin: Theme.dp(12)
                verticalAlignment: TextInput.AlignVCenter
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontBodyLg
                font.variableAxes: Theme.axes(Theme.fontBodyLg, 420, 0)
                selectByMouse: true
                selectionColor: Theme.accent
                selectedTextColor: Theme.fgAccent
                clip: true
                onTextChanged: picker.filter = searchInput.text
                Keys.onEscapePressed: picker.dismiss()
                Keys.onReturnPressed: {
                    if (picker.matches.length > 0)
                        picker.choose(picker.matches[0]);

                }
            }

            Text {
                anchors.left: parent.left
                anchors.leftMargin: Theme.dp(12)
                anchors.verticalCenter: parent.verticalCenter
                text: "Search " + picker.items.length + " installed " + picker.noun
                color: Theme.subtextDim
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontBodyLg
                font.variableAxes: Theme.axes(Theme.fontBodyLg, 420, 0)
                visible: searchInput.text === ""
            }

        }

        Text {
            anchors.centerIn: parent
            width: card.width - Theme.dp(60)
            text: picker.items.length === 0 ? "Nothing installed to choose from" : "No " + picker.noun + " match “" + picker.filter + "”"
            color: Theme.subtextDim
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontBodyLg
            font.variableAxes: Theme.axes(Theme.fontBodyLg, 420, 0)
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            visible: picker.matches.length === 0
        }

        ListView {
            id: list

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: searchBox.bottom
            anchors.bottom: parent.bottom
            anchors.margins: Theme.dp(12)
            anchors.topMargin: Theme.dp(10)
            clip: true
            model: picker.matches
            boundsBehavior: Flickable.StopAtBounds
            flickDeceleration: 6000
            maximumFlickVelocity: 9000
            cacheBuffer: 400

            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: (event) => {
                    event.accepted = true;
                    var maxY = Math.max(0, list.contentHeight - list.height);
                    var base = listScroll.running ? listScroll.to : list.contentY;
                    var target = Math.max(0, Math.min(maxY, base - (event.angleDelta.y / 120) * picker.wheelStep));
                    if (target === base)
                        return ;

                    listScroll.stop();
                    listScroll.from = list.contentY;
                    listScroll.to = target;
                    listScroll.start();
                }
            }

            NumberAnimation {
                id: listScroll

                target: list
                property: "contentY"
                duration: Theme.ms(170)
                easing.type: Easing.OutCubic
            }

            ScrollBar.vertical: ScrollBar {
                id: listBar

                policy: picker.tonal ? ScrollBar.AlwaysOff : ScrollBar.AlwaysOn
                width: Theme.dp(10)

                contentItem: Rectangle {
                    implicitWidth: listBar.hovered || listBar.pressed ? Theme.dp(8) : Theme.dp(5)
                    radius: width / 2
                    color: listBar.pressed ? Theme.accent : (listBar.hovered ? Theme.alpha(Theme.text, 0.4) : Theme.alpha(Theme.text, 0.2))

                    Behavior on implicitWidth {
                        NumberAnimation {
                            duration: Theme.durQuick
                        }

                    }

                }

                background: Rectangle {
                    color: "transparent"
                }

            }

            delegate: Rectangle {
                id: themeRow

                required property string modelData
                readonly property bool isCurrent: themeRow.modelData === picker.current
                readonly property string preview: picker.showPreviews ? (picker.previews[themeRow.modelData] || "") : ""
                readonly property var set: picker.tonal ? picker.setNamed(themeRow.modelData) : null

                width: list.width - Theme.dp(14)
                height: picker.tonal ? Theme.dp(78) : Theme.dp(50)
                radius: picker.tonal ? Theme.radiusLg : height / 2
                color: themeRow.isCurrent ? Theme.accentContainer : "transparent"

                Image {
                    id: swatch

                    anchors.left: parent.left
                    anchors.leftMargin: Theme.dp(13)
                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.dp(26)
                    height: Theme.dp(26)
                    visible: themeRow.preview !== ""
                    source: themeRow.preview === "" ? "" : "file://" + themeRow.preview
                    sourceSize.width: Theme.dp(52)
                    sourceSize.height: Theme.dp(52)
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    smooth: true
                }

                Text {
                    id: rowName

                    anchors.left: swatch.visible ? swatch.right : parent.left
                    anchors.leftMargin: swatch.visible ? Theme.dp(12) : Theme.dp(14)
                    anchors.right: samples.visible ? samples.left : parent.right
                    anchors.rightMargin: Theme.dp(14)
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: blurb.visible ? -Math.round(blurb.height / 2) : 0
                    text: themeRow.modelData
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontBodyLg
                    font.variableAxes: Theme.axes(Theme.fontBodyLg, 420, 0)
                    color: themeRow.isCurrent ? Theme.text : Theme.subtext
                    elide: Text.ElideRight
                }

                Text {
                    id: blurb

                    anchors.left: rowName.left
                    anchors.right: rowName.right
                    anchors.top: rowName.bottom
                    anchors.topMargin: Theme.dp(2)
                    visible: themeRow.set !== null
                    text: themeRow.set ? themeRow.set.blurb : ""
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontBodySm
                    font.variableAxes: Theme.axes(Theme.fontBodySm, 400, 0)
                    color: Theme.subtextDim
                    elide: Text.ElideRight
                }

                // a few of the set's own icons, drawn from it whichever set is in use
                Row {
                    id: samples

                    anchors.right: parent.right
                    anchors.rightMargin: Theme.dp(14)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.dp(6)
                    visible: themeRow.set !== null

                    Repeater {
                        model: themeRow.set ? picker.tonalSlots : []

                        TonalIcon {
                            required property string modelData

                            slot: modelData
                            set: themeRow.set ? themeRow.set.id : ""
                            size: Theme.dp(34)
                            hovered: rowLayer.active
                        }

                    }

                }

                StateLayer {
                    id: rowLayer

                    radius: parent.radius
                    onClicked: picker.choose(themeRow.modelData)
                }

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.durQuick
                    }

                }

            }

        }

        Behavior on scale {
            NumberAnimation {
                duration: Theme.durMedium
                easing.type: Theme.easeEmphasized
                easing.overshoot: Theme.emphasizedOvershoot
            }

        }

    }

    Behavior on opacity {
        NumberAnimation {
            duration: Theme.durShort
            easing.type: Theme.easeStandard
        }

    }

}
