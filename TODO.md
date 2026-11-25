# Vorbereitung

- [ ] ISO bauen und Boot/Installation in einer VM prüfen.
- [ ] Offline-Installation in UEFI-VM ohne Netzwerkkarte mit abweichendem Benutzer, Sprache und generierten UUIDs vollständig prüfen; fehlende lokale Assemblierungsabhängigkeiten ergänzen.
- [ ] Gufo-GPU und Modell auf dem echten M5 prüfen (nicht in einer VM möglich).

## Erledigt

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
