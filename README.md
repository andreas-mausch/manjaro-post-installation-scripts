# BOSGAME M5: NixOS, KDE, Steam und Gufo

Grafischer Calamares-Installer für den M5 mit Ryzen AI Max+ 395 und 128 GB RAM.
Das gesamte gewählte Laufwerk wird nach ausdrücklicher Bestätigung
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
2. Stick im **UEFI-Modus** booten. Im KDE-Live-Desktop automatisch als `nixos`
   anmelden. Ethernet anschließen oder WLAN über NetworkManager einrichten.
   Das Image bietet keinen SSH-Zugang.
3. Calamares öffnen (Autostart oder Desktop-Verknüpfung). Sprache, Zeitzone,
   Tastatur und Benutzer samt Passwort wählen. KDE, Steam und Gufo sind durch
   unsere Flake fest vorgegeben; es gibt keine Desktop-Auswahl.
4. Die **richtige SSD** auswählen, „gesamten Datenträger löschen“ wählen und
   LUKS-Verschlüsselung mit mindestens zwölf Zeichen langer Passphrase aktivieren.
   Kein Swap. Der Datenträger benötigt mindestens 256 GiB.
   Anders als der frühere Wrapper verwendet dieser Stand Calamares' Geräteauswahl,
   ohne unseren zusätzlichen USB-/Transportfilter und ohne abgetippten Löschtext.
   Modell, Größe und Zielgerät deshalb in der Zusammenfassung genau prüfen.
5. Die abschließende Installationsbestätigung akzeptieren. Vor der Partitionierung
   prüft das M5-Modul UEFI, Löschmodus, aktivierte Verschlüsselung, keinen Swap
   sowie Benutzereingaben. Calamares partitioniert, formatiert und mountet.
   Unser Job installiert anschließend `path:/…/etc/nixos#m5` mit `nixos-install`
   und kopiert die Modelle vom Medium. Warten, bis **beides** abgeschlossen ist.
6. Neustarten, Stick entfernen. Bei jedem Boot LUKS-Passphrase eingeben, anschließend
   mit dem gewählten Benutzerpasswort in KDE anmelden.

Layout: 1 GiB unverschlüsselte EFI-Systempartition und LUKS2 mit Btrfs für den
gesamten Rest. Kein unverschlüsselter Swap, kein Hibernation-Setup. Die EFI-
Partition mit Kernel und Initrd bleibt unverschlüsselt; das schützt nicht vor
Manipulation durch jemanden mit physischem Zugriff. Es gibt keinen gespeicherten
LUKS-Schlüssel und keine automatische TPM-Entsperrung.
Btrfs verwendet `compress=zstd` und `noatime`. Dieser erste Stand verwendet
keine zusätzlichen Subvolumes und keine automatische Snapshot-Verwaltung.

Die LUKS-Passphrase wird von Calamares verdeckt abgefragt; unser Modul legt
keine Schlüsseldatei an. Nur der Benutzerpassworthash wird auf der verschlüsselten SSD
unter `/var/lib/nixos-secrets/user-password.hash` gespeichert, nie im Nix Store.
Root-Anmeldung ist gesperrt; der Benutzer kann mit Passwort `sudo` verwenden.

### Calamares-Anbindung und Einschränkungen

Die ISO verwendet das vorhandene NixOS-Modul
`installation-cd-graphical-calamares-plasma6.nix`, das
`installation-cd-graphical-calamares.nix` importiert. Damit kommen KDE-Live-Desktop,
Calamares, Polkit und die nativen Ansichten sowie Partitionierungs-/Mount-Jobs
aus Nixpkgs. Disko und `disko-install` werden nicht mehr verwendet.

`installer/calamares/main.py` ist ausschließlich die Anbindung an unsere Flake:
Vorprüfung, Übernahme der Benutzer-/Spracheinstellungen, Hardwarekonfiguration,
rootgeschützter Passworthash, `nixos-install` und Modellkopie. Python ist hier eine
Calamares-Modulschnittstelle und wird auch von der standardmäßigen NixOS-Anbindung
verwendet; es gibt keinen eigenen interaktiven Python- oder Shell-Installer mehr.
Die nativen Benutzer-Jobs werden nicht ausgeführt, weil unsere Flake Benutzer und
dauerhaften Passworthash bereits deklarativ konfiguriert.

Manuelle Partitionierung ist in diesem Stand deaktiviert. Das gepinnte
Nixpkgs-Calamares-Paket enthält `dont-allow-manual-luks.patch`, der LUKS/LUKS2
aus den manuellen Dateisystemdialogen entfernt. Wir entfernen diesen Patch nicht
ungeprüft. Automatische LUKS2-Partitionierung wird unterstützt.
Die Fortschrittsanzeige zeigt grobe Phasen, keine exakte Download-/Kopierprozentzahl.

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

Bei Fehlern zeigt Calamares eine Fehlermeldung. Ein erneuter normaler
Installationslauf **löscht die SSD erneut** nach Bestätigung. `install-m5` und
`--models-only` gibt es nicht mehr.

Nach erfolgreicher Systeminstallation, aber fehlgeschlagener Modellkopie, kann
die bestehende verschlüsselte Installation vom Live-Desktop aus manuell entsperrt
und nach `/mnt` gemountet werden. Modelle liegen auf dem Medium unter
`/etc/m5-installer/models`; mit `cp -rL` kopieren, damit keine Store-Symlinks auf
dem Ziel landen. Ziel: `/mnt/var/lib/gufo/models`. Danach im Zielsystem die Dateien
`gufo:gufo` zuordnen und Lese-/Schreibrechte wie im Installationsjob setzen.
Vorher unbedingt prüfen, dass `/mnt` wirklich die entsperrte Zielinstallation ist.

Alternativ können die gleichen Modelle vom installierten System aus
heruntergeladen werden:

```bash
sudo -u gufo env HOME=/var/lib/gufo GUFO_MODELS_DIR=/var/lib/gufo/models \
  gufo model install flash-next-q4
```

Gufo setzt Downloads fort.

## System später ändern

Die vollständige Konfiguration wird nach `/etc/nixos` kopiert, ergänzt um
`installation.json` (Benutzername, Hostname und Spracheinstellungen) und
`hardware-configuration.nix` (Hardware, Dateisysteme und LUKS-UUIDs).
Diese beiden Dateien sind keine Geheimnisse, enthalten aber gerätespezifische Daten.
Ein normales `nixos-rebuild` partitioniert oder formatiert nichts.

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

## Installer-Auswahl: nixos-wizard vorerst nicht verwenden

Geprüft am 2026-11-25: [km-clay/nixos-wizard](https://github.com/km-clay/nixos-wizard)
hat eine passende TUI für SSD-Auswahl, Partitionierung und Benutzeranlage,
installiert aber noch keine vorhandene Flake wie unsere M5-Konfiguration.
Prüfstand: Commit `386def227ec27ea61bdfd9c3e7afeab7da39102a`.

- Ein Menü „Source Flake“ fragt einen lokalen oder entfernten Flake-Pfad ab.
- Der Pfad wird gespeichert, in der Konfigurationsvorschau aber lediglich im
  ungenutzten Feld `_flake_path` gehalten.
- Der tatsächliche Installationsablauf kopiert die selbst generierte
  `configuration.nix` und ruft `nixos-install --root /mnt` **ohne `--flake`** auf.
  Die Eingabe unserer Flake würde unsere Konfiguration daher nicht installieren.
- Der letzte Commit auf `main` hat das Committer-Datum 2026-04-07, also zum
  Prüfzeitpunkt gut sieben Monate zuvor. Das allein beweist keine Aufgabe des
  Projekts; zusammen mit dem unvollständigen Flake-Pfad ist es jedoch ein Grund,
  den Installer für unseren Anwendungsfall vorerst nicht einzusetzen.

Quellen im geprüften Commit:
[Source-Flake-Eingabe](https://github.com/km-clay/nixos-wizard/blob/386def227ec27ea61bdfd9c3e7afeab7da39102a/src/installer/mod.rs#L799-L1023),
[Konfigurationsvorschau](https://github.com/km-clay/nixos-wizard/blob/386def227ec27ea61bdfd9c3e7afeab7da39102a/src/installer/mod.rs#L4117-L4203),
[Installationsbefehle](https://github.com/km-clay/nixos-wizard/blob/386def227ec27ea61bdfd9c3e7afeab7da39102a/src/installer/mod.rs#L4532-L4603)
und [Commit](https://github.com/km-clay/nixos-wizard/commit/386def227ec27ea61bdfd9c3e7afeab7da39102a).

Zum Prüfzeitpunkt verwendeten wir deshalb `disko-install` mit einem Wrapper.
Inzwischen verwenden wir Calamares mit einer M5-Flake-Anbindung. Die Bewertung
von nixos-wizard kann bei funktionierendem Flake-Support neu geprüft werden.

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
