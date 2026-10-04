FROM dart:stable AS build

WORKDIR /app

COPY pubspec.* ./
RUN dart pub get

COPY . .
RUN dart pub get --offline
RUN dart test
RUN dart compile exe bin/app.dart -o /app/server

FROM scratch

COPY --from=build /runtime/ /
COPY --from=build /app/server /server

EXPOSE 8080

ENTRYPOINT ["/server"]
