# OpenLDAP on Harvester
Currently the Harvester CLI does not allow for creating vm-templates, cloud-templates, or deeper config options on VMs themselves, so we cannot create much in the way of a VM from the command-line yet.

However, we can generate a valid cloud-init yaml spec, which you can place into Harvester's UI when building an OpenLDAP server. This requires Ubuntu and has only been tested on 22.04, though should work on 20.04 as well. This assumes an Ubuntu cloud image, this one was used: [link](https://cloud-images.ubuntu.com/releases/22.04/release/ubuntu-22.04-server-cloudimg-amd64.img)

## Usage
See the [Makefile](Makefile) for valid targets. Intended use thus far is below:

### Generate a Cloud-Init
Using the `create-openldap-cloud-config` target and the `LDAP_PASSWORD`, `LDAP_DOMAIN_URL` overrides, a valid config can be generated for an OpenLDAP server to stand up on an Ubuntu VM. Ensure you have a DNS entry pointed at ldap.LDAP_DOMAIN_URL for this to work.

Example:
```console
bdurden@bdurden-XPS-13-9370:~/rancher/openldap-harvester$ make create-openldap-cloud-config LDAP_PASSWORD="mydumbpassword" LDAP_DOMAIN_URL="mydomain.lol"

===> Generating cloud config for OpenLDAP
cat /home/bdurden/rancher/openldap-harvester/cloud-init/userdata.yaml | LDAP_ADMIN_PASSWORD=mydumbpassword LDAP_DOMAIN_URL=mydomain.lol LDAP_DC=mydomain LDAP_BASE_DC=lol envsubst > /tmp/userdata.yaml

Cloud Init Ready, file located at /tmp/userdata.yaml

You can regenerate with a non-default password and domain by overriding LDAP_PASSWORD and LDAP_DOMAIN_URL when calling this target
```

The resulting userdata yaml file:
```yaml
#cloud-config
package_update: true
write_files:
  - path: /etc/ldap/ldap.conf
    owner: root
    content: |
      #
      # LDAP Defaults
      #

      # See ldap.conf(5) for details
      # This file should be world readable but not world writable.

      BASE	dc=mydomain,dc=lol
      URI	ldap://ldap.mydomain.lol ldap://localhost

      #SIZELIMIT	12
      #TIMELIMIT	15
      #DEREF		never

      # TLS certificates (needed for GnuTLS)
      TLS_CACERT	/etc/ssl/certs/ca-certificates.crt


packages:
  - qemu-guest-agent
  - debconf-utils
  - slapd 
  - ldap-utils
runcmd:
  - - systemctl
    - enable
    - '--now'
    - qemu-guest-agent.service
  - echo slapd slapd/password2	password mydumbpassword | debconf-set-selections -v
  - echo slapd slapd/internal/generated_adminpw	password mydumbpassword	| debconf-set-selections -v
  - echo slapd slapd/internal/adminpw	password mydumbpassword | debconf-set-selections -v
  - echo slapd slapd/password1	password mydumbpassword	| debconf-set-selections -v
  - echo slapd shared/organization	string	homelab | debconf-set-selections -v
  - echo slapd slapd/move_old_database	boolean	true | debconf-set-selections -v
  - echo slapd slapd/upgrade_slapcat_failure	error	| debconf-set-selections -v
  - echo slapd slapd/purge_database	boolean	false | debconf-set-selections -v
  - echo slapd slapd/dump_database	select	when needed | debconf-set-selections -v
  - echo slapd slapd/invalid_config	boolean	true | debconf-set-selections -v
  - echo slapd slapd/password_mismatch	note | debconf-set-selections -v
  - echo slapd slapd/dump_database_destdir	string	/var/backups/slapd-VERSION | debconf-set-selections -v
  - echo slapd slapd/domain	string	mydomain.lol | debconf-set-selections -v
  - echo slapd slapd/postinst_error	note	| debconf-set-selections -v
  - echo slapd slapd/no_configuration	boolean	false | debconf-set-selections -v
  - dpkg-reconfigure -fnoninteractive slapd

```

### Starting the LDAP Account Manager
We're using docker here to spin up a basic instance of LAM so that we can administer our LDAP server with relative ease and on-demand. There's a simple makefile target for that and it uses similar overrides as when you created the cloud-init. The target is `start-ldap-manager` and the override is `LDAP_DOMAIN_URL` with an optional `LAM_PASSWORD` to set the LAM configuration password (the utility itself).

Example:
```console
bdurden@bdurden-XPS-13-9370:~/rancher/openldap-harvester$ make start-ldap-manager LAM_PASSWORD="demopassword" LDAP_DOMAIN_URL="mydomain.lol"

===> Starting LAM
9f69fb0c779992cd847d8d9c90e5c8f9220a67128a86b896fa2485ed04c286d7

Open a browser to http://localhost:8080
```

From here, you can create groups and then users that can be referenced from external tools like Keycloak that use this instance of OpenLDAP.