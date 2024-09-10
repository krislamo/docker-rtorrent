DOCKER_BUILDKIT ?= 1
BUILDKIT_PROGRESS ?= auto

DOCKER_COMPOSE_OPTS = BUILDX_GIT_LABELS=full \
	DOCKER_BUILDKIT=$(DOCKER_BUILDKIT) \
	BUILDKIT_PROGRESS=$(BUILDKIT_PROGRESS)

DOCKER_COMPOSE_BUILD = $(DOCKER_COMPOSE_OPTS) docker compose -f docker-compose.build.yml build

PRUNE_IMAGES = \
	localhost/rtorrent:latest

.PHONY: default

default:
	$(DOCKER_COMPOSE_BUILD) rtorrent

clean:
	docker image rm $(PRUNE_IMAGES) || true
	docker builder prune -f
