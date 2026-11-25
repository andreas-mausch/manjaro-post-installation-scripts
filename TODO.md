# Vorbereitung

Stand: Der bisherige Offline-Calamares-Test in der vorhandenen UEFI-VM ist abgeschlossen: Installation ohne manuelle Flags, anschließender Systemstart, KDE und Gufo sowie Online-Update, Rebuild und Neustart erfolgreich. Benutzerbestätigter Nachweis für diese VM-Variante; Generalisierung, Live-Logging und getrennte Jobs sind noch nicht in einer neuen ISO geprüft.

## Als Nächstes: modulare ISO-Varianten

- [ ] AI- und Gaming-Funktionen in kombinierbare NixOS-Module (`generative-ai.nix`, `gaming.nix`) auslagern. AI-Modul bündelt Gufo, LLM-/NPU-Unterstützung und die sechs Qwen-Modelle. Benannte Desktop-, AI-, Gaming- und Full-ISO-Ausgaben in derselben Flake anbieten; Modulzusammenstellung für Updates im Zielsystem erhalten. Calamares-Option „Copy weights“ nur bei enthaltenem AI-Modul in die ISO aufnehmen; Kopieren auf das Ziel bleibt optional. Ohne AI-Modul keine AI-spezifischen Pakete oder Modellgewichte auf der ISO. Keine Calamares-Patches.

- [ ] Danach neue ISO bauen und generalisierte Konfiguration, modulare Auswahl, Live-Logging und getrennte Installations-/Modelljobs direkt in der vorhandenen VM offline prüfen; Boot ohne ISO und Online-Update samt Neustart erneut testen.

## Weitere Vorbereitung

- [ ] UKI-Direktboot für das installierte System vorbereiten: UEFI startet das Unified Kernel Image ohne systemd-boot/GRUB. UKI-Erzeugung, Installation auf der EFI-Partition, UEFI-Booteinträge und sichere Updates mit Rückfall-/Recovery-Möglichkeit für vorherige Generationen umsetzen und testen. Grafische LUKS-Passwortabfrage über Plymouth in der Initrd integrieren; Theme, frühe GPU-Treiber und Passwort-/Textfallback auf Zielhardware prüfen. Plymouth ist unabhängig vom UKI-Direktboot nutzbar. Keine automatische LUKS-Entsperrung; Secure-Boot-Signierung ist ein separates Vorhaben.

- [ ] Getrennte Calamares-Jobs „Install NixOS“ und „Copy model weights“ mit der nächsten ISO prüfen: eigene Titel/Fortschrittsgewichte, Modelljob ohne gewählte Gewichte ohne Kopie, Modellfehler ohne Aufforderung zur erneuten Systeminstallation.

- [ ] Live-Ausgabe von `nixos-install` im Calamares-Fenster „Toggle log“ mit der nächsten ISO prüfen: öffentliche Prozess-Schnittstelle statt nur geerbter stdout/stderr-Streams. Keine Passwort-/Konfigurationsbefehle ins UI-Log weiterreichen.

- [ ] Isolierten Offline-Systembuild-/Assembly-Test reproduzierbar ins Repository übernehmen und vor jeder ISO-Freigabe verpflichtend ausführen: getrennte Live-/Ziel-Stores, nur ISO-Inhalte, kein Netzwerk, pro Variante frischer Ziel-Store; mit/ohne LUKS und abweichender Benutzer-/Hardwarekonfiguration. Kein Root-Test auf dem Host und keine zusätzliche Test-VM; echter Installations-/Bootnachweis direkt mit der ISO in der vorhandenen VM. Automatische Werkzeugableitung verbessern, statt langfristig nur eine manuelle Liste zu pflegen.

- [ ] Neue Diagnosephasen, Journal-Zeitfilter und Warnung zum bereits partitionierten Ziel bei einem realen VM-Installationsfehler prüfen; Originalausgabe muss die erste Nix-Fehlermeldung enthalten.

- [ ] Swap-Unterstützung vor Freigabe ergänzen: `nixos-generate-config` erfasst nur aktive Swap-Partitionen und keine Swapdateien; Calamares erstellt Swapdateien im hier nicht ausgeführten fstab-Modul. Zielgerätezuordnung und verschlüsselten Swap beim Neustart prüfen. Bis dahin bleibt „kein Swap“ erhalten.

- [ ] Weitere Installationsvarianten prüfen: unverschlüsseltes Ziel sowie leere oder unterschiedliche LUKS-Passphrasen; Calamares muss ungültige Passphrasen vor der Installation abfangen. Verschlüsselter Basislauf ist bestanden.

- [ ] UEFI-Voraussetzung auf der Calamares-Willkommensseite in BIOS- und UEFI-VM testen; BIOS muss „Weiter“ vor der Partitionierung sperren.

- [ ] Weitere Offline-Varianten mit abweichender Sprache und beiden Modellkopieroptionen vollständig prüfen; alle sechs kopierten Modell-Dateien mit dem Manifest vergleichen. Der erfolgreiche Basislauf deckt diese Varianten und den Datei-Abgleich nicht vollständig ab.
- [ ] Gufo-GPU und Modell auf geeigneter echter Hardware prüfen (nicht in einer VM ohne GPU-Durchreichung möglich).

## Erledigt

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
