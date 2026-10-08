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

            // clear only for the last frames of an unlock
            color: Lockscreen.seeThrough ? "transparent" : "black"

            LockSurface {
                anchors.fill: parent
                // only the shell's own screen gets the field and the cards
                primary: !Monitors.mainScreen || pane.screen === Monitors.mainScreen
                capture: Lockscreen.captureFor(pane.screen)
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
