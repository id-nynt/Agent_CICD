FROM python:3.12-slim

WORKDIR /service

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY service.py .

ENV PORT=8000
EXPOSE 8000

CMD ["python", "service.py"]
