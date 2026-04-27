# 1. Build Stage
FROM eclipse-temurin:21-jdk AS build
WORKDIR /app

# 종속성 파일들만 먼저 복사해서 캐싱 활용
COPY gradlew .
COPY gradle gradle
COPY build.gradle settings.gradle ./
# 라이브러리 먼저 다운로드
RUN chmod +x ./gradlew
RUN ./gradlew dependencies --no-daemon

# 그 다음 소스 코드 복사 후 빌드
COPY . .
RUN chmod +x ./gradlew
RUN ./gradlew bootJar -x test --no-daemon

# 2. Run Stage
FROM eclipse-temurin:21-jre
EXPOSE 9103
WORKDIR /app
COPY --from=build /app/build/libs/*.jar app.jar

ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar app.jar"]
