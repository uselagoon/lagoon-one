SHELL := /bin/bash
# amazee.io lagoon Makefile The main purpose of this Makefile is to provide easier handling of
# building images and running tests It understands the relation of the different images (like
# nginx-drupal is based on nginx) and builds them in the correct order Also it knows which
# services in docker-compose.yml are depending on which base images or maybe even other service
# images
#
# The main commands are:

# make build/<imagename>
# Builds an individual image and all of it's needed parents. Run `make build-list` to get a list of
# all buildable images. Make will keep track of each build image with creating an empty file with
# the name of the image in the folder `build`. If you want to force a rebuild of the image, either
# remove that file or run `make clean`

# make build
# builds all images in the correct order. Uses existing images for layer caching, define via `TAG`
# which branch should be used

# make tests/<testname>
# Runs individual tests. In a nutshell it does:
# 1. Builds all needed images for the test
# 2. Starts needed Lagoon services for the test via docker-compose up
# 3. Executes the test
#
# Run `make tests-list` to see a list of all tests.

# make tests
# Runs all tests together. Can be executed with `-j2` for two parallel running tests

# make up
# Starts all Lagoon Services at once, usefull for local development or just to start all of them.

# make logs
# Shows logs of Lagoon Services (aka docker-compose logs -f)

# make minishift
# Some tests need a full openshift running in order to test deployments and such. This can be
# started via openshift. It will:
# 1. Download minishift cli
# 2. Start an OpenShift Cluster
# 3. Configure OpenShift cluster to our needs

# make minishift/stop
# Removes an OpenShift Cluster

# make minishift/clean
# Removes all openshift related things: OpenShift itself and the minishift cli

#######
####### Default Variables
#######

# Parameter for all `docker build` commands, can be overwritten by passing `DOCKER_BUILD_PARAMS=` via the `-e` option
DOCKER_BUILD_PARAMS := --quiet

# On CI systems like jenkins we need a way to run multiple testings at the same time. We expect the
# CI systems to define an Environment variable CI_BUILD_TAG which uniquely identifies each build.
# If it's not set we assume that we are running local and just call it lagoon.
CI_BUILD_TAG ?= lagoon
# SOURCE_REPO is the repos where the upstream images are found (usually uselagoon, but can substiture for testlagoon)
UPSTREAM_REPO ?= uselagoon
UPSTREAM_TAG ?= latest

# Local environment
ARCH := $(shell uname | tr '[:upper:]' '[:lower:]')
LAGOON_VERSION := $(shell git describe --tags --exact-match 2>/dev/null || echo development)
DOCKER_DRIVER := $(shell docker info -f '{{.Driver}}')

# Version and Hash of the OpenShift cli that should be downloaded
MINISHIFT_VERSION := 1.34.1
OPENSHIFT_VERSION := v3.11.0
MINISHIFT_CPUS := $(nproc --ignore 2)
MINISHIFT_MEMORY := 8GB
MINISHIFT_DISK_SIZE := 30GB

# Version and Hash of the minikube cli that should be downloaded
K3S_VERSION := v1.17.0-k3s.1
KUBECTL_VERSION := v1.20.2
HELM_VERSION := v3.5.0
MINIKUBE_VERSION := 1.5.2
MINIKUBE_PROFILE := $(CI_BUILD_TAG)-minikube
MINIKUBE_CPUS := $(nproc --ignore 2)
MINIKUBE_MEMORY := 2048
MINIKUBE_DISK_SIZE := 30g

K3D_VERSION := 1.4.0
# k3d has a 35-char name limit
K3D_NAME := k3s-$(shell echo $(CI_BUILD_TAG) | sed -E 's/.*(.{31})$$/\1/')

# Name of the Branch we are currently in
BRANCH_NAME := $(shell git rev-parse --abbrev-ref HEAD)
SAFE_BRANCH_NAME := $(shell echo $(BRANCH_NAME) | sed -E 's:/:_:g')

# Init the file that is used to hold the image tag cross-reference table
$(shell >build.txt)
$(shell >scan.txt)

#######
####### Functions
#######

# Builds a docker image. Expects as arguments: name of the image, location of Dockerfile, path of
# Docker Build Context
docker_build = docker build $(DOCKER_BUILD_PARAMS) --build-arg LAGOON_VERSION=$(LAGOON_VERSION) --build-arg IMAGE_REPO=$(CI_BUILD_TAG) --build-arg UPSTREAM_REPO=$(UPSTREAM_REPO) --build-arg UPSTREAM_TAG=$(UPSTREAM_TAG) -t $(CI_BUILD_TAG)/$(1) -f $(2) $(3)

scan_image = docker run --rm -v /var/run/docker.sock:/var/run/docker.sock -v $(HOME)/Library/Caches:/root/.cache/ aquasec/trivy --timeout 5m0s $(CI_BUILD_TAG)/$(1) >> scan.txt

# Tags an image with the `testlagoon` repository and pushes it
docker_publish_testlagoon = docker tag $(CI_BUILD_TAG)/$(1) testlagoon/$(2) && docker push testlagoon/$(2) | cat

# Tags an image with the `uselagoon` repository and pushes it
docker_publish_uselagoon = docker tag $(CI_BUILD_TAG)/$(1) uselagoon/$(2) && docker push uselagoon/$(2) | cat


#######
####### Base Images
#######
####### Base Images are the base for all other images and are also published for clients to use during local development

images :=     oc \
							kubectl \
							oc-build-deploy-dind \
							kubectl-build-deploy-dind \
							rabbitmq \
							rabbitmq-cluster \
							athenapdf-service \
							curator \
							docker-host

# base-images is a variable that will be constantly filled with all base image there are
base-images += $(images)
s3-images += $(images)

# List with all images prefixed with `build/`. Which are the commands to actually build images
build-images = $(foreach image,$(images),build/$(image))

# Define the make recipe for all base images
$(build-images):
#	Generate variable image without the prefix `build/`
	$(eval image = $(subst build/,,$@))
# Call the docker build
	$(call docker_build,$(image),images/$(image)/Dockerfile,images/$(image))
#scan created image with Trivy
	$(call scan_image,$(image),)
# Touch an empty file which make itself is using to understand when the image has been last build
	touch $@

# Define dependencies of Base Images so that make can build them in the right order. There are two
# types of Dependencies
# 1. Parent Images, like `build/centos7-node6` is based on `build/centos7` and need to be rebuild
#    if the parent has been built
# 2. Dockerfiles of the Images itself, will cause make to rebuild the images if something has
#    changed on the Dockerfiles
build/rabbitmq: images/rabbitmq/Dockerfile
build/rabbitmq-cluster: build/rabbitmq images/rabbitmq-cluster/Dockerfile
build/docker-host: images/docker-host/Dockerfile
build/oc: images/oc/Dockerfile
build/kubectl: images/kubectl/Dockerfile
build/curator: images/curator/Dockerfile
build/oc-build-deploy-dind: build/oc images/oc-build-deploy-dind
build/athenapdf-service:images/athenapdf-service/Dockerfile
build/kubectl-build-deploy-dind: build/kubectl images/kubectl-build-deploy-dind


#######
####### Service Images
#######
####### Services Images are the Docker Images used to run the Lagoon Microservices, these images
####### will be expected by docker-compose to exist.

# Yarn Workspace Image which builds the Yarn Workspace within a single image. This image will be
# used by all microservices based on Node.js to not build similar node packages again
build-images += yarn-workspace-builder
build/yarn-workspace-builder: images/yarn-workspace-builder/Dockerfile
	$(eval image = $(subst build/,,$@))
	$(call docker_build,$(image),images/$(image)/Dockerfile,.)
	$(call scan_image,$(image),)
	touch $@

#######
####### Task Images
#######
####### Task Images are standalone images that are used to run advanced tasks when using the builddeploy controllers.

# task-activestandby is the task image that lagoon builddeploy controller uses to run active/standby misc tasks
build/task-activestandby: taskimages/activestandby/Dockerfile

# the `taskimages` are the name of the task directories contained within `taskimages/` in the repostory root
taskimages := activestandby
# in the following process, taskimages are prepended with `task-` to make built task images more identifiable
# use `build/task-<name>` to build it, but the references in the directory structure remain simpler with
# taskimages/
#	activestandby
#	anothertask
# the resulting image will be called `task-<name>` instead of `<name>` to make it known that it is a task image
task-images += $(foreach image,$(taskimages),task-$(image))
build-taskimages = $(foreach image,$(taskimages),build/task-$(image))
$(build-taskimages):
	$(eval image = $(subst build/task-,,$@))
	$(call docker_build,task-$(image),taskimages/$(image)/Dockerfile,taskimages/$(image))
	$(call scan_image,task-$(image),)
	touch $@

# Variables of service images we manage and build
services :=	api \
			api-db \
			api-redis \
			auth-server \
			auto-idler \
			backup-handler \
			broker \
			broker-single \
			controllerhandler \
			drush-alias \
			keycloak \
			keycloak-db \
			logs-concentrator \
			logs-db-curator \
			logs-dispatcher \
			logs-tee \
			logs2email \
			logs2microsoftteams \
			logs2rocketchat \
			logs2slack \
			storage-calculator \
			ui \
			webhook-handler \
			webhooks2tasks


service-images += $(services)

build-services = $(foreach image,$(services),build/$(image))

# Recipe for all building service-images
$(build-services):
	$(eval image = $(subst build/,,$@))
	$(call docker_build,$(image),services/$(image)/Dockerfile,services/$(image))
	$(call scan_image,$(image),)
	touch $@

# Dependencies of Service Images
build/auth-server build/logs2email build/logs2slack build/logs2rocketchat build/logs2microsoftteams build/backup-handler build/controllerhandler build/webhook-handler build/webhooks2tasks build/api build/ui: build/yarn-workspace-builder
build/api-db: services/api-db/Dockerfile
build/api-redis: services/api-redis/Dockerfile
build/auto-idler: build/oc
build/broker-single: build/rabbitmq
build/broker: build/rabbitmq-cluster build/broker-single
build/drush-alias: services/drush-alias/Dockerfile
build/keycloak-db: services/keycloak-db/Dockerfile
build/keycloak: services/keycloak/Dockerfile
build/logs-concentrator: services/logs-concentrator/Dockerfile
build/logs-db-curator: build/curator
build/logs-dispatcher: services/logs-dispatcher/Dockerfile
build/logs-tee: services/logs-tee/Dockerfile
build/storage-calculator: build/oc
build/tests-controller-kubernetes: build/tests
build/tests-kubernetes: build/tests
build/tests-openshift: build/tests
build/tests: tests/Dockerfile
build/local-minio:
# Auth SSH needs the context of the root folder, so we have it individually
build/ssh: services/ssh/Dockerfile
	$(eval image = $(subst build/,,$@))
	$(call docker_build,$(image),services/$(image)/Dockerfile,.)
	$(call scan_image,$(image),)
	touch $@
service-images += ssh

build/local-git: local-dev/git/Dockerfile
build/local-api-data-watcher-pusher: local-dev/api-data-watcher-pusher/Dockerfile
build/local-registry: local-dev/registry/Dockerfile
build/local-dbaas-provider: local-dev/dbaas-provider/Dockerfile
build/local-mongodb-dbaas-provider: local-dev/mongodb-dbaas-provider/Dockerfile

# Images for local helpers that exist in another folder than the service images
localdevimages := local-git \
									local-api-data-watcher-pusher \
									local-registry \
									local-dbaas-provider \
									local-mongodb-dbaas-provider

service-images += $(localdevimages)
build-localdevimages = $(foreach image,$(localdevimages),build/$(image))

$(build-localdevimages):
	$(eval folder = $(subst build/local-,,$@))
	$(eval image = $(subst build/,,$@))
	$(call docker_build,$(image),local-dev/$(folder)/Dockerfile,local-dev/$(folder))
	$(call scan_image,$(image),)
	touch $@

# Image with ansible test
build/tests:
	$(eval image = $(subst build/,,$@))
	$(call docker_build,$(image),$(image)/Dockerfile,$(image))
	$(call scan_image,$(image),)
	touch $@
service-images += tests

s3-images += $(service-images)

#######
####### Commands
#######
####### List of commands in our Makefile

# Builds all Images
.PHONY: build
build: $(foreach image,$(base-images) $(service-images) $(task-images),build/$(image))
# Outputs a list of all Images we manage
.PHONY: build-list
build-list:
	@for number in $(foreach image,$(build-images),build/$(image)); do \
			echo $$number ; \
	done


#######
####### Publishing Images
#######
####### All main&PR images are pushed to testlagoon repository
#######

# Publish command to testlagoon docker hub, done on any main branch or PR
publish-testlagoon-baseimages = $(foreach image,$(base-images),[publish-testlagoon-baseimages]-$(image))
# tag and push all images

.PHONY: publish-testlagoon-baseimages
publish-testlagoon-baseimages: $(publish-testlagoon-baseimages)

# tag and push of each image
.PHONY: $(publish-testlagoon-baseimages)
$(publish-testlagoon-baseimages):
#   Calling docker_publish for image, but remove the prefix '[publish-testlagoon-baseimages]-' first
		$(eval image = $(subst [publish-testlagoon-baseimages]-,,$@))
# 	Publish images with version tag
		$(call docker_publish_testlagoon,$(image),$(image):$(BRANCH_NAME))


# Publish command to amazeeio docker hub, this should probably only be done during a master deployments
publish-testlagoon-serviceimages = $(foreach image,$(service-images),[publish-testlagoon-serviceimages]-$(image))
# tag and push all images
.PHONY: publish-testlagoon-serviceimages
publish-testlagoon-serviceimages: $(publish-testlagoon-serviceimages)

# tag and push of each image
.PHONY: $(publish-testlagoon-serviceimages)
$(publish-testlagoon-serviceimages):
#   Calling docker_publish for image, but remove the prefix '[publish-testlagoon-serviceimages]-' first
		$(eval image = $(subst [publish-testlagoon-serviceimages]-,,$@))
# 	Publish images with version tag
		$(call docker_publish_testlagoon,$(image),$(image):$(BRANCH_NAME))


# Publish command to amazeeio docker hub, this should probably only be done during a master deployments
publish-testlagoon-taskimages = $(foreach image,$(task-images),[publish-testlagoon-taskimages]-$(image))
# tag and push all images
.PHONY: publish-testlagoon-taskimages
publish-testlagoon-taskimages: $(publish-testlagoon-taskimages)

# tag and push of each image
.PHONY: $(publish-testlagoon-taskimages)
$(publish-testlagoon-taskimages):
#   Calling docker_publish for image, but remove the prefix '[publish-testlagoon-taskimages]-' first
		$(eval image = $(subst [publish-testlagoon-taskimages]-,,$@))
# 	Publish images with version tag
		$(call docker_publish_testlagoon,$(image),$(image):$(BRANCH_NAME))


#######
####### All tagged releases are pushed to uselagoon repository with new semantic tags
#######

# Publish command to uselagoon docker hub, only done on tags
publish-uselagoon-baseimages = $(foreach image,$(base-images),[publish-uselagoon-baseimages]-$(image))

# tag and push all images
.PHONY: publish-uselagoon-baseimages
publish-uselagoon-baseimages: $(publish-uselagoon-baseimages)

# tag and push of each image
.PHONY: $(publish-uselagoon-baseimages)
$(publish-uselagoon-baseimages):
#   Calling docker_publish for image, but remove the prefix '[publish-uselagoon-baseimages]-' first
		$(eval image = $(subst [publish-uselagoon-baseimages]-,,$@))
# 	Publish images as :latest
		$(call docker_publish_uselagoon,$(image),$(image):latest)
# 	Publish images with version tag
		$(call docker_publish_uselagoon,$(image),$(image):$(LAGOON_VERSION))


# Publish command to amazeeio docker hub, this should probably only be done during a master deployments
publish-uselagoon-serviceimages = $(foreach image,$(service-images),[publish-uselagoon-serviceimages]-$(image))
# tag and push all images
.PHONY: publish-uselagoon-serviceimages
publish-uselagoon-serviceimages: $(publish-uselagoon-serviceimages)

# tag and push of each image
.PHONY: $(publish-uselagoon-serviceimages)
$(publish-uselagoon-serviceimages):
#   Calling docker_publish for image, but remove the prefix '[publish-uselagoon-serviceimages]-' first
		$(eval image = $(subst [publish-uselagoon-serviceimages]-,,$@))
# 	Publish images as :latest
		$(call docker_publish_uselagoon,$(image),$(image):latest)
# 	Publish images with version tag
		$(call docker_publish_uselagoon,$(image),$(image):$(LAGOON_VERSION))


# Publish command to amazeeio docker hub, this should probably only be done during a master deployments
publish-uselagoon-taskimages = $(foreach image,$(task-images),[publish-uselagoon-taskimages]-$(image))
# tag and push all images
.PHONY: publish-uselagoon-taskimages
publish-uselagoon-taskimages: $(publish-uselagoon-taskimages)

# tag and push of each image
.PHONY: $(publish-uselagoon-taskimages)
$(publish-uselagoon-taskimages):
#   Calling docker_publish for image, but remove the prefix '[publish-uselagoon-taskimages]-' first
		$(eval image = $(subst [publish-uselagoon-taskimages]-,,$@))
# 	Publish images as :latest
		$(call docker_publish_uselagoon,$(image),$(image):latest)
# 	Publish images with version tag
		$(call docker_publish_uselagoon,$(image),$(image):$(LAGOON_VERSION))

# Clean all build touches, which will case make to rebuild the Docker Images (Layer caching is
# still active, so this is a very safe command)
clean:
	rm -rf build/*

# Show Lagoon Service Logs
logs:
	IMAGE_REPO=$(CI_BUILD_TAG) docker-compose -p $(CI_BUILD_TAG) --compatibility logs --tail=10 -f $(service)

# Start all Lagoon Services
up:
ifeq ($(ARCH), darwin)
	IMAGE_REPO=$(CI_BUILD_TAG) docker-compose -p $(CI_BUILD_TAG) --compatibility up -d
else
	# once this docker issue is fixed we may be able to do away with this
	# linux-specific workaround: https://github.com/docker/cli/issues/2290
	KEYCLOAK_URL=$$(docker network inspect -f '{{(index .IPAM.Config 0).Gateway}}' bridge):8088 \
		IMAGE_REPO=$(CI_BUILD_TAG) \
		docker-compose -p $(CI_BUILD_TAG) --compatibility up -d
endif
	$(MAKE) wait-for-keycloak

down:
	IMAGE_REPO=$(CI_BUILD_TAG) docker-compose -p $(CI_BUILD_TAG) --compatibility down -v --remove-orphans

# kill all containers containing the name "lagoon"
kill:
	docker ps --format "{{.Names}}" | grep lagoon | xargs -t -r -n1 docker rm -f -v

## CI targets

KIND_VERSION = v0.10.0
GOJQ_VERSION = v0.11.2
KIND_IMAGE = kindest/node:v1.20.2@sha256:8f7ea6e7642c0da54f04a7ee10431549c0257315b3a634f6ef2fecaaedb19bab
TESTS = [api,features-kubernetes,nginx,drupal-php73,drupal-php74,drupal-postgres,python,gitlab,github,bitbucket,node-mongodb,elasticsearch]
CHARTS_TREEISH = main

# Symlink the installed kubectl client if the correct version is already
# installed, otherwise downloads it.
local-dev/kubectl:
ifeq ($(KUBECTL_VERSION), $(shell kubectl version --short --client 2>/dev/null | sed -E 's/Client Version: v([0-9.]+).*/\1/'))
	$(info linking local kubectl version $(KUBECTL_VERSION))
	ln -s $(shell command -v kubectl) ./local-dev/kubectl
else
	$(info downloading kubectl version $(KUBECTL_VERSION) for $(ARCH))
	curl -sSLo local-dev/kubectl https://storage.googleapis.com/kubernetes-release/release/$(KUBECTL_VERSION)/bin/$(ARCH)/amd64/kubectl
	chmod a+x local-dev/kubectl
endif

# Symlink the installed helm client if the correct version is already
# installed, otherwise downloads it.
local-dev/helm:
ifeq ($(HELM_VERSION), $(shell helm version --short --client 2>/dev/null | sed -nE 's/v([0-9.]+).*/\1/p'))
	$(info linking local helm version $(HELM_VERSION))
	ln -s $(shell command -v helm) ./local-dev/helm
else
	$(info downloading helm version $(HELM_VERSION) for $(ARCH))
	curl -sSL https://get.helm.sh/helm-$(HELM_VERSION)-$(ARCH)-amd64.tar.gz | tar -xzC local-dev --strip-components=1 $(ARCH)-amd64/helm
	chmod a+x local-dev/helm
endif

local-dev/kind:
ifeq ($(KIND_VERSION), $(shell kind version 2>/dev/null | sed -nE 's/kind (v[0-9.]+).*/\1/p'))
	$(info linking local kind version $(KIND_VERSION))
	ln -s $(shell command -v kind) ./local-dev/kind
else
	$(info downloading kind version $(KIND_VERSION) for $(ARCH))
	curl -sSLo local-dev/kind https://github.com/kubernetes-sigs/kind/releases/download/$(KIND_VERSION)/kind-$(ARCH)-amd64
	chmod a+x local-dev/kind
endif

local-dev/jq:
ifeq ($(GOJQ_VERSION), $(shell jq -v 2>/dev/null | sed -nE 's/gojq ([0-9.]+).*/v\1/p'))
	$(info linking local jq version $(KIND_VERSION))
	ln -s $(shell command -v jq) ./local-dev/jq
else
	$(info downloading gojq version $(GOJQ_VERSION) for $(ARCH))
ifeq ($(ARCH), darwin)
	TMPDIR=$$(mktemp -d) \
		&& curl -sSL https://github.com/itchyny/gojq/releases/download/$(GOJQ_VERSION)/gojq_$(GOJQ_VERSION)_$(ARCH)_amd64.zip -o $$TMPDIR/gojq.zip \
		&& (cd $$TMPDIR && unzip gojq.zip) && cp $$TMPDIR/gojq_$(GOJQ_VERSION)_$(ARCH)_amd64/gojq ./local-dev/jq && rm -rf $$TMPDIR
else
	curl -sSL https://github.com/itchyny/gojq/releases/download/$(GOJQ_VERSION)/gojq_$(GOJQ_VERSION)_$(ARCH)_amd64.tar.gz | tar -xzC local-dev --strip-components=1 gojq_$(GOJQ_VERSION)_$(ARCH)_amd64/gojq
	mv ./local-dev/{go,}jq
endif
	chmod a+x local-dev/jq
endif

.PHONY: helm/repos
helm/repos: local-dev/helm
	# install repo dependencies required by the charts
	./local-dev/helm repo add harbor https://helm.goharbor.io
	./local-dev/helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
	./local-dev/helm repo add stable https://charts.helm.sh/stable
	./local-dev/helm repo add bitnami https://charts.bitnami.com/bitnami
	./local-dev/helm repo add amazeeio https://amazeeio.github.io/charts/
	./local-dev/helm repo add lagoon https://uselagoon.github.io/lagoon-charts/
	./local-dev/helm repo update

# stand up a kind cluster configured appropriately for lagoon testing
.PHONY: local/kind-cluster
local/kind-cluster: local-dev/kind
	./local-dev/kind get clusters | grep -q "$(CI_BUILD_TAG)" && exit; \
		docker network create kind || true \
		&& export KUBECONFIG=$$(mktemp) \
		KINDCONFIG=$$(mktemp ./kindconfig.XXX) \
		KIND_NODE_IP=$$(docker run --rm --network kind alpine ip -o addr show eth0 | sed -nE 's/.* ([0-9.]{7,})\/.*/\1/p') \
		&& chmod 644 $$KUBECONFIG \
		&& curl -sSLo $$KINDCONFIG.tpl https://raw.githubusercontent.com/uselagoon/lagoon-charts/$(CHARTS_TREEISH)/test-suite.kind-config.yaml.tpl \
		&& envsubst < $$KINDCONFIG.tpl > $$KINDCONFIG \
		&& echo '  [plugins."io.containerd.grpc.v1.cri".registry.mirrors."docker.io"]'                >> $$KINDCONFIG \
		&& echo '    endpoint = ["https://imagecache.amazeeio.cloud", "https://index.docker.io/v1/"]' >> $$KINDCONFIG \
		&& echo 'nodes:'                                                                              >> $$KINDCONFIG \
		&& echo '- role: control-plane'                                                               >> $$KINDCONFIG \
		&& echo '  image: $(KIND_IMAGE)'                                                              >> $$KINDCONFIG \
		&& echo '  extraMounts:'                                                                      >> $$KINDCONFIG \
		&& echo '  - containerPath: /var/lib/kubelet/config.json'                                     >> $$KINDCONFIG \
		&& echo '    hostPath: $(HOME)/.docker/config.json'                                           >> $$KINDCONFIG \
		&& echo '  - containerPath: /lagoon/services'                                                 >> $$KINDCONFIG \
		&& echo '    hostPath: ./services'                                                            >> $$KINDCONFIG \
		&& echo '    readOnly: false'                                                                 >> $$KINDCONFIG \
		&& echo '  - containerPath: /lagoon/node-packages'                                            >> $$KINDCONFIG \
		&& echo '    hostPath: ./node-packages'                                                       >> $$KINDCONFIG \
		&& echo '    readOnly: false'                                                                 >> $$KINDCONFIG \
		&& KIND_CLUSTER_NAME="$(CI_BUILD_TAG)" ./local-dev/kind create cluster --config=$$KINDCONFIG \
		&& cp $$KUBECONFIG "kubeconfig.$(CI_BUILD_TAG)" \
		&& echo -e 'Interact with the cluster during the test run in Jenkins like so:\n' \
		&& echo "export KUBECONFIG=\$$(mktemp) && scp $$NODE_NAME:$$KUBECONFIG \$$KUBECONFIG && KIND_PORT=\$$(sed -nE 's/.+server:.+:([0-9]+)/\1/p' \$$KUBECONFIG) && ssh -fNL \$$KIND_PORT:127.0.0.1:\$$KIND_PORT $$NODE_NAME" \
		&& echo -e '\nOr running locally:\n' \
		&& echo -e './local-dev/kind export kubeconfig --name "$(CI_BUILD_TAG)"\n' \
		&& echo -e 'kubectl ...\n'
ifeq ($(ARCH), darwin)
	export KUBECONFIG="$$(pwd)/kubeconfig.$(CI_BUILD_TAG)" && \
	if ! ifconfig lo0 | grep $$(./local-dev/kubectl get nodes -o jsonpath='{.items[0].status.addresses[0].address}') -q; then sudo ifconfig lo0 alias $$(./local-dev/kubectl get nodes -o jsonpath='{.items[0].status.addresses[0].address}'); fi
	docker rm --force $(CI_BUILD_TAG)-kind-proxy-32080 || true
	docker run -d --name $(CI_BUILD_TAG)-kind-proxy-32080 \
      --publish 32080:32080 \
      --link $(CI_BUILD_TAG)-control-plane:target --network kind \
      alpine/socat -dd \
      tcp-listen:32080,fork,reuseaddr tcp-connect:target:32080
endif

KIND_SERVICES = api api-db api-redis auth-server broker controllerhandler docker-host drush-alias keycloak keycloak-db webhook-handler webhooks2tasks kubectl-build-deploy-dind local-api-data-watcher-pusher local-git ssh tests ui
KIND_TESTS = local-api-data-watcher-pusher local-git tests
KIND_TOOLS = kind helm kubectl jq

HELM = $$(realpath $(CURDIR)/local-dev/helm)
KUBECTL = $$(realpath $(CURDIR)/local-dev/kubectl)
JQ = $$(realpath $(CURDIR)/local-dev/jq)
KUBECONFIG = $$(realpath $(CURDIR)/kubeconfig.$(CI_BUILD_TAG))
NODE_IP = $$($(KUBECTL) --kubeconfig=$(KUBECONFIG) get nodes -o jsonpath='{.items[0].status.addresses[0].address}')
CHARTSDIR = $$(realpath $(CURDIR)/lagoon-charts.$(CI_BUILD_TAG))
IMAGE_REGISTRY = "registry.$(NODE_IP).nip.io:32080/library"

# install lagoon charts and run lagoon test suites in a kind cluster
.PHONY: local/lagoon-charts
local/lagoon-charts:
	export CHARTSDIR=$$(mktemp -d ./lagoon-charts.XXX) \
		&& ln -sfn "$$CHARTSDIR" lagoon-charts.$(CI_BUILD_TAG) \
		&& git clone https://github.com/uselagoon/lagoon-charts.git "$$CHARTSDIR" \
		&& cd "$$CHARTSDIR" \
		&& git checkout $(CHARTS_TREEISH)

.PHONY: local/install-calico
local/install-calico: local/kind-cluster
	cd $(CHARTSDIR) \
		&& export KUBECONFIG=$(KUBECONFIG) \
		&& export IMAGE_REGISTRY=$(IMAGE_REGISTRY) \
		&& $(MAKE) install-calico

.PHONY: local/install-registry
local/install-registry: local/kind-cluster helm/repos $(addprefix local-dev/,$(KIND_TOOLS))
	cd $(CHARTSDIR) \
		&& export KUBECONFIG=$(KUBECONFIG) \
		&& export IMAGE_REGISTRY=$(IMAGE_REGISTRY) \
		&& $(MAKE) install-registry HELM=$$(realpath ../local-dev/helm) KUBECTL=$$(realpath ../local-dev/kubectl)

.PHONY: local/push-images
local/push-images: local/install-registry $(addprefix build/,$(KIND_SERVICES))
	export KUBECONFIG=$(KUBECONFIG) \
		&& export IMAGE_REGISTRY=$(IMAGE_REGISTRY) \
		&& docker login -u admin -p Harbor12345 $$IMAGE_REGISTRY \
		&& for image in $(KIND_SERVICES); do \
			docker tag $(CI_BUILD_TAG)/$$image $$IMAGE_REGISTRY/$$image:$(SAFE_BRANCH_NAME) \
			&& docker push $$IMAGE_REGISTRY/$$image:$(SAFE_BRANCH_NAME); \
		done

.PHONY: local/install-lagoon
local/install-lagoon:
	cd $(CHARTSDIR) \
		&& export KUBECONFIG=$(KUBECONFIG) \
		&& export IMAGE_REGISTRY=$(IMAGE_REGISTRY) \
		&& $(MAKE) install-lagoon IMAGE_TAG=$(SAFE_BRANCH_NAME) \
			HELM=$(HELM) KUBECTL=$(KUBECTL) JQ=$(JQ) \
			OVERRIDE_BUILD_DEPLOY_DIND_IMAGE=$$IMAGE_REGISTRY/kubectl-build-deploy-dind:$(SAFE_BRANCH_NAME) \
			IMAGE_REGISTRY=$$IMAGE_REGISTRY

## Use local/test to only perform a push of the local-dev, or test images, and run the tests
## It preserves the last build lagoon core&remote setup, reducing rebuild time
.PHONY: local/test
local/test:
	cd $(CHARTSDIR) \
		&& export KUBECONFIG=$(KUBECONFIG) \
		&& export IMAGE_REGISTRY=$(IMAGE_REGISTRY) \
		&& docker login -u admin -p Harbor12345 $$IMAGE_REGISTRY \
		&& for image in $(KIND_TESTS); do \
			docker tag $(CI_BUILD_TAG)/$$image $$IMAGE_REGISTRY/$$image:$(SAFE_BRANCH_NAME) \
			&& docker push $$IMAGE_REGISTRY/$$image:$(SAFE_BRANCH_NAME); \
		done \
		&& $(MAKE) install-tests TESTS=$(TESTS) IMAGE_TAG=$(SAFE_BRANCH_NAME) \
			HELM=$(HELM) KUBECTL=$(KUBECTL) JQ=$(JQ) \
			IMAGE_REGISTRY=$$IMAGE_REGISTRY \
		&& docker run --rm --network host --name ct-$(CI_BUILD_TAG) \
			--volume "$$(pwd)/test-suite-run.ct.yaml:/etc/ct/ct.yaml" \
			--volume "$$(pwd):/workdir" \
			--volume "$$KUBECONFIG:/root/.kube/config" \
			--workdir /workdir \
			"quay.io/helmpack/chart-testing:v3.3.1" \
			ct install

# local/dev can only be run once a cluster is up and running - it doesn't rebuild the cluster at all, just pushes the built images
# into the image registry and reinstalls the lagoon-core helm chart.
.PHONY: local/dev
local/dev: $(addprefix build/,$(KIND_SERVICES))
	export KUBECONFIG=$(KUBECONFIG) \
		&& export IMAGE_REGISTRY=$(IMAGE_REGISTRY) \
		&& $(MAKE) local/push-images \
		&& $(MAKE) local/install-lagoon

LOCAL_DEV_SERVICES = api auth-server controllerhandler logs2email logs2microsoftteams logs2rocketchat logs2slack ui webhook-handler webhooks2tasks

# local/dev-patch will build the services in LOCAL_DEV_SERVICES on your machine, and then use kubectl patch to mount the folders into Kubernetes
# the deployments should be restarted to trigger any updated code changes
# `kubectl rollout undo deployment` can be used to rollback a deployment to before the annotated patch
# ensure that the correct version of Node to build the services is set on your machine
.PHONY: local/dev-patch
local/dev-patch:
	export KUBECONFIG=$(KUBECONFIG) \
		&& export IMAGE_REGISTRY=$(IMAGE_REGISTRY) \
		&& for image in $(LOCAL_DEV_SERVICES); do \
			echo "building $$image" \
			&& cd services/$$image && yarn install && yarn build && cd ../..; \
		done \
		&& for image in $(LOCAL_DEV_SERVICES); do \
			echo "patching lagoon-core-$$image" \
			&& ./local-dev/kubectl --namespace lagoon patch deployment lagoon-core-$$image --patch-file ./local-dev/kubectl-patches/$$image.yaml; \
		done

.PHONY: local/clean
local/clean: local-dev/kind
	KIND_CLUSTER_NAME="$(CI_BUILD_TAG)" ./local-dev/kind delete cluster
