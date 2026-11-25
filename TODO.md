# Vorbereitung

## Als Nächstes: verifizierten Offline-Fix in den Installer übernehmen

1. [x] 2026-11-25: Im Adapter `substitute = true` und `always-allow-substitutes = true` ausschließlich als Installationsoptionen setzen; lokalen ISO-Store und konfigurierte Online-Quellen erhalten. Keine dauerhafte Zielsystemeinstellung.
2. [ ] Signaturbehandlung im ISO-Test bestätigen: `nixos-install` vertraut bereits nur dem lokalen Live-Substituter; keine globale Signaturabschaltung. Lokaler Systembuild mit aktiver Signaturprüfung bestand, vollständiger Installationspfad noch offen.
3. [ ] Reproduzierbaren lokalen Offline-Systembuild-Test mit getrenntem Live-/Ziel-Store ergänzen: nur ISO-Inhalte, kein Netzwerk, pro Variante frischer Ziel-Store; mit/ohne LUKS und abweichender Benutzer-/Hardwarekonfiguration. Kein Root-Test auf dem Host und keine zusätzliche Test-VM; echte Installation und Boot direkt mit der ISO in der vorhandenen VM prüfen.
4. [ ] Nach bestandenen Tests committen; erst danach die ISO neu bauen.
5. [ ] Vollständigen Calamares-Durchlauf ohne manuelle Terminalbefehle, Boot ohne ISO und anschließendes Online-Update prüfen.

Stand: Manueller Offline-VM-Installationslauf, LUKS-Entsperrung und KDE-Start ohne ISO erfolgreich; sichere Signaturstrategie und vollständiger grafischer Durchlauf noch offen.

## Danach: modulare ISO-Varianten

- [ ] Erst den laufenden ISO-/Calamares-Installationstest abschließen; anschließend AI- und Gaming-Funktionen in kombinierbare NixOS-Module (`generative-ai.nix`, `gaming.nix`) auslagern. AI-Modul bündelt Gufo, LLM-/NPU-Unterstützung und die sechs Qwen-Modelle. Benannte Desktop-, AI-, Gaming- und Full-ISO-Ausgaben in derselben Flake anbieten; Modulzusammenstellung für Updates im Zielsystem erhalten. Calamares-Option „Copy weights“ nur bei enthaltenem AI-Modul in die ISO aufnehmen; Kopieren auf das Ziel bleibt optional. Ohne AI-Modul keine AI-spezifischen Pakete oder Modellgewichte auf der ISO. Keine Calamares-Patches.

## Weitere Vorbereitung

- [ ] Isolierten Offline-Assembly-Test reproduzierbar ins Repository übernehmen und vor jeder ISO-Freigabe verpflichtend ausführen; pro Variante frischen Store verwenden. Automatische Werkzeugableitung verbessern, statt langfristig nur eine manuelle Liste zu pflegen.

- [ ] Neue Diagnosephasen, Journal-Zeitfilter und Warnung zum bereits partitionierten Ziel bei einem realen VM-Installationsfehler prüfen; Originalausgabe muss die erste Nix-Fehlermeldung enthalten.

- [ ] Swap-Unterstützung vor Freigabe ergänzen: `nixos-generate-config` erfasst nur aktive Swap-Partitionen und keine Swapdateien; Calamares erstellt Swapdateien im hier nicht ausgeführten fstab-Modul. Zielgerätezuordnung und verschlüsselten Swap beim Neustart prüfen. Bis dahin bleibt „kein Swap“ erhalten.

- [ ] Installation mit und ohne LUKS2 in einer UEFI-VM testen; Calamares muss bei aktivierter Verschlüsselung leere oder unterschiedliche Passphrasen vor der Installation abfangen.

- [ ] UEFI-Voraussetzung auf der Calamares-Willkommensseite in BIOS- und UEFI-VM testen; BIOS muss „Weiter“ vor der Partitionierung sperren.

- [ ] Nach Offline-Installation in der VM Online-Update mit `nix flake update` und Rebuild prüfen; lokale Locks müssen wieder über die ursprünglichen GitHub-Inputs aktualisierbar sein.

- [ ] ISO bauen und Boot/Installation in einer VM prüfen.
- [ ] Offline-Installation in UEFI-VM ohne Netzwerkkarte mit abweichendem Benutzer, Sprache und generierten UUIDs vollständig prüfen; fehlende lokale Assemblierungsabhängigkeiten ergänzen.
- [ ] Gufo-GPU und Modell auf dem echten M5 prüfen (nicht in einer VM möglich).

## Erledigt

- [x] 2026-11-25: Offline-Assembly-Lücke dokumentieren und nach gezielter Ergänzung fertiger Werkzeuge beide Varianten im isolierten Store erfolgreich bauen (abweichende Identität/UUIDs/VirtIO, mit/ohne LUKS). Äußere Store-/Netzwerk-Isolation aktiv, innere Nix-Sandbox wegen UID-Mapping-Beschränkung deaktiviert; kein Installations-/Boot-Nachweis.

- [x] 2026-11-25: UEFI-Requirement als separates C++-Welcome-Modul implementieren, vorhandene UI/Prüfungen delegieren und den verworfenen Partitionierungs-Patch entfernen. Paketbuild geprüft; UI-/Firmware-Test in VM steht aus.

- [x] 2026-11-25: M5-Fehlerdiagnose mit Phase, Validierungsgrund bzw. Programm/Exit-Code und geheimnisfreien Logmeldungen ergänzen; Adapter-Tests erweitern. Journal-Ausgabe im VM-Test noch prüfen.

- [x] 2026-11-25: Im Offline-VM-Test entdeckte Internet-Pflichtprüfung der Calamares-Willkommensseite entfernen; RAM-/Speicherprüfungen beibehalten. Neue ISO und erneuter VM-Test erforderlich.

- [x] 2026-11-25: Native Calamares-Auswahl für optionales Kopieren der Qwen-Gewichte ergänzen (standardmäßig mit Gewichten); Adapter-Tests für beide Varianten. VM-Prüfung steht aus.

- [x] 2026-11-25: Gufo-Cache und Signaturschlüssel im Nix-Daemon freigegeben und Cache-Nutzung per Dry-run geprüft; ROCm wird geladen, Gufo selbst bleibt ein lokaler Build.

- [x] 2026-11-25: Offline-Referenzsystem, lokale Flake-Locks und gezielte Assemblierungswerkzeuge in die ISO aufnehmen; Installation ohne externe Netzwerkverbindung erzwingen. Keine vollständige Kernel-/ROCm-Build-Closure mitnehmen.
- [x] 2026-11-25: Calamares-Root-Dateisystem auf Btrfs in LUKS2 mit zstd-Kompression umstellen, zunächst ohne zusätzliche Subvolumes oder Snapshot-Automatik.
- [x] 2026-11-25: Disko und disko-install entfernen; vorhandene grafische NixOS-Calamares-ISO mit M5-Flake-/Modell-Anbindung verwenden. Laufenden alten ISO-Bau für Downloads unangetastet lassen.
- [x] 2026-11-25: disko-install für Provisionierung, Systeminstallation und Zusatzdateien verwenden statt disko und nixos-install selbst zu orchestrieren.
- [x] 2026-11-25: Partitionierung, LUKS2 und Dateisysteme an gepinntes Disko delegieren; Wrapper auf Bedienung und Installation reduzieren.
- [x] 2026-11-25: Python-Installer durch Shell mit NixOS-/Linux-Bordmitteln ersetzen; LUKS-Passphrase direkt mit cryptsetup abfragen.
- [x] 2026-11-25: Gepinnte Modelldownloads in den ISO-Bau aufnehmen; Installer kopiert Modelle vom Stick statt sie herunterzuladen.
- [x] 2026-11-25: Flake, Desktop-Konfiguration und interaktiven LUKS2-Installer anlegen.
- [x] 2026-11-25: Separaten rootlosen Store nutzen und flake.lock erzeugen.
- [x] 2026-11-25: Flake erfolgreich auswerten, Nix-Dateien formatieren und Installer-Tests ausführen.
