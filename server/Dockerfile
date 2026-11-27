FROM dart:stable AS build

WORKDIR /workspace/server

COPY shared/pubspec.* ../shared/
COPY server/pubspec.* ./
RUN dart pub get

COPY shared/lib/ ../shared/lib/
COPY server/bin/ bin/
COPY server/lib/ lib/
COPY server/assets/ assets/
RUN dart compile exe bin/server.dart -o /workspace/server-bin

FROM scratch

WORKDIR /app
COPY --from=build /runtime/ /
COPY --from=build /workspace/server-bin /server
COPY --from=build /workspace/server/assets/db/ assets/db/

EXPOSE 8080

ENTRYPOINT ["/server"]
