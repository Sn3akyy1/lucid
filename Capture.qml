import QtQuick
import Quickshell
pragma Singleton

// what LucidShot's recorder is doing, for the surfaces outside its window: the
// bar's chip and the control centre's tile. the overlay writes it, they read it
Singleton {
    // "idle" | "recording" | "paused"
    property string state: "idle"
    property int seconds: 0
    // the toolbar was tucked away mid-recording, so nothing else shows it is on
    property bool hidden: false
    readonly property bool active: state !== "idle"

    signal showRequested()

    function clock(sec) {
        return Math.floor(sec / 60) + ":" + String(sec % 60).padStart(2, "0");
    }
}
