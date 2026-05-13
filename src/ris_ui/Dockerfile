FROM ghcr.io/cirruslabs/flutter:stable AS build

ARG RIS_UI_BACKEND_BASE_URL=http://localhost:8080

WORKDIR /app

COPY src/ris_core /app/src/ris_core
COPY src/ris_ui /app/src/ris_ui

WORKDIR /app/src/ris_ui
RUN flutter pub get
RUN flutter build web \
  --release \
  --dart-define=RIS_UI_BACKEND_BASE_URL=${RIS_UI_BACKEND_BASE_URL}

FROM nginx:alpine

COPY --from=build /app/src/ris_ui/build/web /usr/share/nginx/html

EXPOSE 80
