FROM python:3.13-slim

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PORT=8080

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app.py character.py ./
COPY templates/ templates/
COPY static/ static/

EXPOSE 8080

# One worker keeps in-memory ADK sessions consistent; threads handle concurrency.
# `exec` keeps gunicorn as PID 1 so it receives Cloud Run's SIGTERM directly, and
# the shell expands ${PORT} to match whatever port the service is configured for.
CMD ["sh", "-c", "exec gunicorn --bind 0.0.0.0:${PORT:-8080} --workers 1 --threads 8 --timeout 120 app:app"]
