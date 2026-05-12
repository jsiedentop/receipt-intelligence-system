from __future__ import annotations

import shutil
import tempfile
from pathlib import Path

from fastapi import FastAPI, File, HTTPException, UploadFile

from ris_extract import SUPPORTED_SUFFIXES, extract_receipt


app = FastAPI(title="ris_extract_donut", version="0.2.0")


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


@app.post("/extract")
def extract(file: UploadFile = File(...)) -> dict:
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
        return extract_receipt(temp_path)
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc
    finally:
        temp_path.unlink(missing_ok=True)
