# LocalAI mit PocketTTS German

> **Status 2026-10-30: abgelöst.** Die Sprachausgabe übernimmt das
> PocketTTS.cpp-Vulkan-Container-Setup in [`pockettts-gateway/`](pockettts-gateway/)
> (Host-Loopback :8081, Modellname `pocket-tts-german` bleibt als Drop-in identisch).
> Grund: Qualität und Tempo des 24l-April-Modells auf Vulkan
> (Vergleich: [`2026-10-30-benchmark.md`](2026-10-30-benchmark.md)).
> Dieses Dokument bleibt als Aufzeichnung des LocalAI-Setups erhalten.

<https://github.com/mudler/localai>

Der LocalAI-Dienst laeuft als Teil des Hermes-Stacks in
[`../hermes/compose.yaml`](../hermes/compose.yaml) (Service `localai`). Diese Datei
dokumentiert die TTS-seitigen Details; Start erfolgt vom Hermes-Verzeichnis:

```bash
cd ../hermes
docker compose up -d localai
docker compose logs -f localai
```

## Lokale Dateien

Die folgenden Dateien werden schreibgeschuetzt eingebunden und sind nicht in Git; sie
muessen vor dem ersten Start vorhanden sein, sonst startet der Container nicht
(absichtlich, `create_host_path: false`):

- `/srv/llama/models/pocket-tts/german/model.safetensors`: deutsche Cloning-Gewichte.
- `/srv/llama/models/pocket-tts/german/tokenizer.json`: passender Tokenizer.
- `sample.wav` (hier im Verzeichnis): deine Standard-Referenzstimme.

Die Referenzstimme liegt im Container unter `/references/sample.wav`, ausserhalb von `/models`, damit LocalAI sie nicht als eigenstaendiges Modell auflistet.

`tokenizer.model` wird fuer diesen deutschen Checkpoint nicht verwendet und bleibt unveraendert liegen.

Die beiden Modell-Dateien werden direkt an den von der installierten PocketTTS-Konfiguration erwarteten Hugging-Face-Snapshot-Pfaden eingebunden. `HF_HUB_OFFLINE=1` verhindert Modelldownloads. Ein HF-Token ist weder erforderlich noch in Compose enthalten. Die deutsche Architektur-Konfiguration stammt aus dem Backend-Paket.

Der Backend wird automatisch installiert; dafuer kann beim ersten Start Internetzugriff erforderlich sein. Die persistenten Volumes sind explizit benannt (`localai-models`, `localai-backends`, `localai-configuration`, `localai-data`) und haengen damit nicht am Compose-Projektnamen. LocalAI ist auf `v4.12.1` festgelegt, der separat installierte Backend stammt aus dem aktuellen Backend-Katalog. Falls eine zukuenftige Backend-Version andere Snapshot-Revisionen erwartet, muessen die eingebundenen Cache-Pfade angepasst werden; der Offline-Modus verhindert dann einen stillen neuen Modelldownload.

Modell und Referenzstimme werden beim Start vorgeladen. Das Referenz-Preload kann bei Fehlern im Backend nur eine Warnung ausgeben: der Healthcheck prueft Server-Bereitschaft, nicht gelungenes Cloning. Deshalb gehoert ein erfolgreicher TTS-Aufruf zur Funktionspruefung.

## Test

WebUI und API: http://localhost:8081 — auf dem Host ist Port 8080 belegt (gufo),
deshalb published LocalAI auf 8081. Im Compose-Netz des Hermes-Stacks ist der Dienst unter
`http://localai:8080` erreichbar. Modellname: `pocket-tts-german`.

```bash
curl --fail-with-body http://localhost:8081/v1/audio/speech \
  -H 'Content-Type: application/json' \
  -d '{"model":"pocket-tts-german","input":"Hallo, sag mal etwas zu mir.","response_format":"wav"}' \
  --output localai-pocket-test.wav
```

Ein `voice`-Parameter ist fuer die Standard-Referenzstimme nicht erforderlich. Andere lokale Referenzdateien muessen zusaetzlich eingebunden werden. Vorgefertigte Stimmen, deren Embeddings nicht lokal vorliegen, sind im Offline-Modus nicht verfuegbar.

### Ogg-Ausgabe

Dieser Aufruf wurde am 2026-10-29 mit dem laufenden Setup getestet (Port 8080, eigenstaendiger Compose; heute gilt 8081):

```bash
curl --fail-with-body http://localhost:8081/v1/audio/speech \
  -H 'Content-Type: application/json' \
  -d '{
    "model": "pocket-tts-german",
    "input": "Hallo, sag mal etwas zu mir.",
    "response_format": "opus"
  }' \
  --output localai-pocket-test.ogg
```

Wichtig: `response_format: "ogg"` lieferte in diesem Setup eine WAV-Datei (`Content-Type: audio/wav`). Mit `"opus"` wurde dagegen Ogg geliefert (`Content-Type: audio/ogg`), jedoch laut `ffprobe` mit **Vorbis-Codec, nicht Opus**. Der Parametername garantiert hier also nicht den Codec.

Das gepruefte Ergebnis hatte 24.000 Hz, einen Kanal und 2,08 Sekunden Audiodauer. Die gesamte API-Anfrage dauerte 0,978 Sekunden; dies ist eine einzelne Messung, keine garantierte Laufzeit.

Container und Codec lassen sich pruefen mit:

```bash
ffprobe -v error \
  -show_entries format=format_name,duration:stream=codec_name,sample_rate,channels \
  -of json localai-pocket-test.ogg
```

## Anbindung an Hermes

Der hermes-agent kann LocalAI als OpenAI-kompatiblen TTS-Provider nutzen
(`tts.provider=openai` -> `http://localai:8080/v1`, Modell `pocket-tts-german`).
Die konkreten `config set`-Kommandos stehen in
[`../hermes/README.md`](../hermes/README.md), Abschnitt 6. Hinweis: Die Agent-seitige
Sprachausgabe (Auto-TTS im Chat) ist mit LocalAI noch nicht Ende-zu-Ende getestet;
getestet ist die LocalAI-API direkt (siehe oben).

## Betrieb

`docker compose stop localai` (aus `../hermes`) haelt den Rest des Stacks untouched; alle
Compose-`down`-Kommandos von `../hermes` aus betreffen den gesamten Hermes-Stack. Volumes
bleiben bei `down` erhalten; `down -v` loescht die Docker-Volumes (inkl.
`localai-backends`) — die Modell-Dateien unter `/srv` und `sample.wav` werden dadurch
nicht geloescht.

Docker Compose >= 2.23.1 ist fuer die eingebettete Config erforderlich. Keine GPU-Freigabe und keine nachtraegliche Tempoanpassung. Ein `threads`-Flag wurde bewusst nicht gesetzt: Der direkte Wrapper garantiert damit keine entsprechende PyTorch-Threadzahl, PocketTTS setzt aktuell selbst einen Intraop-Thread.
