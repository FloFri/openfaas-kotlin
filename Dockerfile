FROM gradle:5.5.1-jdk11 as build
ENV APP_HOME=/app
WORKDIR $APP_HOME/
# This allows caching of dependencies for repeated builds
COPY ./build.gradle.kts ./settings.gradle.kts ./
COPY gradle $WORKDIR/gradle
RUN gradle build

COPY ./ $WORKDIR
RUN gradle shadowJar

FROM openfaas/of-watchdog:0.7.2 as watchdog

FROM alpine:3.10 as minimal_jre

RUN apk --no-cache add openjdk11-jdk openjdk11-jmods

RUN /usr/lib/jvm/java-11-openjdk/bin/jlink \
    --verbose \
    --add-modules \
        java.base,java.sql,jdk.httpserver \
    --compress 2 --strip-debug --no-header-files --no-man-pages \
    --output "/opt/java_minimal"

FROM alpine:3.10

ENV JAVA_HOME=/opt/jre
ENV PATH="$PATH:$JAVA_HOME/bin"

WORKDIR /app
COPY --from=minimal_jre /opt/java_minimal $JAVA_HOME
COPY --from=watchdog /fwatchdog /usr/bin/fwatchdog
RUN ls -lah
COPY --from=build /app/build/libs/kotlin-all.jar .

ENV cgi_headers="true"
ENV fprocess="java -jar /app/kotlin-all.jar"
ENV mode="http"
ENV upstream_url="http://127.0.0.1:3000"

HEALTHCHECK --interval=5s CMD [ -e /tmp/.lock ] || exit 1

CMD ["fwatchdog"]
