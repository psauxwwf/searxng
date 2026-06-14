ARG NODE_IMAGE=docker.io/node:lts-bookworm-slim
ARG SEARXNG_IMAGE=docker.io/searxng/searxng:2026.5.31-7159b8aed
ARG MCP_SEARXNG_VERSION=latest

FROM ${NODE_IMAGE} AS mcp-build
ARG MCP_SEARXNG_VERSION

RUN npm install -g "mcp-searxng@${MCP_SEARXNG_VERSION}" \
    && npm cache clean --force

FROM ${SEARXNG_IMAGE}

COPY --from=mcp-build /usr/local/bin/node /usr/local/bin/
COPY --from=mcp-build /usr/local/lib/node_modules /usr/local/lib/node_modules

COPY config/searxng/settings.yml /usr/local/share/searxng/settings.yml.template
COPY docker/combined-entrypoint.sh /usr/local/bin/combined-entrypoint.sh

RUN ln -sf /usr/local/lib/node_modules/mcp-searxng/dist/cli.js /usr/local/bin/mcp-searxng \
    && chmod 0755 /usr/local/bin/combined-entrypoint.sh

ENV SEARXNG_URL=http://127.0.0.1:8080

EXPOSE 3000

ENTRYPOINT ["/usr/local/bin/combined-entrypoint.sh"]
