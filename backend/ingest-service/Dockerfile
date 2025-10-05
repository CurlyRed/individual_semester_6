FROM eclipse-temurin:21-jdk-alpine AS builder
WORKDIR /app
COPY . .
RUN chmod +x gradlew && ./gradlew :ingest-service:bootJar --no-daemon

FROM eclipse-temurin:21-jre-alpine
RUN apk add --no-cache gcompat
WORKDIR /app
COPY --from=builder /app/ingest-service/build/libs/*.jar app.jar
EXPOSE 8081
ENTRYPOINT ["java", "-jar", "app.jar"]
