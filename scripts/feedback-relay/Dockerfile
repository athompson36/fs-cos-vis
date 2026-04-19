# Feedback relay — small Express server for GitHub Issues from the app.
# Build: docker build -t cosmic-feedback-relay .
# Run:   docker run --rm -p 8080:8080 -e RELAY_SECRET=... -e GITHUB_TOKEN=... cosmic-feedback-relay

FROM node:22-alpine
WORKDIR /app
COPY package.json package-lock.json* ./
RUN npm ci --omit=dev 2>/dev/null || npm install --omit=dev
COPY server.js ./
ENV PORT=8080
EXPOSE 8080
USER node
CMD ["node", "server.js"]
