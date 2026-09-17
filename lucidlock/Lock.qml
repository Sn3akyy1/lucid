import QtQuick
import Quickshell
import Quickshell.Wayland
import qs

// the session lock itself. everything it knows lives in Lockscreen; this only
// puts a surface on every screen and keeps the compositor honest
Scope {
    id: root

    WlSessionLock {
        id: session

        locked: Lockscreen.locked

        surface: WlSessionLockSurface {
            id: pane

            color: "black"

            LockSurface {
                anchors.fill: parent
                // only the shell's own screen gets the field and the cards
                primary: !Monitors.mainScreen || pane.screen === Monitors.mainScreen
            }

        }

    }

    // the weather and the accounts are only worth fetching once a lock is up
    Connections {
        function onLockedChanged() {
            if (Lockscreen.locked)
                WeatherSource.ensure();

        }

        target: Lockscreen
    }

}
