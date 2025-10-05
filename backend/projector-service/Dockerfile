FROM eclipse-temurin:21-jdk-alpine AS builder
WORKDIR /app
COPY . .
RUN chmod +x gradlew && ./gradlew :projector-service:bootJar --no-daemon

FROM eclipse-temurin:21-jre-alpine
RUN apk add --no-cache gcompat
WORKDIR /app
COPY --from=builder /app/projector-service/build/libs/*.jar app.jar
EXPOSE 8082
ENTRYPOINT ["java", "-jar", "app.jar"]
