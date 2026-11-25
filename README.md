# BOSGAME M5: NixOS, KDE, Steam und Gufo

Grafischer Calamares-Installer für den M5 mit Ryzen AI Max+ 395 und 128 GB RAM.
Das gesamte gewählte Laufwerk wird nach ausdrücklicher Bestätigung
neu partitioniert. **Alle vorhandenen Daten einschließlich Windows werden gelöscht.**
Dieser Installer ist noch nicht auf dem M5 oder in einer VM erprobt.
Die Offline-Variante ist implementiert, aber noch nicht durch eine vollständige
Installation ohne Netzwerk verifiziert.

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
Der Installer kopiert sie vom Stick auf die SSD, ohne Modelldownload.
Die Modelle allein umfassen rund 115 GB; ein 256-GB-Stick ist ein sinnvoller
Ausgangspunkt. Vor dem Schreiben die tatsächliche ISO-Größe prüfen.
Bauen benötigt deutlich mehr
freien Platz im Nix Store; das Repository allein ist klein.
SquashFS-Kompression ist deaktiviert. Die Offline-ISO enthält zusätzlich das
vorbereitete M5-System, lokale Flake-Inputs und Konfigurations-/Initrd-Werkzeuge.

## Stick vorbereiten

Die ISO etwa mit KDE ISO Image Writer auf den **richtigen USB-Stick** schreiben.
Dabei wird auch der Stick gelöscht. Hier gibt es absichtlich keinen automatisch
ausgeführten Schreibbefehl für einen geratenen Gerätenamen.

## Installation

1. Im BIOS Secure Boot deaktivieren und den UMA-Framebuffer möglichst klein
   einstellen (Gufo empfiehlt 512 MiB, sofern das BIOS dies anbietet).
2. Stick im **UEFI-Modus** booten. Im KDE-Live-Desktop automatisch als `nixos`
   anmelden. Für die vorgesehene Offline-Installation ist kein Ethernet oder WLAN
   erforderlich. Das Image bietet keinen SSH-Zugang.
3. Calamares öffnen (Autostart oder Desktop-Verknüpfung). Sprache, Zeitzone,
   Tastatur und Benutzer samt Passwort wählen. KDE, Steam und Gufo sind durch
   unsere Flake fest vorgegeben; es gibt keine Desktop-Auswahl.
4. Die **richtige SSD** auswählen, „gesamten Datenträger löschen“ wählen und
   die gewünschte Verschlüsselung wählen. LUKS ist vorausgewählt, aber optional.
   Bei aktivierter Verschlüsselung prüft Calamares bereits hier, dass die
   Passphrase nicht leer ist und beide Eingaben übereinstimmen.
   Kein Swap. Der Datenträger benötigt mindestens 256 GiB.
   Anders als der frühere Wrapper verwendet dieser Stand Calamares' Geräteauswahl,
   ohne unseren zusätzlichen USB-/Transportfilter und ohne abgetippten Löschtext.
   Modell, Größe und Zielgerät deshalb in der Zusammenfassung genau prüfen.
5. Die abschließende Installationsbestätigung akzeptieren. Vor der Partitionierung
   prüft das M5-Modul UEFI, Löschmodus, keinen Swap
   sowie Benutzereingaben. Calamares partitioniert, formatiert und mountet.
   Unser Job installiert anschließend `path:/…/etc/nixos#m5` mit `nixos-install`
   und kopiert die Modelle vom Medium. Warten, bis **beides** abgeschlossen ist.
6. Neustarten, Stick entfernen. Bei Verschlüsselung beim Boot LUKS-Passphrase eingeben, anschließend
   mit dem gewählten Benutzerpasswort in KDE anmelden.

Layout: 1 GiB unverschlüsselte EFI-Systempartition und Btrfs für den
gesamten Rest, wahlweise innerhalb von LUKS2. Kein Swap, kein Hibernation-Setup. Die EFI-
Partition mit Kernel und Initrd bleibt unverschlüsselt; das schützt nicht vor
Manipulation durch jemanden mit physischem Zugriff. Es gibt keinen gespeicherten
LUKS-Schlüssel und keine automatische TPM-Entsperrung.
Btrfs verwendet `compress=zstd` und `noatime`. Dieser erste Stand verwendet
keine zusätzlichen Subvolumes und keine automatische Snapshot-Verwaltung.

Die LUKS-Passphrase wird von Calamares verdeckt abgefragt; unser Modul legt
keine Schlüsseldatei an. Nur der Benutzerpassworthash wird auf der Ziel-SSD
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

### Offline mit dynamischen Einstellungen

Calamares bietet vor der Zusammenfassung die Auswahl **mit Qwen-Modellgewichten**
(vorausgewählt) oder **ohne Modellgewichte**. Ohne Gewichte entfällt das Kopieren
der sechs Dateien nach `/var/lib/gufo/models`; dies spart etwa 107 GiB auf dem
Zielsystem. KDE, Steam und Gufo werden unverändert installiert. Gufo bleibt
manuell gestartet und benötigt für den Modellbetrieb später bereitgestellte
Gewichte. Die Gewichte sind nur Bestandteil der Live-ISO, nicht der
Zielsystem-Paket-Closure. ISO-Größe und Platzbedarf beim Bau ändern sich nicht.
Beide Varianten müssen noch in der Offline-VM erprobt werden.

`packages.x86_64-linux.offline-system` ist ein vorgebautes Referenzsystem mit
dem festen KDE-/Steam-/Gufo-Paketsatz und LUKS-Initrd-Komponenten. Die ISO nimmt
dessen Laufzeit-Closure sowie die direkten Build-Werkzeuge der System-,
Dateisystem- und Initrd-Assemblierung mit. Das ist **nicht** die vollständige
Source-/Compiler-Closure für Kernel, ROCm oder den gesamten Desktop.

`packages.x86_64-linux.offline-source` archiviert alle gesperrten Flake-Inputs,
einschließlich Gufo-Toolchains, und schreibt ihre Lock-Einträge auf lokale
Store-Pfade um. Die originalen Netzwerk-Locks bleiben als `flake.online.lock`
erhalten. Das installierte System hält die lokalen Input-Quellen als
`system.extraDependencies` fest, damit die Lock-Pfade nicht nach dem Entfernen
des Sticks verschwinden oder vom GC entfernt werden.
Lokale Pfad-Inputs liefern keine Git-Kurzrevision. Gufo erhält deshalb explizit
die ursprüngliche Kurzrevision aus dem Online-Lock, damit sein Store-Pfad gleich
bleibt. Dies wurde durch Vergleich der Online-/Offline-Auswertung geprüft;
alle gelisteten Systempakete außer dem neu erzeugten `nixos-version`-Script
hatten identische Store-Pfade. Eine Offline-Auswertung der archivierten Flake
mit deaktivierter Registry und deaktivierten entfernten Substitutern war erfolgreich.

Benutzername, Hostname, Tastatur, Sprache und die tatsächlichen LUKS-/Dateisystem-
UUIDs werden weiterhin erst bei der Installation festgelegt. Ein gemeinsames
Archiv mit allen unterstützten Locales verhindert einen neuen Locale-Build
bei abweichender Sprachwahl. Nix baut nur die davon abhängigen Systembausteine
neu; Kernel, Desktop und Gufo sollen aus dem lokalen Store übernommen werden.
Neue Pakete oder zusätzliche, nicht vorbereitete Hardwaretreiber sind davon
nicht automatisch abgedeckt.

Der M5-Job lässt `nixos-install` seinen lokalen `auto`-Substituter zum
Übernehmen der Store-Pfade vom Live-System verwenden. Konfigurierte entfernte
Binärcaches bleiben ebenfalls erlaubt, wenn Netzwerk verfügbar ist. Die
Installation soll auch ohne Netzwerk vollständig aus der ISO funktionieren;
dies muss separat in netzlosen Tests nachgewiesen werden. Eine Installation
mit Netzwerk ist kein Nachweis der Offline-Vollständigkeit.
`--no-root-passwd` unterdrückt ausschließlich den interaktiven Root-Passwort-
Prompt; Root bleibt durch `hashedPassword = "!"` gesperrt, nicht passwortlos.

Vor einer Zusage vollständiger Offlinefähigkeit muss die fertige ISO in einer
UEFI-VM **ohne Netzwerkkarte** installiert werden: Benutzername und Sprache
abweichend vom Referenzsystem wählen, neu booten, LUKS entsperren, in KDE anmelden,
Steam-Programm und Gufo-Service-Konfiguration prüfen und alle sechs Modell-Dateien
mit dem Manifest vergleichen. Die GPU-Ausführung bleibt ein Test auf dem M5.
Steam-Anmeldung, Client-/Spiele-Updates und neue Systempakete benötigen später
weiterhin Internet; sie sind nicht Teil der Offline-Installation.

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
Systempakete. Alle Downloads erfolgen beim ISO-Bau; der Installationsschritt
ist für einen ausschließlich lokalen Betrieb vorbereitet (VM-Nachweis steht aus).
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

### Online aktualisieren nach der Offline-Installation

Die Offline-Installation verhindert keine späteren Online-Updates.
Die archivierte `flake.lock` sperrt die Inputs zunächst auf lokale Store-Pfade,
damit die Installation keine Quellen herunterladen muss. Die ursprünglichen
GitHub-Adressen in `flake.nix` bleiben dagegen unverändert erhalten.
`nix flake update` löst diese Adressen neu auf und ersetzt die lokalen Locks
durch aktuelle Netzwerk-Locks. `flake.online.lock` ist eine Sicherung des
ursprünglichen Online-Stands, keine Voraussetzung für ein Update.

Mit Internetverbindung auf dem installierten System:

```bash
cd /etc/nixos
sudo cp flake.lock flake.before-update.lock
sudo nix flake update
sudo nixos-rebuild switch --flake path:/etc/nixos#m5
```

Damit werden alle Flake-Inputs innerhalb ihrer angegebenen Branches bzw. Tags
aktualisiert. Der Nixpkgs-Input folgt `nixos-unstable`: aktualisiert werden die
darin enthaltenen Paketversionen, nicht zwingend jedes neueste Upstream-Release.
Quellen und Pakete dürfen beim Update online geladen werden; die
Netzwerkisolation gilt nur für den Installationsjob auf der Live-ISO.

Gufo ist in `flake.nix` explizit auf `github:gufo-org/gufo/v0.36.0` festgelegt.
Für eine neuere Gufo-Version dort zuerst den gewünschten Release-Tag eintragen,
dann die obigen Update-/Rebuild-Befehle ausführen. Neue Releases können andere
Konfigurationsoptionen oder Modellanforderungen haben. Modellgewichte in
`models.lock.json` werden durch `nix flake update` nicht aktualisiert; ebenso
wenig die bereits nach `/var/lib/gufo/models` kopierten Dateien.

Für einen fehlgeschlagenen Update-Build kann der bisherige Lock wiederhergestellt
werden; das bisher aktivierte System bleibt bei einem Build-Fehler erhalten:

```bash
sudo cp /etc/nixos/flake.before-update.lock /etc/nixos/flake.lock
```

Nach erfolgreicher Aktivierung lässt sich bei Problemen mit
`sudo nixos-rebuild switch --rollback` zur vorherigen Systemgeneration wechseln.
Das setzt die Konfigurationsdateien und den Lock nicht zurück; dafür die
entsprechenden Sicherungen bzw. Git-Versionen verwenden.

Der Online-Update-Ablauf der installierten Offline-Flake ist noch nicht in
einer vollständigen VM-Installation geprüft.

### Installationsfehler diagnostizieren

#### Offline-Installationsproblem und Lösungsversuche (2026-11-25)

- **Symptom:** Netzlose UEFI-Installation scheitert nach „Erase disk“ beim
  Systembuild am Download von `https://ftpmirror.gnu.org/bash/bash-5.3.tar.gz`.
  Partitionierung funktioniert; „unshare fehlgeschlagen“ war nur eine unpräzise
  Meldung zum übergeordneten Aufruf, nicht die Ursache.
- **Erste gefundene Lücke:** Laufzeit-Abhängigkeiten des Referenzsystems reichen
  nicht für das Zusammensetzen geänderter Identität, UUIDs und Initrd aus;
  unter anderem fehlte Texinfo für den Systempfad-Aufbau.
- **Erster Lösungsversuch:** Fertige Systempfad-, Texinfo-, XML- und
  Capability-Werkzeuge sowie AMD-Microcode und Firmware ergänzen (`19833a5`).
  Den vollständigen Quellen-/Compiler-Buildgraph für Kernel/ROCm nicht bündeln.
- **Teilnachweis:** Isolierte Systembuilds mit/ohne LUKS bestanden, mit anderer
  Identität, Sprache, Zeitzone, Tastatur, UUIDs und VirtIO-Modulen. Nur vorgesehene
  ISO-Abhängigkeiten und archivierte Inputs im Test-Store; kein Host-Store oder
  Netzwerk. Die LUKS-Variante verwendete den gleichen Store und gemeinsame Artefakte.
- **Testaufbau:** Arch stellte Nix samt Bibliotheken bereit. Abbrüche an
  `setgroups`/`uid_map` waren Harness-Probleme; deshalb innere Nix-Sandbox aus,
  äußere Store-/Netzwerk-Isolation weiterhin aktiv.
- **Ergebnis mit neuer ISO:** Echter `nixos-install` scheiterte weiterhin an
  Bash. Der bestandene Systembuild war kein Installations- oder Boot-Nachweis.
- **Weitere gefundene Ursache:** `nixos-install` ergänzt zuerst den lokalen
  `auto`-Substituter; unser späteres `substituters = ""` überschreibt ihn wieder.
  Dadurch werden auch vorhandene ISO-Pakete nicht als Substitute übernommen.
  Die Wirkung der Optionsreihenfolge wurde mit Nix 2.35.6 geprüft.
- **Warum der Test das übersah:** Die Pakete lagen direkt im Build-Store;
  Übernahme aus dem Live-Store in einen separaten Ziel-Store wurde nicht getestet.
- **Aktuelle Korrektur:** Netzwerksperre und Substituter-/Builder-/Registry-Sperren
  aus der normalen Installation entfernen. Lokalen ISO-Store und konfigurierte
  Online-Caches erlauben; ohne Netzwerk muss die ISO trotzdem ausreichen.
- **Prüfstand:** 16 Adaptertests und Formatprüfung bestanden. Die aktuelle
  Korrektur ist noch nicht in der ISO; vollständige netzlose Installation,
  Boot und anschließendes Online-Update bleiben unbestätigt.
- **Weiter nötig:** Echten Installationspfad mit separatem Ziel-Store und
  gesperrtem Netzwerk reproduzierbar vor ISO-Freigaben testen. Manuelle
  Werkzeuglisten können nach Updates erneut Lücken haben; Ableitung verbessern.
  Online-Erfolg beweist keine Offline-Vollständigkeit.

#### Voraussetzungen und Diagnoseausgabe

Das separate `uefiwelcome`-Modul meldet UEFI als zwingende Voraussetzung bereits
auf der Willkommensseite. Bei BIOS-Start bleibt „Weiter“ gesperrt und der
Hinweis fordert einen Neustart im UEFI-Modus (bei VMs: UEFI/OVMF).
Die spätere M5-Vorprüfung bleibt zusätzlich aktiv. Ein BIOS-Fallback ist
nicht vorgesehen. Die frühe Prüfung muss noch in der VM bestätigt werden.
Das C++-Modul lädt die unveränderte Calamares-Willkommensseite und ergänzt
deren Requirements über die offizielle ViewStep-Schnittstelle. Es gibt keine
zusätzliche Seite und keinen M5-Patch am Calamares-Quellcode.

Der M5-Job nennt bei Fehlern die Phase und entweder den konkreten
Validierungsgrund oder den Programmnamen mit Exit-Code. Bei `unshare` und
`nixos-install` wird stattdessen der Systeminstallationsaufruf benannt:
Der Exit-Code allein unterscheidet Wrapper- und Kindprozessfehler nicht.
Ziel-Mounts, Konfiguration, Benutzerzugang, Systeminstallation und Modellkopie
haben eigene Diagnosephasen. Betriebssystemfehler
werden mit errno gemeldet. Befehlsargumente, Passwörter und Hashes werden nicht
in diese Diagnose übernommen. Jeder gestartete Adapter-Befehl wird nur mit
seinem Programmnamen in der Calamares-Ausgabe protokolliert.
Nicht zur Weiterverarbeitung erfasste Unterprozessausgaben werden nicht mehr
verworfen, sondern an die vorhandenen Calamares-Ausgabeströme weitergegeben.
Diese Originalausgaben sind nicht sanitisiert; vor Weitergabe auf sensible
Daten prüfen. Es erfolgt kein automatischer Upload.
Der Fehlerdialog enthält einen Journal-Befehl ab Beginn des Adapter-Aufrufs.
Die erste Fehlermeldung prüfen, nicht nur spätere Nix-Abhängigkeitsfehler.
Fehler im Installationsjob warnen ausdrücklich, dass bereits partitioniert
wurde und die Installation unvollständig ist, auch bei erneuter Vorprüfung.
Beim automatisch gestarteten Installer kann diese Ausgabe im Journal der
Live-VM mit `sudo journalctl -b --no-pager` gelesen werden; nach
`M5 installer` suchen. Die VM vor dem Sichern der Diagnose nicht neu starten.
Für einen manuell gestarteten Installer dessen Terminalausgabe sichern.

### Konfiguration ändern ohne Paketupdate

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

### Gufo-Cache im Nix-Daemon freigeben

Auf dem Vorbereitungsrechner sind diese Freigaben eingerichtet. In
`/etc/nix/nix.conf` ergänzen bzw. mit vorhandenen Einträgen zusammenführen:

```ini
trusted-substituters = https://gufo.cachix.org
extra-trusted-public-keys = gufo.cachix.org-1:rfZe3n4lHINgyoACKzs5EthIZmBNvEyCCtufUpth0PE=
```

`trusted-substituters` erlaubt normalen Benutzern, den in der Flake angegebenen
Cache zu verwenden. `extra-trusted-public-keys` ergänzt seinen Signaturschlüssel,
ohne die bestehenden Standardschlüssel zu ersetzen. Eine pauschale Aufnahme des
Benutzers in `trusted-users` ist dafür nicht nötig. Mit dieser Freigabe vertraut
man den vom Gufo-Cache signierten Build-Ergebnissen.
Die Cache-Nutzung wurde am 2026-11-25 nach dem Daemon-Neustart per Dry-run
geprüft: `rocblas-gfx1151` wird geladen, Gufo selbst bleibt als lokaler Build
eingeplant. Für das Offline-Referenzsystem wurden 235 Builds und 3,7 GiB Download
(11,0 GiB entpackt) geplant. Die Warnung zur untrusted Cache-URL ist verschwunden;
die weiterhin ignorierte clientseitige Schlüssel-Einstellung der Flake ist
unnötig, da der Schlüssel im Daemon hinterlegt ist.

**Nicht während eines laufenden ISO-Baus den Daemon neu starten.** Erst warten,
bis alle laufenden Nix-Bauten abgeschlossen sind, dann:

```bash
sudo systemctl restart nix-daemon.service
nix build .#offline-system --dry-run --accept-flake-config
```

Danach prüfen, dass die Warnungen über den untrusted Gufo-Substituter und den
ignorierten Schlüssel verschwunden sind und Gufo/ROCm soweit verfügbar aus dem
Cache eingeplant werden. Die Freigabe allein garantiert nicht, dass für jede
gesperrte Derivation bereits ein Cache-Ergebnis vorhanden ist.
