import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Shapes
import qs
import qs.lucidui

// the time in the places you keep an eye on
Item {
    id: page

    property var host: null
    property date now: Loc.now()
    readonly property var results: Zones.search(addField.text, 6)
    // one notch clears a card row and then some, like the settings panes
    readonly property int wheelStep: 190

    function pick(city) {
        addField.text = "";
        Zones.addCity(city);
    }

    implicitHeight: 404
    onVisibleChanged: {
        if (page.visible)
            Zones.loadAll();

    }

    Timer {
        interval: 1000
        repeat: true
        running: page.visible
        triggeredOnStart: true
        onTriggered: page.now = Loc.now()
    }

    Flickable {
        id: cards

        readonly property bool scrollable: cards.contentHeight > cards.height

        anchors.top: parent.top
        anchors.bottom: adder.top
        anchors.bottomMargin: 12
        width: parent.width
        contentHeight: grid.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickDeceleration: 6000
        maximumFlickVelocity: 9000

        // without this the grid falls back to Flickable's own wheel steps,
        // which crawl. the panes' step, on the panes' curve
        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: (event) => {
                event.accepted = true;
                const maxY = Math.max(0, cards.contentHeight - cards.height);
                const base = cardScroll.running ? cardScroll.to : cards.contentY;
                const target = Math.max(0, Math.min(maxY, base - (event.angleDelta.y / 120) * page.wheelStep));
                if (target === base)
                    return ;

                cardScroll.stop();
                cardScroll.from = cards.contentY;
                cardScroll.to = target;
                cardScroll.start();
            }
        }

        NumberAnimation {
            id: cardScroll

            target: cards
            property: "contentY"
            duration: Theme.ms(170)
            easing.type: Easing.OutCubic
        }

        ScrollBar.vertical: ScrollBar {
            policy: cards.scrollable ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff

            contentItem: Rectangle {
                implicitWidth: 3
                radius: width / 2
                color: Theme.accent
                opacity: cards.scrollable ? 1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.barMs(180)
                    }

                }

            }

            background: Item {
            }

        }

        Grid {
            id: grid

            width: cards.width - (cards.scrollable ? 10 : 0)
            columns: 3
            spacing: 12

            Repeater {
                model: Zones.cities

                Rectangle {
                    id: card

                    required property var modelData
                    readonly property date there: {
                        page.now;
                        return Zones.timeIn(card.modelData);
                    }
                    readonly property bool night: card.there.getHours() < 6 || card.there.getHours() >= 20

                    width: (grid.width - grid.spacing * 2) / 3
                    height: 128
                    radius: Theme.shapeXl
                    color: card.night ? Theme.withBlur(Theme.surfaceHigh) : Theme.withBlur(Theme.secondaryContainer)

                    readonly property color ink: card.night ? Theme.text : Theme.fgSecondaryContainer

                    // a small face, hands only
                    Item {
                        id: face

                        anchors.right: parent.right
                        anchors.rightMargin: 14
                        anchors.top: parent.top
                        anchors.topMargin: 14
                        width: 44
                        height: 44

                        MaterialShape {
                            anchors.fill: parent
                            shape: "cookie9"
                            color: Theme.alpha(card.ink, 0.1)
                        }

                        Rectangle {
                            x: face.width / 2 - 1.5
                            y: face.height / 2 - 12
                            width: 3
                            height: 12
                            radius: 1.5
                            color: card.ink
                            transformOrigin: Item.Bottom
                            rotation: (card.there.getHours() % 12 + card.there.getMinutes() / 60) * 30
                        }

                        Rectangle {
                            x: face.width / 2 - 1
                            y: face.height / 2 - 17
                            width: 2
                            height: 17
                            radius: 1
                            color: Theme.primary
                            transformOrigin: Item.Bottom
                            rotation: card.there.getMinutes() * 6
                        }

                    }

                    Column {
                        x: 16
                        y: 14
                        spacing: 0

                        LText {
                            role: "titleSmall"
                            color: card.ink
                            text: Zones.cityOf(card.modelData)
                            width: card.width - 80
                            elide: Text.ElideRight
                        }

                        LText {
                            role: "bodySmall"
                            color: Theme.alpha(card.ink, 0.7)
                            text: Zones.regionOf(card.modelData)
                        }

                    }

                    LText {
                        x: 16
                        anchors.bottom: sub.top
                        role: "headlineMedium"
                        weight: 600
                        rounded: 100
                        tabular: true
                        color: card.ink
                        text: card.there.toLocaleTimeString(Qt.locale(), Prefs.clock24h ? "HH:mm" : "h:mm AP")
                    }

                    LText {
                        id: sub

                        x: 16
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 14
                        role: "labelMedium"
                        color: Theme.alpha(card.ink, 0.75)
                        text: Zones.dayText(card.modelData) + "  ·  " + Zones.offsetText(card.modelData)
                    }

                    IconButton {
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: 6
                        size: "xs"
                        icon: "close"
                        tintOverride: Theme.alpha(card.ink, 0.6)
                        opacity: cardHover.hovered ? 1 : 0
                        onClicked: Zones.removeCity(card.modelData)
                    }

                    HoverHandler {
                        id: cardHover
                    }

                }

            }

        }

    }

    // nothing added yet: say so, rather than leaving the pane blank
    Column {
        visible: Zones.cities.length === 0
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -30
        width: parent.width - 80
        spacing: 10

        Icon {
            anchors.horizontalCenter: parent.horizontalCenter
            name: "public"
            size: 40
            color: Theme.subtextDim
        }

        LText {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            role: "titleMedium"
            weight: 560
            text: "No cities yet"
        }

        LText {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            role: "bodyMedium"
            color: Theme.subtext
            wrapMode: Text.Wrap
            text: "Search below for a city and it lands here with its time and how far ahead or behind it is."
        }

    }

    Item {
        id: adder

        anchors.bottom: parent.bottom
        width: parent.width
        height: 48

        TextField {
            id: addField

            width: parent.width
            variant: "search"
            icon: "travel_explore"
            placeholder: "Add a city — Lisbon, Tokyo, Sao Paulo…"
            containerColor: Theme.withBlur(Theme.surfaceHigh)
            onAccepted: {
                if (page.results.length > 0) {
                    Zones.addCity(page.results[0]);
                    addField.text = "";
                }
            }
        }

    }

    // suggestions rise above the field as you type
    Rectangle {
        visible: page.results.length > 0
        anchors.bottom: adder.top
        anchors.bottomMargin: 6
        width: parent.width
        height: sugg.implicitHeight + 12
        radius: Theme.shapeLg
        color: Theme.withBlur(Theme.surfaceHighest)
        z: 5

        Column {
            id: sugg

            anchors.centerIn: parent
            width: parent.width - 12
            spacing: 2

            Repeater {
                model: page.results

                Rectangle {
                    required property var modelData

                    width: sugg.width
                    height: 40
                    radius: 12
                    color: "transparent"

                    StateLayer {
                        radius: parent.radius
                        // the row is rebuilt as the results change, so the page does the work
                        onClicked: page.pick(modelData)
                    }

                    Icon {
                        x: 12
                        anchors.verticalCenter: parent.verticalCenter
                        name: "location_on"
                        size: 18
                        color: Theme.primary
                    }

                    LText {
                        x: 42
                        anchors.verticalCenter: parent.verticalCenter
                        role: "bodyMedium"
                        text: Zones.cityOf(modelData) + "  ·  " + Zones.regionOf(modelData)
                    }

                }

            }

        }

    }

}
