from __future__ import annotations

import shutil
import tempfile
from pathlib import Path

from fastapi import FastAPI, File, Form, HTTPException, UploadFile

from ris_extract import SUPPORTED_SUFFIXES, extract_receipt


app = FastAPI(title="ris_extract_donut", version="0.2.0")


@app.get("/healthz")
def health() -> dict[str, str]:
    return {"status": "ok"}


@app.post("/v1/extractions")
def extract(requestId: str = Form(...), file: UploadFile = File(...)) -> dict:
    if not requestId or not requestId.startswith("ext_"):
        raise HTTPException(
            status_code=400,
            detail='requestId must be non-empty and start with "ext_"',
        )

    suffix = Path(file.filename or "upload").suffix.lower()
    if suffix not in SUPPORTED_SUFFIXES:
        supported = ", ".join(sorted(SUPPORTED_SUFFIXES))
        raise HTTPException(
            status_code=400,
            detail=f"Unsupported file type: {suffix or '<none>'}. Expected one of: {supported}",
        )

    with tempfile.NamedTemporaryFile(delete=False, suffix=suffix) as temp_file:
        try:
            shutil.copyfileobj(file.file, temp_file)
            temp_path = Path(temp_file.name)
        finally:
            file.file.close()

    try:
        return extract_receipt(temp_path, request_id=requestId)
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc
    finally:
        temp_path.unlink(missing_ok=True)
