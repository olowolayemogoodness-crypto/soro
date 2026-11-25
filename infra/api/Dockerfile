FROM python:3.12-slim
ENV PYTHONUNBUFFERED=1 PIP_NO_CACHE_DIR=1
WORKDIR /app
COPY pyproject.toml .
RUN pip install "fastapi>=0.115" "uvicorn[standard]>=0.30" "livekit-api>=1.0" "pydantic>=2.7" "psycopg[binary]>=3.2"
COPY main.py .
COPY migrations ./migrations
EXPOSE 8000
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
