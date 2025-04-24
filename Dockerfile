### Base Stage ###
FROM node:22-bookworm-slim AS base

# Cache mount for apt and install required packages
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
    curl bash linux-libc-dev libbpf-dev openssh-client \
    python3 g++ build-essential git \
    poppler-utils poppler-data locales locales-all \
    libcap-dev nginx gettext && \
    apt-get install --only-upgrade -y linux-libc-dev && \
    apt-get install -y --no-install-recommends \
    zlib1g zlib1g-dev libtiff6 && \
    yarn config set python /usr/bin/python3 && \
    npm install -g node-gyp && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Global npm installs
RUN npm i -g npm@11 pnpm@9.15.0

# Environment variables
ENV LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8 \
    NX_DAEMON=false \
    NX_CACHE_DIRECTORY=/tmp/nx-cache

# Preinstall isolated-vm and types
RUN cd /usr/src && npm i isolated-vm@5.0.1 && \
    pnpm store add @tsconfig/node18@1.0.0 \
                  @types/node@18.17.1 \
                  typescript@4.9.4

### Build Stage ###
FROM base AS build

WORKDIR /usr/src/app
COPY . .

# Install dependencies
COPY .npmrc package.json package-lock.json ./
RUN npm install -f

# Install nx and clean cache
RUN npm install -g nx@20.4.2 && \
    rm -rf /root/.cache/nx .nx/cache

# Build shared dependencies
RUN npx nx run-many --target=build --projects=shared,pieces-framework --skip-nx-cache

# Handle pieces-common separately
RUN set -x && \
    npx nx build pieces-common --skip-nx-cache && \
    mkdir -p /tmp/pieces-common && \
    cp -r dist/packages/pieces/community/common/* /tmp/pieces-common/ && \
    cd /tmp/pieces-common && \
    version=$(node -p "require('./package.json').version") && \
    npm install --save tslib @activepieces/pieces-framework && \
    echo "{\"name\":\"@activepieces/pieces-common\",\"version\":\"$version\",\"main\":\"src/index.js\",\"types\":\"src/index.d.ts\"}" > package.json && \
    npm pack && \
    mkdir -p /usr/src/app/node_modules/@activepieces/pieces-common && \
    tar -xzf activepieces-pieces-common-*.tgz -C /usr/src/app/node_modules/@activepieces/pieces-common --strip-components=1

# Build remaining pieces
RUN npx nx run-many --target=build --projects=pieces --skip-nx-cache && \
    cd packages/pieces/community && \
    npm install tslib @activepieces/pieces-framework @activepieces/pieces-common

# Individual community piece builds
RUN for piece in microsoft-teams smtp open-router webhook http whatsapp whatsable slack; do \
    echo "Building piece: $piece" && \
    npx nx build pieces-$piece --skip-nx-cache && \
    rm -rf /tmp/nx-cache/* || true; \
done

# Build API and UI
RUN npx nx run-many --target=build --projects=server-api --configuration production --skip-nx-cache && \
    npx nx run-many --target=build --projects=react-ui --skip-nx-cache

# Setup isolated server dependencies
RUN mkdir -p /tmp/server-deps && \
    cd /tmp/server-deps && \
    echo '{"name":"server-deps","version":"1.0.0","private":true}' > package.json && \
    npm install --no-package-lock \
        @fastify/sensible@5.5.0 \
        @sinclair/typebox@0.31.28 \
        @fastify/type-provider-typebox@3.5.0 \
        fastify@4.28.1 \
        fastify-plugin@4.5.1 \
        fluent-json-schema@3.1.0 \
        pg@8.11.3 \
        ioredis@5.4.1 && \
    cp -r node_modules /usr/src/app/dist/packages/server/api/

### Runtime Stage ###
FROM base AS run

WORKDIR /usr/src/app

# Copy default isolate config
COPY packages/server/api/src/assets/default.cf /usr/local/etc/isolate

# Set up Nginx
COPY nginx.react.conf /etc/nginx/nginx.conf

# Copy license
COPY --from=build /usr/src/app/LICENSE .

# Create necessary directories
RUN mkdir -p /usr/src/app/packages/pieces/community \
             /usr/src/app/packages/pieces/ \
             /usr/src/app/dist/packages/{pieces/community,server,engine,shared}

# Copy pieces and builds
COPY --from=build /usr/src/app/node_modules/@activepieces/pieces-common /usr/src/app/node_modules/@activepieces/pieces-common
COPY --from=build /usr/src/app/packages/pieces /usr/src/app/packages/pieces
COPY --from=build /usr/src/app/dist/packages/pieces /usr/src/app/dist/packages/pieces
COPY --from=build /usr/src/app/dist/packages/server /usr/src/app/dist/packages/server
COPY --from=build /usr/src/app/dist/packages/engine /usr/src/app/dist/packages/engine
COPY --from=build /usr/src/app/dist/packages/shared /usr/src/app/dist/packages/shared

# Final installs for piece loading
WORKDIR /usr/src/app/packages/pieces
RUN npm install tslib @activepieces/pieces-framework @activepieces/pieces-common
WORKDIR /usr/src/app/packages/pieces/community
RUN npm install tslib @activepieces/pieces-framework @activepieces/pieces-common

WORKDIR /usr/src/app

# Env vars for piece loading
ENV AP_DEV_PIECES="microsoft-teams,smtp,open-router,webhook,http,whatsapp,whatsable,slack" \
    AP_PIECES_SOURCE=FILE \
    AP_PIECES_SYNC_MODE=NONE

# Copy all node_modules
COPY --from=build /usr/src/app/node_modules /usr/src/app/node_modules
COPY --from=build /usr/src/app/dist/packages/server/api/node_modules /usr/src/app/dist/packages/server/api/node_modules

# Copy static assets
COPY --from=build /usr/src/app/dist/packages/react-ui /usr/share/nginx/html/
COPY --from=build /usr/src/app/packages /usr/src/app/packages

# Entrypoint setup
COPY docker-entrypoint.sh .
RUN chmod +x docker-entrypoint.sh
ENTRYPOINT ["./docker-entrypoint.sh"]

EXPOSE 80
LABEL service=activepieces
