FROM python:3.12-slim

# Install runtime dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    libmagic1 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /usr/src/app

# Install Python dependencies
COPY requirements.txt ./
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY tgarchive ./tgarchive
COPY LICENSE ./
COPY MANIFEST.in ./
COPY README.md ./
COPY setup.py ./

# Install tgarchive as a proper Python package
RUN pip install --no-cache-dir -e .

# Create entrypoint that changes to config directory
COPY entrypoint.sh ./
RUN chmod +x ./entrypoint.sh

ENTRYPOINT ["./entrypoint.sh"]
CMD ["--help"]
