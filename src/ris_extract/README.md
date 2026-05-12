## ris_extract

Small OCR-only endpoint for receipt images. There is no structured parsing yet, the output only contains raw OCR data:  

- `ocr.rawText`
- `ocr.blocks`
- `ocr.lines`

## Setup

Run everything  from `src/ris_extract`.

```bash
python3.11 -m venv venv
source venv/bin/activate
python -m pip install --upgrade pip
python -m pip install -r requirements.txt
```

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
uvicorn api:app --host 0.0.0.0 --port 8080
```

Health check:

```bash
curl http://localhost:8080/healthz
```

OCR request:

```bash
curl -X POST http://localhost:8080/v1/extractions \
  -F "requestId=ext_demo12345678" \
  -F "file=@../../data/receipt-1.png"
```

## Docker

Build:

```bash
docker build -t ris_extract .
```

Run:

```bash
docker run --rm -p 8080:8080 -v ./.model-cache:/root/.paddlex ris_extract
```
