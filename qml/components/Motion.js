.pragma library
// One motion vocabulary for the whole app, after the Material 3 easing tokens
// (standard, emphasized decelerate, emphasized accelerate). The same cubic-bezier curves drive
// NumberAnimation (BezierSpline arrays below) and the timeline-derived
// choreography of opening/closing (JS functions), so everything moves alike.

var standardCurve = [0.2, 0.0, 0.0, 1.0, 1, 1];   // surfaces that change in place
var decelerateCurve = [0.05, 0.7, 0.1, 1.0, 1, 1]; // things arriving
var accelerateCurve = [0.3, 0.0, 0.8, 0.15, 1, 1]; // things leaving

function clamp01(v) { return v < 0 ? 0 : v > 1 ? 1 : v; }
// Local progress of a [from, to] window inside a 0..1 timeline.
function seg(t, from, to) { return clamp01((t - from) / (to - from)); }
function mix(a, b, p) { return a + (b - a) * p; }

function bezier(x1, y1, x2, y2) {
    function sample(a1, a2, s) { return ((1 - 3 * a2 + 3 * a1) * s + (3 * a2 - 6 * a1)) * s * s + 3 * a1 * s; }
    function slope(a1, a2, s) { return 3 * (1 - 3 * a2 + 3 * a1) * s * s + 2 * (3 * a2 - 6 * a1) * s + 3 * a1; }
    return function (x) {
        if (x <= 0) return 0;
        if (x >= 1) return 1;
        var s = x;
        for (var i = 0; i < 6; ++i) {
            var d = slope(x1, x2, s);
            if (Math.abs(d) < 1e-6) break;
            s -= (sample(x1, x2, s) - x) / d;
        }
        if (s < 0 || s > 1 || Math.abs(sample(x1, x2, s) - x) > 1e-4) {
            var lo = 0, hi = 1;
            s = x;
            for (var j = 0; j < 24; ++j) {
                if (sample(x1, x2, s) < x) lo = s; else hi = s;
                s = (lo + hi) / 2;
            }
        }
        return sample(y1, y2, s);
    };
}
var standard = bezier(0.2, 0.0, 0.0, 1.0);
var decelerate = bezier(0.05, 0.7, 0.1, 1.0);
var accelerate = bezier(0.3, 0.0, 0.8, 0.15);
