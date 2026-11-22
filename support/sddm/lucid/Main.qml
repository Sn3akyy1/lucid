import QtQuick
import QtQuick.Effects
import "components"
import "parts" as Parts

// lucid's lock screen, wearing sddm's auth instead of pam. what sits over the
// wallpaper is the lock's own Stage (parts/, copied from lucidlock/parts), laid
// out by the picked account's own layout (users/<name>/lock.conf)
Item {
    id: surface

    // sddm loads this once per screen. only one of them asks for a password
    readonly property bool primary: (typeof primaryScreen === "undefined") ? true : primaryScreen
    // the arrival driver, linear in time so each block can ease its own slice
    property real t: 0
    // 1 while the greeter is here, 0 once the password has been taken
    property real out: 1
    // 0 glance, 1 focus. the day steps back so the field can step forward
    property real focusK: Lock.focused ? 1 : 0
    // while the field has the screen, everything that steps back also stops
    // taking clicks and hover. a click out there only buys the focus back
    readonly property bool glanceLive: !Lock.focused
    readonly property real e: surface.ease(surface.t)
    // the backdrop, as the account's layout asks: blur and dim 0..100, a wash
    readonly property var layout: Lock.layout
    readonly property real blurK: surface.layout.blur / 100
    readonly property real dimK: surface.layout.dim / 100

    width: 1920
    height: 1080

    // a long tail, so a block lands rather than stops
    function ease(x) {
        var c = Math.max(0, Math.min(1, x));
        return 1 - Math.pow(1 - c, 5);
    }

    // a block's own progress: nothing until its turn, then a full ease of its own
    function rv(delay) {
        return surface.ease((surface.t - delay) / Math.max(0.05, 1 - delay));
    }

    Behavior on focusK {
        NumberAnimation {
            duration: Theme.ms(520)
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.easeEmphasizedDecel
        }

    }

    NumberAnimation {
        id: enterAnim

        target: surface
        property: "t"
        to: 1
        duration: Theme.ms(900)
    }

    // the greeter leans forward and dissolves as the session takes over
    ParallelAnimation {
        id: exitAnim

        NumberAnimation {
            target: surface
            property: "out"
            to: 0
            duration: Theme.ms(300)
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.easeEmphasizedAccel
        }

    }

    Connections {
        function onPhaseChanged() {
            if (Lock.granted)
                exitAnim.restart();

        }

        target: Lock
    }

    // the models, read by role name so no role number has to be guessed
    Instantiator {
        model: userModel

        delegate: QtObject {
            required property string name
            required property string realName
            required property string icon
            required property bool needsPassword
        }

        onObjectAdded: surface.syncUsers()
        onObjectRemoved: surface.syncUsers()

        id: users
    }

    Instantiator {
        id: sessions

        model: sessionModel

        delegate: QtObject {
            required property string name
            required property string comment
        }

        onObjectAdded: surface.syncSessions()
        onObjectRemoved: surface.syncSessions()
    }

    function syncUsers() {
        var out = [];
        for (var i = 0; i < users.count; i++) {
            var o = users.objectAt(i);
            if (o)
                out.push({
                    "name": o.name,
                    "realName": o.realName,
                    "icon": o.icon,
                    "needsPassword": o.needsPassword
                });

        }
        Lock.accounts = out;
    }

    function syncSessions() {
        var out = [];
        for (var i = 0; i < sessions.count; i++) {
            var o = sessions.objectAt(i);
            if (o)
                out.push({
                    "name": o.name,
                    "comment": o.comment || ""
                });

        }
        Lock.sessions = out;
    }

    Component.onCompleted: {
        Lock.driver = surface.primary;
        surface.syncUsers();
        surface.syncSessions();
        // sddm remembers who logged in last, and into what
        for (var i = 0; i < Lock.accounts.length; i++) {
            if (Lock.accounts[i].name === userModel.lastUser) {
                Lock.index = i;
                break;
            }
        }
        if (sessionModel.lastIndex >= 0 && sessionModel.lastIndex < Lock.sessions.length)
            Lock.sessionIndex = sessionModel.lastIndex;

        // sddm can be told to list nobody; then every login is typed by hand
        if (Lock.accounts.length === 0)
            Lock.manual = true;

        // the first account's colours land at once; every pick after it glides
        surface.paperLive = true;
        surface.showPaper();
        Qt.callLater(function() {
            Theme.settled = true;
        });
        surface.t = 0;
        surface.out = 1;
        enterAnim.start();
        if (surface.primary) {
            Lock.sys = sysState;
            Qt.callLater(stage.focusInput);
        }

    }

    // ── backdrop ───────────────────────────────────────────────────────────
    // the scale has to live on a child: MultiEffect renders its source without
    // the source item's own transform, so a scale on the Image itself is lost
    Item {
        id: paperBox

        anchors.fill: parent

        Item {
            id: paper

            anchors.fill: parent
            scale: 1.07 - 0.07 * surface.e + surface.focusK * 0.02 + (1 - surface.out) * 0.06

            // background.jpg is generated by sync-sddm.sh and deliberately not
            // in the repo, so an account that has never painted one gets a
            // flat lucid surface
            Rectangle {
                anchors.fill: parent
                color: Theme.bgOpaque
            }

        }

    }

    // one layer per wallpaper shown. each fades in over whatever is under it
    // once decoded, then retires everything beneath, so switching accounts
    // quickly still crossfades from what is actually on screen
    property var paperLayers: []
    property bool paperLive: false

    function showPaper() {
        var src = Theme.background;
        var video = Theme.backgroundVideo;
        var top = surface.paperLayers.length > 0 ? surface.paperLayers[surface.paperLayers.length - 1] : null;
        if (top && String(top.src) === String(src) && String(top.video) === String(video))
            return ;

        surface.paperLayers.push(paperLayer.createObject(paper, {
            "src": src,
            "video": video
        }));
    }

    function retirePaper(layer) {
        var i = surface.paperLayers.indexOf(layer);
        if (i <= 0)
            return ;

        var gone = surface.paperLayers.splice(0, i);
        for (var j = 0; j < gone.length; j++)
            gone[j].destroy();
    }

    Connections {
        // the picture and the video move together on a switch: one layer for both
        function onBackgroundChanged() {
            if (surface.paperLive)
                Qt.callLater(surface.showPaper);

        }

        function onBackgroundVideoChanged() {
            if (surface.paperLive)
                Qt.callLater(surface.showPaper);

        }

        target: Theme
    }

    Component {
        id: paperLayer

        Item {
            id: layer

            required property url src
            required property url video
            // a picture that will not load still fades in, as a flat surface
            readonly property bool decoded: img.status !== Image.Loading

            anchors.fill: parent
            opacity: 0
            onDecodedChanged: {
                if (layer.decoded)
                    fadeIn.start();

            }
            Component.onCompleted: {
                if (layer.decoded)
                    fadeIn.start();

            }

            Rectangle {
                anchors.fill: parent
                color: Theme.bgOpaque
                visible: img.status !== Image.Ready
            }

            Image {
                id: img

                anchors.fill: parent
                source: layer.src
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: false
            }

            // its own file, so a machine without QtMultimedia loses only the
            // motion and keeps the still under it
            Loader {
                anchors.fill: parent
                active: String(layer.video) !== ""
                source: "components/LiveBackdrop.qml"
                onLoaded: item.source = layer.video
            }

            NumberAnimation {
                id: fadeIn

                target: layer
                property: "opacity"
                to: 1
                duration: Theme.lookMs
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.easeLook
                onFinished: surface.retirePaper(layer)
            }

        }

    }

    // the lock's own blur, live over sharp copies: a blur baked into a small
    // copy showed the encoder's blocks once stretched. a copy from before that
    // has it baked in, so only the focus deepening goes over it; blurs don't
    // add up linearly, and 0.7 over that bake is the lock's 0.82, measured
    MultiEffect {
        anchors.fill: parent
        source: paperBox
        autoPaddingEnabled: false
        blurEnabled: true
        blurMax: 64
        blur: surface.e * surface.out * (Theme.backgroundSharp ? Math.min(1, surface.blurK + surface.focusK * 0.32) : surface.focusK * 0.7)
        visible: Theme.backgroundSharp || surface.focusK > 0.01
    }

    Rectangle {
        anchors.fill: parent
        opacity: surface.e * surface.out * Math.min(1, surface.dimK * 0.85 + surface.focusK * 0.14)

        gradient: Gradient {
            GradientStop {
                position: 0
                color: Theme.alpha(Theme.cScrim, 0.75)
            }

            GradientStop {
                position: 0.45
                color: Theme.alpha(Theme.cScrim, 0.95)
            }

            GradientStop {
                position: 1
                color: Theme.cScrim
            }

        }

    }

    // material you's whole point: the wallpaper's own colour laid back over it
    Rectangle {
        anchors.fill: parent
        color: Theme.accent
        opacity: surface.layout.tint ? surface.e * surface.out * 0.07 : 0
    }

    // everything drawn on top leaves together
    Item {
        id: stageBox

        anchors.fill: parent
        opacity: surface.out
        scale: 1 + (1 - surface.out) * 0.05

        // a click anywhere off the sign-in puts the greeter back to its resting
        // face and forgets whatever was half-typed
        MouseArea {
            anchors.fill: parent
            onClicked: {
                stage.discard();
                Lock.disengage();
            }
        }

        Parts.Stage {
            id: stage

            anchors.fill: parent
            theme: Theme
            lock: Lock
            layout: surface.layout
            greeter: true
            primary: surface.primary
            t: surface.t
            focusK: surface.focusK
            glanceLive: surface.glanceLive
            auth: authC
        }

    }

    Parts.OnScreenKeys {
        id: keys

        anchors.fill: parent
        theme: Theme
        lock: Lock
        stage: stage
        open: Lock.keysOpen && surface.primary && !Lock.granted
        opacity: surface.out
        onCloseRequested: Lock.keysOpen = false
        onFocusWanted: stage.focusInput()
    }

    // whose account and which session: over everything, beside what asked
    Picker {
        anchors.fill: parent
        live: surface.primary
        opacity: surface.out
        onClosed: stage.focusInput()
    }

    Component {
        id: authC

        AuthCard {
        }

    }

    // battery, network and the radio, read off sysfs by the one screen that asks
    SysState {
        id: sysState

        readable: surface.primary
    }

}
