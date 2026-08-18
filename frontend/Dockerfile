# Stage 1: Building static assets using Node.js
FROM node:20-alpine AS builder
WORKDIR /app

# Copy dependency specifications and install packages
COPY package*.json ./
RUN npm install

# Copy application source files and generate production build
COPY . .
RUN npm run build

# Stage 2: Serve compiled production static assets with Nginx
FROM nginx:alpine
# Copy custom Nginx routing config for React Router Single Page App
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copy production build output from builder stage into Nginx root
COPY --from=builder /app/build /usr/share/nginx/html

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
