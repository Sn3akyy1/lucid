import QtQuick
import Quickshell
import Quickshell.Io
import "I18nCore.js" as Core
pragma Singleton

// what every label goes through. the catalogues are i18n/<code>.json keyed by
// the English text, and English itself has none: it is the text in the code.
// tr() reads `strings`, so any binding that calls it is redone when the
// language changes or the file is edited, with no restart
Singleton {
    id: root

    readonly property string envCode: Core.envLocale(Quickshell.env("LC_ALL") || "", Quickshell.env("LC_MESSAGES") || "", Quickshell.env("LANG") || "")
    readonly property string pref: Prefs.language || "auto"
    // [{ code, name, locale }] read from the catalogues' _meta, English first
    property var catalogues: []
    readonly property var available: root.catalogues.map((c) => {
        return c.code;
    })
    readonly property string language: Core.resolve(root.pref, root.envCode, root.available)
    readonly property var languages: [{
        "code": "en",
        "name": "English"
    }].concat(root.catalogues.map((c) => {
        return {
            "code": c.code,
            "name": c.name
        };
    }))
    readonly property string autoName: root.nameOf(Core.resolve("auto", root.envCode, root.available))
    property var strings: ({})
    property var meta: ({})
    // the environment's own region when it speaks the same language (es_MX for
    // es, picked or automatic), else the catalogue's; dates and numbers follow it
    readonly property var locale: Qt.locale(root.envCode !== "" && root.envCode.split("_")[0] === root.language.split("_")[0] ? root.envCode : (root.language === "en" ? "en_US" : (root.meta.locale || root.language)))

    function tr(text, ...args) {
        return Core.tr(root.strings, text, args);
    }

    function trc(ctx, text, ...args) {
        return Core.trc(root.strings, ctx, text, args);
    }

    function trn(singular, plural, n, ...args) {
        return Core.trn(root.strings, singular, plural, n, args);
    }

    function nameOf(code) {
        var l = root.languages.find((x) => {
            return x.code === code;
        });
        return l ? l.name : code;
    }

    function pathOf(code) {
        const c = root.catalogues.find((x) => {
            return x.code === code;
        });
        return c ? c.path : "";
    }

    onLanguageChanged: {
        if (root.language === "en") {
            root.strings = {};
            root.meta = {};
        }
    }

    // languages the user added; a file here wins over a shipped one of the same code
    readonly property string userDir: Quickshell.env("HOME") + "/.config/lucid/i18n"
    // what the last import or export said, for the Language page
    property string report: ""
    property bool reportBad: false

    function rescan() {
        scan.running = false;
        scan.running = true;
    }

    // copy a translation file in after checking it is one; code is its file name
    function importFile(path) {
        run.command = ["python3", "-c", "import json,os,sys,shutil\ntry:\n    p=os.path.expanduser(sys.argv[1]);d=json.load(open(p,encoding='utf-8'))\n    assert isinstance(d,dict) and isinstance(d.get('_meta'),dict) and d['_meta'].get('name'),'it needs a _meta with a name'\n    assert all(isinstance(v,(str,dict)) for k,v in d.items() if k!='_meta'),'values must be text'\n    c=os.path.basename(p)[:-5] if p.endswith('.json') else os.path.basename(p)\n    assert c.replace('_','').replace('-','').isalnum() and c!='en','the file name must be a language code, like de.json'\n    os.makedirs(sys.argv[2],exist_ok=True);shutil.copy(p,os.path.join(sys.argv[2],c+'.json'));print('ok '+d['_meta']['name'])\nexcept Exception as e:\n    print('no '+str(e))", path, root.userDir];
        run.running = true;
    }

    // write a catalogue to the home folder: a language as it is, or "template", every text empty
    function exportCatalogue(code) {
        run.command = ["python3", "-c", "import json,os,sys\nsrc,user,code,out=sys.argv[1:5]\nf=os.path.join(user,code+'.json')\nif not os.path.exists(f): f=os.path.join(src,code if code!='template' else 'es')+'.json'\nd=json.load(open(f,encoding='utf-8'))\nif code=='template':\n    d={'_meta':{'name':'','locale':''},**{k:({'one':'','other':''} if isinstance(v,dict) else '') for k,v in d.items() if k!='_meta'}}\nt=os.path.join(out,'lucid-'+code+'.json')\njson.dump(d,open(t,'w',encoding='utf-8'),ensure_ascii=False,indent=2)\nprint('ok '+t)", Quickshell.shellPath("i18n"), root.userDir, code, Quickshell.env("HOME")];
        run.running = true;
    }

    Process {
        id: scan

        running: true
        command: ["python3", "-c", "import json,glob,os,sys\nout={}\nfor d in sys.argv[1:]:\n    for f in sorted(glob.glob(os.path.join(d,'*.json'))):\n        try: m=json.load(open(f,encoding='utf-8')).get('_meta',{})\n        except Exception: continue\n        c=os.path.basename(f)[:-5]\n        out[c]={'code':c,'name':m.get('name',c),'locale':m.get('locale',c),'path':f,'user':d==sys.argv[2]}\nprint(json.dumps(sorted(out.values(),key=lambda x:x['code'])))", Quickshell.shellPath("i18n"), root.userDir]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.catalogues = JSON.parse(this.text);
                } catch (e) {
                    console.warn("i18n: could not list the catalogues: " + e);
                }
            }
        }

    }

    Process {
        id: run

        stdout: StdioCollector {
            onStreamFinished: {
                const t = this.text.trim();
                root.reportBad = t.indexOf("ok ") !== 0;
                root.report = root.reportBad ? t.replace(/^no /, "") : t.slice(3);
                root.rescan();
            }
        }

    }

    FileView {
        path: root.pathOf(root.language)
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                var d = JSON.parse(text());
                root.meta = d._meta || {};
                delete d._meta;
                root.strings = d;
            } catch (e) {
                // a half-written or broken file keeps what was there
                console.warn("i18n: " + path + ": " + e);
            }
        }
    }

}
