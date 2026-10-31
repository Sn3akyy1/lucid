//@ pragma Env QSG_DISTANCEFIELD_ANTIALIASING=gray
//@ pragma Env QT_FFMPEG_DECODING_HW_DEVICE_TYPES=vaapi,cuda
//@ pragma Env QT_FFMPEG_ENCODING_HW_DEVICE_TYPES=
// qt's default subpixel text splits into colour fringes on translucent surfaces.
// qt multimedia reads its decoders once per process: the integrated gpu first,
// so a video doesn't wake a hybrid laptop's dgpu, and no encoders, which a
// player opens up front for nothing (as LiveWall.qml sets them)
// lens, lucid's picture viewer: its own quickshell instance beside the shell,
// started by lucidlens/lens, one process for any number of windows
import QtQuick
import Quickshell
import qs.lucidlens

ShellRoot {
    // a viewer keeps its windows: saving anything in the tree would otherwise
    // reload it and close them all. LENS_DEV=1 for working on lens
    settings.watchFiles: Quickshell.env("LENS_DEV") === "1"

    Lens {
    }

}
