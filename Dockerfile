# Multi-stage build for tg-archive
FROM python:3.12-alpine AS builder

# Install build dependencies
RUN apk --no-cache add \
    gcc \
    musl-dev \
    libffi-dev \
    python3-dev \
    build-base

WORKDIR /usr/src/app

# Copy and install Python dependencies
COPY requirements.txt ./
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# Final stage
FROM python:3.12-alpine

# Install runtime dependencies
RUN apk --no-cache add \
    libffi \
    libmagic

WORKDIR /usr/src/app

# Copy Python packages from builder
COPY --from=builder /usr/local/lib/python3.12/site-packages /usr/local/lib/python3.12/site-packages
COPY --from=builder /usr/local/bin /usr/local/bin

# Copy application code
COPY tgarchive ./tgarchive
COPY LICENSE ./
COPY MANIFEST.in ./
COPY README.md ./
COPY setup.py ./
COPY entrypoint.sh ./

RUN chmod +x ./entrypoint.sh

ENTRYPOINT ["./entrypoint.sh"]
CMD ["--help"]
