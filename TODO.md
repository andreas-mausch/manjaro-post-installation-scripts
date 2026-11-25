# Vorbereitung

Stand: Der bisherige Offline-Calamares-Test in der vorhandenen UEFI-VM ist abgeschlossen: Installation ohne manuelle Flags, anschließender Systemstart, KDE und Gufo sowie Online-Update, Rebuild und Neustart erfolgreich. Benutzerbestätigter Nachweis für diese VM-Variante; Generalisierung, Live-Logging und getrennte Jobs sind noch nicht in einer neuen ISO geprüft.

## Als Nächstes: modulare ISO-Varianten

- [ ] Neue Base-/Desktop-/AI-/Gaming-/Full-Varianten im Offline-Installationslauf bestätigen; lokale Modul-/Installer-/Archivtests ersetzen keinen Installationsnachweis.

- [ ] Danach neue ISO bauen und generalisierte Konfiguration, modulare Auswahl, Live-Logging und getrennte Installations-/Modelljobs direkt in der vorhandenen VM offline prüfen; Boot ohne ISO und Online-Update samt Neustart erneut testen.

## Weitere Vorbereitung

- [ ] NixOS-Varianten direkt als wiederverwendbare libvirt-Basisimages bereitstellen können: zusätzliche QCOW2-Flake-Outputs aus denselben Zielmodulen erzeugen, beispielsweise mit `nixos-generators`. Umsetzung unter `modules/virtualization/` einordnen; Bootmodus, virtuelle Hardware und Erstzugang konfigurieren. Individuelle Identität und Geheimnisse nicht ins Basisimage einbauen; cloud-init für die Erstkonfiguration prüfen. Image-/Zielsystemtests ersetzen keinen ISO-/Calamares-Installationsnachweis.

- [ ] Die enthaltenen Softwarekomponenten jeder Variante nachvollziehen und extern prüfen können: SBOMs für Zielsystem und Live-ISO als separate Build-Ausgaben bereitstellen. `sbomnix` mit CycloneDX-/SPDX-Ausgabe prüfen; Live-Installer-Werkzeuge vom Zielsystem unterscheiden. Optionale Modellgewichte mit Herkunft, Lizenz und Prüfsummen erfassen und dafür `modules/generative-ai/models.lock.json` nutzen. Vollständigkeit und Grenzen der erfassten Komponenten und Lizenzdaten dokumentieren; eine SBOM ist kein Sicherheitsnachweis.

- [ ] Eine Arbeitsstation passend zu ihren Aufgaben zusammenstellen können, ohne für jede Kombination eine eigene ISO pflegen zu müssen. Weitere kombinierbare Module aus dem bisherigen Manjaro-Setup ableiten:
  - Development: Git mit lazygit/tig/delta, Editoren, Sprachserver, Meld, Zeal sowie HTTP-/Datenwerkzeuge; projektspezifische Compiler und SDKs bevorzugt über `nix develop` bereitstellen.
  - Virtualization: QEMU, libvirt und virt-manager samt benötigten Diensten und Berechtigungen.
  - Media: mpv, Audacity, HandBrake, Videoschnitt, yt-dlp und Metadatenwerkzeuge.
  - Documents: E-Book-/PDF-/Comic-Reader sowie OCR mit deutschen und englischen Sprachdaten.
  - Security tools: GnuPG, pass, OpenPGP-Karten- und Zertifikatswerkzeuge; keine persönlichen Schlüssel oder Geheimnisse ins Repository aufnehmen.
  - Desktop utilities: Dateisuche, Rechner, GPXSee und praktische Dateiverwaltungswerkzeuge.
  - Tool-Installation und zugehörige Lieblingskonfiguration thematisch zusammenhalten, beispielsweise unter `modules/git/`: `system.nix` installiert Git/tig/lazygit/delta systemweit, `home.nix` verwaltet die Benutzerkonfiguration und Aliase mit Home Manager. Zuständigkeiten und Paketversionen bei automatisch durch Home Manager installierten Programmen abstimmen. XFCE-/X11-spezifische Lösungen nicht blind nach KDE/Wayland übernehmen, Hardware-Workarounds beim jeweiligen PC belassen.
  - Bestehende Varianten als Voreinstellungen erhalten; später eine Modulauswahl im Installer prüfen. Desktop + Development + Virtualization als mögliche Arbeitsstation mit optionalem Gaming und AI berücksichtigen.

- [ ] Einen installierten PC auf den neuen Stand dieses Repositories bringen können, ohne Neuinstallation und ohne seine Hardware- oder Benutzerdaten ins Entwicklungsrepo kopieren zu müssen. Dafür bleibt die PC-Konfiguration unter `/etc/nixos` und bindet die wiederverwendbaren Setup-Module als gepinnten Flake-Input ein. Die bisherigen relativen Hardware-/Identitätsimporte anpassen; auch Updates aus einem lokalen Checkout ohne `--impure` unterstützen. Ablauf dokumentieren und testen.

- [ ] Gemeinsame Releases der Flake und ihrer Base-/Desktop-/Gaming-/AI-Module über Git-Tags (z. B. `v0.1.0`) einführen; optional dieselbe explizite Releaseversion im ISO-Dateinamen verwenden. Kein automatisch ermitteltes Builddatum und keine Änderung von `system.stateVersion` zur Projektversionierung.

- [ ] Variantenabhängige Calamares-Konfigurationspfade auch für Base/Desktop/Gaming ohne Modellauswahl und AI mit Modellauswahl direkt in der Live-GUI prüfen; Full ist bestätigt.

- [ ] Später einen geeigneten TUI-Installer als Alternative zur grafischen Live-Umgebung prüfen; Zielmodule unabhängig von der Installationsoberfläche halten.

- [ ] UKI-Direktboot für das installierte System vorbereiten: UEFI startet das Unified Kernel Image ohne systemd-boot/GRUB. UKI-Erzeugung, Installation auf der EFI-Partition, UEFI-Booteinträge und sichere Updates mit Rückfall-/Recovery-Möglichkeit für vorherige Generationen umsetzen und testen. Grafische LUKS-Passwortabfrage über Plymouth in der Initrd integrieren; Theme, frühe GPU-Treiber und Passwort-/Textfallback auf Zielhardware prüfen. Plymouth ist unabhängig vom UKI-Direktboot nutzbar. Keine automatische LUKS-Entsperrung; Secure-Boot-Signierung ist ein separates Vorhaben.

- [ ] Isolierten Offline-Systembuild-/Assembly-Test reproduzierbar ins Repository übernehmen und vor jeder ISO-Freigabe verpflichtend ausführen: getrennte Live-/Ziel-Stores, nur ISO-Inhalte, kein Netzwerk, pro Variante frischer Ziel-Store; mit/ohne LUKS und abweichender Benutzer-/Hardwarekonfiguration. Kein Root-Test auf dem Host und keine zusätzliche Test-VM; echter Installations-/Bootnachweis direkt mit der ISO in der vorhandenen VM. Automatische Werkzeugableitung verbessern, statt langfristig nur eine manuelle Liste zu pflegen.

- [ ] Neue Diagnosephasen, Journal-Zeitfilter und Warnung zum bereits partitionierten Ziel bei einem realen VM-Installationsfehler prüfen; Originalausgabe muss die erste Nix-Fehlermeldung enthalten.

- [ ] Swap-Unterstützung vor Freigabe ergänzen: `nixos-generate-config` erfasst nur aktive Swap-Partitionen und keine Swapdateien; Calamares erstellt Swapdateien im hier nicht ausgeführten fstab-Modul. Zielgerätezuordnung und verschlüsselten Swap beim Neustart prüfen. Bis dahin bleibt „kein Swap“ erhalten.

- [ ] Weitere Installationsvarianten prüfen: unverschlüsseltes Ziel sowie leere oder unterschiedliche LUKS-Passphrasen; Calamares muss ungültige Passphrasen vor der Installation abfangen. Verschlüsselter Basislauf ist bestanden.

- [ ] UEFI-Voraussetzung auf der Calamares-Willkommensseite in BIOS- und UEFI-VM testen; BIOS muss „Weiter“ vor der Partitionierung sperren.

- [ ] Weitere Offline-Varianten mit abweichender Sprache und beiden Modellkopieroptionen vollständig prüfen; alle sechs kopierten Modell-Dateien mit dem Manifest vergleichen. Der erfolgreiche Basislauf deckt diese Varianten und den Datei-Abgleich nicht vollständig ab.
- [ ] Gufo-GPU und Modell auf geeigneter echter Hardware prüfen (nicht in einer VM ohne GPU-Durchreichung möglich).

## Erledigt

- [x] 2026-11-25: Benutzer bestätigt die verbleibenden Fälle der getrennten Calamares-Jobs als erledigt: ohne gewählte Gewichte keine Kopie, Modellfehler ohne Aufforderung zur erneuten Systeminstallation sowie eigene Titel und Übergang zwischen Systeminstallation und Modellkopie. Fortschrittsanzeige mit der neuen Full-ISO ebenfalls bestätigt.

- [x] 2026-11-25: Benutzer bestätigt mit der neuen Full-ISO in der vorhandenen VM funktionierende Live-Logausgabe, Fortschrittsanzeige der Modellkopie und korrektes neues Modellverzeichnis. Kein Prüfsummennachweis für die sechs Dateien und keine Bestätigung von Kopierfehlerbehandlung oder Installation ohne Modellkopie.

- [x] 2026-11-25: Separaten Calamares-Wrapper mit der neuen Full-ISO in der vorhandenen VM geprüft: Benutzer bestätigt Autostart, erneuten Desktop-Start über Polkit, korrekt dargestellte grafische Umgebung und sichtbare optionale Modellauswahl. GUI-Nachweis für Full; kein Installationsnachweis und keine Bestätigung der übrigen Varianten.

- [x] 2026-11-25: Desktop-ISO in der vorhandenen VM installiert; Benutzer bestätigt erfolgreichen Installationslauf sowie erwartungsgemäß fehlendes Steam und Gufo. Kein Nachweis für andere Varianten, Offline-Netzwerkisolation, Boot ohne ISO oder Online-Update aus dieser Rückmeldung. Die Korrektur der Prozessausgabe im „Toggle log“ ist nicht in dieser ISO enthalten und bleibt separat zu prüfen.

- [x] 2026-11-25: Module `base.nix`, `desktop.nix`, `gaming.nix` und `generative-ai.nix` mit Imports strukturieren; fünf ISO-Ausgaben anbieten. KDE/Calamares bleiben bei Base nur in der Live-Umgebung. Gufo-Inputs, Gewichte, Modell-Auswahl und Kopierjob nur bei AI/Full archivieren. Zielvariante für Rebuilds erhalten und in `installation.json` dokumentieren. Lokale Tests ergänzen; neue ISO-/VM-Prüfung bleibt offen.

- [x] 2026-11-25: Im Adapter `substitute = true` und `always-allow-substitutes = true` ausschließlich als Installationsoptionen setzen; lokalen ISO-Store und konfigurierte Online-Quellen erhalten. Keine dauerhafte Zielsystemeinstellung. Fix committed und ISO neu gebaut.

- [x] 2026-11-25: Vollständigen Offline-Calamares-Lauf ohne manuelle Terminalbefehle oder Signaturabschaltung in der vorhandenen UEFI-VM abschließen; lokaler Live-Substituter bleibt quellenbezogen vertrauenswürdig. Anschließender Systemstart, KDE und Gufo erfolgreich. Nachweis für die bisherige ISO, nicht für spätere Repo-Änderungen oder beliebige Hardware.

- [x] 2026-11-25: Nach Offline-Installation in der vorhandenen VM Online-Update mit `nix flake update` und anschließendem `nixos-rebuild switch` mit dem bisherigen Flake-Ziel aus `/etc/nixos` erfolgreich ausgeführt; GitHub-Quellen wurden wieder erreicht. Neustart der aktualisierten Generation erfolgreich (Benutzerbestätigung). Nachweis gilt für die installierte bisherige Konfiguration, nicht für die anschließend generalisierte Repo-Version.

- [x] 2026-11-25: Offline-Assembly-Lücke dokumentieren und nach gezielter Ergänzung fertiger Werkzeuge beide Varianten im isolierten Store erfolgreich bauen (abweichende Identität/UUIDs/VirtIO, mit/ohne LUKS). Äußere Store-/Netzwerk-Isolation aktiv, innere Nix-Sandbox wegen UID-Mapping-Beschränkung deaktiviert; kein Installations-/Boot-Nachweis.

- [x] 2026-11-25: UEFI-Requirement als separates C++-Welcome-Modul implementieren, vorhandene UI/Prüfungen delegieren und den verworfenen Partitionierungs-Patch entfernen. Paketbuild geprüft; UI-/Firmware-Test in VM steht aus.

- [x] 2026-11-25: Installer-Fehlerdiagnose mit Phase, Validierungsgrund bzw. Programm/Exit-Code und geheimnisfreien Logmeldungen ergänzen; Adapter-Tests erweitern. Journal-Ausgabe im VM-Test noch prüfen.

- [x] 2026-11-25: Im Offline-VM-Test entdeckte Internet-Pflichtprüfung der Calamares-Willkommensseite entfernen; RAM-/Speicherprüfungen beibehalten. Neue ISO und erneuter VM-Test erforderlich.

- [x] 2026-11-25: Native Calamares-Auswahl für optionales Kopieren der Qwen-Gewichte ergänzen (standardmäßig mit Gewichten); Adapter-Tests für beide Varianten. VM-Prüfung steht aus.

- [x] 2026-11-25: Gufo-Cache und Signaturschlüssel im Nix-Daemon freigegeben und Cache-Nutzung per Dry-run geprüft; ROCm wird geladen, Gufo selbst bleibt ein lokaler Build.

- [x] 2026-11-25: Offline-Referenzsystem, lokale Flake-Locks und gezielte Assemblierungswerkzeuge in die ISO aufnehmen; Installation ohne externe Netzwerkverbindung erzwingen. Keine vollständige Kernel-/ROCm-Build-Closure mitnehmen.
- [x] 2026-11-25: Calamares-Root-Dateisystem auf Btrfs in LUKS2 mit zstd-Kompression umstellen, zunächst ohne zusätzliche Subvolumes oder Snapshot-Automatik.
- [x] 2026-11-25: Disko und disko-install entfernen; vorhandene grafische NixOS-Calamares-ISO mit Flake-/Modell-Anbindung verwenden. Laufenden alten ISO-Bau für Downloads unangetastet lassen.
- [x] 2026-11-25: disko-install für Provisionierung, Systeminstallation und Zusatzdateien verwenden statt disko und nixos-install selbst zu orchestrieren.
- [x] 2026-11-25: Partitionierung, LUKS2 und Dateisysteme an gepinntes Disko delegieren; Wrapper auf Bedienung und Installation reduzieren.
- [x] 2026-11-25: Python-Installer durch Shell mit NixOS-/Linux-Bordmitteln ersetzen; LUKS-Passphrase direkt mit cryptsetup abfragen.
- [x] 2026-11-25: Gepinnte Modelldownloads in den ISO-Bau aufnehmen; Installer kopiert Modelle vom Stick statt sie herunterzuladen.
- [x] 2026-11-25: Flake, Desktop-Konfiguration und interaktiven LUKS2-Installer anlegen.
- [x] 2026-11-25: Separaten rootlosen Store nutzen und flake.lock erzeugen.
- [x] 2026-11-25: Flake erfolgreich auswerten, Nix-Dateien formatieren und Installer-Tests ausführen.
