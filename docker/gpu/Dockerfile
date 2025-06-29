# FROM --platform=$BUILDPLATFORM nvidia/cuda:12.8.0-cudnn-runtime-ubuntu24.04
FROM --platform=$BUILDPLATFORM registry.lazycat.cloud/x/xtts:r36.3.0

# Set non-interactive frontend
ENV DEBIAN_FRONTEND=noninteractive

# Ubuntu 22.04 源
RUN sed -i 's/ports.ubuntu.com/mirrors.tuna.tsinghua.edu.cn/g' /etc/apt/sources.list

# Jetson source
RUN apt-key adv --fetch-keys https://repo.download.nvidia.com/jetson/jetson-ota-public.asc
RUN echo "deb https://repo.download.nvidia.com/jetson/common r36.4 main" | tee -a /etc/apt/sources.list && \
    echo "deb https://repo.download.nvidia.com/jetson/t234 r36.4 main" | tee -a /etc/apt/sources.list && \
    echo "deb https://repo.download.nvidia.com/jetson/ffmpeg r36.4 main" | tee -a /etc/apt/sources.list

# Install dependencies
RUN apt-get update && apt-get install -y \
    espeak-ng \
    espeak-ng-data \
    libsndfile1 \
    ffmpeg \
    && apt-get clean && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /usr/share/espeak-ng-data \
    && ln -s /usr/lib/*/espeak-ng-data/* /usr/share/espeak-ng-data/

# Install UV using the installer script
RUN curl -LsSf https://astral.sh/uv/install.sh | sh && \
    mv /root/.local/bin/uv /usr/local/bin/ && \
    mv /root/.local/bin/uvx /usr/local/bin/ 

# Create non-root user and set up directories and permissions
RUN useradd -m -u 1001 appuser && \
    mkdir -p /app/api/src/models/v1_1-zh && \
    chown -R appuser:appuser /app

USER appuser
WORKDIR /app

# Copy dependency files
COPY --chown=appuser:appuser pyproject.toml ./pyproject.toml

ENV PHONEMIZER_ESPEAK_PATH=/usr/bin \
    PHONEMIZER_ESPEAK_DATA=/usr/share/espeak-ng-data \
    ESPEAK_DATA_PATH=/usr/share/espeak-ng-data

# Use the system Python environment
ENV UV_PROJECT_ENVIRONMENT="/usr/local"

# Install dependencies with GPU extras (using cache mounts)
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --extra gpu

# Copy project files including models
COPY --chown=appuser:appuser api ./api
COPY --chown=appuser:appuser web ./web
COPY --chown=appuser:appuser docker/scripts/ ./
RUN chmod +x ./entrypoint.sh


# Set all environment variables in one go
ENV PYTHONUNBUFFERED=1 \
    PYTHONPATH=/app:/app/api \
    PATH="/usr/local/bin:$PATH" \
    UV_LINK_MODE=copy \
    USE_GPU=true 

ENV DOWNLOAD_MODEL=false
# Download model if enabled
RUN if [ "$DOWNLOAD_MODEL" = "true" ]; then \
    python download_model.py --output api/src/models/v1_1-zh; \
    fi

ENV DEVICE="gpu"
# Run FastAPI server through entrypoint.sh
CMD ["./entrypoint.sh"]
