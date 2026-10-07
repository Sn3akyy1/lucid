import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Widgets
import qs
import qs.lucidui

// a picture frame that turns over on its own. click for the next one
WidgetBody {
    id: w

    readonly property string home: Quickshell.env("HOME")
    readonly property string folder: {
        switch (w.opt("source")) {
        case "wallpapers":
            return Prefs.wallpaperDir;
        case "screenshots":
            return w.home + "/Pictures/Screenshots";
        }
        return w.home + "/Pictures";
    }
    readonly property int everyMs: (parseInt(w.opt("every")) || 0) * 60000
    readonly property int count: files.count
    property int pick: 0
    readonly property string current: w.count > 0 ? String(files.get(w.pick % w.count, "fileUrl")) : ""
    readonly property string caption: {
        if (w.count === 0)
            return "";

        var d = files.get(w.pick % w.count, "fileModified");
        return d ? new Date(d).toLocaleDateString(Qt.locale(), "d MMMM yyyy") : "";
    }
    readonly property string frameShape: w.opt("shape") || "cookie12"

    function next() {
        if (w.count < 2)
            return ;

        var n = w.pick;
        // shuffle, but never the same one twice running
        while (n === w.pick) n = Math.floor(Math.random() * w.count)
        w.pick = n;
    }

    bare: w.variant === "shape"
    defaultTone: "surface"
    onCountChanged: {
        if (w.count > 0 && w.pick >= w.count)
            w.pick = 0;

    }

    FolderListModel {
        id: files

        folder: "file://" + w.folder
        nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.webp", "*.JPG", "*.JPEG", "*.PNG"]
        showDirs: false
        sortField: FolderListModel.Time
        onStatusChanged: {
            if (files.status === FolderListModel.Ready && files.count > 0)
                w.pick = Math.floor(Math.random() * files.count);

        }
    }

    Timer {
        interval: Math.max(60000, w.everyMs)
        repeat: true
        running: w.everyMs > 0 && !w.preview && w.visible
        onTriggered: w.next()
    }

    // frame: the photo filling the card, its date on a chip
    ClippingRectangle {
        visible: w.variant === "frame"
        anchors.fill: parent
        radius: w.corner
        color: Theme.alpha(w.ink, 0.06)

        Image {
            id: frameImg

            anchors.fill: parent
            source: w.variant === "frame" ? w.current : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            sourceSize.width: Theme.dp(720)
            sourceSize.height: Theme.dp(720)
            opacity: frameImg.status === Image.Ready ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.durSlowEffects
                }

            }

        }

        Rectangle {
            visible: w.caption !== "" && w.opt("showDate") !== false
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            anchors.margins: Theme.dp(12)
            width: capText.implicitWidth + Theme.dp(20)
            height: Theme.dp(26)
            radius: Theme.dp(13)
            color: Theme.alpha(Theme.bgOpaque, 0.78)

            LText {
                id: capText

                anchors.centerIn: parent
                role: "labelMedium"
                color: Theme.text
                text: w.caption
            }

        }

    }

    // shape: the photo cut to an expressive shape, straight on the wallpaper
    ShapedImage {
        visible: w.variant === "shape"
        anchors.centerIn: parent
        width: Math.min(parent.width, parent.height)
        height: width
        shape: w.frameShape
        source: w.variant === "shape" ? w.current : ""
        decode: 720
        fallbackColor: Theme.withBlur(Theme.surfaceHigh)
    }

    // polaroid: a white print with the date written under it
    Item {
        visible: w.variant === "polaroid"
        anchors.fill: parent
        anchors.margins: Theme.dp(12)

        ClippingRectangle {
            id: printCard

            width: parent.width
            height: parent.height - Theme.dp(34)
            radius: Theme.rad(10)
            color: Theme.alpha(w.ink, 0.06)

            Image {
                anchors.fill: parent
                source: w.variant === "polaroid" ? w.current : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                sourceSize.width: Theme.dp(720)
                sourceSize.height: Theme.dp(720)
            }

        }

        LText {
            anchors.top: printCard.bottom
            anchors.topMargin: Theme.dp(6)
            anchors.horizontalCenter: parent.horizontalCenter
            role: "titleSmall"
            weight: 520
            rounded: 100
            color: w.ink
            text: w.caption
        }

    }

    Column {
        visible: w.count === 0
        anchors.centerIn: parent
        width: parent.width - Theme.dp(32)
        spacing: Theme.dp(6)

        Icon {
            anchors.horizontalCenter: parent.horizontalCenter
            name: "photo_library"
            size: Theme.dp(30)
            color: w.inkFaint
        }

        LText {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            role: "bodySmall"
            color: w.inkDim
            wrapMode: Text.Wrap
            text: "No pictures in " + w.folder.replace(w.home, "~")
        }

    }

    // a click turns to the next photo, a press that travels moves the card
    MouseArea {
        id: grab

        property real pressX: 0
        property real pressY: 0
        property bool moved: false
        readonly property bool movable: !w.preview && w.host !== null && !w.host.locked

        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        cursorShape: Qt.PointingHandCursor
        onPressed: (mouse) => {
            grab.pressX = mouse.x;
            grab.pressY = mouse.y;
            grab.moved = false;
        }
        onPositionChanged: (mouse) => {
            if (!grab.movable)
                return ;

            if (!grab.moved) {
                if (Math.abs(mouse.x - grab.pressX) < 4 && Math.abs(mouse.y - grab.pressY) < 4)
                    return ;

                grab.moved = true;
                const from = grab.mapToItem(w.host, grab.pressX, grab.pressY);
                w.host.beginDrag(from.x, from.y);
            }
            const at = grab.mapToItem(w.host, mouse.x, mouse.y);
            w.host.moveDrag(at.x, at.y);
        }
        onReleased: {
            if (grab.moved) {
                w.host.endDrag();
                grab.moved = false;
                return ;
            }
            w.next();
        }
        onCanceled: {
            if (grab.moved && grab.movable)
                w.host.endDrag();

            grab.moved = false;
        }
    }

}
