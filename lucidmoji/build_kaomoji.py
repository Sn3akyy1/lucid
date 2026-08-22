#!/usr/bin/env python3
"""Build lucidmoji/kaomoji.json - curated text faces + Japanese-style marks.

Same shape as emoji.json so the panel can drive both tabs off one delegate:
  { "groups": [...], "kaomoji": [{"e": "(＾▽＾)", "n": "happy", "g": 0, "k": "smile"}] }
"""
import json
import os

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "kaomoji.json")

GROUPS = ["Joy", "Love", "Sad", "Angry", "Confused", "Surprise", "Greeting",
          "Animals", "Actions", "Cute", "Lenny", "Marks"]

# (kaomoji, name, group index, extra search keywords)
DATA = [
    # ---- Joy -------------------------------------------------------------
    ("(＾▽＾)", "happy", 0, "smile joy glad"),
    ("(￣▽￣)", "smug grin", 0, "smile pleased"),
    ("(＾ω＾)", "cheerful", 0, "smile happy"),
    ("(´∀｀)", "delighted", 0, "smile happy"),
    ("(≧▽≦)", "excited", 0, "joy happy thrilled"),
    ("(*≧ω≦)", "giddy", 0, "excited happy"),
    ("ヽ(´▽`)/", "cheering", 0, "happy celebrate yay"),
    ("＼(^o^)／", "hooray", 0, "yay celebrate happy"),
    ("(๑˃ᴗ˂)ﻭ", "fired up", 0, "happy excited go"),
    ("(◕‿◕)", "content", 0, "smile happy"),
    ("(´｡• ᵕ •｡`)", "sweet smile", 0, "happy cute"),
    ("( ˙꒳​˙ )", "quiet joy", 0, "content calm"),
    ("(*^▽^*)", "beaming", 0, "happy smile"),
    ("(❁´◡`❁)", "blissful", 0, "happy flower"),
    ("(⁀ᗢ⁀)", "grinning", 0, "smile happy"),
    ("(*´ω`*)", "warm", 0, "happy cozy"),
    ("(＾▽＾)b", "thumbs up", 0, "good nice approve"),
    ("ヽ(・∀・)ﾉ", "excited wave", 0, "happy yay"),
    ("(๑>◡<๑)", "joyful", 0, "happy smile"),
    ("(¬‿¬)", "smirk", 0, "sly grin"),
    ("(◠‿◠)", "gentle smile", 0, "happy kind"),
    ("(´▽`ʃ♡ƪ)", "so happy", 0, "joy love"),
    ("ヾ(≧▽≦*)o", "party", 0, "happy celebrate"),
    ("(๑˘︶˘๑)", "peaceful", 0, "calm content happy"),
    ("(灬º‿º灬)", "shy happy", 0, "blush cute"),

    # ---- Love ------------------------------------------------------------
    ("(♡°▽°♡)", "in love", 1, "heart adore"),
    ("(*♡∀♡)", "smitten", 1, "heart love"),
    ("(´♡‿♡`)", "adoring", 1, "heart love"),
    ("♡(˃͈ દ ˂͈ ༶ )", "lovestruck", 1, "heart adore"),
    ("(づ￣ ³￣)づ", "kiss hug", 1, "love smooch"),
    ("( ˘ ³˘)♥", "kiss", 1, "love smooch heart"),
    ("(っ˘з(˘⌣˘ )", "kissing", 1, "love couple"),
    ("(*╯3╰)", "smooch", 1, "kiss love"),
    ("♡＼(￣▽￣)／♡", "spreading love", 1, "heart happy"),
    ("(◍•ᴗ•◍)❤", "loving", 1, "heart cute"),
    ("(っ▀¯▀)つ", "creeping love", 1, "hug sneak"),
    ("(つ✧ω✧)つ", "starstruck", 1, "love excited"),
    ("♥‿♥", "heart eyes", 1, "love adore"),
    ("(´,,•ω•,,)♡", "affection", 1, "love cute heart"),
    ("(≧◡≦) ♡", "cherish", 1, "love happy heart"),
    ("(*¯ ³¯*)♡", "blow kiss", 1, "love smooch"),

    # ---- Sad -------------------------------------------------------------
    ("(╥﹏╥)", "crying", 2, "tears sad sob"),
    ("(个_个)", "sobbing", 2, "cry sad tears"),
    ("(ಥ﹏ಥ)", "bawling", 2, "cry sad tears"),
    ("(っ˘̩╭╮˘̩)っ", "heartbroken", 2, "cry sad"),
    ("(´；ω；`)", "teary", 2, "cry sad"),
    ("(ᵕ̣̣̣̣̣̣﹏ᵕ̣̣̣̣̣̣)", "miserable", 2, "cry sad"),
    ("(._.)", "downcast", 2, "sad quiet"),
    ("(´-ω-`)", "dejected", 2, "sad tired"),
    ("( ˘︹˘ )", "unhappy", 2, "sad frown"),
    ("(⌣_⌣”)", "disappointed", 2, "sad let down"),
    ("(╯_╰)", "distressed", 2, "sad upset"),
    ("(っ- ‸ - ς)", "sulking", 2, "sad pout"),
    ("(´。＿。｀)", "gloomy", 2, "sad down"),
    ("｡ﾟ(ﾟ´Д｀)ﾟ｡", "wailing", 2, "cry sad loud"),
    ("(◞‸◟)", "downhearted", 2, "sad blue"),
    ("(´+ω+`)", "worn out", 2, "sad tired"),

    # ---- Angry -----------------------------------------------------------
    ("(╬ ಠ益ಠ)", "furious", 3, "angry rage mad"),
    ("(ノಠ益ಠ)ノ", "raging", 3, "angry mad flip"),
    ("(≖､≖╬)", "seething", 3, "angry mad"),
    ("(¬_¬)", "annoyed", 3, "angry irritated"),
    ("(￣ヘ￣)", "displeased", 3, "angry grumpy"),
    ("ヽ(ｏ`皿′ｏ)ﾉ", "yelling", 3, "angry shout mad"),
    ("(⋋▂⋌)", "irate", 3, "angry mad"),
    ("(҂◡_◡)", "menacing", 3, "angry threat"),
    ("ಠ_ಠ", "disapproval", 3, "look stare judging"),
    ("(눈_눈)", "unimpressed", 3, "annoyed done"),
    ("(＃`Д´)", "outraged", 3, "angry mad"),
    ("凸(￣ヘ￣)", "middle finger", 3, "rude angry"),
    ("(ノ`Д´)ノ彡┻━┻", "table flip rage", 3, "angry flip mad"),
    ("(ﾉಥ益ಥ)ﾉ", "melting down", 3, "angry cry"),

    # ---- Confused --------------------------------------------------------
    ("(・_・?)", "puzzled", 4, "confused what huh"),
    ("(￢_￢)", "skeptical", 4, "doubt suspicious"),
    ("(－‸ლ)", "facepalm", 4, "disappointed ugh"),
    ("(・・？)", "questioning", 4, "confused huh"),
    ("(」°ロ°)」", "bewildered", 4, "confused shocked"),
    ("(⊙_☉)", "baffled", 4, "confused stare"),
    ("(°ロ°) !", "wait what", 4, "confused shock"),
    ("┐(‘～`;)┌", "no idea", 4, "shrug dunno confused"),
    ("¯\\_(ツ)_/¯", "shrug", 4, "dunno whatever idk"),
    ("╮(￣～￣)╭", "who knows", 4, "shrug dunno"),
    ("(⓿_⓿)", "blank stare", 4, "confused empty"),
    ("(・∧‐)ゞ", "unsure", 4, "confused hmm"),
    ("(￢‿￢ )", "suspicious", 4, "sly doubt"),
    ("(?_?)", "lost", 4, "confused huh"),

    # ---- Surprise --------------------------------------------------------
    ("(⊙_⊙)", "startled", 5, "shock surprise wow"),
    ("(ﾟﾛﾟ)", "shocked", 5, "surprise gasp"),
    ("(ʘ言ʘ╬)", "horrified", 5, "shock scared"),
    ("Σ(°ロ°)", "astonished", 5, "shock surprise"),
    ("(＃ﾟдﾟ)", "aghast", 5, "shock surprise"),
    ("(ﾟдﾟ；)", "alarmed", 5, "shock scared"),
    ("Σ(ﾟДﾟ)", "gasping", 5, "shock surprise"),
    ("(°o°)", "amazed", 5, "wow surprise"),
    ("(*_*)", "dazzled", 5, "wow amazed"),
    ("(ﾉ﹃ﾉ)", "drooling", 5, "want hungry"),
    ("(⊙o⊙)", "wide eyed", 5, "surprise wow"),

    # ---- Greeting --------------------------------------------------------
    ("(*・ω・)ﾉ", "hi there", 6, "hello wave greet"),
    ("(^-^*)/", "hello", 6, "hi wave greet"),
    ("ヾ(＾-＾)ノ", "waving", 6, "hi hello bye"),
    ("( ´ ▽ ` )ﾉ", "friendly wave", 6, "hi hello"),
    ("(￣▽￣)ノ", "casual hi", 6, "hello wave"),
    ("(*￣▽￣)b", "nice one", 6, "good approve thumbs"),
    ("(＾▽＾)/", "bye bye", 6, "goodbye wave farewell"),
    ("(・∀・)ノ", "yo", 6, "hi hello wave"),
    ("(¬‿¬ )づ", "sup", 6, "hello greet"),
    ("m(_ _)m", "bowing", 6, "sorry thanks respect"),
    ("(＿ ＿*) Z z z", "goodnight", 6, "sleep tired bed"),
    ("(´• ω •`)ﾉ", "gentle wave", 6, "hi hello"),
    ("(￣ｰ￣)ゞ", "salute", 6, "greet respect"),

    # ---- Animals ---------------------------------------------------------
    ("(=^･ω･^=)", "cat", 7, "kitty neko meow"),
    ("(=^･ｪ･^=)", "kitten", 7, "cat neko"),
    ("ฅ(^･ω･^ฅ)", "cat paws", 7, "kitty neko"),
    ("(≡ᴥ≡)", "dog", 7, "puppy woof"),
    ("ʕ•ᴥ•ʔ", "bear", 7, "kuma cute"),
    ("ʕ￫ᴥ￩ʔ", "bear peek", 7, "kuma cute"),
    ("(･ｪ-)", "bunny", 7, "rabbit cute"),
    ("(\\(\\ (•ㅅ•)", "rabbit", 7, "bunny cute"),
    ("(・(ｪ)・)", "panda", 7, "bear cute"),
    ("<コ:彡", "squid", 7, "ika sea"),
    ("＜°))))彡", "fish", 7, "sea swim"),
    ("(°▽°)/ 🐟", "fish treat", 7, "cat feed"),
    ("(:3 っ)っ", "cat loaf", 7, "kitty lazy"),
    ("ʕ·ᴥ·ʔ", "little bear", 7, "kuma cute"),
    ("/ᐠ｡ꞈ｡ᐟ\\", "cat face", 7, "kitty neko"),
    ("(´･(ｪ)･`)", "sad bear", 7, "kuma"),
    ("૮ ˶ᵔ ᵕ ᵔ˶ ა", "soft creature", 7, "cute blob"),
    ("(◕ᴥ◕ʋ)", "good dog", 7, "puppy woof"),

    # ---- Actions ---------------------------------------------------------
    ("(╯°□°)╯︵ ┻━┻", "table flip", 8, "rage angry flip"),
    ("┬─┬ノ( º _ ºノ)", "table back", 8, "fix calm put"),
    ("(ノ ゜Д゜)ノ ︵ ┻━┻", "big flip", 8, "rage angry"),
    ("┻━┻ ︵ヽ(`Д´)ﾉ︵ ┻━┻", "double flip", 8, "rage angry"),
    ("ᕕ( ᐛ )ᕗ", "running", 8, "go leave run"),
    ("ᕙ(⇀‸↼‶)ᕗ", "flexing", 8, "strong muscle gym"),
    ("ᕦ(ò_óˇ)ᕤ", "gains", 8, "strong flex gym"),
    ("┏(＾0＾)┛", "dancing", 8, "party happy"),
    ("♪┏(・o･)┛♪", "dance music", 8, "party song"),
    ("(っ˘ڡ˘ς)", "eating", 8, "yum food tasty"),
    ("( ͡° ͜ʖ ͡°)づ╧╧", "shooting", 8, "gun lenny"),
    ("(∩ ͡° ͜ʖ ͡°)⊃━☆ﾟ", "casting spell", 8, "magic wand"),
    ("(づ｡◕‿‿◕｡)づ", "hug", 8, "cuddle love"),
    ("╰(*´︶`*)╯", "big hug", 8, "cuddle love"),
    ("⊂(・﹏・⊂)", "sneaking hug", 8, "cuddle creep"),
    ("⊂(´• ω •`⊂)", "coming for hug", 8, "cuddle"),
    ("_(:3 」∠)_", "flopped over", 8, "tired lazy dead"),
    ("(-_-) zzz", "sleeping", 8, "tired bed nap"),
    ("(x_x)", "dead", 8, "ko dying tired"),
    ("(￣﹃￣)", "daydreaming", 8, "drool zone out"),
    ("¯\\(°_o)/¯", "clueless shrug", 8, "dunno idk"),
    ("(ノ^_^)ノ", "throwing hands", 8, "yay celebrate"),
    ("༼ つ ◕_◕ ༽つ", "give energy", 8, "summon take"),
    ("(⌐■_■)", "deal with it", 8, "cool sunglasses"),
    ("( •_•)>⌐■-■", "putting on shades", 8, "cool sunglasses"),
    ("(☞ﾟヮﾟ)☞", "pointing", 8, "you that"),
    ("☜(ﾟヮﾟ☜)", "pointing left", 8, "you that"),
    ("(¬､¬)ﾉ", "dismissing", 8, "wave off nah"),

    # ---- Cute ------------------------------------------------------------
    ("(｡◕‿◕｡)", "adorable", 9, "cute sweet"),
    ("(⁄ ⁄•⁄ω⁄•⁄ ⁄)", "blushing", 9, "shy cute embarrassed"),
    ("(*/ω＼*)", "bashful", 9, "shy blush"),
    ("(๑•́ ₃ •̀๑)", "pouting", 9, "sulk cute"),
    ("(´꒳`)", "soft", 9, "cute calm"),
    ("(｡•́︿•̀｡)", "sad puppy", 9, "cute sad"),
    ("( ˘⌣˘)♡", "cozy", 9, "cute love warm"),
    ("(*ﾉ▽ﾉ)", "flustered", 9, "shy blush"),
    ("(◍•ᴗ•◍)", "wholesome", 9, "cute happy"),
    ("ʚ(*´꒳`*)ɞ", "little angel", 9, "cute sweet"),
    ("(´｡• ω •｡`)", "innocent", 9, "cute pure"),
    ("૮₍ ˶ᵔ ᵕ ᵔ˶ ₎ა", "soft blob", 9, "cute creature"),
    ("(=◕ᆽ◕ฺ=)", "cutie cat", 9, "kitty cute"),
    ("(๑˃̵ᴗ˂̵)و", "cheer up", 9, "encourage cute"),
    ("(｡•̀ᴗ-)✧", "wink", 9, "cute sparkle"),
    ("(´ ▽`).。ｏ♡", "thinking of you", 9, "love cute"),
    ("(⑅˘꒳˘)", "sleepy cute", 9, "soft calm"),
    ("ヽ(=^･ω･^=)丿", "happy cat", 9, "kitty cute"),

    # ---- Lenny -----------------------------------------------------------
    ("( ͡° ͜ʖ ͡°)", "lenny", 10, "lewd smirk meme"),
    ("( ͡~ ͜ʖ ͡°)", "lenny wink", 10, "lewd smirk"),
    ("( ͡ʘ ͜ʖ ͡ʘ)", "lenny wide", 10, "lewd stare"),
    ("( ͡°( ͡° ͜ʖ( ͡° ͜ʖ ͡°)ʖ ͡°) ͡°)", "lenny army", 10, "meme many"),
    ("(͠≖ ͜ʖ͠≖)", "sly lenny", 10, "sneaky smirk"),
    ("( ͡ಠ ʖ̯ ͡ಠ)", "disapproving lenny", 10, "annoyed"),
    ("(ง ͠° ͟ل͜ ͡°)ง", "fight me", 10, "lenny fists"),
    ("ᶘ ͡°ᴥ͡°ᶅ", "lenny seal", 10, "animal"),
    ("( ͡° ͜ʖ ͡°)╭∩╮", "lenny rude", 10, "flip off"),

    # ---- Marks (Japanese-style decoration) --------------------------------
    ("【 】", "corner brackets", 11, "japanese lenticular title"),
    ("「 」", "quote brackets", 11, "japanese corner quotes"),
    ("『 』", "double quote brackets", 11, "japanese corner"),
    ("〜", "wave dash", 11, "japanese tilde long"),
    ("・", "middle dot", 11, "japanese separator interpunct"),
    ("々", "repeat mark", 11, "japanese iteration"),
    ("〆", "closing mark", 11, "japanese shime"),
    ("ー", "long vowel", 11, "japanese dash choonpu"),
    ("♪", "note", 11, "music song"),
    ("♫", "notes", 11, "music song"),
    ("★", "filled star", 11, "sparkle favourite"),
    ("☆", "open star", 11, "sparkle favourite"),
    ("✧", "sparkle", 11, "star shine"),
    ("✿", "flower", 11, "blossom cute"),
    ("❀", "blossom", 11, "flower cute"),
    ("♡", "heart outline", 11, "love cute"),
    ("♥", "heart", 11, "love"),
    ("෴", "sinhala squiggle", 11, "decoration"),
    ("彡", "speed lines", 11, "japanese motion"),
    ("ﾟ", "half voiced mark", 11, "japanese sparkle dot"),
    ("｡", "small period", 11, "japanese halfwidth stop"),
    ("→", "right arrow", 11, "direction"),
    ("←", "left arrow", 11, "direction"),
    ("↑", "up arrow", 11, "direction"),
    ("↓", "down arrow", 11, "direction"),
    ("※", "reference mark", 11, "japanese note kome"),
    ("〒", "postal mark", 11, "japanese mail"),
    ("￥", "yen", 11, "japanese money"),
    ("℃", "celsius", 11, "degree temperature"),
    ("∴", "therefore", 11, "math logic"),
    ("≠", "not equal", 11, "math"),
    ("∞", "infinity", 11, "math forever"),
    ("…", "ellipsis", 11, "dots pause"),
    ("‼", "double bang", 11, "exclamation"),
    ("⁉", "interrobang", 11, "question exclamation"),
]

out = []
for e, n, g, k in DATA:
    row = {"e": e, "n": n, "g": g}
    if k:
        row["k"] = k
    out.append(row)

seen = {}
for row in out:
    if row["e"] in seen:
        raise SystemExit(f"duplicate kaomoji: {row['e']}")
    seen[row["e"]] = True

with open(OUT, "w", encoding="utf-8") as fh:
    json.dump({"groups": GROUPS, "kaomoji": out}, fh,
              ensure_ascii=False, separators=(",", ":"))
print(f"wrote {len(out)} kaomoji in {len(GROUPS)} groups -> {OUT}")
