# Modularer NixOS-Installer

Grafischer Calamares-Installer für x86_64-Rechner mit UEFI.
Das gesamte gewählte Laufwerk wird nach ausdrücklicher Bestätigung
neu partitioniert. **Alle vorhandenen Daten einschließlich Windows werden gelöscht.**
Die bisherige ISO wurde offline mit Calamares in einer UEFI-VM installiert;
anschließend starteten KDE und Gufo. Die generalisierte Konfiguration muss
erneut mit einer ISO geprüft werden. Online-Update und Rebuild der bisherigen
installierten Konfiguration wurden vom Benutzer als erfolgreich bestätigt;
auch der anschließende Neustart war erfolgreich. Reale Hardware bleibt ungeprüft.

Ausgangspunkt des Projekts war ein Bosgame M5. Das Setup enthält keine
dafür festgelegten GPU-Speicherlimits oder
erzwungenen AMD-Treiber. Hardwaretreiber und CPU-Microcode werden über die bei
der Installation erzeugte Hardwarekonfiguration ausgewählt. Das ist keine
Zusage universeller Hardware- oder Offline-Treiberunterstützung. Das gepinnte
Gufo-Release verwendet upstream ein ROCm-Backend für AMD Strix Halo (`gfx1151`);
für andere GPUs ist ein passendes Gufo-Backend beziehungsweise ein anderer
Build nötig. KDE und der Installer sind nicht an dieses GPU-Modell gebunden.

## Voraussetzungen und reproduzierbarer Bau

Die Flake bietet fünf feste Zielzusammenstellungen:

| Variante | Zielmodule                           | ISO-Ausgabe    | Freie Anwendungspakete |
| -------- | ------------------------------------ | -------------- | ---------------------- |
| Base     | `base.nix`                           | `iso-base`     | ✅                     |
| Desktop  | `desktop.nix`                        | `iso-desktop`  | ✅                     |
| Gaming   | `gaming.nix`                         | `iso-gaming`   | ❌ Steam               |
| AI       | `desktop.nix` + `generative-ai/`      | `iso-ai`       | ✅                     |
| Full     | `gaming.nix` + `generative-ai/`       | `iso-full`     | ❌ Steam               |

Die Spalte beschreibt die Nixpkgs-Paketfreigabe, keinen vollständigen
Lizenznachweis: Redistributable Firmware ist in allen Varianten aktiviert;
Modellgewichte haben eigene Lizenzen.

`desktop.nix` importiert `base.nix`, `gaming.nix` importiert `desktop.nix`.
`generative-ai/default.nix` importiert nur `base.nix` und ist auch ohne Desktop nutzbar.
Das AI-Modul definiert `generative-ai.models.directory` (Standard:
`/var/lib/generative-ai/models`). Gufo, Verzeichnisregeln und Installer-Kopie verwenden
denselben Wert. Eine spätere Änderung verschiebt bereits vorhandene Gewichte
nicht automatisch; diese müssen separat ins neue Verzeichnis übernommen werden.
Qwen-Gewichte liegen unter `text-generation/Qwen3.8-Flash-Next/UD-Q4_K_XL/`,
MTP unter `text-generation/Qwen3.8-Flash-Next/MTP/` und der Projektor direkt
unter `text-generation/Qwen3.8-Flash-Next/`. Die HF-Dateinamen bleiben erhalten.
Gufo verwendet den konkreten Pfad des ersten GGUF-Shards statt eines Modellalias.
`generative-ai.models.text-generation.directory` leitet sich vom Modellwurzelpfad
ab; `generative-ai.models.text-generation.qwen38FlashNext.directory` davon.
Die Unterverzeichnisse müssen innerhalb ihrer jeweiligen Elternverzeichnisse liegen.
Alle Live-ISOs enthalten KDE und Calamares; das Base-Zielsystem enthält weder
KDE noch Firefox. Gaming ergänzt Steam, AI ergänzt Gufo und dessen Unterstützung.
Nur AI-/Full-ISOs enthalten alle sechs Qwen-Dateien und die optionale Modellkopie.
Unfreie Pakete werden nicht pauschal freigegeben: Nur das Gaming-Modul erlaubt
`steam` und `steam-unwrapped` über `allowUnfreePredicate`. Redistributable Firmware
bleibt über die gesonderte NixOS-Hardwareoption aktiviert; das Setup ist daher
nicht als ausschließlich freie Software zu verstehen.
Ohne AI werden auch Gufo-/Toolchain-Inputs aus der Installations-Flake entfernt.

Ziele heißen `nixosConfigurations.<variante>`, Live-Konfigurationen
`nixosConfigurations.installer-<variante>`. `iso`, `default` und `installer`
bleiben Aliase für Full. Die Namen sind unabhängig vom gewählten Hostnamen.
Die neuen Varianten sind lokal ausgewertet, aber noch nicht per ISO installiert.

Ein Linux-x86_64-Rechner mit funktionierender Nix-Installation und Nix Store.
Die Flake aktiviert `nix-command` und `flakes` nicht für das aufrufende Nix;
falls nötig die folgenden Befehle mit
`nix --extra-experimental-features 'nix-command flakes' …` ausführen.

```bash
nix flake lock
nix fmt
nix flake check --no-build
nix build .#checks.x86_64-linux.installer-tests
nix build .#checks.x86_64-linux.variant-tests
nix build .#iso-full
```

`flake.lock` zusammen mit allen Konfigurationsdateien versionieren und archivieren.
Der erste Lock-Vorgang legt die Versionen fest; für weitere Bauten **nicht**
`nix flake update` ausführen. Gufo ist zusätzlich auf Release v0.36.0 festgelegt.
Die separaten Gufo-Toolchain-Inputs werden bewusst nicht auf das Host-Nixpkgs
umgebogen, damit der offizielle Build und sein Cache nutzbar bleiben.
Der Gufo-Cachix-Cache wird zusätzlich zum NixOS-Cache verwendet; damit vertraut
man auch dessen signierten Builds. Ohne akzeptierten Cache können große lokale
ROCm-/Gufo-Builds erforderlich werden.

Das Image liegt unter `result/iso/` und enthält den
Installer und die gesperrte Flake; bei AI/Full zusätzlich alle sechs Modell-Dateien. Diese werden
beim ISO-Bau heruntergeladen und anhand der gepinnten SHA-256-Prüfsummen geprüft.
Der Installer kopiert sie auf Wunsch vom Stick auf das Ziel, ohne Modelldownload.
Die Modelle allein umfassen rund 115 GB; ein 256-GB-Stick ist ein sinnvoller
Ausgangspunkt. Vor dem Schreiben die tatsächliche ISO-Größe prüfen.
Bauen benötigt deutlich mehr
freien Platz im Nix Store; das Repository allein ist klein.
SquashFS-Kompression ist deaktiviert. Die Offline-ISO enthält zusätzlich das
vorbereitete Desktop-System, lokale Flake-Inputs und Konfigurations-/Initrd-Werkzeuge.

## Stick vorbereiten

Die ISO etwa mit KDE ISO Image Writer auf den **richtigen USB-Stick** schreiben.
Dabei wird auch der Stick gelöscht. Hier gibt es absichtlich keinen automatisch
ausgeführten Schreibbefehl für einen geratenen Gerätenamen.

## Installation

1. In der Firmware Secure Boot deaktivieren. Für GPU-Inferenz zusätzlich die
   Gufo-Anforderungen für die vorhandene GPU und deren Speicher prüfen.
2. Stick im **UEFI-Modus** booten. Im KDE-Live-Desktop automatisch als `nixos`
   anmelden. Für die vorgesehene Offline-Installation ist kein Ethernet oder WLAN
   erforderlich. Das Image bietet keinen SSH-Zugang.
3. Calamares öffnen (Autostart oder Desktop-Verknüpfung). Sprache, Zeitzone,
   Tastatur und Benutzer samt Passwort wählen. Die Zielzusammenstellung ist durch
   die ISO-Variante fest vorgegeben; es gibt keine Desktop-Auswahl.
4. Die **richtige SSD** auswählen, „gesamten Datenträger löschen“ wählen und
   die gewünschte Verschlüsselung wählen. LUKS ist vorausgewählt, aber optional.
   Bei aktivierter Verschlüsselung prüft Calamares bereits hier, dass die
   Passphrase nicht leer ist und beide Eingaben übereinstimmen.
   Kein Swap. Mindestgröße: 256 GiB bei AI/Full, sonst 32 GiB.
   Anders als der frühere Wrapper verwendet dieser Stand Calamares' Geräteauswahl,
   ohne unseren zusätzlichen USB-/Transportfilter und ohne abgetippten Löschtext.
   Modell, Größe und Zielgerät deshalb in der Zusammenfassung genau prüfen.
5. Die abschließende Installationsbestätigung akzeptieren. Vor der Partitionierung
   prüft das Installer-Modul UEFI, Löschmodus, keinen Swap
   sowie Benutzereingaben. Calamares partitioniert, formatiert und mountet.
   Der Job „Install NixOS“ installiert anschließend `path:/…/etc/nixos#<variante>`
   mit `nixos-install`. Bei AI/Full kopiert danach der separate Job „Copy model weights“ bei
   Auswahl die Modelle vom Medium; ohne Gewichte überspringt er die Kopie.
   Warten, bis die Finish-Seite
   erscheint; 100 % allein bedeutet noch nicht, dass alle Abschlussjobs fertig sind.
6. Neustarten, Stick entfernen. Bei Verschlüsselung beim Boot LUKS-Passphrase eingeben, anschließend
   mit dem gewählten Benutzerpasswort anmelden (bei Base an der Konsole, sonst KDE).

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
Das kompilierte Calamares-Paket bleibt variantenunabhängig. Ein separater
Wrapper setzt die Konfigurationspfade; Desktop-/Autostart-Eintrag und Polkit
verweisen auf diesen Wrapper. Änderungen der Installer-Konfiguration lösen
dadurch keine erneute Calamares-Kompilierung aus.

`modules/installer/calamares/main.py` ist ausschließlich die Anbindung an unsere Flake:
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
Systeminstallation und Modellkopie sind getrennte Calamares-Job-Instanzen mit
eigenen Titeln und Fortschrittsgewichten. Die Fortschrittsanzeige zeigt grobe
Phasen, keine exakte Download-/Kopierprozentzahl. Beide Jobs verwenden denselben
Adapter; ein Modellkopierfehler fordert keine erneute Systeminstallation.

### Offline mit dynamischen Einstellungen

Bei AI/Full bietet Calamares vor der Zusammenfassung die Auswahl **mit Qwen-Modellgewichten**
(vorausgewählt) oder **ohne Modellgewichte**. Ohne Gewichte entfällt das Kopieren
der sechs Dateien nach `/var/lib/generative-ai/models`; dies spart etwa 107 GiB auf dem
Zielsystem. Die gewählte Modulzusammenstellung bleibt unverändert. Gufo bleibt
manuell gestartet und benötigt für den Modellbetrieb später bereitgestellte
Gewichte. Die Gewichte sind nur Bestandteil der Live-ISO, nicht der
Zielsystem-Paket-Closure. ISO-Größe und Platzbedarf beim Bau ändern sich nicht.
Beide Varianten müssen noch in der Offline-VM erprobt werden.

`packages.x86_64-linux.offline-system` ist ein vorgebautes Referenzsystem mit
dem Full-Paketsatz und LUKS-Initrd-Komponenten. Jede ISO nimmt stattdessen den
zu ihrer Variante passenden Paketsatz und
dessen Laufzeit-Closure sowie die direkten Build-Werkzeuge der System-,
Dateisystem- und Initrd-Assemblierung mit. Das ist **nicht** die vollständige
Source-/Compiler-Closure für Kernel, ROCm oder den gesamten Desktop.

Die Variante steht in `/etc/nixos/installation.json` unter `variant`.
Bei späteren Rebuilds dasselbe Flake-Ziel verwenden, beispielsweise
`sudo nixos-rebuild switch --flake /etc/nixos#full`. In den folgenden
Desktop-Beispielen `#desktop` durch die tatsächlich installierte Variante ersetzen.

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

Der Installer-Job lässt `nixos-install` seinen lokalen `auto`-Substituter zum
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
mit dem Manifest vergleichen. GPU-Ausführung auf geeigneter realer Hardware
oder mit GPU-Durchreichung prüfen.
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
neben dem Modell. `gufo diagnose` auf der tatsächlichen Zielhardware ausführen.

Der ISO-Bau lädt die Dateien, deren Revisionen, Größen und SHA-256-Prüfsummen
in diesem gepinnten Release festgelegt sind, einschließlich MTP und Bildprojektor.
Es gibt keinen automatischen Modell-Update-Timer. Die installierten Dateien
liegen außerhalb des Nix Stores in `/var/lib/generative-ai/models`.
`modules/generative-ai/models.lock.json` dokumentiert diese sechs Dateien zusätzlich im Repository;
die Flake prüft, dass es exakt dem Manifest des gepinnten Gufo-Releases entspricht.
Zusammen sind dies rund 115 GB (107 GiB) Download beim ISO-Bau, ohne Spiele und
Systempakete. Alle Modelldownloads erfolgen beim ISO-Bau; die Modellkopie selbst
benötigt keine Netzwerkverbindung. Der Abgleich aller sechs Dateien im
installierten System bleibt separat zu prüfen.
Modellbetrieb setzt genügend RAM beziehungsweise GPU-Speicher und ein von Gufo
unterstütztes Backend voraus. Installation und `gufo --version` allein beweisen
keine funktionierende GPU-Inferenz. GPU-Speicherlimits, Kontextgröße und
Treiberkonfiguration müssen zur tatsächlichen Hardware passen.

## Fehler und erneute Modellkopie

Bei Fehlern zeigt Calamares eine Fehlermeldung. Ein erneuter normaler
Installationslauf **löscht das Ziellaufwerk erneut** nach Bestätigung. Es gibt
keinen separaten interaktiven Installer für reine Modellkopien.

Nach erfolgreicher Systeminstallation, aber fehlgeschlagener Modellkopie, kann
die bestehende verschlüsselte Installation vom Live-Desktop aus manuell entsperrt
und nach `/mnt` gemountet werden. Modelle liegen auf dem Medium unter
`/etc/desktop-installer/models`; mit `cp -rL` kopieren, damit keine Store-Symlinks auf
dem Ziel landen. Ziel: `/mnt/var/lib/generative-ai/models`. Danach im Zielsystem die Dateien
`gufo:gufo` zuordnen und Lese-/Schreibrechte wie im Installationsjob setzen.
Vorher unbedingt prüfen, dass `/mnt` wirklich die entsperrte Zielinstallation ist.

Alternativ die sechs gepinnten Dateien aus
`modules/generative-ai/models.lock.json` herunterladen und mit den dortigen
Prüfsummen vergleichen. Dabei die oben beschriebene Verzeichnisstruktur und
HF-Dateinamen beibehalten. `gufo model install flash-next-q4` verwendet Gufos
eigene Alias-Verzeichnisstruktur und ersetzt diesen Ablauf nicht direkt.

## System später ändern

### Änderungen dieses Repositories übernehmen

Eine Neuinstallation oder neue ISO ist dafür nicht nötig: Neue Tools, Dienste
und Module werden durch einen Rebuild übernommen. Persönliche Dateien bleiben
erhalten; Dienste können dabei neu gestartet werden. Kerneländerungen benötigen
gegebenenfalls einen Neustart. Ein Rebuild ersetzt keine Datensicherung.

`nix flake update` aktualisiert nur die Flake-Abhängigkeiten, nicht unsere
Moduldateien. Die unter `/etc/nixos` installierte Flake ist eine archivierte Kopie,
kein automatisch eingerichteter Git-Checkout. Änderungen dieses Projekts daher
separat über einen eigenen Checkout übernehmen, beispielsweise unter
`~/coding/nixos-setup`.

**Der Checkout muss die Daten genau dieses Ziel-PCs enthalten.** Unsere Module
lesen `hardware-configuration.nix` und `installation.json` relativ zur Flake.
Ohne diese Dateien greifen Evaluierungsdefaults statt der tatsächlichen
Datenträger-UUIDs und Benutzeridentität. Vor dem ersten Rebuild aus dem Checkout
die vorhandenen Dateien übernehmen (bestehende lokale Dateien vorher prüfen):

```bash
cd ~/coding/nixos-setup
cp /etc/nixos/hardware-configuration.nix .
cp /etc/nixos/installation.json .
sudo nixos-rebuild switch --flake "path:$HOME/coding/nixos-setup#desktop"
```

`#desktop` durch die tatsächlich installierte beziehungsweise bewusst gewünschte
Variante ersetzen. Der Passworthash bleibt auf dem Ziel-PC unter
`/var/lib/nixos-secrets/user-password.hash`; ihn nicht ins Repository kopieren.
Die beiden übernommenen Dateien sind im Repository absichtlich Git-ignoriert.
Deshalb hier **`path:` verwenden**: Ein automatisch als Git-Flake behandelter
Checkout würde ignorierte/unversionierte Dateien nicht in die Quelle aufnehmen.
Ein Rebuild ohne diese Dateien ist für unser Setup nicht der richtige Ablauf.

Später nach Prüfung der Projektänderungen im Checkout `git pull --ff-only`
ausführen (lokale Änderungen vorher berücksichtigen) und denselben Rebuild
wiederholen. Optional zusätzlich `nix flake update` ausführen, wenn auch die
Abhängigkeiten auf einen neuen Stand gebracht werden sollen. Für einen vom
Projekt veröffentlichten, reproduzierbaren Stand dessen `flake.lock` verwenden.

Der Rebuild kopiert den Checkout nicht automatisch nach `/etc/nixos`.
Für spätere Updates weiter dieselbe Konfigurationsquelle verwenden; sonst könnte
ein Rebuild aus `/etc/nixos` wieder den alten Stand aktivieren. Dieser
Repo-Update-Ablauf ist dokumentiert, aber noch nicht in der vorhandenen VM geprüft.

### Online aktualisieren nach der Offline-Installation

Die erzeugte Ziel-Flake enthält keine Cache-Vorgaben unter `nixConfig`.
AI-/Full-Systeme konfigurieren den Gufo-Cache und seinen Signaturschlüssel
bereits über das AI-Modul im Nix-Daemon; dafür ist beim Update keine zusätzliche
Flake-Zustimmung nötig. Auch die Entwicklungs-Flake enthält kein `nixConfig`;
der Build-Rechner konfiguriert den optionalen Cache selbst (siehe unten).

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
sudo nixos-rebuild switch --flake path:/etc/nixos#desktop
```

Damit werden alle Flake-Inputs innerhalb ihrer angegebenen Branches bzw. Tags
aktualisiert. Der Nixpkgs-Input folgt `nixos-unstable`: aktualisiert werden die
darin enthaltenen Paketversionen, nicht zwingend jedes neueste Upstream-Release.
Quellen und Pakete dürfen beim Update online geladen werden; die
Netzwerkisolation gilt nur für Offline-Tests, nicht für normale Installationen.

Gufo ist in `flake.nix` explizit auf `github:gufo-org/gufo/v0.36.0` festgelegt.
Für eine neuere Gufo-Version dort zuerst den gewünschten Release-Tag eintragen,
dann die obigen Update-/Rebuild-Befehle ausführen. Neue Releases können andere
Konfigurationsoptionen oder Modellanforderungen haben. Modellgewichte in
`modules/generative-ai/models.lock.json` werden durch `nix flake update` nicht aktualisiert; ebenso
wenig die bereits nach `/var/lib/generative-ai/models` kopierten Dateien.

Für einen fehlgeschlagenen Update-Build kann der bisherige Lock wiederhergestellt
werden; das bisher aktivierte System bleibt bei einem Build-Fehler erhalten:

```bash
sudo cp /etc/nixos/flake.before-update.lock /etc/nixos/flake.lock
```

Nach erfolgreicher Aktivierung lässt sich bei Problemen mit
`sudo nixos-rebuild switch --rollback` zur vorherigen Systemgeneration wechseln.
Das setzt die Konfigurationsdateien und den Lock nicht zurück; dafür die
entsprechenden Sicherungen bzw. Git-Versionen verwenden.

Der Online-Update-Ablauf der bisherigen installierten Offline-Flake wurde am
2026-11-25 in der vorhandenen VM geprüft: GitHub-Inputs wurden geladen und
`nixos-rebuild switch` erfolgreich ausgeführt (Benutzerbestätigung). Dieser
Nachweis gilt noch nicht für die danach generalisierte Repo-Konfiguration.
Der Befehl wurde aus `/etc/nixos` mit `--flake .#m5` ausgeführt; auch der
anschließende Neustart war erfolgreich (Benutzerbestätigung).

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
- **Live-Test der Korrektur:** Manueller `nixos-install` auf dem noch gemounteten
  Ziel scheiterte auch ohne die ursprünglichen Sperren. Ein ausdrücklich
  gesetzter `auto?trusted=1`-Substituter allein behob den Fehler ebenfalls nicht.
  Die Optionsreihenfolge erklärt daher nicht den gesamten Installationsfehler.
- **Weiterer Aufruffehler:** Ein verkürzter manueller Befehl ließ `build-dir`
  weg und scheiterte am world-writable `/tmp`. Mit
  `--option build-dir /nix/var/nix/builds` kam er bis zum Paketbuild.
- **Direkte Store-Übernahme:** Drei fertige Bash-Pfade sind in der VM vorhanden.
  `nix copy` in den Ziel-Store scheiterte zunächst an einer nicht vertrauenswürdig
  signierten `libgcc`-Abhängigkeit; mit `--no-check-sigs` gelang die Kopie.
  Der folgende Installationsversuch scheiterte dann an gnused/Python statt Bash.
- **Signatur-Test:** Auch `--option require-sigs false` beim netzlosen
  Installationsaufruf reichte nicht. Erste Fehler waren Quellendownloads von
  Python 3.14.6, ACL 2.4.0 und attr 2.6.0. Keine dauerhafte Signatursperre ändern;
  der Test ist kein Nachweis, dass diese Pakete auf der ISO fehlen.
- **Aktuelle Untersuchung:** Separaten Ziel-Store nachstellen statt Pakete
  direkt im Build-Store bereitzustellen. Ein Dry-Run mit `--offline` plante
  13.460 Builds einschließlich Bootstrap-Werkzeugen; mit explizitem
  `substitute = true` waren es 313 Builds. Der zweite Lauf meldete jedoch
  eingeschränkte Einstellungen und einen nicht erlaubten lokalen Substituter
  beim Host-Daemon. Daher kein sauberer Installationsnachweis; Nix' automatische
  Deaktivierung von Substitution ohne Netzwerk bleibt zu untersuchen.
- **Weiter nötig:** Echten Installationspfad mit separatem Ziel-Store und
  gesperrtem Netzwerk reproduzierbar vor ISO-Freigaben testen. Manuelle
  Werkzeuglisten können nach Updates erneut Lücken haben; Ableitung verbessern.
  Online-Erfolg beweist keine Offline-Vollständigkeit.
- **Lokaler Reproduktionsversuch:** Echter Build mit getrennten Stores,
  ausschließlich ISO-Pfaden als lokaler Paketquelle und gesperrtem Netzwerk
  scheiterte ebenfalls am Bash-Quellendownload. Noch kein sauberer Nachweis:
  Die folgende direkte Kopie deckte dereferenzierte Store-Symlinks im Harness
  auf (Hash-Mismatch). Symlinks werden jetzt unverändert nachgebildet;
  der Vergleichstest läuft erneut. Signaturprüfung war für diesen Test aus.
  Noch kein vollständiger `nixos-install`-/Boot-Test: Ziel-Store liegt im
  unprivilegierten Namespace regulär unter `/nix/store`, ISO-Store separat;
  die innere Nix-Sandbox ist wegen Host-Namespace-Grenzen ausgeschaltet.
- **Konkrete fehlende Ausgabe:** Das Log fordert zusätzlich Bashs `dev`-Output
  `/nix/store/02pyv1n66h4l27zv105gip35b99qrqam-bash-5.3p20-dev` an; dieser
  fehlt im ISO-Manifest, obwohl Bashs `out` vorhanden ist. Den auslösenden
  übergeordneten Build-Zweig weiter verfolgen, nicht den ganzen Bootstrap bündeln.
- **Audit-Lücke:** Der temporäre Graphabgleich markierte ganze Derivationen als
  besucht und übersah später angeforderte zusätzliche Outputs derselben
  Derivation. Die Analyse berücksichtigt jetzt einzelne Outputs; eine
  verifizierte Installer-Korrektur steht weiterhin aus.
- **Belegter Substitutionsausschluss:** Die auf der ISO vorhandene Perl-Umgebung
  des Aktivierungsskripts (`7f11jkm…-perl-5.42.3-env.drv`) setzt in ihren
  `structuredAttrs` ausdrücklich `allowSubstitutes = false`. Nix verlangt dann
  ihre Build-Abhängigkeiten statt die fertige Ausgabe zu übernehmen. Der
  Graphabgleich berücksichtigte diesen Ausschluss ebenfalls nicht.
  Lokaler Vergleich mit `always-allow-substitutes = true` baute das Zielsystem
  erfolgreich ohne Netzwerk. Der Store enthielt bereits direkt kopierte
  ISO-Pakete; auch die Wiederholung mit frischem Ziel-Store ohne Vorkopieren
  bestand: nur tatsächliche ISO-Pfade als Quelle, Netzwerk gesperrt.
  Signaturprüfung war aus; Signaturstrategie, echte Installation und Boot
  bleiben zu prüfen.
- **Warum diese Sperre existiert:** Nicht Perl selbst, sondern Nixpkgs'
  Bauanleitung für die Perl-Umgebung setzt `preferLocalBuild = true` und
  `allowSubstitutes = false`. Die Umgebung kombiniert fertige Pakete und
  erzeugt Wrapper. Solche kleinen Zusammenbau-Schritte sollen typischerweise
  lokal günstiger sein als Cache-Abfrage und Download; das ist eine
  Optimierungsentscheidung, keine Sicherheitsanforderung. Im separaten
  Offline-Ziel-Store erzwingt sie jedoch zusätzliche Build-Werkzeuge, obwohl
  das fertige Ergebnis auf der ISO liegt. `always-allow-substitutes` überstimmt
  den Ausschluss, ohne die unabhängige Signaturprüfung abzuschalten.
  Hash und vertrauenswürdige Signatur sichern Integrität und signierte Herkunft,
  sind aber kein unabhängiger Beweis eines korrekten Builds.
- **VM-Nachweis:** Manueller netzloser `nixos-install` auf den von Calamares
  vorbereiteten Partitionen bestand mit lokalem Substituter, `substitute = true`
  und `always-allow-substitutes = true`; `require-sigs = false` blieb nur für
  diesen Diagnoselauf gesetzt. Etwa 12 GiB wurden übernommen, systemd-boot und
  UEFI-Einträge eingerichtet, Abschlussmeldung `installation finished!`.
  Danach Start ohne ISO, erfolgreiche LUKS-Entsperrung und KDE-Desktop.
  Bestätigt ist diese verschlüsselte VM-Variante, nicht beliebige Hardware.
- **Noch offen nach VM-Erfolg:** Optionen im Installer sauber umsetzen,
  sichere Übernahme unsignierter ISO-Pakete ohne globale Signaturabschaltung,
  automatisierter Regressionstest, vollständiger Calamares-Durchlauf ohne
  manuelle Befehle sowie Online-Update. Bestehende ISO unverändert.
- **Signaturstrategie:** Nix 2.35 erlaubt mit dem Store-Parameter `trusted=1`
  unsignierte Substitute aus genau dieser Quelle. `nixos-install` setzt bereits
  `auto?trusted=1` für den lokalen Live-Store. Keine globale Abschaltung von
  `require-sigs` und keine zusätzliche Signaturausnahme im Adapter nötig;
  Online-Caches behalten ihre normale Signaturprüfung. Vertrauen setzt eine
  vertrauenswürdig bezogene ISO und einen nicht manipulierten Live-Store voraus.
- **Lokaler Signaturtest:** Frischer Ziel-Store, nur ISO-Pfade, kein Netzwerk,
  `require-sigs = true` und `local?root=/mnt&trusted=1`: Systembuild bestanden.
  Auch der Gesamtablauf ohne `--no-check-sigs` bestand: Flake-Archiv samt Inputs
  zuerst mit `nix-store --realise` über denselben vertrauenswürdigen lokalen
  Substituter übernehmen, anschließend Zielsystem bauen. Direktes `nix copy`
  ohne Signaturausnahme scheiterte dagegen an unsignierten Flake-Inputs;
  quellenbezogenes Substituter-Vertrauen gilt nicht automatisch für direkte
  Kopieraufrufe. Der Test verwendet die lokale Store-Variante statt `auto`
  und ist noch kein vollständiger Installationstest. Die Quellenübernahme
  im tatsächlichen `nixos-install`-Pfad bleibt separat zu validieren.

- **Abschließender VM-Test:** Neu gebaute ISO vollständig offline über Calamares
  installiert, ohne manuelle Flags oder globale Signaturabschaltung. Danach
  Systemstart, KDE und `gufo --version` erfolgreich. Online-Update der Inputs,
  Rebuild und anschließender Neustart ebenfalls erfolgreich (Benutzerbestätigung).
  Generalisierung, Live-Logging und getrennte Jobs wurden erst danach geändert
  und brauchen einen neuen ISO-Test. Weitere Hardware-/Sprach-/Modellvarianten
  und vollständiger Abgleich der sechs Gewichte bleiben offen.

#### Voraussetzungen und Diagnoseausgabe

Das separate `uefiwelcome`-Modul meldet UEFI als zwingende Voraussetzung bereits
auf der Willkommensseite. Bei BIOS-Start bleibt „Weiter“ gesperrt und der
Hinweis fordert einen Neustart im UEFI-Modus (bei VMs: UEFI/OVMF).
Die spätere Installer-Vorprüfung bleibt zusätzlich aktiv. Ein BIOS-Fallback ist
nicht vorgesehen. Die frühe Prüfung muss noch in der VM bestätigt werden.
Das C++-Modul lädt die unveränderte Calamares-Willkommensseite und ergänzt
deren Requirements über die offizielle ViewStep-Schnittstelle. Es gibt keine
zusätzliche Seite und keinen projektspezifischen Patch am Calamares-Quellcode.

Der Installer-Job nennt bei Fehlern die Phase und entweder den konkreten
Validierungsgrund oder den Programmnamen mit Exit-Code. Bei `unshare` und
`nixos-install` wird stattdessen der Systeminstallationsaufruf benannt:
Der Exit-Code allein unterscheidet Wrapper- und Kindprozessfehler nicht.
Ziel-Mounts, Konfiguration, Benutzerzugang, Systeminstallation und Modellkopie
haben eigene Diagnosephasen. Betriebssystemfehler
werden mit errno gemeldet. Befehlsargumente, Passwörter und Hashes werden nicht
in diese Diagnose übernommen. Jeder gestartete Adapter-Befehl wird nur mit
seinem Programmnamen in der Calamares-Ausgabe protokolliert.
`nixos-install` verwendet Calamares' öffentliche Prozess-Schnittstelle, um
seine Ausgabe während des Laufs an den Calamares-Logger weiterzugeben.
Die Anzeige unter „Toggle log“ muss mit der nächsten ISO noch geprüft werden.
Passwort- und Konfigurationsbefehle bleiben von diesem Streaming ausgeschlossen.
Andere Unterprozessausgaben gehen weiterhin an geerbte stdout/stderr-Streams;
das allein macht sie nicht im UI-Log sichtbar.
Diese Originalausgaben sind nicht sanitisiert; vor Weitergabe auf sensible
Daten prüfen. Es erfolgt kein automatischer Upload.
Der Fehlerdialog enthält einen Journal-Befehl ab Beginn des Adapter-Aufrufs.
Die erste Fehlermeldung prüfen, nicht nur spätere Nix-Abhängigkeitsfehler.
Fehler im Installationsjob warnen ausdrücklich, dass bereits partitioniert
wurde und die Installation unvollständig ist, auch bei erneuter Vorprüfung.
Beim automatisch gestarteten Installer kann diese Ausgabe im Journal der
Live-VM mit `sudo journalctl -b --no-pager` gelesen werden; nach
`Desktop installer` suchen. Die VM vor dem Sichern der Diagnose nicht neu starten.
Für einen manuell gestarteten Installer dessen Terminalausgabe sichern.

### Konfiguration ändern ohne Paketupdate

Die vollständige Konfiguration wird nach `/etc/nixos` kopiert, ergänzt um
`installation.json` (Benutzername, Hostname und Spracheinstellungen) und
`hardware-configuration.nix` (Hardware, Dateisysteme und LUKS-UUIDs).
Diese beiden Dateien sind keine Geheimnisse, enthalten aber gerätespezifische Daten.
Ein normales `nixos-rebuild` partitioniert oder formatiert nichts.

```bash
sudo nixos-rebuild switch --flake path:/etc/nixos#desktop
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
installiert aber noch keine vorhandene Flake wie unsere Desktop-Konfiguration.
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
Inzwischen verwenden wir Calamares mit einer Flake-Anbindung. Die Bewertung
von nixos-wizard kann bei funktionierendem Flake-Support neu geprüft werden.

## Aktuelle Bauumgebung

Mit daemonbasiertem Nix Store unter `/nix/store` und aktivierten Funktionen
`nix-command` und `flakes` lässt sich die ISO so bauen:

```bash
nix build .#iso
```

Der Gufo-Cache ist optional. Ohne ihn funktionieren Builds weiterhin, können
aber einen großen lokalen Gufo-/ROCm-Build erfordern.

### Gufo-Cache im Nix-Daemon freigeben

Auf einem NixOS-Build-Rechner im Systemmodul die gemeinsame Definition einbinden
(den absoluten Pfad an den eigenen Checkout anpassen):

```nix
{
  nix.settings = import /path/to/repository/modules/generative-ai/cache.nix;
}
```

Danach die Systemkonfiguration mit `sudo nixos-rebuild switch` aktivieren.
Auf anderen Distributionen lassen sich die Einträge aus derselben Datei erzeugen:

```bash
nix eval --json --file modules/generative-ai/cache.nix \
  | jq -r 'to_entries[] | "\(.key) = \(.value | join(" "))"'
```

Die Ausgabe in `/etc/nix/nix.conf` mit vorhandenen Einträgen zusammenführen.
Die Definition ergänzt Cache und Signaturschlüssel, ohne die Nix-Standards zu
ersetzen. `trusted-users` oder eine automatische Flake-Zustimmung sind nicht
nötig. Damit vertraut man den vom Gufo-Cache signierten Build-Ergebnissen.

**Nicht während eines laufenden ISO-Baus den Daemon neu starten.** Erst warten,
bis alle laufenden Nix-Bauten abgeschlossen sind, dann:

```bash
sudo systemctl restart nix-daemon.service
nix build .#offline-system --dry-run
```

Danach prüfen, ob Gufo/ROCm soweit verfügbar aus dem Cache eingeplant werden.
Die Konfiguration allein garantiert nicht, dass für jede
gesperrte Derivation bereits ein Cache-Ergebnis vorhanden ist.
