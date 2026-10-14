"""Minimal web service with a health endpoint and a version endpoint."""
import os
import socket

from fastapi import FastAPI

APP_VERSION = os.environ.get("APP_VERSION", "local")

app = FastAPI(title="container-app", version=APP_VERSION)


@app.get("/health")
def health():
    """Used by the load balancer to decide whether a task can receive traffic."""
    return {"status": "ok"}


@app.get("/")
def root():
    """Shows which version and which task answered, useful to watch a rolling deploy."""
    return {
        "service": "container-app",
        "version": APP_VERSION,
        "task_host": socket.gethostname(),
        "message": "Released by GitHub Actions",
    }
