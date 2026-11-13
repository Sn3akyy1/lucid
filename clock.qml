//@ pragma Env QSG_DISTANCEFIELD_ANTIALIASING=gray
// qt's default subpixel text splits into colour fringes on translucent surfaces.
// clock, lucid's clock app: its own quickshell instance beside the shell,
// started by lucidclock/clock. the alarms, timers and reminders it shows run in
// the shell, so they keep time with this closed
import QtQuick
import Quickshell
import qs.lucidclock

ShellRoot {
    // an app keeps its window: saving anything in the tree would otherwise
    // reload it and close the window. CLOCK_DEV=1 for working on the clock
    settings.watchFiles: Quickshell.env("CLOCK_DEV") === "1"

    ClockApp {
    }

}
