FROM node:18-alpine AS build
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . ./
# Set the API URL for the container environment
ARG REACT_APP_API_URL
ENV REACT_APP_API_URL=$REACT_APP_API_URL
RUN npm run build

# Stage 2: Serve with Nginx
FROM nginx:1.25-alpine
# Copy the built static files from the build stage
COPY --from=build /app/build /usr/share/nginx/html
# Nginx will serve files from this directory by default
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]