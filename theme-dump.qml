import QtQuick
import Quickshell
import qs
import qs.lucidlock

// prints the resolved Theme tokens as json, for anything outside the shell
// that needs Lucid's colours - sddm, which runs before this config exists.
// the tone maths in Theme.qml is not reproducible from the palette file, so
// the only honest source is the Theme itself.
//
//   qs -p ~/.config/quickshell/theme-dump.qml
ShellRoot {
    // the shared lock parts' palette, as the lock itself reads it: the login
    // screen gets every one of these under the same name
    LockTokens {
        id: tokens
    }

    // builds Theme now rather than inside the print below: a singleton read for
    // the first time hands back its fallback colours, and the file it is waiting
    // on only lands on the next event loop turn
    Component.onCompleted: Theme.paletteLoaded

    Timer {
        property int tries: 0

        running: true
        interval: 250
        repeat: true
        onTriggered: {
            tries += 1;
            // both arrive over a FileView, so the first tick is too early
            if ((!Prefs.loaded || !Theme.paletteLoaded) && tries < 20)
                return ;

            var out = {
                "isLight": Theme.isLight,
                "accent": Theme.accent.toString(),
                "accentHover": Theme.accentHover.toString(),
                "fgAccent": Theme.fgAccent.toString(),
                "accentMuted": Theme.accentMuted.toString(),
                "clockHour": Theme.atTone(Theme.cPrimary, Theme.isLight ? 25 : 92).toString(),
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
                "uiScale": Theme.uiScale,
                "cornerScale": Theme.cornerScale,
                "clock24h": Prefs.clock24h
            };
            for (var i = 0; i < tokens.colourKeys.length; i++) {
                var k = tokens.colourKeys[i];
                out[k] = tokens[k].toString();
            }
            console.log("LUCIDTOKENS " + JSON.stringify(out));
            Qt.exit(0);
        }
    }

}
