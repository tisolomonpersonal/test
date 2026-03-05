# =========================
# Nanobot + Ollama Docker
# =========================
FROM python:3.11-slim

# Install system tools
RUN apt-get update && apt-get install -y \
    curl \
    git \
    bash \
    supervisor \
    && rm -rf /var/lib/apt/lists/*

# Install Ollama
RUN curl -fsSL https://ollama.com/install.sh | sh

# Create working directory
WORKDIR /app

# Clone nanobot repo
RUN git clone https://github.com/HKUDS/nanobot.git

# Create virtual environment
RUN python -m venv /nano_env

# Install Nanobot
RUN /nano_env/bin/pip install --upgrade pip && \
    /nano_env/bin/pip install nanobot-ai

# Create nanobot config
RUN mkdir -p /root/.nanobot

RUN cat <<EOF > /root/.nanobot/config.json
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
      "token": "8608913518:AAHCnEO8AFSU-CgSi6bML_TPASJmhXn8xWQ",
      "allowFrom": []
    }
  }
}
EOF

# Supervisor config to run multiple services
RUN mkdir -p /etc/supervisor/conf.d

RUN cat <<EOF > /etc/supervisor/conf.d/services.conf
[supervisord]
nodaemon=true

[program:ollama]
command=/usr/local/bin/ollama serve
autostart=true
autorestart=true

[program:nanobot_gateway]
command=/nano_env/bin/nanobot gateway
directory=/app/nanobot
autostart=true
autorestart=true

[program:nanobot_agent]
command=/nano_env/bin/nanobot agent
directory=/app/nanobot
autostart=true
autorestart=true
EOF

# Expose ports
EXPOSE 11434

# Start everything
CMD ["/usr/bin/supervisord"]
