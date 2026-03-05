# =========================
# Zeabur-ready Dockerfile
# =========================
FROM ubuntu:22.04

LABEL "language"="python"

# -------------------------
# Install system dependencies
# -------------------------
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    git \
    python3 \
    python3-pip \
    python3-venv \
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
WORKDIR /root

# -------------------------
# Create Python virtual environment
# -------------------------
RUN python3 -m venv nano_env

# -------------------------
# Install Python packages in venv
# -------------------------
RUN /bin/bash -c "source nano_env/bin/activate && pip install --no-cache-dir --upgrade pip && pip install --no-cache-dir nanobot-ai open-webui"

# -------------------------
# Create necessary directories
# -------------------------
RUN mkdir -p /root/.nanobot/workspace/memory \
    /root/.nanobot/workspace/sessions \
    /root/.nanobot/cron \
    /root/.ollama \
    /var/log/supervisor

# -------------------------
# Create Nanobot configuration
# -------------------------
RUN cat > /root/.nanobot/config.json << 'EOF'
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
# Create Supervisor configuration
# -------------------------
RUN cat > /etc/supervisor/conf.d/services.conf << 'EOF'
[program:ollama]
command=/usr/local/bin/ollama serve
autostart=true
autorestart=true
stderr_logfile=/var/log/supervisor/ollama.err.log
stdout_logfile=/var/log/supervisor/ollama.out.log
startsecs=5
environment=OLLAMA_HOST=0.0.0.0:11434

[program:nanobot-gateway]
command=/root/nano_env/bin/nanobot gateway
autostart=true
autorestart=true
stderr_logfile=/var/log/supervisor/gateway.err.log
stdout_logfile=/var/log/supervisor/gateway.out.log
directory=/root
startsecs=10

[program:nanobot-agent]
command=/root/nano_env/bin/nanobot agent
autostart=true
autorestart=true
stderr_logfile=/var/log/supervisor/agent.err.log
stdout_logfile=/var/log/supervisor/agent.out.log
directory=/root
startsecs=15

[program:webui]
command=/root/nano_env/bin/open-webui serve --host 0.0.0.0 --port 8080
autostart=true
autorestart=true
stderr_logfile=/var/log/supervisor/webui.err.log
stdout_logfile=/var/log/supervisor/webui.out.log
EOF

# -------------------------
# Expose ports
# -------------------------
EXPOSE 8080 11434

# -------------------------
# Start Supervisor
# -------------------------
CMD ["/usr/bin/supervisord", "-n"]
