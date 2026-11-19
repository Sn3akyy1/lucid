import QtQuick
import qs
import qs.lucidui

// how much of the day, the week, the month and the year has gone by
WidgetBody {
    id: w

    property date now: Loc.now()
    readonly property string span: w.opt("span") || "day"
    readonly property var kinds: ["day", "week", "month", "year"]
    readonly property int year: w.now.getFullYear()
    readonly property int days: Math.round((new Date(w.year + 1, 0, 1) - new Date(w.year, 0, 1)) / 86400000)
    // today, counted from 0 on the first of January
    readonly property int doy: Math.round((new Date(w.year, w.now.getMonth(), w.now.getDate()) - new Date(w.year, 0, 1)) / 86400000)
    readonly property var monthOfDay: {
        const out = [];
        for (let m = 0; m < 12; m++) {
            const n = new Date(w.year, m + 1, 0).getDate();
            for (let d = 0; d < n; d++) out.push(m)
        }
        return out;
    }

    function bounds(kind) {
        const y = w.now.getFullYear();
        const m = w.now.getMonth();
        const d = w.now.getDate();
        // days since the locale's first day of the week
        const back = (w.now.getDay() - I18n.locale.firstDayOfWeek + 7) % 7;
        switch (kind) {
        case "week":
            return [new Date(y, m, d - back), new Date(y, m, d - back + 7)];
        case "month":
            return [new Date(y, m, 1), new Date(y, m + 1, 1)];
        case "year":
            return [new Date(y, 0, 1), new Date(y + 1, 0, 1)];
        }
        return [new Date(y, m, d), new Date(y, m, d + 1)];
    }

    function part(kind) {
        const b = w.bounds(kind);
        return Math.max(0, Math.min(1, (w.now - b[0]) / (b[1] - b[0])));
    }

    function pctOf(kind) {
        return Math.floor(w.part(kind) * 100) + "%";
    }

    function title(kind) {
        switch (kind) {
        case "week":
            return I18n.tr("This week");
        case "month":
            return w.now.toLocaleDateString(I18n.locale, "MMMM");
        case "year":
            return String(w.year);
        }
        return I18n.tr("Today");
    }

    function of(kind) {
        switch (kind) {
        case "week":
            return I18n.tr("of the week");
        case "month":
            return "of " + w.now.toLocaleDateString(I18n.locale, "MMMM");
        case "year":
            return "of " + w.year;
        }
        return I18n.tr("of the day");
    }

    function remaining(kind) {
        const mins = Math.floor(Math.max(0, w.bounds(kind)[1] - w.now) / 60000);
        if (mins < 60)
            return I18n.tr("%1 min left", mins);

        if (mins < 1440)
            return Math.floor(mins / 60) + " h " + (mins % 60 > 0 ? mins % 60 + " min " : "") + "left";

        const d = Math.floor(mins / 1440);
        return d === 1 ? I18n.tr("1 day left") : I18n.tr("%1 days left", d);
    }

    defaultTone: w.variant === "ring" ? "primary" : "surface"

    Timer {
        interval: 60000
        repeat: true
        running: !w.preview
        onTriggered: w.now = Loc.now()
    }

    // ring: one stretch of time as a wavy ring, how much is gone in the middle
    Item {
        visible: w.variant === "ring"
        anchors.fill: parent

        CircularProgress {
            anchors.fill: parent
            anchors.margins: Theme.dp(14)
            thickness: Theme.dp(14)
            value: w.part(w.span)
            color: w.inkAccent
            trackColor: Theme.alpha(w.ink, 0.12)
        }

        Column {
            anchors.centerIn: parent
            spacing: -Theme.dp(2)

            LText {
                anchors.horizontalCenter: parent.horizontalCenter
                size: Theme.dp(44)
                weight: 640
                rounded: 100
                tabular: true
                color: w.ink
                text: w.pctOf(w.span)
            }

            LText {
                anchors.horizontalCenter: parent.horizontalCenter
                role: "labelLarge"
                color: w.inkDim
                text: w.of(w.span)
            }

            LText {
                anchors.horizontalCenter: parent.horizontalCenter
                topPadding: Theme.dp(4)
                role: "labelMedium"
                color: w.inkFaint
                text: w.remaining(w.span)
            }

        }

    }

    // bars: the four stretches one under another; the waves run while you point at it
    Column {
        id: bars

        visible: w.variant === "bars"
        anchors.fill: parent
        anchors.margins: Theme.dp(18)
        spacing: Theme.dp(10)

        Repeater {
            model: w.variant === "bars" ? w.kinds : []

            Column {
                id: bar

                required property string modelData

                width: bars.width
                spacing: Theme.dp(4)

                Item {
                    width: parent.width
                    height: barTitle.implicitHeight

                    LText {
                        id: barTitle

                        role: "titleSmall"
                        color: w.ink
                        text: w.title(bar.modelData)
                    }

                    LText {
                        anchors.right: parent.right
                        role: "titleSmall"
                        tabular: true
                        color: w.inkAccent
                        text: w.pctOf(bar.modelData)
                    }

                }

                LinearProgress {
                    width: parent.width
                    value: w.part(bar.modelData)
                    wavy: true
                    flowing: w.hovered
                    thickness: Theme.dp(5)
                    amplitude: Theme.dp(2.5)
                    wavelength: Theme.dp(22)
                    color: w.inkAccent
                    trackColor: Theme.alpha(w.ink, 0.12)
                }

            }

        }

    }

    // dots: every day of the year, the ones gone filled in and today in the accent
    Item {
        id: dots

        visible: w.variant === "dots"
        anchors.fill: parent
        anchors.margins: Theme.dp(18)

        Column {
            id: dotsHead

            width: parent.width
            spacing: -Theme.dp(1)

            Item {
                width: parent.width
                height: dotsYear.implicitHeight

                LText {
                    id: dotsYear

                    role: "titleLarge"
                    weight: 600
                    rounded: 100
                    color: w.ink
                    text: String(w.year)
                }

                LText {
                    anchors.right: parent.right
                    anchors.baseline: dotsYear.baseline
                    role: "titleLarge"
                    weight: 600
                    rounded: 100
                    tabular: true
                    color: w.inkAccent
                    text: w.pctOf("year")
                }

            }

            LText {
                role: "bodySmall"
                color: w.inkDim
                text: I18n.tr("Day %1 · %2", (w.doy + 1), w.remaining("year"))
            }

        }

        Item {
            id: field

            // the column count that leaves the biggest dots
            readonly property int cols: {
                let best = 7;
                let bestPitch = 0;
                for (let c = 7; c <= 60; c++) {
                    const p = Math.min(field.width / c, field.height / Math.ceil(w.days / c));
                    if (p > bestPitch) {
                        bestPitch = p;
                        best = c;
                    }
                }
                return best;
            }
            readonly property real pitch: Math.max(2, Math.min(field.width / field.cols, field.height / Math.ceil(w.days / field.cols)))
            readonly property real offX: (field.width - field.cols * field.pitch) / 2

            anchors.top: dotsHead.bottom
            anchors.topMargin: Theme.dp(10)
            anchors.bottom: parent.bottom
            width: parent.width

            Repeater {
                model: w.variant === "dots" ? w.days : 0

                Rectangle {
                    required property int index
                    readonly property bool today: index === w.doy

                    x: field.offX + (index % field.cols) * field.pitch + (field.pitch - width) / 2
                    y: Math.floor(index / field.cols) * field.pitch + (field.pitch - height) / 2
                    width: Math.round(field.pitch * (today ? 1 : 0.64))
                    height: width
                    radius: width / 2
                    color: today ? w.inkAccent : (index < w.doy ? Theme.alpha(w.ink, 0.78) : Theme.alpha(w.ink, w.monthOfDay[index] % 2 === 0 ? 0.13 : 0.24))
                }

            }

        }

    }

}
