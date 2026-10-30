import QtQuick
import Quickshell.Io

// One AI subscription's usage limits, for AiUsageService. `script` prints
// "signed-out", or a first line passed on to `parse` (e.g. the plan), then the
// API's answer and its HTTP status on the last line (curl -w '\n%{http_code}').
// `parse(data, firstLine)` turns the answer into { plan, limits, resets }, with
// limits as [{ name, percent, resetsAt (Date), session / weekly (true for the
// 5-hour and the all-models weekly limit, shown on the bar) }] and resets (limit
// resets one can use now) as [{ name, until (Date or null) }], one per reset.
QtObject {
    id: root

    required property string name
    required property string script
    required property var parse
    required property string iconPath // the logo, an SVG path in a 24×24 box (PathIcon)
    property string expiredHint: "" // what to do when the API says the sign-in expired (401)

    property bool signedIn: false
    property string plan: ""
    property var limits: []
    property var resets: []
    property real updated: 0    // ms since epoch of the last good answer, 0 = none yet
    property string error: ""   // why the last check failed ("" if it didn't)

    readonly property bool busy: checker.running
    readonly property var session: limits.find(l => l.session) ?? null
    readonly property var weekly: limits.find(l => l.weekly) ?? null

    function refresh() {
        if (!checker.running)
            checker.running = true;
    }

    property Process checker: Process {
        command: ["sh", "-c", root.script]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n");
                root.signedIn = lines[0] !== "signed-out";
                if (!root.signedIn)
                    return;
                const status = lines[lines.length - 1];
                try {
                    const data = JSON.parse(lines.slice(1, -1).join("\n"));
                    if (status !== "200")
                        throw new Error(status === "401" && root.expiredHint ? root.expiredHint
                            : status === "429" ? "Too many checks, try again in a few minutes"
                            : data.error?.message ?? data.detail ?? "HTTP " + status);
                    const out = root.parse(data, lines[0]);
                    root.plan = out.plan;
                    root.limits = out.limits;
                    root.resets = out.resets;
                    root.updated = Date.now();
                    root.error = "";
                } catch (e) {
                    root.error = status === "000" ? "No connection" : String(e.message ?? e);
                }
            }
        }
    }
}
