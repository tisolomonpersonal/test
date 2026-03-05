# =========================
# Zeabur-ready Dockerfile
# =========================
FROM python:3.11-slim

LABEL language="python"

# -------------------------
# Install system dependencies
# -------------------------
RUN apt-get update && apt-get install -y \
    bash \
    curl \
    wget \
    git \
    supervisor \
    ca-certificates \
    zstd \
    && rm -rf /var/lib/apt/lists/*

# -------------------------
# Install Ollama
# -------------------------
RUN curl -fsSL https://ollama.com/install.sh | sh

# -------------------------
# Set working directory
# -------------------------
WORKDIR /app

# -------------------------
# Environment variables
# -------------------------
ENV NANOBOT_DATA_DIR=/data/nanobot
ENV OLLAMA_MODELS=/data/ollama
ENV WEBUI_DATA_DIR=/data/webui

# -------------------------
# Create Python virtual environment
# -------------------------
RUN python -m venv /venv

# -------------------------
# Install Python packages
# -------------------------
RUN /venv/bin/pip install --upgrade pip && \
    /venv/bin/pip install --no-cache-dir nanobot-ai open-webui

# -------------------------
# Create persistent directories
# -------------------------
RUN mkdir -p \
    /data/nanobot/workspace/memory \
    /data/nanobot/workspace/sessions \
    /data/nanobot/cron \
    /data/ollama \
    /data/webui \
    /var/log/supervisor

# -------------------------
# Nanobot config
# -------------------------
RUN cat > /data/nanobot/config.json << 'EOF'
{
  "providers": {
    "openai": {
      "apiKey": "ollama",
      "apiBase": "http://localhost:11434/v1"
    }
  },
  "agents": {
    "defaults": {
      "model": "openai/kimi-k2.5:cloud"
    }
  },
  "channels": {
    "telegram": {
      "enabled": true,
      "token": "${TELEGRAM_BOT_TOKEN}",
      "allowFrom": []
    }
  }
}
EOF

# -------------------------
# Supervisor configuration
# -------------------------
RUN cat > /etc/supervisor/conf.d/services.conf << 'EOF'
[supervisord]
nodaemon=true

[program:ollama]
command=/usr/local/bin/ollama serve
environment=OLLAMA_HOST=0.0.0.0:11434,OLLAMA_MODELS=/data/ollama
autostart=true
autorestart=true
stdout_logfile=/var/log/supervisor/ollama.log
stderr_logfile=/var/log/supervisor/ollama.err

[program:nanobot-gateway]
command=/venv/bin/nanobot gateway
directory=/data/nanobot
autostart=true
autorestart=true
stdout_logfile=/var/log/supervisor/gateway.log
stderr_logfile=/var/log/supervisor/gateway.err

[program:nanobot-agent]
command=/venv/bin/nanobot agent
directory=/data/nanobot
autostart=true
autorestart=true
stdout_logfile=/var/log/supervisor/agent.log
stderr_logfile=/var/log/supervisor/agent.err

[program:webui]
command=/venv/bin/open-webui serve --host 0.0.0.0 --port 8080
directory=/data/webui
autostart=true
autorestart=true
stdout_logfile=/var/log/supervisor/webui.log
stderr_logfile=/var/log/supervisor/webui.err
EOF

# -------------------------
# Expose ports
# -------------------------
EXPOSE 8080
EXPOSE 11434

# -------------------------
# Start supervisor
# -------------------------
CMD ["/usr/bin/supervisord"]
