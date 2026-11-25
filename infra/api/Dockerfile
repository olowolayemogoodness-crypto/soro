FROM python:3.12-slim
ENV PYTHONUNBUFFERED=1 PIP_NO_CACHE_DIR=1 SORO_AGENT_DIR=/app/agent
WORKDIR /app
COPY infra/api/pyproject.toml .
RUN pip install "fastapi>=0.115" "uvicorn[standard]>=0.30" "livekit-api>=1.0" "pydantic>=2.7" "psycopg[binary]>=3.2" "httpx>=0.27"
COPY infra/api/main.py infra/api/tutor_turn.py ./
COPY infra/api/migrations ./migrations
# tutor brain code and its small content side files (step_graph reads ../content/*.json)
COPY agent/brain.py agent/tutor.py agent/step_graph.py agent/tts.py ./agent/
COPY content/term-map.json content/en-text.json ./content/
EXPOSE 8000
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
