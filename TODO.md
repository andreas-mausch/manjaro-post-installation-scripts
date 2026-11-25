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
