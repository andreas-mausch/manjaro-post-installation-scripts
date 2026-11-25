# BOSGAME M5: NixOS, KDE, Steam und Gufo

Interaktiver Installer mit Disko für den M5 mit Ryzen AI Max+ 395 und 128 GB RAM.
Das gesamte gewählte NVMe-, SATA- oder VirtIO-Laufwerk wird nach ausdrücklicher Bestätigung
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
Installer, die gesperrte Flake sowie alle sechs Modell-Dateien. Diese werden
beim ISO-Bau heruntergeladen und anhand der gepinnten SHA-256-Prüfsummen geprüft.
Der Installer kopiert sie vom Stick auf die verschlüsselte SSD, ohne Modelldownload.
Die Modelle allein umfassen rund 115 GB; ein 256-GB-Stick ist ein sinnvoller
Ausgangspunkt. Vor dem Schreiben die tatsächliche ISO-Größe prüfen.
Bauen benötigt deutlich mehr
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
3. Der Shell-Installer auf der ersten Konsole fragt SSD, Benutzername und
   Benutzerpasswort ab. Python ist nicht nötig; verwendet werden die üblichen
   NixOS-Werkzeuge und Disko. Das Benutzerpasswort wird verdeckt wiederholt.
4. Den Löschtext mit dem exakten SSD-Gerätenamen bestätigen. Davor werden keine
   Datenträger verändert. Nur ungemountete NVMe-, SATA- und VirtIO-Laufwerke ab
   256 GiB sind wählbar. USB-, entfernbare und schreibgeschützte Laufwerke sind
   ausgeschlossen; andere Datenträger werden nicht automatisch verwendet.
5. Disko partitioniert, formatiert und mountet anhand von `modules/disk-layout.nix`.
   Es fragt nach der LUKS-Passphrase samt Wiederholung. Warten, bis Systeminstallation **und
   Modellkopie vom Stick** abgeschlossen sind.
6. `reboot`, Stick entfernen. Bei jedem Boot LUKS-Passphrase eingeben, anschließend
   mit dem gewählten Benutzerpasswort in KDE anmelden.

Layout: 1 GiB unverschlüsselte EFI-Systempartition und LUKS2 mit ext4 für den
gesamten Rest. Kein unverschlüsselter Swap, kein Hibernation-Setup. Die EFI-
Partition mit Kernel und Initrd bleibt unverschlüsselt; das schützt nicht vor
Manipulation durch jemanden mit physischem Zugriff. Es gibt keinen gespeicherten
LUKS-Schlüssel und keine automatische TPM-Entsperrung.

Die LUKS-Passphrase wird von Disko verdeckt abgefragt; der Installer legt
keine Schlüsseldatei an. Nur der Benutzerpassworthash wird auf der verschlüsselten SSD
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

Der ISO-Bau lädt die Dateien, deren Revisionen, Größen und SHA-256-Prüfsummen
in diesem gepinnten Release festgelegt sind, einschließlich MTP und Bildprojektor.
Es gibt keinen automatischen Modell-Update-Timer. Die installierten Dateien
liegen außerhalb des Nix Stores in `/var/lib/gufo/models`.
`models.lock.json` dokumentiert diese sechs Dateien zusätzlich im Repository;
die Flake prüft, dass es exakt dem Manifest des gepinnten Gufo-Releases entspricht.
Zusammen sind dies rund 115 GB (107 GiB) Download beim ISO-Bau, ohne Spiele und
Systempakete. Internet wird am M5 weiterhin für die NixOS-Systeminstallation
benötigt; die ISO ist kein vollständig offlinefähiger Systeminstaller.
Desktop und KI teilen sich GPU und RAM: GTT auf 112 GiB begrenzt; dieser Wert
reserviert nicht sofort Speicher und ist kein Schutz gegen jede Speicherauslastung.

## Fehler und erneute Modellkopie

Bei Fehlern oder Abbruch erscheint eine Shell. `install-m5` startet erneut,
**partitioniert aber auch erneut**, wenn die Löschung bestätigt wird.
Nach erfolgreicher Systeminstallation, aber fehlgeschlagener Modellkopie,
die bestehende LUKS-Installation vom Stick nach `/mnt` mounten und
`install-m5 --models-only` ausführen. Diese Option formatiert nichts; sie
erwartet bereits `/mnt/etc/nixos/flake.lock` und kopiert die Modelle erneut.
Alternativ können die gleichen Modelle vom installierten System aus
heruntergeladen werden:

```bash
sudo -u gufo env HOME=/var/lib/gufo GUFO_MODELS_DIR=/var/lib/gufo/models \
  gufo model install flash-next-q4
```

Gufo setzt Downloads fort.

## System später ändern

Die vollständige Konfiguration wird nach `/etc/nixos` kopiert, ergänzt um
`installation.json` (Benutzername und gewählte SSD) und `hardware-configuration.nix`
(Hardwaremodule). Disko liefert Dateisysteme und LUKS-Konfiguration anhand des
deklarativen Layouts; die generierte Hardwarekonfiguration enthält keine Dateisysteme.
Diese beiden Dateien sind keine Geheimnisse, enthalten aber gerätespezifische Daten.
Die SSD-Auswahl wird für spätere Disko-Aufrufe gespeichert; vor jedem erneuten
Partitionieren muss der Gerätename überprüft werden. Ein normales `nixos-rebuild`
partitioniert oder formatiert nichts.

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

Auf diesem Vorbereitungsrechner ist der normale daemonbasierte Nix Store
unter `/nix/store` eingerichtet. `nix-command` und `flakes` sind bereits aktiviert:

```bash
nix build .#iso --accept-flake-config
```

Der frühere isolierte tmpfs-Store wird nicht mehr verwendet. Das Projekt liegt
dauerhaft unter `~/Desktop/2026-11-25 nixOS Spike`.
Der Nix-Daemon muss den Gufo-Cache samt Signaturschlüssel zulassen; andernfalls
ignoriert er die Flake-Einstellungen und Gufo kann einen großen lokalen Build erfordern.
