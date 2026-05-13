#!/usr/bin/env python3

"""CLI OCR extractor for receipt images with optional TSE QR and LLM parsing."""

from __future__ import annotations

import argparse
import concurrent.futures
import json
import mimetypes
import os
import platform
import re
import subprocess
import sys
import time
from pathlib import Path
from typing import Any

from openai import OpenAI


SCRIPT_VERSION = "0.3.0"
SUPPORTED_SUFFIXES = {".png", ".jpg", ".jpeg"}
OPENAI_MODEL = "gpt-5.4-nano"
OPENAI_DEVELOPER_MESSAGE = (
    "Extract structured data from provided receipt text according to specified fields and data types."
)
OPENAI_MAX_RETRIES = 3
OPENAI_RETRY_DELAYS_SECONDS = (0.5, 1.0, 2.0)

LINE_ITEMS_SCHEMA: dict[str, Any] = {
    "name": "receipt",
    "strict": True,
    "schema": {
        "type": "object",
        "properties": {
            "total_amount": {
                "type": ["number", "null"],
                "description": "Sum of all item totals, in the given currency.",
            },
            "currency": {
                "type": ["string", "null"],
                "description": "ISO 4217 currency code (e.g. USD, EUR, GBP).",
                "minLength": 3,
                "maxLength": 3,
                "pattern": "^[A-Z]{3}$",
            },
            "items": {
                "type": "array",
                "description": "Line items listed on the receipt.",
                "items": {
                    "type": "object",
                    "properties": {
                        "name": {
                            "type": ["string", "null"],
                            "description": "Name or description of the purchased item.",
                        },
                        "total_price": {
                            "type": ["number", "null"],
                            "description": "Total price for this item (includes all quantities).",
                        },
                        "category": {
                            "type": ["string", "null"],
                            "description": "Category for this item.",
                            "enum": [
                                "FOOD",
                                "HOUSEHOLD",
                                "RESTAURANT",
                                "HEALTH",
                                "ELECTRONICS",
                                "OTHER",
                                None,
                            ],
                        },
                        "item_number": {
                            "type": ["string", "null"],
                            "description": "Optional: Item's SKU, barcode, or unique identifier.",
                        },
                        "quantity": {
                            "type": ["integer", "null"],
                            "description": "Optional: Number of units purchased.",
                            "minimum": 1,
                        },
                    },
                    "required": [
                        "name",
                        "total_price",
                        "category",
                        "item_number",
                        "quantity",
                    ],
                    "additionalProperties": False,
                },
            },
        },
        "required": ["total_amount", "currency", "items"],
        "additionalProperties": False,
    },
}

MERCHANT_INFO_SCHEMA: dict[str, Any] = {
    "name": "german_receipt_info",
    "strict": True,
    "schema": {
        "type": "object",
        "properties": {
            "city": {
                "type": ["string", "null"],
                "description": "Merchant city name.",
                "minLength": 1,
            },
            "post_code": {
                "type": ["string", "null"],
                "description": "Merchant postal code (PLZ).",
                "pattern": "^\\d{5}$",
            },
            "street": {
                "type": ["string", "null"],
                "description": "Merchant street address.",
                "minLength": 1,
            },
            "ustid": {
                "type": ["string", "null"],
                "description": "Merchant tax ID (USt-IdNr.), typically in the format 'DE' followed by 9 digits.",
                "pattern": "^DE[0-9]{9}$",
            },
            "tse_serial_number": {
                "type": ["string", "null"],
                "description": "TSE serial number consisting of 40-48 characters; may contain line breaks; usually ends with one or two '='.",
                "minLength": 40,
                "pattern": "^[A-Za-z0-9=]+$",
            },
            "datetime": {
                "type": ["string", "null"],
                "description": "Datetime of the receipt in ISO 8601 format (e.g. 2024-06-09T13:45:00Z).",
                "format": "date-time",
            },
        },
        "required": [
            "city",
            "post_code",
            "street",
            "ustid",
            "tse_serial_number",
            "datetime",
        ],
        "additionalProperties": False,
    },
}

def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Extract OCR and structured data from a receipt image."
    )
    parser.add_argument("receipt_path", type=Path, help="Path to a PNG or JPEG receipt image")
    parser.add_argument(
        "--output",
        type=Path,
        help="Optional path for the JSON output file",
    )
    parser.add_argument(
        "--request-id",
        type=str,
        help="Optional extract request id. If omitted, a generated id is used.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    request_id = args.request_id or _create_extract_request_id()

    try:
        result = extract_receipt(args.receipt_path, request_id=request_id)
    except Exception as exc:  # pragma: no cover - CLI boundary
        print(f"error: {exc}", file=sys.stderr)
        return 1

    output_text = json.dumps(result, ensure_ascii=False, indent=2)

    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(output_text + "\n", encoding="utf-8")

    print(output_text)
    return 0


def extract_receipt(receipt_path: Path, request_id: str) -> dict[str, Any]:
    _validate_receipt_path(receipt_path)
    _validate_request_id(request_id)

    warnings: list[str] = []
    ocr_result = _run_paddle_ocr(receipt_path)
    warnings.extend(ocr_result["warnings"])
    blocks = ocr_result["blocks"]
    if not blocks:
        raise RuntimeError("PaddleOCR failed to produce usable text blocks")

    lines = _group_blocks_into_lines(blocks)
    raw_text = "\n".join(line["text"] for line in lines)

    tse_qr_result = _extract_tse_qr_data(receipt_path)
    warnings.extend(tse_qr_result["warnings"])

    llm_result = _extract_structured_data(
        prompt_text=_build_prompt_text(lines, tse_qr_result["qrcode_tse_data"]),
    )
    warnings.extend(llm_result["warnings"])

    llm_status = _resolve_llm_status(llm_result)

    return {
        "requestId": request_id,
        "source": {
            "fileName": receipt_path.name,
            "filePath": str(receipt_path.resolve()),
            "mimeType": mimetypes.guess_type(receipt_path.name)[0] or "application/octet-stream",
        },
        "warnings": _unique_strings(warnings),
        "ocr": {
            "rawText": raw_text,
            "blocks": blocks,
            "lines": lines,
        },
        "structured": {
            "lineItems": llm_result["line_items"],
            "merchantInfo": llm_result["merchant_info"],
            "qrcode_tse_data": tse_qr_result["qrcode_tse_data"],
        },
        "metadata": {
            "extractor": "ris_extract",
            "version": SCRIPT_VERSION,
            "models": {
                "ocr": ocr_result["model_info"],
                "llm": {
                    "provider": "openai",
                    "model": OPENAI_MODEL,
                    "status": llm_status,
                },
            },
            "runtime": {
                "python": platform.python_version(),
                "platform": platform.platform(),
            },
        },
    }


def _validate_receipt_path(receipt_path: Path) -> None:
    if not receipt_path.exists():
        raise FileNotFoundError(f"Receipt image not found: {receipt_path}")

    if receipt_path.suffix.lower() not in SUPPORTED_SUFFIXES:
        supported = ", ".join(sorted(SUPPORTED_SUFFIXES))
        raise ValueError(f"Unsupported file type: {receipt_path.suffix}. Expected one of: {supported}")


def _validate_request_id(request_id: str) -> None:
    if not request_id or not request_id.startswith("ext_"):
        raise ValueError('request_id must be non-empty and start with "ext_"')


def _create_extract_request_id() -> str:
    import uuid

    return f"ext_{uuid.uuid4().hex[:14]}"


def _run_paddle_ocr(receipt_path: Path) -> dict[str, Any]:
    warnings: list[str] = []

    try:
        from paddleocr import PaddleOCR
    except ImportError:
        return {
            "blocks": [],
            "warnings": [
                "PaddleOCR is not installed. Install it with: python -m pip install paddleocr"
            ],
            "model_info": {"name": "PaddleOCR", "status": "missing"},
        }

    ocr = _create_paddle_ocr(PaddleOCR)
    raw_prediction = _predict_with_paddle_ocr(ocr, receipt_path)
    blocks = _extract_blocks_from_payload(raw_prediction)

    if not blocks:
        warnings.append("PaddleOCR returned no text blocks")

    return {
        "blocks": blocks,
        "warnings": warnings,
        "model_info": {
            "name": "PaddleOCR",
            "textDetectionModel": "PP-OCRv5_mobile_det",
            "textRecognitionModel": "latin_PP-OCRv5_mobile_rec",
            "status": "ok",
        },
    }


def _create_paddle_ocr(paddle_ocr_cls: Any) -> Any:
    attempts = (
        {
            "device": "cpu",
            "use_doc_orientation_classify": False,
            "use_doc_unwarping": False,
            "use_textline_orientation": False,
            "text_detection_model_name": "PP-OCRv5_mobile_det",
            "text_recognition_model_name": "latin_PP-OCRv5_mobile_rec",
        },
        {
            "device": "cpu",
            "use_doc_orientation_classify": False,
            "use_doc_unwarping": False,
            "use_textline_orientation": False,
        },
        {
            "use_angle_cls": False,
            "lang": "en",
            "show_log": False,
        },
        {},
    )

    last_error: Exception | None = None
    for kwargs in attempts:
        try:
            return paddle_ocr_cls(**kwargs)
        except Exception as exc:
            last_error = exc
            continue

    raise RuntimeError(f"Unable to initialize PaddleOCR: {last_error}")


def _predict_with_paddle_ocr(ocr: Any, receipt_path: Path) -> Any:
    if hasattr(ocr, "predict"):
        try:
            return list(ocr.predict(str(receipt_path)))
        except TypeError:
            pass

    if hasattr(ocr, "ocr"):
        return ocr.ocr(str(receipt_path), cls=False)

    raise RuntimeError("Unsupported PaddleOCR API: neither 'predict' nor 'ocr' is available")


def _extract_tse_qr_data(receipt_path: Path) -> dict[str, Any]:
    warnings: list[str] = []
    qr_payloads = _scan_qr_payloads(receipt_path, warnings)

    for payload in qr_payloads:
        tse_data = _parse_tse_qr_payload(payload)
        if tse_data is not None:
            return {
                "qrcode_tse_data": tse_data,
                "warnings": warnings,
            }

    return {
        "qrcode_tse_data": None,
        "warnings": warnings,
    }


def _scan_qr_payloads(receipt_path: Path, warnings: list[str]) -> list[str]:
    zbarimg_path = _find_executable("zbarimg")
    if zbarimg_path is None:
        warnings.append("zbarimg is not available in PATH for this extractor runtime. Skipping TSE QR detection.")
        return []

    try:
        completed = subprocess.run(
            [zbarimg_path, "--quiet", "--raw", str(receipt_path)],
            capture_output=True,
            check=False,
            text=True,
        )
    except Exception as exc:
        warnings.append(f"Failed to execute zbarimg for TSE QR detection: {exc}")
        return []

    stdout_lines = [line.strip() for line in completed.stdout.splitlines() if line.strip()]
    stderr_lines = [line.strip() for line in completed.stderr.splitlines() if line.strip()]

    if completed.returncode not in (0, 4) and stderr_lines:
        warnings.append(f"zbarimg failed while scanning TSE QR data: {' '.join(stderr_lines)}")

    return stdout_lines


def _parse_tse_qr_payload(payload: str) -> dict[str, Any] | None:
    normalized = payload.strip()
    if not normalized.startswith("V0;"):
        return None

    parts = normalized.split(";")
    if len(parts) < 12:
        return None

    if parts[2] != "Kassenbeleg-V1":
        return None

    parsed = {
        "version": parts[0],
        "tss_serial_number": parts[1],
        "receipt_type": parts[2],
        "process_data": parts[3],
        "transaction_number": parts[4],
        "signature_counter": parts[5],
        "time_start": parts[6],
        "time_end": parts[7],
        "signature_algorithm": parts[8],
        "timestamp_format": parts[9],
        "signature": parts[10],
        "public_key": parts[11],
    }
    return {
        "raw_text": normalized,
        "format": "kassensichv-v0",
        "is_tse_qr": True,
        "parsed": parsed,
    }


def _build_prompt_text(lines: list[dict[str, Any]], tse_qr_data: dict[str, Any] | None) -> str:
    prompt_lines = [line["text"] for line in lines if line.get("text")]
    prompt_sections = ["OCR receipt lines:", "\n".join(prompt_lines)]

    if tse_qr_data is not None:
        prompt_sections.extend(
            [
                "",
                "TSE QR data:",
                tse_qr_data["raw_text"],
            ]
        )

    return "\n".join(section for section in prompt_sections if section is not None)


def _extract_structured_data(prompt_text: str) -> dict[str, Any]:
    token = os.environ.get("OPEN_AI_TOKEN")
    if not token:
        return {
            "line_items": None,
            "merchant_info": None,
            "warnings": ["OPEN_AI_TOKEN is not configured. Skipping structured extraction."],
        }

    warnings: list[str] = []
    openai_client = OpenAI(api_key=token)
    prompts = (
        ("line items", LINE_ITEMS_SCHEMA),
        ("merchant info", MERCHANT_INFO_SCHEMA),
    )

    results: dict[str, dict[str, Any]] = {}
    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as executor:
        future_map = {
            executor.submit(
                _run_openai_structured_prompt,
                openai_client,
                prompt_name,
                schema,
                prompt_text,
            ): prompt_name
            for prompt_name, schema in prompts
        }

        for future in concurrent.futures.as_completed(future_map):
            prompt_name = future_map[future]
            try:
                results[prompt_name] = future.result()
            except Exception as exc:
                warnings.append(f"Structured extraction for {prompt_name} failed unexpectedly: {exc}")
                results[prompt_name] = {
                    "data": None,
                    "warnings": [],
                }

    for prompt_name in ("line items", "merchant info"):
        warnings.extend(results.get(prompt_name, {}).get("warnings", []))

    return {
        "line_items": results.get("line items", {}).get("data"),
        "merchant_info": results.get("merchant info", {}).get("data"),
        "warnings": warnings,
    }


def _run_openai_structured_prompt(
    openai_client: OpenAI,
    prompt_name: str,
    schema: dict[str, Any],
    prompt_text: str,
) -> dict[str, Any]:
    warnings: list[str] = []

    for attempt in range(1, OPENAI_MAX_RETRIES + 1):
        try:
            response_json = _call_openai_responses_api(openai_client, schema, prompt_text)
            parsed = _extract_openai_output_json(response_json)
            _validate_schema(parsed, schema["schema"], field_name=f"{prompt_name} root")
            return {"data": parsed, "warnings": warnings}
        except Exception as exc:
            warnings.append(
                f"OpenAI structured extraction attempt {attempt}/{OPENAI_MAX_RETRIES} failed for {prompt_name}: {exc}"
            )
            if attempt < OPENAI_MAX_RETRIES:
                time.sleep(OPENAI_RETRY_DELAYS_SECONDS[attempt - 1])

    warnings.append(f"Structured extraction for {prompt_name} was skipped after {OPENAI_MAX_RETRIES} failed attempts.")
    return {"data": None, "warnings": warnings}


def _call_openai_responses_api(
    openai_client: OpenAI, schema: dict[str, Any], prompt_text: str
) -> dict[str, Any]:
    try:
        response = openai_client.responses.create(
            model=OPENAI_MODEL,
            instructions=OPENAI_DEVELOPER_MESSAGE,
            input=prompt_text,
            text={
                "verbosity": "medium",
                "format": {
                    "type": "json_schema",
                    "name": schema["name"],
                    "strict": schema["strict"],
                    "schema": schema["schema"],
                }
            },
            store=True,
            reasoning={"effort": "medium", "summary": "auto"},
        )
        return response.model_dump(mode="json")
    except Exception as exc:
        raise RuntimeError(f"OpenAI request failed: {exc}") from exc


def _extract_openai_output_json(response_json: dict[str, Any]) -> dict[str, Any]:
    output_items = response_json.get("output") or []
    refusal = response_json.get("refusal")
    if refusal:
        raise RuntimeError(f"Model refused request: {refusal}")

    for item in output_items:
        if item.get("type") != "message":
            continue
        for content in item.get("content") or []:
            if content.get("type") == "output_text" and isinstance(content.get("text"), str):
                return _as_json_object(json.loads(content["text"]))

    raise RuntimeError("OpenAI response did not contain output_text JSON content.")


def _resolve_llm_status(llm_result: dict[str, Any]) -> str:
    line_items = llm_result.get("line_items")
    merchant_info = llm_result.get("merchant_info")
    warnings = llm_result.get("warnings") or []
    if any("OPEN_AI_TOKEN is not configured" in warning for warning in warnings):
        return "missing_token"
    if line_items is not None and merchant_info is not None:
        return "ok"
    if line_items is None and merchant_info is None:
        return "failed"
    return "partial"


def _find_executable(name: str) -> str | None:
    for directory in os.environ.get("PATH", "").split(os.pathsep):
        candidate = Path(directory, name)
        if candidate.exists() and os.access(candidate, os.X_OK):
            return str(candidate)
    return None


def _extract_blocks_from_payload(payload: Any) -> list[dict[str, Any]]:
    coerced = _coerce_payload(payload)

    if isinstance(coerced, dict):
        direct_blocks = _extract_blocks_from_dict(coerced)
        if direct_blocks:
            return direct_blocks

    if _looks_like_legacy_block(coerced):
        block = _legacy_block_to_dict(coerced)
        return [block] if block else []

    if isinstance(coerced, (list, tuple)):
        blocks: list[dict[str, Any]] = []
        for item in coerced:
            blocks.extend(_extract_blocks_from_payload(item))
        return blocks

    return []


def _coerce_payload(payload: Any) -> Any:
    if payload is None:
        return None

    if isinstance(payload, (list, tuple, dict, str, int, float)):
        return payload

    if hasattr(payload, "tolist"):
        try:
            return payload.tolist()
        except Exception:
            pass

    if hasattr(payload, "to_dict"):
        try:
            return payload.to_dict()
        except Exception:
            pass

    if hasattr(payload, "json"):
        try:
            json_value = payload.json() if callable(payload.json) else payload.json
            if isinstance(json_value, str):
                return json.loads(json_value)
            return json_value
        except Exception:
            pass

    if hasattr(payload, "res"):
        return _coerce_payload(payload.res)

    return payload


def _extract_blocks_from_dict(data: dict[str, Any]) -> list[dict[str, Any]]:
    keys = set(data.keys())

    if {"dt_polys", "rec_texts"}.issubset(keys):
        polys = data.get("dt_polys") or []
        texts = data.get("rec_texts") or []
        scores = data.get("rec_scores") or [None] * len(texts)
        blocks = []
        for poly, text, score in zip(polys, texts, scores):
            block = _make_block(text, score, poly)
            if block:
                blocks.append(block)
        return blocks

    if {"boxes", "texts"}.issubset(keys):
        polys = data.get("boxes") or []
        texts = data.get("texts") or []
        scores = data.get("scores") or [None] * len(texts)
        blocks = []
        for poly, text, score in zip(polys, texts, scores):
            block = _make_block(text, score, poly)
            if block:
                blocks.append(block)
        return blocks

    if "text" in data and ({"dt_poly", "polygon"} & keys or {"bbox", "box"} & keys):
        polygon = data.get("dt_poly") or data.get("polygon") or data.get("bbox") or data.get("box")
        block = _make_block(data.get("text"), data.get("score") or data.get("confidence"), polygon)
        return [block] if block else []

    return []


def _looks_like_legacy_block(payload: Any) -> bool:
    if not isinstance(payload, (list, tuple)) or len(payload) != 2:
        return False

    polygon, text_part = payload
    if not isinstance(text_part, (list, tuple)) or len(text_part) < 1:
        return False

    return isinstance(polygon, (list, tuple))


def _legacy_block_to_dict(payload: Any) -> dict[str, Any] | None:
    polygon, text_part = payload
    text = text_part[0] if text_part else None
    score = text_part[1] if len(text_part) > 1 else None
    return _make_block(text, score, polygon)


def _make_block(text: Any, score: Any, polygon: Any) -> dict[str, Any] | None:
    clean_text = _clean_text(text)
    points = _normalize_polygon(polygon)
    if not clean_text or not points:
        return None

    bbox = _polygon_to_bbox(points)
    return {
        "text": clean_text,
        "confidence": _to_float(score),
        "boundingBox": bbox,
        "polygon": points,
    }


def _normalize_polygon(polygon: Any) -> list[dict[str, float]]:
    polygon = _coerce_payload(polygon)
    if not isinstance(polygon, (list, tuple)):
        return []

    points: list[dict[str, float]] = []
    for point in polygon:
        if not isinstance(point, (list, tuple)) or len(point) < 2:
            continue
        x = _to_float(point[0])
        y = _to_float(point[1])
        if x is None or y is None:
            continue
        points.append({"x": x, "y": y})
    return points


def _polygon_to_bbox(points: list[dict[str, float]]) -> dict[str, float]:
    xs = [point["x"] for point in points]
    ys = [point["y"] for point in points]
    x_min = min(xs)
    y_min = min(ys)
    x_max = max(xs)
    y_max = max(ys)
    return {
        "x": round(x_min, 2),
        "y": round(y_min, 2),
        "width": round(x_max - x_min, 2),
        "height": round(y_max - y_min, 2),
    }


def _group_blocks_into_lines(blocks: list[dict[str, Any]]) -> list[dict[str, Any]]:
    normalized_blocks = []
    for block in blocks:
        bbox = block["boundingBox"]
        normalized_blocks.append(
            {
                **block,
                "centerY": bbox["y"] + (bbox["height"] / 2),
            }
        )

    normalized_blocks.sort(key=lambda block: (block["centerY"], block["boundingBox"]["x"]))
    lines: list[dict[str, Any]] = []

    for block in normalized_blocks:
        placed = False
        for line in lines:
            threshold = max(10.0, min(line["avgHeight"], block["boundingBox"]["height"]) * 0.6)
            if abs(block["centerY"] - line["centerY"]) <= threshold:
                line["blocks"].append(block)
                line["centerYValues"].append(block["centerY"])
                line["heightValues"].append(block["boundingBox"]["height"])
                line["centerY"] = sum(line["centerYValues"]) / len(line["centerYValues"])
                line["avgHeight"] = sum(line["heightValues"]) / len(line["heightValues"])
                placed = True
                break

        if not placed:
            lines.append(
                {
                    "blocks": [block],
                    "centerY": block["centerY"],
                    "avgHeight": block["boundingBox"]["height"],
                    "centerYValues": [block["centerY"]],
                    "heightValues": [block["boundingBox"]["height"]],
                }
            )

    grouped_lines: list[dict[str, Any]] = []
    for line in lines:
        line_blocks = sorted(line["blocks"], key=lambda block: block["boundingBox"]["x"])
        polygons = [point for block in line_blocks for point in block["polygon"]]
        bbox = _polygon_to_bbox(polygons)
        confidences = [block["confidence"] for block in line_blocks if block["confidence"] is not None]
        grouped_lines.append(
            {
                "text": _clean_text(" ".join(block["text"] for block in line_blocks)),
                "confidence": round(sum(confidences) / len(confidences), 4) if confidences else None,
                "boundingBox": bbox,
                "polygon": polygons,
            }
        )

    grouped_lines.sort(key=lambda line: (line["boundingBox"]["y"], line["boundingBox"]["x"]))
    return grouped_lines


def _validate_schema(value: Any, schema: dict[str, Any], field_name: str) -> None:
    schema_type = schema.get("type")
    if isinstance(schema_type, list):
        if value is None and "null" in schema_type:
            return
        non_null_types = [entry for entry in schema_type if entry != "null"]
        for entry in non_null_types:
            try:
                _validate_schema(value, {**schema, "type": entry}, field_name)
                return
            except ValueError:
                continue
        raise ValueError(f"{field_name} does not match any allowed type.")

    if schema_type == "object":
        if not isinstance(value, dict):
            raise ValueError(f"{field_name} must be an object.")
        properties = schema.get("properties", {})
        required = schema.get("required", [])
        for key in required:
            if key not in value:
                raise ValueError(f"{field_name}.{key} is required.")
        if schema.get("additionalProperties") is False:
            unexpected = set(value.keys()) - set(properties.keys())
            if unexpected:
                raise ValueError(f"{field_name} contains unexpected keys: {sorted(unexpected)}")
        for key, child_schema in properties.items():
            if key in value:
                _validate_schema(value[key], child_schema, f"{field_name}.{key}")
        return

    if schema_type == "array":
        if not isinstance(value, list):
            raise ValueError(f"{field_name} must be an array.")
        item_schema = schema.get("items")
        if item_schema is not None:
            for index, item in enumerate(value):
                _validate_schema(item, item_schema, f"{field_name}[{index}]")
        return

    if schema_type == "string":
        if not isinstance(value, str):
            raise ValueError(f"{field_name} must be a string.")
        min_length = schema.get("minLength")
        if min_length is not None and len(value) < min_length:
            raise ValueError(f"{field_name} is shorter than {min_length}.")
        max_length = schema.get("maxLength")
        if max_length is not None and len(value) > max_length:
            raise ValueError(f"{field_name} is longer than {max_length}.")
        pattern = schema.get("pattern")
        if pattern and not re.fullmatch(pattern, value):
            raise ValueError(f"{field_name} does not match required pattern.")
        string_format = schema.get("format")
        if string_format == "date-time":
            _validate_datetime_string(value, field_name)
        enum_values = schema.get("enum")
        if enum_values is not None and value not in enum_values:
            raise ValueError(f"{field_name} must be one of {enum_values}.")
        return

    if schema_type == "number":
        if not isinstance(value, (int, float)) or isinstance(value, bool):
            raise ValueError(f"{field_name} must be numeric.")
        minimum = schema.get("minimum")
        if minimum is not None and value < minimum:
            raise ValueError(f"{field_name} must be >= {minimum}.")
        maximum = schema.get("maximum")
        if maximum is not None and value > maximum:
            raise ValueError(f"{field_name} must be <= {maximum}.")
        return

    if schema_type == "integer":
        if not isinstance(value, int) or isinstance(value, bool):
            raise ValueError(f"{field_name} must be an integer.")
        minimum = schema.get("minimum")
        if minimum is not None and value < minimum:
            raise ValueError(f"{field_name} must be >= {minimum}.")
        return

    if schema_type == "null":
        if value is not None:
            raise ValueError(f"{field_name} must be null.")
        return

    raise ValueError(f"Unsupported schema type for {field_name}: {schema_type}")


def _validate_datetime_string(value: str, field_name: str) -> None:
    try:
        if value.endswith("Z"):
            __import__("datetime").datetime.fromisoformat(value.replace("Z", "+00:00"))
        else:
            __import__("datetime").datetime.fromisoformat(value)
    except ValueError as exc:
        raise ValueError(f"{field_name} must be a valid ISO 8601 datetime.") from exc


def _as_json_object(value: Any) -> dict[str, Any]:
    if isinstance(value, dict):
        return value
    raise ValueError("Expected JSON object response from OpenAI.")


def _clean_text(value: Any) -> str | None:
    if value is None:
        return None
    text = " ".join(str(value).split())
    return text or None


def _to_float(value: Any) -> float | None:
    if value is None:
        return None
    try:
        return round(float(value), 4)
    except (TypeError, ValueError):
        return None


def _unique_strings(values: list[str]) -> list[str]:
    deduplicated: list[str] = []
    seen: set[str] = set()
    for value in values:
        if value in seen:
            continue
        deduplicated.append(value)
        seen.add(value)
    return deduplicated
if __name__ == "__main__":  # pragma: no cover - CLI entrypoint
    raise SystemExit(main())
