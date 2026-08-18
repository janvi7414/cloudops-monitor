# Base Node.js production image
FROM node:20-alpine

# Set target environment to production
ENV NODE_ENV=production

WORKDIR /app

# Copy dependency manifests
COPY package*.json ./

# Install only production dependencies cleanly
RUN npm install --omit=dev && npm cache clean --force

# Copy application code with non-root ownership
COPY --chown=node:node . .

# Switch to standard non-root node user for container execution
USER node

EXPOSE 5000

# Execute entrypoint process directly to forward OS signals cleanly
CMD ["node", "index.js"]
