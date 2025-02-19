FROM node:18.20.5-bullseye-slim AS base

# Use a cache mount for apt to speed up the process
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && \
    apt-get install -y --no-install-recommends \
    openssh-client \
    python3 \
    g++ \
    build-essential \
    git \
    poppler-utils \
    poppler-data && \
    yarn config set python /usr/bin/python3 && \
    npm install -g node-gyp
RUN npm i -g npm@9.9.3 pnpm@9.15.0

# Set the locale
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8
ENV NX_DAEMON=false
ENV NX_CACHE_DIRECTORY=/tmp/nx-cache

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
    locales \
    locales-all \
    libcap-dev \
    && rm -rf /var/lib/apt/lists/*

# install isolated-vm in a parent directory to avoid linking the package in every sandbox
RUN cd /usr/src && npm i isolated-vm@5.0.1

RUN pnpm store add @tsconfig/node18@1.0.0
RUN pnpm store add @types/node@18.17.1

RUN pnpm store add typescript@4.9.4

### STAGE 1: Build ###
FROM base AS build

# Set up backend
WORKDIR /usr/src/app
COPY . .

# Install all dependencies first
COPY .npmrc package.json package-lock.json ./
RUN npm ci

# Install nx globally for building pieces
RUN npm install -g nx@20.4.2

# Clean any existing nx cache
RUN rm -rf /root/.cache/nx && rm -rf .nx/cache

# Build shared dependencies first
RUN npx nx run-many --target=build --projects=shared,pieces-framework --skip-nx-cache

# Find pieces-common location and build it
RUN set -x && \
    # Build pieces-common
    npx nx build pieces-common --skip-nx-cache && \
    # Create temp directory
    mkdir -p /tmp/pieces-common && \
    # Copy community common files
    cp -r dist/packages/pieces/community/common/* /tmp/pieces-common/ && \
    cd /tmp/pieces-common && \
    # Keep version from original package.json
    version=$(node -p "require('./package.json').version") && \
    # Install dependencies
    npm install --save tslib @activepieces/pieces-framework && \
    # Create proper package.json with version
    echo "{\"name\":\"@activepieces/pieces-common\",\"version\":\"$version\",\"main\":\"src/index.js\",\"types\":\"src/index.d.ts\"}" > package.json && \
    # Pack and install directly to node_modules
    npm pack && \
    mkdir -p /usr/src/app/node_modules/@activepieces/pieces-common && \
    tar -xzf activepieces-pieces-common-*.tgz -C /usr/src/app/node_modules/@activepieces/pieces-common --strip-components=1

# Now build remaining pieces
RUN npx nx run-many --target=build --projects=pieces --skip-nx-cache

# Install dependencies for all pieces with pieces-common available
RUN cd packages/pieces/community && \
    npm install tslib @activepieces/pieces-framework @activepieces/pieces-common

# Build community pieces individually with cleanup between builds
RUN for piece in activecampaign activepieces actualbudget acumbamail afforai aianswer airtable amazon-s3 amazon-sns amazon-sqs aminos apify apitable apollo approval asana ashby assemblyai azure-communication-services azure-openai bamboohr bannerbear baserow beamer bettermode binance bonjoro box brilliant-directories bubble cal-com calendly captain-data cartloom certopus chargekeep clarifai claude clearout clickup clockodo common confluence connections constant-contact contentful contiguity convertkit crypto csv customer-io data-mapper data-summarizer date-helper datocms deepl deepseek delay discord discourse drip dropbox dust elevenlabs facebook-leads facebook-pages figma file-helper fliqr-ai flowise flowlu formbricks forms frame framework freshdesk freshsales gameball gcloud-pubsub generatebanners ghostcms gistly github gitlab gmail google-calendar google-contacts google-docs google-drive google-forms google-gemini google-my-business google-search-console google-sheets google-tasks gotify graphql gravityforms grist groq hackernews harvest heartbeat http hubspot image-ai image-helper imap instagram-business instasent intercom invoiceninja jira-cloud jotform json kallabot-ai kimai kizeo-forms krisp-call lead-connector lever line linear linka linkedin llmrails localai mailchimp mailer-lite maileroo mailjet mastodon math-helper matomo matrix mattermost mautic messagebird metabase microsoft-dynamics-365-business-central microsoft-dynamics-crm microsoft-excel-365 microsoft-onedrive microsoft-outlook-calendar microsoft-sharepoint microsoft-teams mindee mixpanel monday moxie-crm mysql nifty nocodb notion ntfy odoo onfleet openai open-router pastebin pastefy pdf perplexity-ai photoroom pipedrive poper postgres posthog pushover pylon qdrant qrcode queue quickzu rabbitmq razorpay reachinbox reoon-verifier resend retable retune robolly rss saastic salesforce scenario schedule scrapegrapghai segment sendfox sendgrid sendinblue sendy sessions-us seven sftp shopify simplepdf slack smaily smtp snowflake soap sperse spotify square stability-ai stable-diffusion-webui store straico stripe subflows supabase supadata surrealdb surveymonkey tags talkable tally taskade tavily telegram-bot text-ai text-helper tidycal todoist totalcms trello twilio twin-labs twitter typeform upgradechat utility-ai vbout village vtex vtiger webflow webhook webling wedof whatsable whatsapp woocommerce wootric wordpress xero xml youtube zendesk zerobounce zoho-books zoho-crm zoho-invoice zoom zuora; do \
    echo "Building piece: $piece" && \
    npx nx build pieces-$piece --skip-nx-cache && \
    rm -rf /tmp/nx-cache/* || true; \
done

# Now build the server and UI
RUN npx nx run-many --target=build --projects=server-api --configuration production --skip-nx-cache
RUN npx nx run-many --target=build --projects=react-ui --skip-nx-cache

# Set up isolated directory for server dependencies
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
    cd /usr/src/app/dist/packages/server/api && \
    rm -rf node_modules && \
    cp -r /tmp/server-deps/node_modules .

### STAGE 2: Run ###
FROM base AS run

# Set up backend
WORKDIR /usr/src/app

COPY packages/server/api/src/assets/default.cf /usr/local/etc/isolate

# Install Nginx and gettext for envsubst
RUN apt-get update && apt-get install -y nginx gettext

# Copy Nginx configuration template
COPY nginx.react.conf /etc/nginx/nginx.conf

COPY --from=build /usr/src/app/LICENSE .

# Create necessary directories
RUN mkdir -p /usr/src/app/packages/pieces/community/
RUN mkdir -p /usr/src/app/packages/pieces/
RUN mkdir -p /usr/src/app/dist/packages/pieces/community/

# Copy pieces-common first
COPY --from=build /usr/src/app/node_modules/@activepieces/pieces-common /usr/src/app/node_modules/@activepieces/pieces-common

# Copy piece directories maintaining the exact structure expected by the server
COPY --from=build /usr/src/app/packages/pieces/ /usr/src/app/packages/pieces/
COPY --from=build /usr/src/app/packages/pieces/community/ /usr/src/app/packages/pieces/community/
COPY --from=build /usr/src/app/dist/packages/pieces/ /usr/src/app/dist/packages/pieces/
COPY --from=build /usr/src/app/dist/packages/pieces/community/ /usr/src/app/dist/packages/pieces/community/

# Set up other necessary directories
RUN mkdir -p /usr/src/app/dist/packages/server/
RUN mkdir -p /usr/src/app/dist/packages/engine/
RUN mkdir -p /usr/src/app/dist/packages/shared/

# Copy server files
COPY --from=build /usr/src/app/dist/packages/engine/ /usr/src/app/dist/packages/engine/
COPY --from=build /usr/src/app/dist/packages/server/ /usr/src/app/dist/packages/server/
COPY --from=build /usr/src/app/dist/packages/shared/ /usr/src/app/dist/packages/shared/

# Install dependencies for piece loading
WORKDIR /usr/src/app/packages/pieces
RUN npm install tslib @activepieces/pieces-framework @activepieces/pieces-common
WORKDIR /usr/src/app/packages/pieces/community
RUN npm install tslib @activepieces/pieces-framework @activepieces/pieces-common

# Back to app directory
WORKDIR /usr/src/app

# Set environment variables for FILE mode piece loading
ENV AP_DEV_PIECES="activecampaign activepieces actualbudget acumbamail afforai aianswer airtable amazon-s3 amazon-sns amazon-sqs aminos apify apitable apollo approval asana ashby assemblyai azure-communication-services azure-openai bamboohr bannerbear baserow beamer bettermode binance bonjoro box brilliant-directories bubble cal-com calendly captain-data cartloom certopus chargekeep clarifai claude clearout clickup clockodo common confluence connections constant-contact contentful contiguity convertkit crypto csv customer-io data-mapper data-summarizer date-helper datocms deepl deepseek delay discord discourse drip dropbox dust elevenlabs facebook-leads facebook-pages figma file-helper fliqr-ai flowise flowlu formbricks forms frame framework freshdesk freshsales gameball gcloud-pubsub generatebanners ghostcms gistly github gitlab gmail google-calendar google-contacts google-docs google-drive google-forms google-gemini google-my-business google-search-console google-sheets google-tasks gotify graphql gravityforms grist groq hackernews harvest heartbeat http hubspot image-ai image-helper imap instagram-business instasent intercom invoiceninja jira-cloud jotform json kallabot-ai kimai kizeo-forms krisp-call lead-connector lever line linear linka linkedin llmrails localai mailchimp mailer-lite maileroo mailjet mastodon math-helper matomo matrix mattermost mautic messagebird metabase microsoft-dynamics-365-business-central microsoft-dynamics-crm microsoft-excel-365 microsoft-onedrive microsoft-outlook-calendar microsoft-sharepoint microsoft-teams mindee mixpanel monday moxie-crm mysql nifty nocodb notion ntfy odoo onfleet openai open-router pastebin pastefy pdf perplexity-ai photoroom pipedrive poper postgres posthog pushover pylon qdrant qrcode queue quickzu rabbitmq razorpay reachinbox reoon-verifier resend retable retune robolly rss saastic salesforce scenario schedule scrapegrapghai segment sendfox sendgrid sendinblue sendy sessions-us seven sftp shopify simplepdf slack smaily smtp snowflake soap sperse spotify square stability-ai stable-diffusion-webui store straico stripe subflows supabase supadata surrealdb surveymonkey tags talkable tally taskade tavily telegram-bot text-ai text-helper tidycal todoist totalcms trello twilio twin-labs twitter typeform upgradechat utility-ai vbout village vtex vtiger webflow webhook webling wedof whatsable whatsapp woocommerce wootric wordpress xero xml youtube zendesk zerobounce zoho-books zoho-crm zoho-invoice zoom zuora"
ENV AP_PIECES_SOURCE=FILE
ENV AP_PIECES_SYNC_MODE=NONE

# Redis configuration
ENV AP_REDIS_URL=redis://redis:6379

# Copy node_modules and ensure all dependencies are available
COPY --from=build /usr/src/app/node_modules /usr/src/app/node_modules
COPY --from=build /usr/src/app/dist/packages/server/api/node_modules /usr/src/app/dist/packages/server/api/node_modules

# Copy remaining files
COPY --from=build /usr/src/app/packages packages
COPY --from=build /usr/src/app/dist/packages/react-ui /usr/share/nginx/html/

LABEL service=activepieces

# Set up entrypoint script
COPY docker-entrypoint.sh .
RUN chmod +x docker-entrypoint.sh
ENTRYPOINT ["./docker-entrypoint.sh"]

EXPOSE 80