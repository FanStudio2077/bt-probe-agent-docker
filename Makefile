IMAGE ?= fanstudio2077/bt-probe-agent
TAG   ?= latest

.PHONY: build run logs stop clean push

build:
	docker build -t $(IMAGE):$(TAG) .

run:
	docker run -d --name bt-probe-agent --restart unless-stopped \
		--cap-add=NET_RAW --security-opt=no-new-privileges:true \
		-v bt-probe-agent-data:/data $(IMAGE):$(TAG)

logs:
	docker logs -f bt-probe-agent

stop:
	-docker rm -f bt-probe-agent

clean: stop
	-docker volume rm bt-probe-agent-data

# 多架构构建并推送（需先 docker login）
push:
	docker buildx build --platform linux/amd64,linux/arm64 \
		-t $(IMAGE):$(TAG) -t $(IMAGE):latest --push .
