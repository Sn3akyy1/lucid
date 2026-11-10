import Quickshell
import qs

// the blur under the hang plan's fillets, one patch a fillet the bar draws
Region {
    id: reg

    property var host: null

    FlareRegion {
        readonly property var spec: reg.host && reg.host.hangPlan.fillets.length > 0 ? reg.host.hangPlan.fillets[0] : null

        host: reg.host
        on: spec !== null
        size: spec ? spec.size : 0
        mirrored: spec ? spec.mirrored : false
        flipped: spec ? spec.flipped : false
        fx: spec ? spec.x : 0
        fy: spec ? spec.y : 0
    }

    FlareRegion {
        readonly property var spec: reg.host && reg.host.hangPlan.fillets.length > 1 ? reg.host.hangPlan.fillets[1] : null

        host: reg.host
        on: spec !== null
        size: spec ? spec.size : 0
        mirrored: spec ? spec.mirrored : false
        flipped: spec ? spec.flipped : false
        fx: spec ? spec.x : 0
        fy: spec ? spec.y : 0
    }

    FlareRegion {
        readonly property var spec: reg.host && reg.host.hangPlan.fillets.length > 2 ? reg.host.hangPlan.fillets[2] : null

        host: reg.host
        on: spec !== null
        size: spec ? spec.size : 0
        mirrored: spec ? spec.mirrored : false
        flipped: spec ? spec.flipped : false
        fx: spec ? spec.x : 0
        fy: spec ? spec.y : 0
    }

    FlareRegion {
        readonly property var spec: reg.host && reg.host.hangPlan.fillets.length > 3 ? reg.host.hangPlan.fillets[3] : null

        host: reg.host
        on: spec !== null
        size: spec ? spec.size : 0
        mirrored: spec ? spec.mirrored : false
        flipped: spec ? spec.flipped : false
        fx: spec ? spec.x : 0
        fy: spec ? spec.y : 0
    }

    FlareRegion {
        readonly property var spec: reg.host && reg.host.hangPlan.fillets.length > 4 ? reg.host.hangPlan.fillets[4] : null

        host: reg.host
        on: spec !== null
        size: spec ? spec.size : 0
        mirrored: spec ? spec.mirrored : false
        flipped: spec ? spec.flipped : false
        fx: spec ? spec.x : 0
        fy: spec ? spec.y : 0
    }

    FlareRegion {
        readonly property var spec: reg.host && reg.host.hangPlan.fillets.length > 5 ? reg.host.hangPlan.fillets[5] : null

        host: reg.host
        on: spec !== null
        size: spec ? spec.size : 0
        mirrored: spec ? spec.mirrored : false
        flipped: spec ? spec.flipped : false
        fx: spec ? spec.x : 0
        fy: spec ? spec.y : 0
    }

    FlareRegion {
        readonly property var spec: reg.host && reg.host.hangPlan.fillets.length > 6 ? reg.host.hangPlan.fillets[6] : null

        host: reg.host
        on: spec !== null
        size: spec ? spec.size : 0
        mirrored: spec ? spec.mirrored : false
        flipped: spec ? spec.flipped : false
        fx: spec ? spec.x : 0
        fy: spec ? spec.y : 0
    }

    FlareRegion {
        readonly property var spec: reg.host && reg.host.hangPlan.fillets.length > 7 ? reg.host.hangPlan.fillets[7] : null

        host: reg.host
        on: spec !== null
        size: spec ? spec.size : 0
        mirrored: spec ? spec.mirrored : false
        flipped: spec ? spec.flipped : false
        fx: spec ? spec.x : 0
        fy: spec ? spec.y : 0
    }

    FlareRegion {
        readonly property var spec: reg.host && reg.host.hangPlan.fillets.length > 8 ? reg.host.hangPlan.fillets[8] : null

        host: reg.host
        on: spec !== null
        size: spec ? spec.size : 0
        mirrored: spec ? spec.mirrored : false
        flipped: spec ? spec.flipped : false
        fx: spec ? spec.x : 0
        fy: spec ? spec.y : 0
    }

    FlareRegion {
        readonly property var spec: reg.host && reg.host.hangPlan.fillets.length > 9 ? reg.host.hangPlan.fillets[9] : null

        host: reg.host
        on: spec !== null
        size: spec ? spec.size : 0
        mirrored: spec ? spec.mirrored : false
        flipped: spec ? spec.flipped : false
        fx: spec ? spec.x : 0
        fy: spec ? spec.y : 0
    }

    FlareRegion {
        readonly property var spec: reg.host && reg.host.hangPlan.fillets.length > 10 ? reg.host.hangPlan.fillets[10] : null

        host: reg.host
        on: spec !== null
        size: spec ? spec.size : 0
        mirrored: spec ? spec.mirrored : false
        flipped: spec ? spec.flipped : false
        fx: spec ? spec.x : 0
        fy: spec ? spec.y : 0
    }

    FlareRegion {
        readonly property var spec: reg.host && reg.host.hangPlan.fillets.length > 11 ? reg.host.hangPlan.fillets[11] : null

        host: reg.host
        on: spec !== null
        size: spec ? spec.size : 0
        mirrored: spec ? spec.mirrored : false
        flipped: spec ? spec.flipped : false
        fx: spec ? spec.x : 0
        fy: spec ? spec.y : 0
    }

    FlareRegion {
        readonly property var spec: reg.host && reg.host.hangPlan.fillets.length > 12 ? reg.host.hangPlan.fillets[12] : null

        host: reg.host
        on: spec !== null
        size: spec ? spec.size : 0
        mirrored: spec ? spec.mirrored : false
        flipped: spec ? spec.flipped : false
        fx: spec ? spec.x : 0
        fy: spec ? spec.y : 0
    }

    FlareRegion {
        readonly property var spec: reg.host && reg.host.hangPlan.fillets.length > 13 ? reg.host.hangPlan.fillets[13] : null

        host: reg.host
        on: spec !== null
        size: spec ? spec.size : 0
        mirrored: spec ? spec.mirrored : false
        flipped: spec ? spec.flipped : false
        fx: spec ? spec.x : 0
        fy: spec ? spec.y : 0
    }

    FlareRegion {
        readonly property var spec: reg.host && reg.host.hangPlan.fillets.length > 14 ? reg.host.hangPlan.fillets[14] : null

        host: reg.host
        on: spec !== null
        size: spec ? spec.size : 0
        mirrored: spec ? spec.mirrored : false
        flipped: spec ? spec.flipped : false
        fx: spec ? spec.x : 0
        fy: spec ? spec.y : 0
    }

    FlareRegion {
        readonly property var spec: reg.host && reg.host.hangPlan.fillets.length > 15 ? reg.host.hangPlan.fillets[15] : null

        host: reg.host
        on: spec !== null
        size: spec ? spec.size : 0
        mirrored: spec ? spec.mirrored : false
        flipped: spec ? spec.flipped : false
        fx: spec ? spec.x : 0
        fy: spec ? spec.y : 0
    }

}
