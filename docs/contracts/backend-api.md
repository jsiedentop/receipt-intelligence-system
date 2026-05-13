# Backend API Contract

## 1. Purpose

This document describes the current HTTP contract for `ris_backend`.

The backend accepts receipt image uploads, stores the original image on the local filesystem, starts extraction asynchronously through `ris_extract`, and persists the resulting OCR payload in SQLite.

## 2. Endpoints

### `GET /healthz`

Purpose:
- backend health check

Expected response:
- `200 OK`

Example response:

```json
{
  "status": "ok"
}
```

### `POST /v1/merchants`

Purpose:
- create a persisted merchant record

Request body:
- `application/json`

```json
{
  "name": "Lidl",
  "street": "Julius-Lossmann-Strasse 11",
  "postCode": "90469",
  "city": "Nuernberg",
  "taxId": "DE123456789"
}
```

Success response:
- `201 Created`

Response headers:
- `Location: /v1/merchants/{merchantId}`

Example response:

```json
{
  "id": "mer_1747061885123456",
  "name": "Lidl",
  "street": "Julius-Lossmann-Strasse 11",
  "postCode": "90469",
  "city": "Nuernberg",
  "taxId": "DE123456789"
}
```

### `GET /v1/merchants/{merchantId}`

Purpose:
- retrieve one persisted merchant

Success response:
- `200 OK`

Not found response:
- `404 Not Found`

### `GET /v1/merchants`

Purpose:
- list persisted merchants for overview screens

Success response:
- `200 OK`

Current response shape:
- JSON array of merchant objects
- ordered by `name` ascending

### `DELETE /v1/merchants/{merchantId}`

Purpose:
- delete one persisted merchant

Success response:
- `204 No Content`

Not found response:
- `404 Not Found`

### `POST /v1/receipts`

Purpose:
- upload a receipt image
- persist the stored receipt and image metadata immediately
- start extraction asynchronously

Request characteristics:
- `multipart/form-data`
- exactly one uploaded receipt image
- form field: `file`
- supported formats: `image/jpeg`, `image/png`

Success response:
- `201 Created`
- extraction is not completed yet when this response is returned

Current response fields:
- `id`
- `createdAt`
- `status`
- `extractRequestId`
- `merchantId`
- `merchant`
- `itemsCurrency`
- `items`
- `validationWarnings`
- `image`
- `extraction`

Response headers:
- `Location: /v1/receipts/{receiptId}`

Example response:

```json
{
  "id": "rcp_1747061885123456_a1b2c3d4",
  "createdAt": "2026-05-12T20:17:12.345678Z",
  "status": "pending",
  "extractRequestId": "ext_1a789ec91878",
  "merchantId": null,
  "merchant": null,
  "itemsCurrency": null,
  "items": [],
  "validationWarnings": [],
  "image": {
    "originalFileName": "receipt-1.png",
    "mimeType": "image/png",
    "storagePath": "receipts/rcp_1747061885123456_a1b2c3d4/original.png",
    "sha256": "8ffb6f5baf5b9f2c2d90d3a8b3f2cc5c8dff5cf759c992f6579e0f9b3ce8d8bb",
    "sizeBytes": 123456
  },
  "extraction": null
}
```

### `GET /v1/receipts/{receiptId}`

Purpose:
- retrieve one persisted receipt including image metadata and raw extraction payload
- poll asynchronous extraction state

Success response:
- `200 OK`

Not found response:
- `404 Not Found`

Current response shape:
- same object structure as `POST /v1/receipts`

### `PATCH /v1/receipts/{receiptId}/items/{itemId}`

Purpose:
- update one persisted receipt item
- re-run receipt item validation warnings after the update

Request body:
- `application/json`

```json
{
  "itemNumber": "0508023",
  "name": "Sandale",
  "totalPrice": 9.99,
  "quantity": 1,
  "category": "OTHER"
}
```

Rules:
- `quantity` may be `null` or an integer `>= 1`
- `totalPrice` may be `null` or a number `>= 0`
- `category` may be `null` or one of `FOOD`, `HOUSEHOLD`, `RESTAURANT`, `HEALTH`, `ELECTRONICS`, `OTHER`
- `currency` is receipt-level data and cannot be edited through this endpoint

Success response:
- `200 OK`
- response body is the updated receipt object

Validation response:
- `400 Bad Request` for invalid field types or values

Not found response:
- `404 Not Found` when the receipt or receipt item does not exist

### `POST /v1/receipts/{receiptId}/merchant`

Purpose:
- create a merchant from receipt detail input
- assign the created merchant to the receipt

Request body:
- `application/json`

```json
{
  "name": "Lidl",
  "street": "Julius-Lossmann-Strasse 11",
  "postCode": "90469",
  "city": "Nuernberg",
  "taxId": "DE123456789"
}
```

Success response:
- `201 Created`
- response body is the updated receipt object

Conflict response:
- `409 Conflict` when the receipt already has an assigned merchant

### `GET /v1/receipts/{receiptId}/image`

Purpose:
- retrieve the original uploaded receipt image as binary content

Success response:
- `200 OK`
- response body contains the original image bytes
- `Content-Type` matches the stored image MIME type such as `image/png` or `image/jpeg`

Not found response:
- `404 Not Found`

### `DELETE /v1/receipts/{receiptId}`

Purpose:
- delete one stored receipt
- delete the stored original image
- delete any persisted extraction payload for that receipt

Success response:
- `204 No Content`

Not found response:
- `404 Not Found`

### `GET /v1/receipts`

Purpose:
- list persisted receipts for overview screens
- support paginated polling over stored receipts

Query parameters:
- `page`: optional positive integer, default `1`
- `pageSize`: optional positive integer, default `20`, maximum `100`

Success response:
- `200 OK`

Current response shape:
- JSON array of receipt objects
- each item has the same object structure as `POST /v1/receipts`
- ordered by `createdAt` descending, with newest receipts first

Example response:

```json
[
  {
    "id": "rcp_1747061885123999_a1b2c3d5",
    "createdAt": "2026-05-12T20:18:12.345678Z",
    "status": "processing",
    "extractRequestId": "ext_1a789ec91879",
    "merchantId": null,
    "merchant": null,
    "itemsCurrency": null,
    "items": [],
    "validationWarnings": [],
    "image": {
      "originalFileName": "receipt-2.png",
      "mimeType": "image/png",
      "storagePath": "receipts/rcp_1747061885123999_a1b2c3d5/original.png",
      "sha256": "9ffb6f5baf5b9f2c2d90d3a8b3f2cc5c8dff5cf759c992f6579e0f9b3ce8d8bc",
      "sizeBytes": 123789
    },
    "extraction": null
  },
  {
    "id": "rcp_1747061885123456_a1b2c3d4",
    "createdAt": "2026-05-12T20:17:12.345678Z",
    "status": "processed",
    "extractRequestId": "ext_1a789ec91878",
    "merchantId": null,
    "merchant": null,
    "itemsCurrency": "EUR",
    "items": [
      {
        "id": "itm_4m3n2b1v9c8x7z",
        "itemNumber": "0508023",
        "name": "Sandale",
        "totalPrice": 9.99,
        "quantity": 1,
        "category": "OTHER"
      },
      {
        "id": "itm_5n4m3b2v1c9x8z",
        "itemNumber": "0537161",
        "name": "LuftbettCamp",
        "totalPrice": 9.99,
        "quantity": 1,
        "category": "HOUSEHOLD"
      }
    ],
    "validationWarnings": [],
    "image": {
      "originalFileName": "receipt-1.png",
      "mimeType": "image/png",
      "storagePath": "receipts/rcp_1747061885123456_a1b2c3d4/original.png",
      "sha256": "8ffb6f5baf5b9f2c2d90d3a8b3f2cc5c8dff5cf759c992f6579e0f9b3ce8d8bb",
      "sizeBytes": 123456
    },
    "extraction": {
      "requestId": "ext_1a789ec91878",
      "rawText": "LDL\nJulius-Loßmann-Straße 11\n90469 Nürnberg\nEUR",
      "ocr": {
        "rawText": "LDL\nJulius-Loßmann-Straße 11\n90469 Nürnberg\nEUR",
        "blocks": [],
        "lines": []
      },
      "structured": {
        "lineItems": null,
        "merchantInfo": null,
        "qrcode_tse_data": null
      },
      "metadata": {
        "extractor": "ris_extract_donut",
        "version": "0.2.0",
        "models": {
          "ocr": {
            "name": "PaddleOCR",
            "textDetectionModel": "PP-OCRv5_mobile_det",
            "textRecognitionModel": "latin_PP-OCRv5_mobile_rec",
            "status": "ok"
          },
          "llm": {
            "provider": "openai",
            "model": "gpt-5.4-nano",
            "status": "missing_token"
          }
        },
        "runtime": {
          "python": "3.11.15",
          "platform": "Linux-6.10.14-linuxkit-aarch64-with-glibc2.41"
        }
      },
      "warnings": []
    }
  }
]
```

### `POST /v1/receipts/{receiptId}/extractions`

Purpose:
- start a new extraction for an already stored receipt image
- remove any previous extraction payload immediately

Success response:
- `202 Accepted`

Conflict response:
- `409 Conflict` when the receipt already has an active extraction with status `pending` or `processing`

Current response shape:
- same object structure as `POST /v1/receipts`

## 3. Models

### Merchant

| Field | Type | Description |
| --- | --- | --- |
| `id` | string | Backend merchant identifier. |
| `name` | string | Merchant display name. |
| `street` | string | Merchant street address. |
| `postCode` | string | Merchant postal code. |
| `city` | string | Merchant city. |
| `taxId` | string | Merchant tax identifier. |

### Receipt

| Field | Type | Description |
| --- | --- | --- |
| `id` | string | Backend receipt identifier. |
| `createdAt` | string | UTC timestamp in ISO-8601 format. |
| `status` | string | Current extraction state. One of `pending`, `processing`, `processed`, or `failed`. |
| `extractRequestId` | string | Identifier of the current extraction attempt. |
| `merchantId` | string or `null` | Linked merchant identifier when a merchant is assigned. |
| `merchant` | object or `null` | Linked merchant snapshot for receipt detail views. |
| `itemsCurrency` | string or `null` | Currency shared by the persisted receipt items. |
| `items` | array | Persisted receipt items derived from structured extraction and later manual edits. |
| `validationWarnings` | array | Receipt-level validation warnings generated from persisted item data. |
| `image` | object | Stored image metadata. |
| `extraction` | object or `null` | Raw extraction payload persisted by the backend. It is `null` while extraction is pending, processing, or failed. |

### linked `merchant`

| Field | Type | Description |
| --- | --- | --- |
| `id` | string | Linked merchant identifier. |
| `name` | string | Merchant display name. |
| `street` | string | Merchant street address. |
| `postCode` | string | Merchant postal code. |
| `city` | string | Merchant city. |
| `taxId` | string | Merchant tax identifier. |

### `image`

| Field | Type | Description |
| --- | --- | --- |
| `originalFileName` | string | Original uploaded file name. |
| `mimeType` | string | Detected or declared file MIME type. |
| `storagePath` | string | Relative filesystem path below the backend data directory. |
| `sha256` | string | SHA-256 hash of the stored image bytes. |
| `sizeBytes` | number | Stored image size in bytes. |

### `items[]`

| Field | Type | Description |
| --- | --- | --- |
| `id` | string | Backend receipt item identifier. |
| `itemNumber` | string or `null` | Extracted or corrected item number. |
| `name` | string or `null` | Extracted or corrected item name. |
| `totalPrice` | number or `null` | Item total price. |
| `quantity` | number or `null` | Optional item quantity. |
| `category` | string or `null` | Item category. One of `FOOD`, `HOUSEHOLD`, `RESTAURANT`, `HEALTH`, `ELECTRONICS`, `OTHER`. |

### `validationWarnings[]`

| Field | Type | Description |
| --- | --- | --- |
| `code` | string | Stable warning code. |
| `message` | string | Human-readable warning message. |

### `extraction`

| Field | Type | Description |
| --- | --- | --- |
| `requestId` | string | Caller-generated extraction request identifier created by the backend and echoed back by `ris_extract`. |
| `rawText` | string | Convenience copy of `ocr.rawText`. |
| `ocr` | object | Raw OCR payload returned by `ris_extract`. |
| `structured` | object | Structured extraction payload returned by `ris_extract`, including optional LLM output and parsed TSE QR data. |
| `metadata` | object | Extractor metadata returned by `ris_extract`. |
| `warnings` | array | Extraction warnings returned by `ris_extract`. |

## 4. Error Handling

The backend maps typed application exceptions to HTTP status codes.

Current error categories:
- `400 Bad Request`
  - malformed multipart request
  - missing upload field
  - invalid request parameters
  - invalid pagination parameters
  - invalid merchant create body
  - invalid receipt item update body
- `409 Conflict`
  - merchant delete requested while receipts still reference the merchant
  - merchant assignment requested for a receipt that already has a merchant
  - extraction restart requested while another extraction is active
- `404 Not Found`
  - missing merchant
  - missing receipt
  - missing receipt item
  - missing original image for a known receipt
- `415 Unsupported Media Type`
  - unsupported upload MIME type
- `500 Internal Server Error`
  - storage failures
  - database failures
  - extraction failures
  - unexpected internal failures

Error response shape:

```json
{
  "error": {
    "type": "UnsupportedMediaTypeException",
    "message": "Unsupported file type: text/plain."
  }
}
```

## 5. Behavioral Rules

The backend currently follows these rules:
- uploaded receipts become persisted backend entities immediately
- original uploaded images are stored on the local filesystem
- image metadata and raw OCR payloads are stored in SQLite
- structured receipt items and receipt item validation warnings are stored in SQLite
- the backend calls `ris_extract` through a dedicated client in `ris_core`
- the backend generates an extraction `requestId` before calling `ris_extract`
- `POST /v1/receipts` returns immediately after the receipt is stored and queued for extraction
- clients poll `GET /v1/receipts/{receiptId}` to observe `status`
- `GET /v1/receipts` returns receipts ordered by newest first
- `GET /v1/receipts` supports page-based pagination through `page` and `pageSize`
- `GET /v1/receipts/{receiptId}/image` returns the stored original image bytes
- `DELETE /v1/receipts/{receiptId}` is allowed even while extraction is `pending` or `processing`
- deleting a receipt removes it from listing and detail endpoints immediately
- the backend processes extraction jobs asynchronously in the background
- when a new extraction is started for an existing receipt, any previous extraction payload is deleted immediately
- `extraction` remains `null` until the current extraction finishes successfully
- successful extraction persists structured line items as editable receipt items
- receipt item validation currently emits `ITEM_TOTAL_MISMATCH` when item totals differ from the extracted final amount after cent-based comparison
- the backend retries receipts in status `pending` or `processing` after restart
- background extraction jobs ignore receipts that were deleted before processing finished
- the backend expects the extraction response `requestId` to exactly match the generated request id
- API handlers map application exceptions to HTTP status codes
- business logic is implemented in use cases rather than directly in HTTP handlers

## 6. Current Scope

The current backend implementation intentionally focuses on the first vertical slice.

Implemented now:
- `GET /healthz`
- `POST /v1/merchants`
- `GET /v1/merchants`
- `GET /v1/merchants/{merchantId}`
- `DELETE /v1/merchants/{merchantId}`
- `POST /v1/receipts`
- `GET /v1/receipts`
- `GET /v1/receipts/{receiptId}`
- `POST /v1/receipts/{receiptId}/merchant`
- `PATCH /v1/receipts/{receiptId}/items/{itemId}`
- `GET /v1/receipts/{receiptId}/image`
- `POST /v1/receipts/{receiptId}/extractions`
- `DELETE /v1/receipts/{receiptId}`
- image persistence
- OCR persistence
- structured line-item persistence
- manual receipt-item correction
- typed exception handling

Not implemented yet:
- receipt-item creation and deletion
