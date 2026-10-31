//@ pragma Env QSG_DISTANCEFIELD_ANTIALIASING=gray
// qt's default subpixel text splits into colour fringes on translucent surfaces
// lumen, lucid's file manager: its own quickshell instance beside the shell,
// started by lucidlumen/lumen, one process for any number of windows
import QtQuick
import Quickshell
import qs.lucidlumen

ShellRoot {
    // a file manager keeps its windows: saving anything in the tree would
    // otherwise reload it and close them all. LUMEN_DEV=1 for working on lumen
    settings.watchFiles: Quickshell.env("LUMEN_DEV") === "1"

    Lumen {
    }

}
