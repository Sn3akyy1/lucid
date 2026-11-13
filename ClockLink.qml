import QtQuick
import Quickshell
import Quickshell.Io
pragma Singleton

// the clock app's line to the shell. the app is a process of its own, with its
// own window id and icon, but alarms, timers and reminders have to keep going
// with it closed, so they stay in the shell and the app works them from here.
// it is sent the state when it connects and again after every change, and it
// sends back what to do: one json object a line, both ways
Singleton {
    id: link

    readonly property string path: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/lucid-clock.sock"
    property var peers: []
    property int rev: 0
    property bool queued: false
    readonly property int peerCount: link.peers.length
    // the settings the app may change; anything else it asks for is refused
    readonly property var prefKeys: ["clock24h", "weekStartMonday", "timerSound", "reminderSound", "pomodoroFocus", "pomodoroShort", "pomodoroLong", "pomodoroRounds", "pomodoroGoal", "pomodoroAutoStart", "pomodoroAutoFocus", "pomodoroRepeat", "pomodoroSilence"]
    // what the app mirrors: the stores themselves, nothing derived from the
    // time, so this changes when something is done and not as the clock ticks
    readonly property var state: ({
        "ready": Prefs.loaded && Alarms.loaded,
        "prefs": {
            "clock24h": Prefs.clock24h,
            "weekStartMonday": Prefs.weekStartMonday,
            "timerSound": Prefs.timerSound,
            "reminderSound": Prefs.reminderSound,
            "pomodoroFocus": Prefs.pomodoroFocus,
            "pomodoroShort": Prefs.pomodoroShort,
            "pomodoroLong": Prefs.pomodoroLong,
            "pomodoroRounds": Prefs.pomodoroRounds,
            "pomodoroGoal": Prefs.pomodoroGoal,
            "pomodoroAutoStart": Prefs.pomodoroAutoStart,
            "pomodoroAutoFocus": Prefs.pomodoroAutoFocus,
            "pomodoroRepeat": Prefs.pomodoroRepeat,
            "pomodoroSilence": Prefs.pomodoroSilence,
            "doNotDisturb": Prefs.doNotDisturb
        },
        "tz": {
            "read": Loc.zoneRead,
            "offset": Loc.trueOffsetMin,
            "zone": Loc.zone
        },
        "alarms": {
            "list": Alarms.alarms,
            "ringing": Alarms.ringing,
            "snoozed": Alarms.snoozed,
            "snoozeMinutes": Alarms.snoozeMinutes,
            "silenceMinutes": Alarms.silenceMinutes,
            "gradual": Alarms.gradual,
            "sound": Alarms.sound,
            "volume": Alarms.volume,
            "sounds": Alarms.soundChoices
        },
        "chrono": {
            "timers": Chrono.timers,
            "swRunning": Chrono.swRunning,
            "swStart": Chrono.swStart,
            "swBank": Chrono.swBank,
            "laps": Chrono.laps,
            "pomoPhase": Chrono.pomoPhase,
            "pomoRound": Chrono.pomoRound,
            "pomoRunning": Chrono.pomoRunning,
            "pomoEndsAt": Chrono.pomoEndsAt,
            "pomoLeft": Chrono.pomoLeft,
            "pomoSpan": Chrono.pomoSpan,
            "pomoDay": Chrono.pomoDay,
            "pomoDone": Chrono.pomoDone,
            "pomoFocusMs": Chrono.pomoFocusMs,
            "presets": Chrono.pomoPresets
        },
        "reminders": {
            "items": Agenda.items,
            "ringing": Agenda.ringing.map((r) => {
                return r.id;
            }),
            "snoozed": Agenda.snoozedUntil
        },
        "zones": {
            "cities": Zones.cities,
            "offsets": Zones.offsets
        }
    })

    function queue() {
        if (link.queued)
            return ;

        link.queued = true;
        Qt.callLater(link.pushAll);
    }

    function line(obj) {
        return JSON.stringify(obj) + "\n";
    }

    function snapshot() {
        return link.line(Object.assign({
            "ev": "state",
            "rev": link.rev
        }, link.state));
    }

    function send(peer, text) {
        try {
            peer.write(text);
            peer.flush();
        } catch (e) {
        }
    }

    function pushAll() {
        link.queued = false;
        if (link.peers.length === 0)
            return ;

        link.rev++;
        const text = link.snapshot();
        for (const p of link.peers) link.send(p, text)
    }

    function join(peer) {
        if (link.peers.indexOf(peer) < 0)
            link.peers = link.peers.concat([peer]);

        link.rev++;
        link.send(peer, link.snapshot());
    }

    function leave(peer) {
        const left = link.peers.filter((p) => {
            return p !== peer;
        });
        if (left.length !== link.peers.length)
            link.peers = left;

    }

    function handle(peer, text) {
        let m;
        try {
            m = JSON.parse(text);
        } catch (e) {
            return ;
        }
        if (!m || typeof m.op !== "string")
            return ;

        let reply = {
            "re": m.rid === undefined ? null : m.rid,
            "ok": true
        };
        try {
            const data = link.run(m.op, m.args || {
            }, peer);
            if (data !== undefined)
                reply.data = data;

        } catch (e) {
            reply.ok = false;
            reply.error = String(e);
        }
        if (m.rid !== undefined)
            link.send(peer, link.line(reply));

    }

    function run(op, a, peer) {
        switch (op) {
        case "state":
            link.send(peer, link.snapshot());
            return ;
        // alarms
        case "alarm.add":
            return Alarms.add(a);
        case "alarm.update":
            Alarms.update(String(a.id), a.fields || {
            });
            return ;
        case "alarm.remove":
            Alarms.remove(String(a.id));
            return ;
        case "alarm.on":
            Alarms.setOn(String(a.id), a.on === true);
            return ;
        case "alarm.skip":
            Alarms.skipNext(String(a.id), a.yes === true);
            return ;
        case "alarm.stop":
            if (a.id === undefined)
                Alarms.stopAll();
            else
                Alarms.stop(String(a.id));
            return ;
        case "alarm.snooze":
            if (a.id === undefined)
                Alarms.snoozeAll();
            else
                Alarms.snooze(String(a.id), parseInt(a.minutes, 10) || 0);
            return ;
        case "alarm.set":
            Alarms.setSetting(String(a.key), a.value);
            return ;
        case "alarm.preview":
            Alarms.preview(String(a.sound || ""));
            return ;
        // timers, the stopwatch and the pomodoro
        case "timer.add":
            Chrono.addTimer(Math.max(1, Math.min(359999, Number(a.sec) || 60)), String(a.name || "").slice(0, 60));
            return Chrono.timers.length ? Chrono.timers[Chrono.timers.length - 1].id : "";
        case "timer.toggle":
            Chrono.toggle(String(a.id));
            return ;
        case "timer.reset":
            Chrono.reset(String(a.id));
            return ;
        case "timer.restart":
            Chrono.reset(String(a.id));
            Chrono.resume(String(a.id));
            return ;
        case "timer.extend":
            Chrono.extend(String(a.id), Number(a.sec) || 60);
            return ;
        case "timer.rename":
            Chrono.rename(String(a.id), String(a.name || "").slice(0, 60));
            return ;
        case "timer.remove":
            Chrono.remove(String(a.id));
            return ;
        case "timer.clear":
            Chrono.clearFinished();
            return ;
        case "sw.toggle":
            Chrono.swToggle();
            return ;
        case "sw.lap":
            Chrono.swLap();
            return ;
        case "sw.reset":
            Chrono.swReset();
            return ;
        case "pomo.toggle":
            Chrono.pomoToggle();
            return ;
        case "pomo.skip":
            Chrono.pomoSkip();
            return ;
        case "pomo.stop":
            Chrono.pomoStop();
            return ;
        case "pomo.extend":
            Chrono.pomoExtend(Number(a.sec) || 60);
            return ;
        case "pomo.preset":
            Chrono.pomoUsePreset(String(a.key));
            return ;
        // reminders
        case "rem.add":
            Agenda.add(parseInt(a.year, 10), parseInt(a.month, 10), parseInt(a.day, 10), parseInt(a.hour, 10), parseInt(a.minute, 10), String(a.name || "").slice(0, 120), String(a.repeat || ""));
            return ;
        case "rem.update":
            Agenda.update(String(a.id), a.fields || {
            });
            return ;
        case "rem.remove":
            Agenda.remove(String(a.id));
            return ;
        case "rem.snooze":
            Agenda.snooze(String(a.id), Math.max(1, parseInt(a.minutes, 10) || 10));
            return ;
        case "rem.dismiss":
            Agenda.dismiss(String(a.id));
            return ;
        // the world
        case "zone.add":
            Zones.addCity(String(a.tz));
            return ;
        case "zone.remove":
            Zones.removeCity(String(a.tz));
            return ;
        case "zone.move":
            Zones.moveCity(String(a.tz), parseInt(a.by, 10) || 0);
            return ;
        // settings
        case "pref.set":
            if (link.prefKeys.indexOf(a.key) < 0)
                throw "not a clock setting: " + a.key;
            Prefs.set(a.key, a.value);
            return ;
        case "sound.preview":
            Sounds.play(String(a.key || "alarm"), 1, 400);
            return ;
        case "ping":
            return "pong";
        }
        throw "unknown op " + op;
    }

    onStateChanged: link.queue()

    SocketServer {
        active: true
        path: link.path

        handler: Socket {
            id: peer

            onConnectedChanged: {
                if (peer.connected)
                    link.join(peer);
                else
                    link.leave(peer);
            }
            Component.onDestruction: link.leave(peer)

            parser: SplitParser {
                onRead: (text) => {
                    return link.handle(peer, text);
                }
            }

        }

    }

}
