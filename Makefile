PLUGIN_NAME = cjbottaro/do_storage
PLUGIN_TAG = latest

all: clean rootfs create

clean:
	@echo "### rm ./plugin"
	@rm -rf ./plugin
	# @docker rm -vf tmp

rootfs:
	@echo "### docker build: rootfs image with current dir"
	@docker build -q -t ${PLUGIN_NAME}:rootfs .
	@echo "### create rootfs directory in ./plugin/rootfs"
	@mkdir -p ./plugin/rootfs
	@echo "### docker create"
	@docker create --name tmp ${PLUGIN_NAME}:rootfs
	@echo "### docker export"
	@docker export tmp | tar -x -C ./plugin/rootfs
	@echo "### copy config.json to ./plugin/"
	@cp config.json ./plugin/
	@docker rm -vf tmp

create:
	@echo "### remove existing plugin ${PLUGIN_NAME}:${PLUGIN_TAG} if exists"
	@docker plugin rm -f ${PLUGIN_NAME}:${PLUGIN_TAG} || true
	@echo "### create new plugin ${PLUGIN_NAME}:${PLUGIN_TAG} from ./plugin"
	@docker plugin create ${PLUGIN_NAME}:${PLUGIN_TAG} ./plugin

enable:
	@echo "### enable plugin ${PLUGIN_NAME}:${PLUGIN_TAG}"
	@docker plugin enable ${PLUGIN_NAME}:${PLUGIN_TAG}

push:  clean rootfs create enable
	@echo "### push plugin ${PLUGIN_NAME}:${PLUGIN_TAG}"
	@docker plugin push ${PLUGIN_NAME}:${PLUGIN_TAG}
