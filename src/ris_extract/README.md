## ris_extract

OCR extraction service for receipt images with optional structured parsing through OpenAI Responses API.

Current output includes:

- `ocr.rawText`
- `ocr.blocks`
- `ocr.lines`
- `structured.lineItems`
- `structured.merchantInfo`
- `structured.qrcode_tse_data`

## Setup

Run everything  from `src/ris_extract`.

```bash
python3.11 -m venv venv
source venv/bin/activate
python -m pip install --upgrade pip
python -m pip install -r requirements.txt
```

Optional environment:

```bash
export OPEN_AI_TOKEN=your-token
```

If `OPEN_AI_TOKEN` is not set, OCR still works and the service returns warnings instead of failing the whole extraction.

## CLI

```bash
python ris_extract.py ../../data/receipt-1.png --request-id ext_demo12345678
```

With file output:

```bash
python ris_extract.py ../../data/receipt-1.png --request-id ext_demo12345678 --output result.json
```

## API

Start it like this:

```bash
uvicorn api:app --host 0.0.0.0 --port 8081
```

Health check:

```bash
curl http://localhost:8081/healthz
```

OCR request:

```bash
curl -X POST http://localhost:8081/v1/extractions \
  -F "requestId=ext_demo12345678" \
  -F "file=@../../data/receipt-1.png"
```

## Notes

- The service uses `ocr.lines[].text` as prompt text for OpenAI.
- If a TSE QR code is found, the raw TSE payload is added to both structured extraction prompts.
- Only TSE QR payloads in the MVP format `V0;...;Kassenbeleg-V1;...` are parsed.
- Generic QR codes are ignored.

## Docker

Build:

```bash
docker build -t ris_extract .
```

Run:

```bash
docker run --rm -p 8081:8081 -v ./.model-cache:/root/.paddlex -e OPEN_AI_TOKEN="$OPEN_AI_TOKEN" ris_extract
```
