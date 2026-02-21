FROM node:22-bookworm

ARG OPENCLAW_DOCKER_APT_PACKAGES=""

RUN if [ -n "$OPENCLAW_DOCKER_APT_PACKAGES" ]; then \
        apt-get update && \
        apt-get install -y --no-install-recommends $OPENCLAW_DOCKER_APT_PACKAGES && \
        rm -rf /var/lib/apt/lists/*; \
    fi

RUN curl -fsSL https://bun.sh/install | bash
ENV PATH="/root/.bun/bin:${PATH}"

RUN corepack enable

WORKDIR /app

COPY package.json pnpm-lock.yaml pnpm-workspace.yaml .npmrc ./
COPY ui/package.json ./ui/package.json
COPY scripts ./scripts

RUN pnpm install --frozen-lockfile

COPY . .
RUN pnpm build
RUN pnpm ui:install
RUN pnpm ui:build

RUN chown -R node:node /app /home/node
USER node

ENV NODE_ENV=production

EXPOSE 18789

CMD ["node", "dist/index.js", "--allow-unconfigured"]
