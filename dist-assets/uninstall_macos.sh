#!/usr/bin/env bash

set -ue

read -p "Are you sure you want to stop and uninstall Mullvad VPN? (y/n) "
if [[ "$REPLY" =~ [Yy]$ ]]; then
    echo "Uninstalling Mullvad VPN ..."
else
    echo "Aborting uninstall"
    exit 0
fi

echo "Stopping GUI process ..."
sudo pkill -x "Mullvad VPN" || echo "No GUI process found"

mullvad account clear-history || echo "Failed to remove leftover WireGuard keys"

echo "Stopping and unloading mullvad-daemon system daemon ..."
DAEMON_PLIST_PATH="/Library/LaunchDaemons/net.mullvad.daemon.plist"
sudo launchctl unload -w "$DAEMON_PLIST_PATH"
sudo rm -f "$DAEMON_PLIST_PATH"

echo "Removing zsh shell completion symlink ..."
sudo rm -f /usr/local/share/zsh/site-functions/_mullvad

FISH_COMPLETIONS_PATH="/usr/local/share/fish/vendor_completions.d/mullvad.fish"
if [ -h "$FISH_COMPLETIONS_PATH" ]; then
    echo "Removing fish shell completion symlink ..."
    sudo rm -f "$FISH_COMPLETIONS_PATH"
fi

echo "Removing CLI symlinks from /usr/local/bin/ ..."
sudo rm -f /usr/local/bin/mullvad /usr/local/bin/mullvad-problem-report

echo "Removing app from /Applications ..."
sudo rm -rf /Applications/Mullvad\ VPN.app
sudo pkgutil --forget net.mullvad.vpn || true

read -p "Do you want to delete the log and cache files the app has created? (y/n) "
if [[ "$REPLY" =~ [Yy]$ ]]; then
    sudo rm -rf /var/log/mullvad-vpn /var/root/Library/Caches/mullvad-vpn
    for user in /Users/*; do
        user_log_dir="$user/Library/Logs/Mullvad VPN"
        if [[ -d "$user_log_dir" ]]; then
            echo "Deleting GUI logs at $user_log_dir"
            sudo rm -rf "$user_log_dir"
        fi
    done
fi

read -p "Do you want to delete the Mullvad VPN settings? (y/n) "
if [[ "$REPLY" =~ [Yy]$ ]]; then
    sudo rm -rf /etc/mullvad-vpn
    for user in /Users/*; do
        user_settings_dir="$user/Library/Application Support/Mullvad VPN"
        if [[ -d "$user_settings_dir" ]]; then
            echo "Deleting GUI settings at $user_settings_dir"
            sudo rm -rf "$user_settings_dir"
        fi
    done
fi
