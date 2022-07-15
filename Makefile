SHELL:=/bin/bash
REQUIRED_BINARIES := docker
WORKING_DIR := $(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))
ROOT_DIR := $(shell git rev-parse --show-toplevel)
SCRIPTS_DIR := ${ROOT_DIR}/scripts
CLOUD_INIT_DIR := ${ROOT_DIR}/cloud-init

OPT_ARGS=""

# LDAP Vars
LDAP_PASSWORD ?= "demopassword"
LDAP_DOMAIN_URL ?= "platformfeverdream.io"

# LDAP generated
LDAP_DC := $(shell v='${LDAP_DOMAIN_URL}'; echo "$${v%.*}" )
LDAP_BASE_DC := $(shell v='${LDAP_DOMAIN_URL}'; echo "$${v#*.}" )


check-tools: ## Check to make sure you have the right tools
	$(foreach exec,$(REQUIRED_BINARIES),\
		$(if $(shell which $(exec)),,$(error "'$(exec)' not found. Tanzu CLI is required. See instructions at https://docs.vmware.com/en/VMware-Tanzu-Kubernetes-Grid/1.5/vmware-tanzu-kubernetes-grid-15/GUID-install-cli.html")))

start-ldap-manager: check-tools
	@printf "\n===> Starting LAM\n";
	@${SCRIPTS_DIR}/start-ldap-manager
	@printf "\nOpen a browser to http://localhost:8080\n";

stop-ldap-manager: check-tools
	@printf "\n===> Stopping LAM\n";
	@docker stop lam 2&> /dev/null || true
	@docker rm lam 2&> /dev/null || true

create-openldap-cloud-config: check-tools
	@printf "\n===> Generating cloud config for OpenLDAP\n";
	cat ${CLOUD_INIT_DIR}/userdata.yaml | LDAP_ADMIN_PASSWORD=$(LDAP_PASSWORD) LDAP_DOMAIN_URL=${LDAP_DOMAIN_URL} LDAP_DC=${LDAP_DC} LDAP_BASE_DC=${LDAP_BASE_DC} envsubst > /tmp/userdata.yaml
	@printf "\nCloud Init Ready, file located at /tmp/userdata.yaml\n";
	@printf "\nYou can regenerate with a non-default password by overriding PASSWORD when calling this target\n";




