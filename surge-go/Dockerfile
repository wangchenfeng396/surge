# 多阶段构建 Dockerfile for Surge-Go
FROM golang:1.21-alpine AS builder

# 安装构建依赖
RUN apk add --no-cache git ca-certificates

WORKDIR /build

# 复制 go mod 文件
COPY go.mod go.sum ./
RUN go mod download

# 复制源代码
COPY . .

# 构建二进制文件
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o surge cmd/surge/main.go

# 最终镜像
FROM alpine:latest

# 安装运行时依赖
RUN apk add --no-cache ca-certificates tzdata

# 创建非 root 用户
RUN addgroup -g 1000 surge && \
    adduser -D -u 1000 -G surge surge

WORKDIR /app

# 从构建阶段复制二进制文件
COPY --from=builder /build/surge /app/surge

# 创建配置目录
RUN mkdir -p /etc/surge && chown -R surge:surge /etc/surge

# 切换到非 root 用户
USER surge

# 暴露端口
EXPOSE 8888 8889 9090

# 健康检查
HEALTHCHECK --interval=30s --timeout=3s \
  CMD wget --quiet --tries=1 --spider http://localhost:9090/api/health || exit 1

# 启动命令
ENTRYPOINT ["/app/surge"]
CMD ["-c", "/etc/surge/surge.conf"]
