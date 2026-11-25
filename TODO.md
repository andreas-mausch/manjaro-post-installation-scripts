# Vorbereitung

- [ ] ISO bauen und Boot/Installation in einer VM prüfen.
- [ ] Gufo-GPU und Modell auf dem echten M5 prüfen (nicht in einer VM möglich).

## Erledigt

- [x] 2026-11-25: Partitionierung, LUKS2 und Dateisysteme an gepinntes Disko delegieren; Wrapper auf Bedienung und Installation reduzieren.
- [x] 2026-11-25: Python-Installer durch Shell mit NixOS-/Linux-Bordmitteln ersetzen; LUKS-Passphrase direkt mit cryptsetup abfragen.
- [x] 2026-11-25: Gepinnte Modelldownloads in den ISO-Bau aufnehmen; Installer kopiert Modelle vom Stick statt sie herunterzuladen.
- [x] 2026-11-25: Flake, Desktop-Konfiguration und interaktiven LUKS2-Installer anlegen.
- [x] 2026-11-25: Separaten rootlosen Store nutzen und flake.lock erzeugen.
- [x] 2026-11-25: Flake erfolgreich auswerten, Nix-Dateien formatieren und Installer-Tests ausführen.
