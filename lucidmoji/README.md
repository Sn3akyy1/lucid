# LucidMoji

Emoji / kaomoji / GIF picker. Centred draggable overlay that types straight
into whatever window you were in, and stays open so you can send several in a
row.

## Opening it

`SUPER + .` (bound in `~/.config/hypr/modules/binds.lua`), or by IPC:

```
qs ipc call moji toggle     # or: open, close
qs ipc call moji emoji      # open straight onto a tab
qs ipc call moji kaomoji
qs ipc call moji gif
```

## Using it

| | |
|---|---|
| Type | search the current tab (word-start matches, name before keywords) |
| ← → ↑ ↓ | move the selection · `Enter` copies it |
| `Tab` | next tab · `Esc` closes |
| Click | type it into the window you came from; panel stays open |
| Right-click | favourite / unfavourite (also the ☆ in the footer) |
| Drag | the header or footer strip moves the panel; position is remembered |

## How insertion works

Typing needs **wtype** (`pacman -S wtype`) — Wayland has no way for a client to
push text into another window on its own. Without it the panel silently falls
back to copying to the clipboard, and the footer hint says so.

The panel takes keyboard focus while it's open (that's what makes search work),
which means the window you came from is no longer focused and synthetic keys
would land in the panel's own search box. So each insert runs a three-stage
hand-off: drop `keyboardFocus` → re-activate the toplevel that was focused when
the panel opened → type → take focus back. The re-activate step is not
optional; releasing layer-shell keyboard focus on its own leaves focus nowhere
and the keystrokes go into the void. Rapid clicks queue behind one hand-off
instead of each doing their own.

Local GIFs are the exception and still go to the clipboard as image data —
there's nothing typeable about a `.gif`. Tenor GIFs type their URL.

### Electron and Chromium apps

Chromium ignores the Unicode keysyms `wtype` synthesizes. ASCII arrives fine;
emoji, `é`, `→` — anything non-ASCII — is silently dropped, and no `wtype`
delay flag changes it (verified against a Chromium test page: `AB` typed,
`😀 é → ☺` all lost). That's why insertion looked broken in Vesktop while
working everywhere else.

So apps whose window id matches `pasteApps` get clipboard+`Ctrl+V` instead of
`wtype`. Your clipboard is backed up to a temp file with its real mime type and
restored ~450 ms after the paste, so picking an emoji doesn't cost you whatever
you had copied. `pasteApps` in `config.json` is empty by default, which means
the built-in list (vesktop, discord, slack, element, signal, spotify, code,
codium, obsidian, notion, teams, chrome, chromium, brave, edge…); set it to
override. Matching is a case-insensitive substring of the app id, so `vesktop`
covers `vesktop`, and you can add any app that turns out to need it.

Skin tone comes from the six dots in the footer and applies to every emoji
that has variants (315 of them). Recents and favourites keep the exact tone
you copied.

## GIFs

Two sources, both optional:

- **Giphy** (preferred) — free key from <https://developers.giphy.com/dashboard/>,
  email only, no credit card. Put it in `config.json` as `giphyKey`. Free "beta"
  keys are rate limited (roughly 42 searches/hour), which is fine for personal use.
- **Tenor** — also supported, but its key needs a Google Cloud *billing account*
  even though the API itself is free. Put it in `config.json` as `tenorKey`.
  Whichever key is present is used, Giphy first. With neither, the tab opens on
  Local instead.
- **Local** — every `.gif` under `gifDir` (default `~/Pictures/GIFs`, up to 3
  levels deep). Local GIFs are copied as actual image data, so they paste
  straight into a chat window; Tenor GIFs copy their URL, which is what chat
  apps expand into an embed.

## Files

| | |
|---|---|
| `Moji.qml` | window, IPC, persistence, clipboard |
| `MojiFace.qml` | emoji + kaomoji tabs |
| `GifPane.qml` | GIF tab |
| `emoji.json` | 1946 emoji, 9 groups — generated |
| `kaomoji.json` | 217 text faces, 12 groups — hand-curated |
| `config.json` | `giphyKey`, `tenorKey`, `gifDir`, `pasteApps` |
| `state.json` | recents, favourites, skin tone, panel position |

`emoji.json` is built from Unicode's `emoji-test.txt` (16.0) plus CLDR
keywords, filtered to what Noto Color Emoji and Twemoji can actually render,
with skin-tone variants folded into their base entry. Regenerate either
dataset with:

```
python3 build_emoji.py      # needs network + python-fonttools
python3 build_kaomoji.py    # edits go in the DATA table
```
