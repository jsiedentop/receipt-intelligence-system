# Use latest stable channel SDK.
FROM dart:stable AS build

# Resolve app dependencies.
WORKDIR /app
COPY src/ris_core /app/src/ris_core
COPY src/ris_backend /app/src/ris_backend
WORKDIR /app/src/ris_backend
RUN dart pub get

# Copy app source code (except anything in .dockerignore) and AOT compile app.
RUN dart build cli --target bin/server.dart -o output

# Build serving image from the stable Dart runtime image.
FROM dart:stable
RUN apt-get update && apt-get install -y --no-install-recommends \
    libsqlite3-dev \
    && rm -rf /var/lib/apt/lists/*
COPY --from=build /app/src/ris_backend/output/bundle/ /app/

# Start server.
EXPOSE 8080
CMD ["/app/bin/server"]
