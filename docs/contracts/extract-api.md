# Extraction Service API Contract

## 1. Purpose

This document describes the current HTTP contract for `ris_extract`.

The contract is documented outside code so that the extraction service can be implemented in Dart, Python, or another runtime without changing the public interface.

The response schema below reflects the current API structure defined by `data/recipe-1.json`.

## 2. Endpoints

### `GET /healthz`

Purpose:
- basic service health check

Expected response:
- `200 OK`

Example response:

```json
{
  "status": "ok"
}
```

### `POST /v1/extractions`

Purpose:
- submit a receipt image for extraction

Request characteristics:
- `multipart/form-data`
- one uploaded receipt image
- supported formats: `image/jpeg`, `image/png`

Form fields:
- `file`: receipt image
- `requestId`: caller-generated extraction request identifier

`requestId` rules:
- required
- must not be empty
- must start with `ext_`

## 3. Response Schema

The extraction response currently contains five top-level fields:
- `requestId`
- `source`
- `warnings`
- `ocr`
- `metadata`

### Top-level object

| Field | Type | Description |
| --- | --- | --- |
| `requestId` | string | Extraction request identifier provided by the caller and echoed back unchanged by the service. |
| `source` | object | Metadata about the uploaded file processed by the extractor. |
| `warnings` | array | Extraction warnings. The sample fixture contains an empty array. |
| `ocr` | object | Raw OCR output, including full text and geometric OCR elements. |
| `metadata` | object | Extractor, model, and runtime metadata. |

### `source`

| Field | Type | Description |
| --- | --- | --- |
| `fileName` | string | File name associated with the upload. |
| `filePath` | string | File system path used by the current extractor implementation. |
| `mimeType` | string | Uploaded file MIME type. |

### `ocr`

| Field | Type | Description |
| --- | --- | --- |
| `rawText` | string | Full OCR text output as a single string with embedded line breaks. |
| `blocks` | array of `OcrElement` | OCR block-level detections. |
| `lines` | array of `OcrElement` | OCR line-level detections. |

### `OcrElement`

| Field | Type | Description |
| --- | --- | --- |
| `text` | string | Recognized text for the OCR region. |
| `confidence` | number | Confidence score for the OCR region. |
| `boundingBox` | `BoundingBox` | Axis-aligned bounding box of the OCR region. |
| `polygon` | array of `Point` | Polygon describing the OCR region geometry. |

### `BoundingBox`

| Field | Type |
| --- | --- |
| `x` | number |
| `y` | number |
| `width` | number |
| `height` | number |

### `Point`

| Field | Type |
| --- | --- |
| `x` | number |
| `y` | number |

### `metadata`

| Field | Type | Description |
| --- | --- | --- |
| `extractor` | string | Extractor implementation name. |
| `version` | string | Extractor version. |
| `models` | object | Model metadata used by the extractor. |
| `runtime` | object | Runtime environment metadata. |

### `metadata.models.ocr`

| Field | Type | Description |
| --- | --- | --- |
| `name` | string | OCR engine name. |
| `textDetectionModel` | string | OCR text detection model identifier. |
| `textRecognitionModel` | string | OCR text recognition model identifier. |
| `status` | string | OCR model status. |

### `metadata.runtime`

| Field | Type | Description |
| --- | --- | --- |
| `python` | string | Python runtime version used by the current implementation. |
| `platform` | string | Runtime platform string reported by the extractor environment. |

## 4. Example Response

```json
{
  "requestId": "ext_1a789ec91878",
  "source": {
    "fileName": "tmp80blzw3o.png",
    "filePath": "/tmp/tmp80blzw3o.png",
    "mimeType": "image/png"
  },
  "warnings": [],
  "ocr": {
    "rawText": "LDL\nJulius-Loßmann-Straße 11\n90469 Nürnberg\nEUR",
    "blocks": [
      {
        "text": "LDL",
        "confidence": 0.987,
        "boundingBox": {
          "x": 398.0,
          "y": 157.0,
          "width": 397.0,
          "height": 141.0
        },
        "polygon": [
          {
            "x": 398.0,
            "y": 157.0
          },
          {
            "x": 795.0,
            "y": 157.0
          },
          {
            "x": 795.0,
            "y": 298.0
          },
          {
            "x": 398.0,
            "y": 298.0
          }
        ]
      }
    ],
    "lines": [
      {
        "text": "LDL",
        "confidence": 0.987,
        "boundingBox": {
          "x": 398.0,
          "y": 157.0,
          "width": 397.0,
          "height": 141.0
        },
        "polygon": [
          {
            "x": 398.0,
            "y": 157.0
          },
          {
            "x": 795.0,
            "y": 157.0
          },
          {
            "x": 795.0,
            "y": 298.0
          },
          {
            "x": 398.0,
            "y": 298.0
          }
        ]
      }
    ]
  },
  "metadata": {
    "extractor": "ris_extract",
    "version": "0.2.0",
    "models": {
      "ocr": {
        "name": "PaddleOCR",
        "textDetectionModel": "PP-OCRv5_mobile_det",
        "textRecognitionModel": "latin_PP-OCRv5_mobile_rec",
        "status": "ok"
      }
    },
    "runtime": {
      "python": "3.11.15",
      "platform": "Linux-6.10.14-linuxkit-aarch64-with-glibc2.41"
    }
  }
}
```

## 5. Contract Rules

The extraction service must follow these rules:
- the caller must provide `requestId` as a multipart form field
- the service must reject a missing or empty `requestId`
- the service must reject a `requestId` that does not start with `ext_`
- the response `requestId` must exactly match the request `requestId`
- missing fields are allowed where extraction data cannot be detected reliably
- extraction should not fail only because some fields cannot be detected
- `warnings` must always be present, even when it is empty
- `ocr.rawText`, `ocr.blocks`, and `ocr.lines` are part of the current response contract
- polygon point counts are not guaranteed to be fixed across all OCR elements
