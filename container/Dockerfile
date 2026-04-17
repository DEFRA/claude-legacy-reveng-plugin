FROM node:20

# Dev tools
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      git jq zsh ripgrep fzf bat neovim curl sudo \
 && rm -rf /var/lib/apt/lists/* \
 && ln -s /usr/bin/batcat /usr/local/bin/bat

# GitHub CLI
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
      -o /usr/share/keyrings/githubcli-archive-keyring.gpg \
 && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
      > /etc/apt/sources.list.d/github-cli.list \
 && apt-get update \
 && apt-get install -y --no-install-recommends gh \
 && rm -rf /var/lib/apt/lists/*

# Claude Code
RUN npm install -g @anthropic-ai/claude-code

# Passwordless sudo for the node user
RUN echo "node ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/node \
 && chmod 0440 /etc/sudoers.d/node

# Mark as devcontainer
ENV DEVCONTAINER=true

# Shell history directory (mount target for persistent volume)
RUN mkdir -p /commandhistory && chown node:node /commandhistory

USER node
WORKDIR /workspace
