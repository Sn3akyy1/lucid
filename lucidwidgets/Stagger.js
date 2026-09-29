.pragma library

// spaces out work shared by every caller, so a page full of live widget previews
// builds one card a frame instead of all in one. timers that fell due together behind a
// slow card are turned back by wait() until a frame has had room to draw
var gap = 34;
var lastRun = 0;

function wait() {
    var since = Date.now() - lastRun;
    return since >= gap ? 0 : gap - since;
}

function ran() {
    lastRun = Date.now();
}
