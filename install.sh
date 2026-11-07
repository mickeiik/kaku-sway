#!/bin/bash
# Installs kaku-sway on Fedora Sway: packages, then the config files (existing ones
# are moved to ~/.config/kaku-backup-<date> first), then the system parts (login
# theme, fingerprint + lockout rules, GTK look). Asks for sudo. Log out and back in after.
# Speech to text (voxtype) is optional: asked at the start, or --dictation / --no-dictation.
set -euo pipefail
here=$(dirname "$(readlink -f "$0")")
backup=~/.config/kaku-backup-$(date +%Y%m%d-%H%M%S)

step() { echo -e "\n\033[1;34m== $*\033[0m"; }

# Speech to text: hold Super+D to dictate. Optional, as it's a ~2.6 GB download and
# keeps ~2 GB of memory while running. Already installed: kept.
case "${1:-}" in
    --dictation) dictation=yes ;;
    --no-dictation) dictation=no ;;
    *)
        if rpm -q voxtype >/dev/null 2>&1; then
            dictation=yes
        elif [ -t 0 ]; then
            read -rp "Install speech to text (Super+D, offline; ~2.6 GB download)? [y/N] " answer
            [[ $answer == [yY]* ]] && dictation=yes || dictation=no
        else
            dictation=no
        fi
        ;;
esac

# Copies src to dest, moving an existing dest into the backup folder first
place() {
    local src=$1 dest=$2
    if [ -e "$dest" ]; then
        mkdir -p "$backup/$(dirname "${dest#$HOME/}")"
        mv "$dest" "$backup/${dest#$HOME/}"
    fi
    mkdir -p "$(dirname "$dest")"
    cp -r "$src" "$dest"
}

step "Fedora packages"
sudo dnf install -y $(sed 's/#.*//' "$here/packages.txt" | grep -v '^\s*$')
# Replaced by the Quickshell launcher and notifications
sudo dnf remove -y rofi dunst || true
pipx install autotiling || pipx upgrade autotiling

if [ "$dictation" = yes ]; then
    step "Speech to text (voxtype, not in Fedora's repos: newest 1.x RPM from GitHub)"
    # Later updates: the launcher's Update > Update system (the bar counts them too)
    "$here/bin/launcher-pkg" voxtype-update
fi

step "Config files (old ones go to $backup)"
for d in sway quickshell sddm-theme gtk-3.0 gtk-4.0 foot micro swappy voxtype; do
    place "$here/config/$d" ~/.config/"$d"
done
for f in "$here"/bin/*; do
    place "$f" ~/.local/bin/"$(basename "$f")"
done
for f in "$here"/wallpapers/*; do
    place "$f" ~/Pictures/Wallpapers/"$(basename "$f")"
done
mkdir -p ~/Pictures/Screenshots ~/Videos/Recordings
# Where Flatpak puts launcher entries: it must exist when the shell starts, or the
# first Flathub app only shows up in the launcher after a restart
mkdir -p ~/.local/share/flatpak/exports/share/applications

if [ "$dictation" = yes ]; then
    step "Speech to text: Parakeet model (~2.6 GB, once) and the voxtype service"
    ~/.local/bin/voxtype-onnx setup --download --model parakeet-tdt-0.6b-v3
    place "$here/config/systemd/user/voxtype.service.d" ~/.config/systemd/user/voxtype.service.d
    systemctl --user daemon-reload
    systemctl --user enable voxtype
    systemctl --user restart voxtype || true # starts at the next login otherwise
fi

step "Login screen theme"
sudo cp -r ~/.config/sddm-theme/tokyo-night /usr/share/sddm/themes/
sudo mkdir -p /etc/sddm.conf.d
printf '[Theme]\nCurrent=tokyo-night\n' | sudo tee /etc/sddm.conf.d/10-theme.conf >/dev/null

step "Login rules: fingerprint, and lockout after 3 wrong passwords (faillock)"
sudo authselect enable-feature with-fingerprint
sudo authselect enable-feature with-faillock

step "Firefox defaults (scroll over the tabs to switch them)"
sudo install -Dm644 "$here/config/firefox/kaku-prefs.js" /usr/lib64/firefox/browser/defaults/preferences/kaku-prefs.js

step "DNS over HTTPS for the whole system (Mullvad: dns.mullvad.net)"
# systemd-resolved can't speak HTTPS, so it forwards to dnscrypt-proxy, which does
sudo install -Dm644 "$here/config/dns/dnscrypt-proxy.toml" /etc/dnscrypt-proxy/dnscrypt-proxy.toml
sudo install -Dm644 "$here/config/dns/forwarding-rules.txt" /etc/dnscrypt-proxy/forwarding-rules.txt
sudo install -Dm644 "$here/config/dns/kaku-dns.conf" /etc/systemd/resolved.conf.d/kaku-dns.conf
sudo install -Dm644 "$here/config/dns/nm-kaku-dns.conf" /etc/NetworkManager/conf.d/kaku-dns.conf
sudo systemctl enable --now dnscrypt-proxy
sudo systemctl restart dnscrypt-proxy systemd-resolved
sudo systemctl reload NetworkManager
# The DNS servers NetworkManager already handed over stay until the next reconnect
for link in $(resolvectl status | sed -n 's/^Link [0-9]* (\(.*\))$/\1/p'); do
    [ "$link" = tailscale0 ] || sudo resolvectl revert "$link"
done
# Tailscale would otherwise take over every lookup (its tailnet DNS settings);
# tailnet names (*.ts.net) still reach it through dnscrypt-proxy
if command -v tailscale >/dev/null; then
    sudo tailscale set --accept-dns=false || true
    # Short tailnet names (ssh pve) need the tailnet's suffix as a search domain,
    # which Tailscale only set while it handled DNS
    suffix=$(tailscale status --json 2>/dev/null | jq -r '.MagicDNSSuffix // empty' || true)
    if [ -n "$suffix" ]; then
        printf '# kaku-sway: short tailnet names (pve -> pve.%s)\n[Resolve]\nDomains=%s\n' "$suffix" "$suffix" |
            sudo tee /etc/systemd/resolved.conf.d/kaku-tailnet.conf >/dev/null
        sudo systemctl restart systemd-resolved
    fi
fi

step "Keyring (oo7: keeps apps' saved sign-ins, unlocked by your login password)"
# SDDM's login already hands the password to oo7 (pam_oo7); gnome-keyring would
# take its place on D-Bus and ask for the password again, so it goes
sudo dnf remove -y gnome-keyring || true
systemctl --user enable oo7-daemon.service

step "GTK look"
gsettings set org.gnome.desktop.interface gtk-theme 'adw-gtk3-dark'
gsettings set org.gnome.desktop.interface icon-theme 'Papirus-Dark'
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'

step "Done"
[ -d "$backup" ] && echo "Your previous files: $backup"
echo "Log out and back in to start kaku-sway."
