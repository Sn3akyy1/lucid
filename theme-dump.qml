import QtQuick
import Quickshell
import qs

// prints the resolved Theme tokens as json, for anything outside the shell
// that needs Lucid's colours - sddm, which runs before this config exists.
// the tone maths in Theme.qml is not reproducible from the palette file, so
// the only honest source is the Theme itself.
//
//   qs -p ~/.config/quickshell/theme-dump.qml
ShellRoot {
    Timer {
        property int tries: 0

        running: true
        interval: 250
        repeat: true
        onTriggered: {
            tries += 1;
            // Prefs arrives over a FileView, so the first tick is too early
            if (!Prefs.loaded && tries < 20)
                return ;

            console.log("LUCIDTOKENS " + JSON.stringify({
                "isLight": Theme.isLight,
                "accent": Theme.accent.toString(),
                "accentHover": Theme.accentHover.toString(),
                "fgAccent": Theme.fgAccent.toString(),
                "accentMuted": Theme.accentMuted.toString(),
                "accentContainer": Theme.accentContainer.toString(),
                "fgAccentContainer": Theme.fgAccentContainer.toString(),
                "bgOpaque": Theme.bgOpaque.toString(),
                "bgHigh": Theme.bgHigh.toString(),
                "text": Theme.text.toString(),
                "subtext": Theme.subtext.toString(),
                "subtextDim": Theme.subtextDim.toString(),
                "outline": Theme.outline.toString(),
                "outlineStrong": Theme.outlineStrong.toString(),
                "error": Theme.error.toString(),
                "fgError": Theme.fgError.toString(),
                "errorHover": Theme.atTone(Theme.error, Theme.toneOf(Theme.error) + (Theme.isLight ? -6 : 6)).toString(),
                "success": Theme.success.toString(),
                "fgSuccess": Theme.fgSuccess.toString(),
                "warning": Theme.warning.toString(),
                "scrim": Theme.cScrim.toString(),
                "fontFamily": Theme.fontFamily,
                "fontScale": Theme.fontScale,
                "motionScale": Theme.motionScale,
                "clock24h": Prefs.clock24h
            }));
            Qt.exit(0);
        }
    }

}
