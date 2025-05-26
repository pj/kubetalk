FROM python:3.12-slim

# Default port argument
ARG PORT=8000
ENV PORT=$PORT

WORKDIR /app

# Install uv
RUN pip install uv

# Copy requirements first for better caching
COPY pyproject.toml .

RUN uv venv

# Install dependencies using uv
RUN uv pip install .

# Copy the rest of the application
COPY src/ src/

WORKDIR /app/src

# Command to run the application
CMD ["sh", "-c", "uv run uvicorn main:app --host 0.0.0.0 --port ${PORT}"] 