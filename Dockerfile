# ═══════════════════════════════════════════════════════════════════
# CP2 — Containerization (production-ready)
#
#   [x] Multi-stage build: `builder` cài dependency, `runtime` chỉ copy kết quả
#   [x] Base image slim
#   [x] COPY requirements.txt + pip install TRƯỚC khi COPY source code
#   [x] Chạy bằng user thường (USER appuser), không phải root
#   [x] HEALTHCHECK gọi vào /health
#   [x] Đọc cổng từ biến môi trường PORT
#
# Kiểm tra:  pytest tests/test_cp2.py -v
# Build thử: docker build -t day12-agent:prod .
# ═══════════════════════════════════════════════════════════════════

# ─── Stage 1: builder — được phép nặng, bị vứt đi sau khi build ───
FROM python:3.11-slim AS builder

ENV PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=1

# Mọi dependency hiện có sẵn wheel cho Python 3.11/Linux nên không cần compiler.
# Nếu sau này thêm thư viện phải biên dịch, cài build-essential ở ĐÂY — stage
# này bị vứt đi nên compiler không lọt vào image cuối.

WORKDIR /build

# Chỉ copy requirements trước → layer pip install được cache khi sửa code
COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

# ─── Stage 2: runtime — thứ duy nhất trở thành image ───
FROM python:3.11-slim AS runtime

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PORT=8000

# Chỉ mang theo thư viện đã cài, không mang compiler
COPY --from=builder /install /usr/local

RUN useradd --create-home --uid 10001 appuser

WORKDIR /app

# Source code copy SAU cùng — sửa code chỉ làm mất cache từ đây trở xuống
COPY --chown=appuser:appuser app ./app
COPY --chown=appuser:appuser utils ./utils

USER appuser

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD python -c "import os, urllib.request; urllib.request.urlopen('http://127.0.0.1:' + os.environ.get('PORT', '8000') + '/health', timeout=4).read()" || exit 1

# 0.0.0.0 để bên ngoài container gọi vào được; ${PORT:-8000} vì cloud tự gán cổng.
# exec → uvicorn là PID 1 và nhận SIGTERM trực tiếp (graceful shutdown).
CMD ["sh", "-c", "exec uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}"]
