# Set Up pam-gnupg on Manjaro KDE

This setup unlocks selected GPG keys with the password entered at the SDDM login screen. It also runs a user service that clears the GPG agent cache when KDE locks the screen and restores access to the keys when the account password is entered to unlock the screen.

## Security model

- The selected GPG keys must use the same passphrase as the SDDM login password.
- `pam-gnupg` gives the login password to `gpg-agent`; it does not remove the key passphrases.
- Any process running as the same Unix user and able to access the agent socket may request private-key operations while a passphrase is cached.
- The KDE watcher reacts when the lock becomes active. KScreenLocker does not provide a supported blocking pre-lock hook.
- The PAM entries are optional, so a GPG failure does not block login.

## 1. Install pam-gnupg

Install the `pam-gnupg` PAM module. On Manjaro, it may be available through the AUR:

```bash
paru -S pam-gnupg
```

Upstream source and installation documentation:

<https://github.com/cruegge/pam-gnupg>

Verify that the PAM module was installed:

```bash
ls /usr/lib/security/pam_gnupg.so
```

Do not continue with the PAM configuration if this file is missing.

## 2. Select the GPG keys

List secret keys and their keygrips:

```bash
gpg -K --with-keygrip
```

Create `~/.config/pam-gnupg` and put one keygrip on each line. For normal GPG use, select the keygrip of the encryption subkey marked `[E]`, not the key fingerprint. The current setup uses:

```text
3AD59F8AF5C055F4136D6558DDC93428752CCB35
400D42C4EA756E0D7C588238179544883EC4ADBE
2D9D2A6748BBF5D548BCE4203B95F3633F442614
```

Use the keygrips belonging to the new installation instead if the keys change. Keygrips are 40 hexadecimal characters long.

The passphrase of every listed key must match the SDDM login password for automatic unlocking to succeed.

## 3. Configure gpg-agent

Add the following to `~/.gnupg/gpg-agent.conf`:

```ini
allow-preset-passphrase
enable-ssh-support
default-cache-ttl 7200
max-cache-ttl 86400
default-cache-ttl-ssh 7200
max-cache-ttl-ssh 86400
```

`allow-preset-passphrase` is required by `pam-gnupg`. `enable-ssh-support` and the SSH TTL settings are only needed when using `gpg-agent` as the SSH agent.

For higher-value signing keys, optionally add:

```ini
ignore-cache-for-signing
```

This makes `gpg-agent` request the passphrase for every signing operation, even when the passphrase is cached. Cached credentials can still be used for other operations such as decryption, so this option deliberately prevents the automatic login unlock from making signatures passwordless.

Apply the configuration:

```bash
gpgconf --reload gpg-agent
```

## 4. Integrate pam-gnupg with SDDM

Back up the existing SDDM PAM configuration:

```bash
sudo cp /etc/pam.d/sddm /etc/pam.d/sddm.backup
```

Edit `/etc/pam.d/sddm` as root:

```bash
sudo helix /etc/pam.d/sddm
```

Add the `auth` and `session` entries so the file contains:

```pam
#%PAM-1.0

auth     include     system-login
auth     optional    pam_kwallet5.so
auth     optional    pam_gnupg.so store-only
account  include     system-login
password include     system-login
session  include     system-login
session  optional    pam_kwallet5.so auto_start
session  optional    pam_gnupg.so
```

The authentication hook stores the password temporarily. The session hook uses it to preset the selected keys in `gpg-agent`.

Keep an existing root shell open while testing PAM changes. A malformed PAM configuration can prevent graphical login.

## 5. Clear the cache when KDE locks

Create the script directory:

```bash
mkdir -p ~/.local/bin
```

Create `~/.local/bin/clear-gpg-on-lock`:

```bash
#!/bin/bash

gdbus monitor \
    --session \
    --dest org.freedesktop.ScreenSaver \
    --object-path /ScreenSaver |
while IFS= read -r event; do
    if [[ "$event" == *"ActiveChanged (true"* ]]; then
        printf 'KDE locked; clearing GPG agent cache\n'
        if gpg-connect-agent --no-autostart reloadagent /bye; then
            printf 'GPG agent cache cleared\n'
        else
            printf 'Failed to clear GPG agent cache\n' >&2
        fi
    fi
done
```

`--no-autostart` clears an existing agent without starting a new one solely for the lock event. Reloading clears cached passphrases but leaves the running agent available for `pam-gnupg` when the screen is unlocked.

Make it executable:

```bash
chmod +x ~/.local/bin/clear-gpg-on-lock
```

Create `~/.config/systemd/user/clear-gpg-on-lock.service`:

```ini
[Unit]
Description=Clear GPG cache when KDE locks

[Service]
Type=simple
ExecStart=%h/.local/bin/clear-gpg-on-lock
Restart=always
RestartSec=2

[Install]
WantedBy=default.target
```

Load, enable, and start the service:

```bash
systemctl --user daemon-reload
systemctl --user enable --now clear-gpg-on-lock.service
```

## 6. Unlock keys after screen unlock

Recent `kscreenlocker` packages install their vendor PAM configuration at `/usr/lib/pam.d/kde`. PAM checks `/etc/pam.d` first, so create an administrator override there instead of editing the package-managed file.

Check whether the override already exists:

```bash
ls -l /etc/pam.d/kde
```

If it is missing, copy the current vendor configuration:

```bash
sudo cp /usr/lib/pam.d/kde /etc/pam.d/kde
```

Edit the override:

```bash
sudo helix /etc/pam.d/kde
```

Add `pam_gnupg.so` directly after the existing `auth include` line. The result should contain:

```pam
#%PAM-1.0

auth       include     system-local-login
auth       optional    pam_gnupg.so

account    include     system-local-login
password   include     system-local-login
session    include     system-local-login
```

For a screen locker, use `auth optional pam_gnupg.so` without `store-only` and without another `session` entry. After KDE verifies the screen-unlock password, `pam-gnupg` sends that password directly to the already-running `gpg-agent`.

This only unlocks keys whose passphrase matches the account password. Fingerprint authentication generally does not restore the GPG cache because it does not provide the account password to `pam-gnupg`. Smart-card authentication has the same limitation unless it also makes the account password available. Screen-unlock integration also depends on KScreenLocker calling `pam_setcred()` after successful authentication, as required by `pam-gnupg`.

Keep `/etc/pam.d/kde` synchronized with relevant vendor changes after `kscreenlocker` updates. Compare it periodically with:

```bash
diff -u /usr/lib/pam.d/kde /etc/pam.d/kde
```

The comparison will always show the intentionally added `auth optional pam_gnupg.so` line. Preserve that line while incorporating any unrelated changes from the updated vendor file. Do not blindly replace the override with the vendor file, because doing so would remove the screen-unlock integration.

## 7. Test the setup

Fully log out of KDE and log in through SDDM. Screen unlock alone does not invoke the SDDM login PAM stack.

Verify that the service is running:

```bash
systemctl --user status clear-gpg-on-lock.service
```

Encrypt a test message to a key whose encryption-subkey keygrip is listed in `~/.config/pam-gnupg`. Set `KEY_FINGERPRINT` to that key's fingerprint:

```bash
KEY_FINGERPRINT="replace-with-the-key-fingerprint"
printf 'pam-gnupg test\n' | \
    gpg --encrypt --recipient "$KEY_FINGERPRINT" \
        --output /tmp/pam-gnupg-test.gpg
```

Decrypt the message:

```bash
gpg --decrypt /tmp/pam-gnupg-test.gpg >/dev/null
```

Immediately after SDDM login, decryption should use the passphrase preset by `pam-gnupg` without prompting.

Lock the screen:

```bash
loginctl lock-session
```

Unlock the screen by entering the account password, then repeat the decryption command. With the KDE PAM integration above, it should again work without a GPG passphrase prompt because `pam-gnupg` repopulated the agent cache during screen unlock. This decryption test is unaffected by `ignore-cache-for-signing`.

Inspect watcher logs if this does not happen:

```bash
journalctl --user -u clear-gpg-on-lock.service
```

Also verify that KDE emits the expected signal:

```bash
gdbus monitor --session \
    --dest org.freedesktop.ScreenSaver \
    --object-path /ScreenSaver
```

Lock the screen from another terminal or with the normal KDE shortcut and look for `ActiveChanged (true,...)`.

## 8. Recovery

If SDDM login stops working, switch to a text console, log in, and restore the PAM backup:

```bash
sudo cp /etc/pam.d/sddm.backup /etc/pam.d/sddm
```

If KDE screen unlock stops working after creating the override, remove it to fall back to the packaged configuration:

```bash
sudo rm /etc/pam.d/kde
```

This restores `/usr/lib/pam.d/kde` for newly started PAM sessions. An already-running lock screen may still retain its existing PAM state, so reboot after removing the override if screen unlocking remains broken.

Disable the lock watcher if necessary:

```bash
systemctl --user disable --now clear-gpg-on-lock.service
```
