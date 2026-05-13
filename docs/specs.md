# Receipt Intelligence System

## Purpose

RIS is a prototype for ingesting receipt images, extracting structured receipt data, storing the result, and reviewing or correcting it through an API and a Flutter UI.

Detailed HTTP contracts live in:
- `docs/contracts/backend-api.md`
- `docs/contracts/extract-api.md`

## Current Packages

| Package | Role |
| --- | --- |
| `src/ris_backend` | Dart/Shelf backend for receipt and merchant workflows. |
| `src/ris_core` | Shared DTOs, IDs, and HTTP clients used by backend and UI. |
| `src/ris_ui` | Flutter application for receipt and merchant management. |
| `src/ris_extract` | Python/FastAPI extraction service using PaddleOCR, TSE QR parsing, and optional LLM-based structured extraction. |
| `src/ris_extract_mock` | Fixture-based mock of the extraction API used by tests and local integration flows. |

## Current Architecture

- The backend follows a use-case-driven clean architecture style.
- It is organized into `api`, `application`, `domain`, and `infrastructure`, but the key characteristic is the inward dependency direction: handlers call use cases, use cases depend on domain abstractions, and infrastructure provides concrete implementations.
- This gives the backend clean-architecture or onion-like characteristics without forcing a strict textbook onion model.
- The Flutter UI follows a feature-first structure. Each feature groups its own `data`, `logic`, and `ui` code.
- `ris_extract` is a separate service boundary because OCR, QR parsing, and structured data extraction are the most volatile part of the system (Volatility-Based Decomposition).

## Implemented Scope

- Receipt upload for PNG and JPEG files.
- Immediate receipt persistence with asynchronous extraction.
- Receipt listing, detail view, image retrieval, restart, and deletion.
- Merchant creation, listing, detail, deletion, assignment, and unassignment.
- Merchant candidate scoring and automatic merchant assignment for clear high-confidence matches.
- Structured receipt item persistence and manual item correction.
- Receipt validation warnings for mismatched item totals.
- OCR overlays in the UI using stored OCR block and line geometry.
- TSE QR parsing and exposure of parsed TSE data in the backend response and UI.

## Extraction Pipeline

- OCR is performed by PaddleOCR in `src/ris_extract`.
- Structured extraction uses the OpenAI Responses API with `gpt-5.4-nano`.
- Structured extraction currently targets line items and merchant information.
- TSE QR data is detected with `zbarimg` and parsed when the QR payload matches the supported German KassenSichV MVP format.
- If `OPEN_AI_TOKEN` is not configured, OCR still succeeds and the service returns warnings instead of failing the full extraction.

## Persistence And Replaceability

- Structured application data is currently stored in SQLite.
- Original receipt images are currently stored in the local filesystem.
- SQLite access sits behind repository abstractions, so another persistence layer can be introduced later without reshaping the core backend flows.
- Image storage sits behind `ImageStorageRepository`, so the filesystem can later be replaced by object storage or another binary storage implementation.

## Matching Strategy

- Merchant matching is based on normalized exact matches over multiple extracted properties.
- The strongest current signals are German tax ID and TSE serial number.
- Additional signals are merchant name, street, post code, and city.
- Automatic assignment only happens when one top candidate is strong enough and clearly ahead of the next candidate.

## Known Limitations

- This is a prototype, not a production-hardened system.
- There is no authentication or authorization.
- The extractor remains the area with the highest technical uncertainty.
- Receipt item creation and deletion are not implemented yet.
- Backend integration tests currently run against `ris_extract_mock`, not the real extractor.

## LLM Cost Note

- Model: `gpt-5.4-nano`
- Input price: `$0.20` per 1 million tokens
- Output price: `$1.25` per 1 million tokens
- Typical receipt: about `1500` input tokens and `700` output tokens
- Estimated cost per 1000 receipts: `$1.175`

## Example Data

- Sample receipt images live in `data/receipt-1.png`, `data/receipt-2.png`, `data/receipt-3.png`, and `data/receipt-4.png`.
- Fixture responses for extraction tests live in `data/recipe-1.json`, `data/recipe-2.json`, and `data/recipe-3.json`.
