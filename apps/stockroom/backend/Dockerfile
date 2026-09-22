# Go 백엔드 Dockerfile
FROM golang:1.21-alpine AS builder

WORKDIR /app

# Go 모듈 파일 복사
COPY go.mod ./

# 소스 코드 복사 (의존성 해결을 위해)
COPY . .

# 의존성 다운로드 및 정리
RUN go mod tidy

# 애플리케이션 빌드
RUN go build -o main cmd/main.go

# 운영 이미지
FROM alpine:latest

WORKDIR /app

# 필요한 패키지 설치
RUN apk --no-cache add ca-certificates tzdata

# 빌드된 바이너리 복사
COPY --from=builder /app/main .

EXPOSE 8080

CMD ["./main"]
