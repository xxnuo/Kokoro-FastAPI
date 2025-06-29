#!/bin/bash
set -e

if [ "$DOWNLOAD_MODEL" = "true" ]; then
    python3 download_model.py --output api/src/models/v1_1-zh
fi

exec uvicorn api.src.main:app --host 0.0.0.0 --port 8880 --log-level debug