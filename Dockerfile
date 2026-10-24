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
# JSON form so gunicorn is PID 1 and receives Cloud Run's SIGTERM directly.
CMD ["gunicorn", "--bind", "0.0.0.0:8080", "--workers", "1", "--threads", "8", "--timeout", "120", "app:app"]
