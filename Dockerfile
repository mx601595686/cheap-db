FROM node:12-stretch as builder

# 提升node内存大小上限
ENV NODE_OPTIONS="--max_old_space_size=8192"

WORKDIR /app

# 复制代码
COPY ["src", "/app/src/"]
COPY ["package.json", "gulpfile.js", "tsconfig.json", ".eslintrc.json", "LICENSE", "/app/"]

# 编译
RUN npm install && \ 
    npm run lint && \
    npm run compile && \
# 清除devDependencies包
    npm prune --production && \
# 删除多余文件
    rm -r src gulpfile.js tsconfig.json .eslintrc.json && \
# 确保程序代码不会被破坏
    chmod 755 /app && \
# 确保可执行
    chmod 755 node_modules/service-starter/src/Docker/health_check.sh

FROM mongo:4.0

# 删除mongo设置的ENTRYPOINT
ENTRYPOINT [] 

RUN apt-get update && apt-get install -y --no-install-recommends \
    tzdata \
    curl \
    && rm -rf /var/lib/apt/lists/* && \
    echo '# 设置系统时区' >> /root/.bashrc && \
    echo 'ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone' >> /root/.bashrc

# TZ：时区默认是上海
ENV TZ=Asia/Shanghai

WORKDIR /app

COPY mongod.conf /etc/mongod.conf
COPY --from=builder /app /app
COPY --from=builder /usr/local/bin/node /usr/local/bin/node

HEALTHCHECK \
    # 每次检查的间隔时间
    --interval=1m \
    # 单次检查的超时时长
    --timeout=30s \
    # 这个可以理解为在开始正式检查之前容器所需要的启动时间
    --start-period=1m \
    # 连续多少次检查失败可判定该服务是unhealthy
    --retries=3 \
    # 调用程序所暴露出的健康检查接口(要使用绝对路径)
    CMD /app/node_modules/service-starter/src/Docker/health_check.sh

EXPOSE 80

CMD ["node", "."]