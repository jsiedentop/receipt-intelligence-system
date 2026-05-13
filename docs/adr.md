# Architecture Decision Record

This document records the main architecture decisions for the current RIS prototype.

## ADR 000 - Use Dart Instead Of Node.js For The Backend

Decision:
- The backend is implemented in Dart instead of Node.js.

Rationale:
- This is a deliberate deviation from the original requirements and was aligned with the stakeholders.
- In this project, Dart reduces overall system complexity because backend and frontend can share types, IDs, DTOs, and client code through `ris_core`.
- That shared code approach improves consistency across package boundaries and reduces duplicate implementation effort.
- I have built more backend systems with Dart in recent years than with Node.js, so Dart is the technology where I currently have stronger practical backend experience.
- For this prototype, that experience lowers implementation risk and helps keep the focus on architecture, extraction quality, and end-to-end delivery instead of spending additional time on backend stack adaptation.


## ADR 001 - Use-Case-Driven Backend Architecture

Decision:
- The backend uses a use-case-driven clean architecture style.

Rationale:
- The backend is organized into `api`, `application`, `domain`, and `infrastructure`.
- The important property is not only the folder split, but the dependency direction: HTTP handlers call use cases, use cases depend on domain abstractions, and infrastructure implements those abstractions.
- This keeps business workflows out of HTTP handlers and reduces direct coupling to SQLite, filesystem storage, or external HTTP clients.
- The result has clear clean-architecture or onion-like characteristics, but it is best described as a pragmatic use-case-driven ports-and-adapters architecture rather than a strict textbook onion architecture.

## ADR 002 - Separate `ris_extract` Service

Decision:
- Receipt extraction is implemented as a separate service behind an HTTP contract.

Rationale:
- From an architectural perspective, this is the area with the highest uncertainty.
- OCR, QR parsing, and LLM-based extraction are the most volatile parts of the system and are the most likely to change as better approaches become available.
- This follows the principle "Encapsulate the concept that varies" and the idea of volatility-based decomposition.
- A separate service makes it relatively easy to test extractor implementations against each other, replace them, and evolve them without rewriting the backend or UI.
- It also allows a different runtime and library stack where that is useful. In this project, `ris_extract` is implemented in Python with FastAPI and PaddleOCR.
- The stable HTTP boundary is documented separately in `docs/contracts/extract-api.md`.
- `src/ris_extract_mock` exists to support fixture-based testing against the same service contract.

## ADR 003 - SQLite And Filesystem Storage Behind Abstractions

Decision:
- The current prototype stores structured backend data in SQLite and original receipt images in the local filesystem.

Rationale:
- SQLite is a pragmatic fit for a prototype because it keeps deployment and operations simple.
- The backend does not depend directly on SQLite semantics in its application flows. Persistence is accessed through repository abstractions.
- This means a different persistence layer can be introduced later for production without major changes to use cases or the HTTP API.
- Original image storage is currently simple filesystem storage for the same reason: it is easy to inspect, easy to operate locally, and good enough for the prototype.
- Image storage is abstracted behind `ImageStorageRepository`, so a later move to object storage or another binary storage system remains straightforward.

## ADR 004 - Weighted Merchant Matching And Conservative Auto-Assignment

Decision:
- Merchant matching uses weighted evidence across multiple extracted properties, and auto-assignment only happens for a clear top candidate.

Rationale:
- Receipt OCR and structured extraction are inherently noisy and incomplete, so binary one-field matching would be too brittle.
- RIS therefore combines normalized exact matches over several merchant properties and converts them into a normalized score.
- The strongest current signals are the German tax ID and the TSE serial number.
- Additional signals are merchant name, street, post code, and city.
- The current implementation gives high weight to tax ID and TSE serial number, because they are much stronger identifiers than a city or merchant name alone.
- Automatic assignment is intentionally conservative: it requires a sufficiently high score and a sufficient gap to the next candidate.
- Weak or ambiguous matches stay unmatched and are surfaced for manual review instead of being assigned automatically.

## ADR 005 - Parse And Use TSE QR Data

Decision:
- RIS parses TSE QR data and uses it as part of extraction and merchant matching.

Rationale:
- German receipts are a particularly good fit for this because the legal and technical format contains structured signals that are more reliable than OCR alone.
- The reference points here are the German requirements usually summarized as "Pflichtangaben nach § 6 KassenSichV" and the standardized DSFinV-K QR code format used on German receipts.
- These requirements include merchant identity and address, timestamps, item details, totals and taxes, transaction identifiers, serial numbers of the recording system and TSE, and signature-related fields.
- The DSFinV-K QR code is a machine-readable standardized encoding of TSE data. That makes it easier and more reliable to read than OCR-only extraction of the same information from printed text.
- In this system, the TSE serial number is treated as a very strong and effectively unique signal for mapping a receipt to a specific market or location.
- Address data and the German tax ID are also strong matching signals.
- `ris_extract` therefore parses supported TSE QR payloads and passes that data forward to both structured extraction and merchant matching.

## ADR 006 - Use `gpt-5.4-nano` For Structured Extraction

Decision:
- RIS uses `gpt-5.4-nano` for structured extraction of receipt line items and merchant information.

Rationale:
- The LLM is used for structure recovery from OCR text, not as a replacement for OCR itself.
- This keeps the extractor useful even when the LLM is unavailable. OCR can still run and the service can still return raw extraction output with warnings.
- `gpt-5.4-nano` offers a reasonable cost profile for a prototype while still supporting structured extraction through the OpenAI Responses API.

Cost note:
- Input price: `$0.20` per 1 million tokens
- Output price: `$1.25` per 1 million tokens
- Typical receipt: about `1500` input tokens and `700` output tokens
- Estimated cost per 1000 receipts: `$1.175`
