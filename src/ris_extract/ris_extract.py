#!/usr/bin/env python3

"""CLI OCR extractor for receipt images using PaddleOCR only."""

from __future__ import annotations

import argparse
import json
import mimetypes
import platform
import sys
import uuid
from pathlib import Path
from typing import Any


SCRIPT_VERSION = "0.2.0"
SUPPORTED_SUFFIXES = {".png", ".jpg", ".jpeg"}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Extract raw OCR data from a receipt image."
    )
    parser.add_argument("receipt_path", type=Path, help="Path to a PNG or JPEG receipt image")
    parser.add_argument(
        "--output",
        type=Path,
        help="Optional path for the JSON output file",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()

    try:
        result = extract_receipt(args.receipt_path)
    except Exception as exc:  # pragma: no cover - CLI boundary
        print(f"error: {exc}", file=sys.stderr)
        return 1

    output_text = json.dumps(result, ensure_ascii=False, indent=2)

    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(output_text + "\n", encoding="utf-8")

    print(output_text)
    return 0


def extract_receipt(receipt_path: Path) -> dict[str, Any]:
    _validate_receipt_path(receipt_path)

    ocr_result = _run_paddle_ocr(receipt_path)
    blocks = ocr_result["blocks"]
    if not blocks:
        raise RuntimeError("PaddleOCR failed to produce usable text blocks")

    lines = _group_blocks_into_lines(blocks)
    raw_text = "\n".join(line["text"] for line in lines)

    return {
        "requestId": f"ext_{uuid.uuid4().hex[:12]}",
        "source": {
            "fileName": receipt_path.name,
            "filePath": str(receipt_path.resolve()),
            "mimeType": mimetypes.guess_type(receipt_path.name)[0] or "application/octet-stream",
        },
        "warnings": _unique_strings(ocr_result["warnings"]),
        "ocr": {
            "rawText": raw_text,
            "blocks": blocks,
            "lines": lines,
        },
        "metadata": {
            "extractor": "ris_extract",
            "version": SCRIPT_VERSION,
            "models": {
                "ocr": ocr_result["model_info"],
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
