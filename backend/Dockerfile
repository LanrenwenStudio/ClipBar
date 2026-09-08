FROM python:3.12-alpine

WORKDIR /app
COPY clipbar_backend.py /app/clipbar_backend.py

ENV PYTHONUNBUFFERED=1
EXPOSE 8080
VOLUME ["/data"]

CMD ["python", "/app/clipbar_backend.py"]
