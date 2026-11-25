# BOSGAME M5: NixOS, KDE, Steam und Gufo

Interaktiver Online-Installer für den M5 mit Ryzen AI Max+ 395 und 128 GB RAM.
Die gesamte gewählte interne NVMe-SSD wird nach ausdrücklicher Bestätigung
neu partitioniert. **Alle vorhandenen Daten einschließlich Windows werden gelöscht.**
Dieser Installer ist noch nicht auf dem M5 oder in einer VM erprobt.

## Voraussetzungen und reproduzierbarer Bau

Ein Linux-x86_64-Rechner mit funktionierender Nix-Installation und Nix Store.
Die Flake aktiviert `nix-command` und `flakes` nicht für das aufrufende Nix;
falls nötig die folgenden Befehle mit
`nix --extra-experimental-features 'nix-command flakes' …` ausführen.

```bash
nix flake lock
nix fmt
nix flake check --no-build
nix build .#checks.x86_64-linux.installer-tests
nix build .#iso
```

`flake.lock` zusammen mit allen Konfigurationsdateien versionieren und archivieren.
Der erste Lock-Vorgang legt die Versionen fest; für weitere Bauten **nicht**
`nix flake update` ausführen. Gufo ist zusätzlich auf Release v0.36.0 festgelegt.
Die separaten Gufo-Toolchain-Inputs werden bewusst nicht auf das Host-Nixpkgs
umgebogen, damit der offizielle Build und sein Cache nutzbar bleiben.
Der Gufo-Cachix-Cache wird zusätzlich zum NixOS-Cache verwendet; damit vertraut
man auch dessen signierten Builds. Ohne akzeptierten Cache können große lokale
ROCm-/Gufo-Builds erforderlich werden.

Das Image liegt unter `result/iso/bosgame-m5-installer.iso` und enthält den
Installer, die gesperrte Flake sowie Gufo für den Modelldownload. Die großen
Modell-Dateien werden erst am M5 auf die verschlüsselte SSD heruntergeladen.
Damit braucht der Stick nicht 256 GB: Seine erforderliche Größe ergibt sich
aus der fertigen ISO. 32 GB sind ein vernünftiger Ausgangspunkt, aber vor dem
Schreiben die tatsächliche ISO-Größe prüfen. Bauen benötigt deutlich mehr
freien Platz im Nix Store; das Repository allein ist klein.

## Stick vorbereiten

Die ISO etwa mit KDE ISO Image Writer auf den **richtigen USB-Stick** schreiben.
Dabei wird auch der Stick gelöscht. Hier gibt es absichtlich keinen automatisch
ausgeführten Schreibbefehl für einen geratenen Gerätenamen.

## Installation

1. Im BIOS Secure Boot deaktivieren und den UMA-Framebuffer möglichst klein
   einstellen (Gufo empfiehlt 512 MiB, sofern das BIOS dies anbietet).
2. Stick im **UEFI-Modus** booten. Ethernet anschließen; alternativ fragt der
   Installer nach Einrichtung per `nmtui`. Das Image startet lokal als root und
   bietet keinen SSH-Zugang.
3. Der Installer auf der ersten Konsole fragt SSD, Benutzername, Benutzerpasswort
   und LUKS-Passphrase ab. Passwörter werden verdeckt eingegeben und wiederholt.
4. Den Löschtext mit dem exakten SSD-Gerätenamen bestätigen. Davor werden keine
   Datenträger verändert. Nur ungemountete interne NVMe-SSDs ab 256 GiB sind
   wählbar; andere Datenträger werden nicht automatisch verwendet.
5. Warten, bis Systeminstallation **und Modelldownload** abgeschlossen sind.
6. `reboot`, Stick entfernen. Bei jedem Boot LUKS-Passphrase eingeben, anschließend
   mit dem gewählten Benutzerpasswort in KDE anmelden.

Layout: 1 GiB unverschlüsselte EFI-Systempartition und LUKS2 mit ext4 für den
gesamten Rest. Kein unverschlüsselter Swap, kein Hibernation-Setup. Die EFI-
Partition mit Kernel und Initrd bleibt unverschlüsselt; das schützt nicht vor
Manipulation durch jemanden mit physischem Zugriff. Es gibt keinen gespeicherten
LUKS-Schlüssel und keine automatische TPM-Entsperrung.

Die LUKS-Passphrase wird nur kurz in einer rootgeschützten Datei unter `/run`
(RAM) verwendet. Nur der Benutzerpassworthash wird auf der verschlüsselten SSD
unter `/var/lib/nixos-secrets/user-password.hash` gespeichert, nie im Nix Store.
Root-Anmeldung ist gesperrt; der Benutzer kann mit Passwort `sudo` verwenden.

## Gufo nutzen

```bash
sudo systemctl start gufo
sudo journalctl -u gufo -f
# Vor anspruchsvollen Spielen GPU und Modellspeicher freigeben:
sudo systemctl stop gufo
```

OpenAI-kompatible API: `http://127.0.0.1:8080/v1`, Modellname `flash-next`.
Der Dienst wird **nicht** beim Boot gestartet und ist nicht im LAN erreichbar.
Konfiguration: eine Sitzung, 32.768 Tokens Kontext, MTP, Bildprojektor automatisch
neben dem Modell. `gufo diagnose` auf dem echten M5 ausführen.

Gufo lädt mit `gufo model install flash-next-q4` die Dateien, deren Revisionen,
Größen und SHA-256-Prüfsummen in diesem gepinnten Release festgelegt sind,
einschließlich MTP und Bildprojektor. Es gibt keinen automatischen Modell-Update-
Timer. Die Dateien liegen außerhalb des Nix Stores in `/var/lib/gufo/models`.
`models.lock.json` dokumentiert diese sechs Dateien zusätzlich im Repository;
die Flake prüft, dass es exakt dem Manifest des gepinnten Gufo-Releases entspricht.
Zusammen sind dies rund 115 GB (107 GiB) Download, ohne Spiele und Systempakete.
Downloads brauchen viel Speicherplatz, Bandbreite und je nach Verbindung Zeit.
Desktop und KI teilen sich GPU und RAM: GTT auf 112 GiB begrenzt; dieser Wert
reserviert nicht sofort Speicher und ist kein Schutz gegen jede Speicherauslastung.

## Fehler und erneute Downloads

Bei Fehlern oder Abbruch erscheint eine Shell. `install-m5` startet erneut,
**partitioniert aber auch erneut**, wenn die Löschung bestätigt wird.
Nach erfolgreicher Systeminstallation, aber fehlgeschlagenem Modelldownload,
kann man stattdessen vom installierten System aus fortsetzen:

```bash
sudo -u gufo env HOME=/var/lib/gufo GUFO_MODELS_DIR=/var/lib/gufo/models \
  gufo model install flash-next-q4
```

Gufo setzt Downloads fort. Alternativ die bestehende LUKS-Installation vom Stick
nach `/mnt` mounten und `install-m5 --models-only` ausführen. Diese Option formatiert
nichts; sie erwartet bereits `/mnt/etc/nixos/flake.lock`.

## System später ändern

Die vollständige Konfiguration wird nach `/etc/nixos` kopiert, ergänzt um
`installation.json` (Benutzername) und `hardware-configuration.nix` (UUIDs).
Diese beiden Dateien sind keine Geheimnisse, enthalten aber gerätespezifische Daten.

```bash
sudo nixos-rebuild switch --flake path:/etc/nixos#m5
```

Bei einem späteren Git-Repository dort müssen auch die generierten Dateien
explizit aufgenommen werden oder weiterhin `path:/etc/nixos` verwendet werden.
Der Passworthash bleibt außerhalb des Repositories. Für Passwortänderungen
muss die Hashdatei rootgeschützt ersetzt werden; `users.mutableUsers = false`
macht einen bloßen `passwd`-Aufruf nicht zu einer dauerhaften Konfigurationsänderung.

Reproduzierbar sind Paketversionen, Konfiguration und Modell-Auswahl, nicht
bitidentische SSD-Inhalte. UUIDs, LUKS-Salts und Passwort-Salts entstehen pro
Installation neu. Steam aktualisiert seinen Client und die Spiele unabhängig
von Nix. Langfristige Wiederholbarkeit setzt weiterhin verfügbare Downloads
oder ein eigenes Archiv der Pakete und Modelle voraus.

## Aktuelle Bauumgebung

Auf diesem Vorbereitungsrechner ist bislang nur die Nix-Binary installiert,
kein systemweiter Store. Die bisherigen Prüfungen verwenden deshalb den
isolierten Store `/tmp/opencode/m5-nix-root`:

```bash
nix --extra-experimental-features 'nix-command flakes' \
  --store 'local?root=/tmp/opencode/m5-nix-root' \
  build .#iso --no-link --accept-flake-config
```

Dieser Store liegt hier auf tmpfs und geht beim Neustart verloren. Das Projekt
liegt dauerhaft unter `~/Desktop/2026-11-25 nixOS Spike`.
Für spätere größere Bauten ist ein normal eingerichteter Nix Store auf einer SSD
sinnvoller. Die Konfiguration selbst benötigt den isolierten Store nicht.
