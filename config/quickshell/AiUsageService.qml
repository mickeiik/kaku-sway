pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// How much of each AI subscription's usage limits is used, as on their own usage
// pages. Each one is read with its command-line tool's sign-in, and only shows
// when that tool is signed in. Access tokens go to curl on stdin, never on a
// command line. The panel's settings hide subscriptions: a hidden one is not
// checked at all (no request for its usage), until it's shown again.
Singleton {
    id: root

    readonly property string configFile: Quickshell.env("HOME") + "/.config/kaku/ai-usage.json"
    readonly property list<AiUsageProvider> providers: [claude, chatgpt, opencodeGo]
    property var hidden: [] // provider ids hidden in the settings
    property bool configLoaded: false
    readonly property var active: providers.filter(p => p.enabled)
    readonly property var shown: active.filter(p => p.signedIn)
    readonly property bool loaded: shown.some(p => p.updated > 0)
    readonly property bool busy: active.some(p => p.busy)
    readonly property real updated: shown.reduce((m, p) => Math.max(m, p.updated), 0)
    property real lastCheck: 0

    // How far along a limit is, for the bar: no color, then yellow, orange and red near the end
    function progressColor(percent) {
        return percent >= 90 ? Theme.red : percent >= 75 ? Theme.orange : percent >= 50 ? Theme.yellow : Theme.fg;
    }

    function levelColor(percent, normal) {
        return percent >= 90 ? Theme.red : percent >= 70 ? Theme.yellow : normal;
    }

    function isProviderShown(id) {
        return hidden.indexOf(id) === -1;
    }

    // A hidden provider is fully disabled: no check is ever run for it
    function syncEnabled() {
        for (const p of providers)
            p.enabled = isProviderShown(p.providerId);
    }

    function setProviderShown(id, visible) {
        if (!providers.some(p => p.providerId === id) || isProviderShown(id) === visible)
            return;
        hidden = visible ? hidden.filter(k => k !== id) : hidden.concat([id]);
        syncEnabled();
        saveConfig();
        if (visible)
            providers.find(p => p.providerId === id).refresh();
    }

    function applyConfig(text) {
        let next = [];
        try {
            const c = JSON.parse(text || "{}");
            const ids = providers.map(p => p.providerId);
            next = Array.isArray(c.hidden)
                ? c.hidden.filter(k => typeof k === "string" && ids.indexOf(k) !== -1)
                : [];
        } catch (e) {}
        const changed = next.length !== hidden.length || next.some(k => hidden.indexOf(k) === -1);
        hidden = next;
        syncEnabled();
        const first = !configLoaded;
        configLoaded = true;
        if (first || changed)
            refresh(true);
    }

    function saveConfig() {
        Quickshell.execDetached(["sh", "-c", 'mkdir -p "$(dirname "$1")" && printf "%s\\n" "$2" > "$1.tmp" && mv "$1.tmp" "$1"',
            "ai-usage-config", configFile, JSON.stringify({ hidden: hidden }, null, 2)]);
        reloadConfig.restart();
    }

    // At most every minute unless forced (the panel's reload button)
    function refresh(force) {
        if (!configLoaded)
            return;
        if (!force && Date.now() - lastCheck < 60 * 1000)
            return;
        lastCheck = Date.now();
        for (const p of active)
            p.refresh();
    }

    function capitalize(s) {
        return s.charAt(0).toUpperCase() + s.slice(1);
    }

    // "5 hours", "Week"… for a limit's window length
    function windowName(seconds) {
        const h = Math.round(seconds / 3600);
        return h >= 24 * 7 ? "Week" : h >= 24 ? Math.round(h / 24) + " days" : h + " hours";
    }

    // Claude (Claude Code's sign-in, ~/.claude/.credentials.json). Its access token
    // lasts 8 hours and only Claude Code renews it, so when it has run out
    // "claude auth status" is run first: that renews it without using any quota.
    AiUsageProvider {
        id: claude
        name: "Claude"
        providerId: "claude"
        expiredHint: "Signed out: run \"claude\" and /login to sign in again"
        // Simple Icons "claude" (CC0)
        iconPath: "m4.7144 15.9555 4.7174-2.6471.079-.2307-.079-.1275h-.2307l-.7893-.0486-2.6956-.0729-2.3375-.0971-2.2646-.1214-.5707-.1215-.5343-.7042.0546-.3522.4797-.3218.686.0608 1.5179.1032 2.2767.1578 1.6514.0972 2.4468.255h.3886l.0546-.1579-.1336-.0971-.1032-.0972L6.973 9.8356l-2.55-1.6879-1.3356-.9714-.7225-.4918-.3643-.4614-.1578-1.0078.6557-.7225.8803.0607.2246.0607.8925.686 1.9064 1.4754 2.4893 1.8336.3643.3035.1457-.1032.0182-.0728-.164-.2733-1.3539-2.4467-1.445-2.4893-.6435-1.032-.17-.6194c-.0607-.255-.1032-.4674-.1032-.7285L6.287.1335 6.6997 0l.9957.1336.419.3642.6192 1.4147 1.0018 2.2282 1.5543 3.0296.4553.8985.2429.8318.091.255h.1579v-.1457l.1275-1.706.2368-2.0947.2307-2.6957.0789-.7589.3764-.9107.7468-.4918.5828.2793.4797.686-.0668.4433-.2853 1.8517-.5586 2.9021-.3643 1.9429h.2125l.2429-.2429.9835-1.3053 1.6514-2.0643.7286-.8196.85-.9046.5464-.4311h1.0321l.759 1.1293-.34 1.1657-1.0625 1.3478-.8804 1.1414-1.2628 1.7-.7893 1.36.0729.1093.1882-.0183 2.8535-.607 1.5421-.2794 1.8396-.3157.8318.3886.091.3946-.3278.8075-1.967.4857-2.3072.4614-3.4364.8136-.0425.0304.0486.0607 1.5482.1457.6618.0364h1.621l3.0175.2247.7892.522.4736.6376-.079.4857-1.2142.6193-1.6393-.3886-3.825-.9107-1.3113-.3279h-.1822v.1093l1.0929 1.0686 2.0035 1.8092 2.5075 2.3314.1275.5768-.3218.4554-.34-.0486-2.2039-1.6575-.85-.7468-1.9246-1.621h-.1275v.17l.4432.6496 2.3436 3.5214.1214 1.0807-.17.3521-.6071.2125-.6679-.1214-1.3721-1.9246L14.38 17.959l-1.1414-1.9428-.1397.079-.674 7.2552-.3156.3703-.7286.2793-.6071-.4614-.3218-.7468.3218-1.4753.3886-1.9246.3157-1.53.2853-1.9004.17-.6314-.0121-.0425-.1397.0182-1.4328 1.9672-2.1796 2.9446-1.7243 1.8456-.4128.164-.7164-.3704.0667-.6618.4008-.5889 2.386-3.0357 1.4389-1.882.929-1.0868-.0062-.1579h-.0546l-6.3385 4.1164-1.1293.1457-.4857-.4554.0608-.7467.2307-.2429 1.9064-1.3114Z"
        script: `
            creds="$HOME/.claude/.credentials.json"
            [ -r "$creds" ] || { echo "signed-out"; exit; }
            if [ "$(jq '.claudeAiOauth.expiresAt / 1000 < (now + 60)' "$creds")" = true ]; then
                PATH="$HOME/.local/bin:$PATH" timeout 30 claude auth status >/dev/null 2>&1
            fi
            jq -r '.claudeAiOauth | [.subscriptionType, .rateLimitTier] | join(" ")' "$creds"
            # Signed out (tokens emptied): the API answers an empty token with a
            # 429, so say it's the sign-in instead of asking it
            if [ -z "$(jq -r '.claudeAiOauth.accessToken // empty' "$creds")" ]; then
                printf '{}\\n401\\n'; exit
            fi
            jq -r '"Authorization: Bearer " + .claudeAiOauth.accessToken' "$creds" |
                curl -sS --max-time 15 -H @- -H "anthropic-beta: oauth-2025-04-20" \
                    -w '\\n%{http_code}' 'https://api.anthropic.com/api/oauth/usage?cedar_ember=1' 2>&1
        `
        // firstLine: "max default_claude_max_5x" → plan "Max 5x"
        parse: (data, firstLine) => {
            const [type, tier] = firstLine.split(" ");
            return {
                plan: (root.capitalize(type) + " " + (tier?.match(/_(\d+x)$/)?.[1] ?? "")).trim(),
                limits: (data.limits ?? []).map(l => ({
                    name: l.kind === "session" ? "Session (5 hours)"
                        : l.kind === "weekly_all" ? "Week, all models"
                        : l.kind === "weekly_scoped" ? "Week, " + (l.scope?.model?.display_name ?? l.scope?.surface ?? "other")
                        : root.capitalize(l.kind.replace(/_/g, " ")),
                    percent: Math.round(l.percent),
                    resetsAt: new Date(l.resets_at),
                    session: l.kind === "session",
                    weekly: l.kind === "weekly_all"
                })),
                // Granted limit resets ("cedar_ember", as Claude Code reads it). For now
                // the server only offers them to Claude Code itself (ineligible_reason
                // "surface"), so this stays empty unless that changes.
                resets: (data.cedar_ember?.eligible ? data.cedar_ember.grants ?? [] : [])
                    .filter(g => g.resets_left > 0 && !g.paused)
                    .reduce((all, g) => all.concat(Array(g.resets_left).fill({
                        name: g.label || "Limit reset",
                        until: g.ends_at ? new Date(g.ends_at) : null
                    })), [])
            };
        }
    }

    // ChatGPT (the Codex CLI's sign-in, ~/.codex/auth.json), the limits Codex
    // shows in /status. Only Codex renews its token, when it's used.
    AiUsageProvider {
        id: chatgpt
        name: "ChatGPT"
        providerId: "chatgpt"
        // Simple Icons "openai" (CC0)
        iconPath: "M22.2819 9.8211a5.9847 5.9847 0 0 0-.5157-4.9108 6.0462 6.0462 0 0 0-6.5098-2.9A6.0651 6.0651 0 0 0 4.9807 4.1818a5.9847 5.9847 0 0 0-3.9977 2.9 6.0462 6.0462 0 0 0 .7427 7.0966 5.98 5.98 0 0 0 .511 4.9107 6.051 6.051 0 0 0 6.5146 2.9001A5.9847 5.9847 0 0 0 13.2599 24a6.0557 6.0557 0 0 0 5.7718-4.2058 5.9894 5.9894 0 0 0 3.9977-2.9001 6.0557 6.0557 0 0 0-.7475-7.0729zm-9.022 12.6081a4.4755 4.4755 0 0 1-2.8764-1.0408l.1419-.0804 4.7783-2.7582a.7948.7948 0 0 0 .3927-.6813v-6.7369l2.02 1.1686a.071.071 0 0 1 .038.052v5.5826a4.504 4.504 0 0 1-4.4945 4.4944zm-9.6607-4.1254a4.4708 4.4708 0 0 1-.5346-3.0137l.142.0852 4.783 2.7582a.7712.7712 0 0 0 .7806 0l5.8428-3.3685v2.3324a.0804.0804 0 0 1-.0332.0615L9.74 19.9502a4.4992 4.4992 0 0 1-6.1408-1.6464zM2.3408 7.8956a4.485 4.485 0 0 1 2.3655-1.9728V11.6a.7664.7664 0 0 0 .3879.6765l5.8144 3.3543-2.0201 1.1685a.0757.0757 0 0 1-.071 0l-4.8303-2.7865A4.504 4.504 0 0 1 2.3408 7.872zm16.5963 3.8558L13.1038 8.364 15.1192 7.2a.0757.0757 0 0 1 .071 0l4.8303 2.7913a4.4944 4.4944 0 0 1-.6765 8.1042v-5.6772a.79.79 0 0 0-.407-.667zm2.0107-3.0231l-.142-.0852-4.7735-2.7818a.7759.7759 0 0 0-.7854 0L9.409 9.2297V6.8974a.0662.0662 0 0 1 .0284-.0615l4.8303-2.7866a4.4992 4.4992 0 0 1 6.6802 4.66zM8.3065 12.863l-2.02-1.1638a.0804.0804 0 0 1-.038-.0567V6.0742a4.4992 4.4992 0 0 1 7.3757-3.4537l-.142.0805L8.704 5.459a.7948.7948 0 0 0-.3927.6813zm1.0976-2.3654l2.602-1.4998 2.6069 1.4998v2.9994l-2.5974 1.4997-2.6067-1.4997Z"
        expiredHint: "Sign-in expired: open Codex to renew it"
        script: `
            auth="\${CODEX_HOME:-$HOME/.codex}/auth.json"
            [ -r "$auth" ] && [ "$(jq -r '.tokens.access_token // empty' "$auth")" ] ||
                { echo "signed-out"; exit; }
            echo ok
            headers=$(jq -r '"Authorization: Bearer " + .tokens.access_token,
                             "chatgpt-account-id: " + (.tokens.account_id // "")' "$auth")
            get() {
                printf '%s\\n' "$headers" | curl -sS --max-time 15 -H @- -w '\\n%{http_code}' \
                    "https://chatgpt.com/backend-api/wham/$1" 2>&1
            }
            out=$(get usage)
            body=$(printf '%s\\n' "$out" | sed '$d')
            # With resets available, add their list (each one's title and expiry)
            if [ "$(printf '%s' "$body" | jq '.rate_limit_reset_credits.available_count > 0' 2>/dev/null)" = true ]; then
                list=$(get rate-limit-reset-credits | sed '$d')
                body=$({ printf '%s' "$body"; printf '%s' "$list"; } |
                    jq -cs '.[0] + { reset_credits: .[1] }' 2>/dev/null || printf '%s' "$body")
            fi
            printf '%s\\n%s\\n' "$body" "$(printf '%s\\n' "$out" | tail -n 1)"
        `
        // A main limit (rate_limit), and maybe ones for code reviews and for some
        // models (additional_rate_limits), each with up to two windows (5 hours, week)
        parse: data => {
            const limits = [];
            const add = (rateLimit, prefix, main) => {
                for (const w of [rateLimit?.primary_window, rateLimit?.secondary_window]) {
                    if (!w)
                        continue;
                    const span = root.windowName(w.limit_window_seconds);
                    limits.push({
                        name: (prefix ? prefix + ", " : "") + (span === "Week" ? span : "Session (" + span + ")"),
                        percent: Math.round(w.used_percent),
                        resetsAt: new Date(w.reset_at * 1000),
                        session: main && w.limit_window_seconds === 5 * 3600,
                        weekly: main && w.limit_window_seconds === 7 * 24 * 3600
                    });
                }
            };
            add(data.rate_limit, "", true);
            add(data.code_review_rate_limit, "Code review", false);
            for (const extra of data.additional_rate_limits ?? [])
                add(extra.rate_limit, extra.limit_name, false);
            // The list if we got it, else as many undated ones as available
            const count = data.rate_limit_reset_credits?.available_count ?? 0;
            const resets = data.reset_credits?.credits
                ?.filter(c => c.status === "available")
                .map(c => ({ name: c.title || "Limit reset", until: c.expires_at ? new Date(c.expires_at) : null }))
                ?? Array(count).fill({ name: "Limit reset", until: null });
            return { plan: root.capitalize(data.plan_type ?? ""), limits: limits, resets: resets };
        }
    }

    // OpenCode Go (opencode's sign-in: the key from /connect, in its database, or in
    // auth.json for older versions), the limits on its console page. The key alone
    // is enough; it doesn't run out.
    AiUsageProvider {
        id: opencodeGo
        name: "OpenCode Go"
        providerId: "opencode-go"
        // OpenCode's logo, the frame of its square "O"
        iconPath: "M16.8 4.8H7.2v14.4h9.6ZM21.6 24H2.4V0h19.2Z"
        expiredHint: "Key not accepted: run \"opencode\" and /connect OpenCode Go again"
        script: `
            dir="\${XDG_DATA_HOME:-$HOME/.local/share}/opencode"
            key=$(python3 -I -c '
import json, sqlite3, sys
db = sqlite3.connect("file:" + sys.argv[1] + "?mode=ro", uri=True)
row = db.execute("select value from credential where integration_id = ? and active is not 0"
                 " order by active desc, time_updated desc limit 1", ("opencode-go",)).fetchone()
print(json.loads(row[0])["key"] if row else "")
' "$dir/opencode.db" 2>/dev/null)
            [ -n "$key" ] || key=$(jq -r '."opencode-go".key // empty' "$dir/auth.json" 2>/dev/null)
            [ -n "$key" ] || { echo "signed-out"; exit; }
            echo ok
            printf 'Authorization: Bearer %s\\n' "$key" |
                curl -sS --max-time 15 -H @- -w '\\n%{http_code}' 'https://opencode.ai/zen/go/v1/usage' 2>&1
        `
        // Three windows: rolling (5 hours), weekly and monthly
        parse: data => ({
            plan: "Go",
            limits: [["rolling", "Session (5 hours)"], ["weekly", "Week"], ["monthly", "Month"]]
                .filter(([key]) => data.usage?.[key])
                .map(([key, name]) => ({
                    name: name,
                    percent: Math.round(data.usage[key].percent),
                    resetsAt: new Date(data.usage[key].resetsAt),
                    session: key === "rolling",
                    weekly: key === "weekly"
                })),
            resets: []
        })
    }

    Timer {
        interval: 5 * 60 * 1000
        running: root.configLoaded && root.active.length > 0
        repeat: true
        onTriggered: root.refresh(false)
    }

    // The hidden list: also re-read when the file changes (a dotfiles sync, an
    // edit)
    Timer {
        id: reloadConfig
        interval: 300
        onTriggered: config.reload()
    }

    FileView {
        id: config
        path: root.configFile
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.applyConfig(text())
        onLoadFailed: root.applyConfig("{}")
    }
}
