# 3NWeb Service

This is a place for directions on how to run 3NWeb service(s).

We use implementation published as `spec-3nweb-server` [npm package](https://www.npmjs.com/package/spec-3nweb-server).


### Content
- Intro: What is 3NWeb? How does it work? And how it spills into actual running server.
- Hookup: Setup names. DNS in a common case.
- Spec Server: Using implementation from `spec-3nweb-server` npm package.
- For Docker: image(s), scripts, setting.
- For systemd: service file, etc.
- Dedicated VPS scenario.


## Intro

3NWeb is a set of protocol that provides basic utility functionality needed to build multi-device environment with modern apps and UX. Current set contains:
- ASMail - for messaging, passing encrypted blobs.
- 3NStorage - for storing and sharing encrypted blobs.
- MailerId - non-tracking identity provider.

3NWeb is the Principle of Least Authority for client-server communication:
- 3N: when client gives No plain text content to the server (clients E2EEncrypt stuff), when client gives No unnecessary metadata, then there is Nothing abusable on the server.
- Web: web-style federation that has no server-to-server communication, with clients finding their own and their peers' services through naming system (e.g. DNS). Web-style federation helps to reduce amount of metadata that client provides to server. It also ensures permissionless participation, as long as you can get server's coordinates into naming system.

On a client side users have [client side platforms](https://github.com/PrivacySafe/privacysafe-platform-electron) like [PrivacySafe](https://download.privacysafe.app/). Client side platform is responsible for
- turning user data into encrypted blobs, accounting of keys;
- finding user peers' services via naming system (DNS) and contacting them directly;
- providing runtimes to run user apps on user devices, updating those user apps, etc. When user finds, creates and installs another shiny app into their digital realm, server knows nothing about it.

MailerId is a system for user identities that provides ids in form, similar to email addresses. For user `username@example.com` we'll say that `example.com` is user's domain, and `example.com` records should point to respective services for users on this domain.

Actual 3NWeb apps run on client devices. Therefore, compute requirement on server is not big. Servers need constant internet connection and reliable storage. Little home RasberryPi may just work for households with static IP's, or with dynamic DNS.

To roll out 3NWeb services today for your domain do these:
- setup server, accessible from the internet or network sections with your users;
- run minimal test from cli
- setup DNS TXT records on user domain(s) to point to your server
- set signup parameters on server
- download [PrivacySafe client platform](https://download.privacysafe.app/), create user, testing signup
- instruct others to download [PrivacySafe](https://download.privacysafe.app/) and give them respetive token to create accounts

Let's cover DNS setup first, and then cover possible server setup scenarios.


## Hookup DNS

Note, in following examples we'll use fictional domains like `example.com`, `exemple.fr`, `esempio.it`, `beispiel.de`, etc.

Let's imagine that for users of `example.com`:
- ASMail is provided by service point `https://post.beispiel.de/`
- 3NStorage is provided by  `https://stockage.exemple.fr:7070/quebec/`
- MailerId is provided by `https://esempio.it/mailerid/`

Then for each service user's domain `example.org` should have following TXT records:
- `asmail=post.beispiel.de` for ASMail
- `3nstorage=stockage.exemple.fr:7070/quebec` for 3NStorage
- `mailerid=esempio.it/mailerid` for MailerId

All three records have same pattern: `<service>=<domain>[:port][/path]`. Same or different domains in records, optional port and path allow to place services on same box, under the same proxy, or on different ends of the planet -- all options are open. DNS is not restricting how services can be set up.

Going more specific, [`spec-3nweb-server`](https://www.npmjs.com/package/spec-3nweb-server) implementation, used below, can run all three services. Each service exists under respective prefix path: `/asmail/`, `/3nstorage/`, `/mailerid/`. And when `spec-3nweb-server` is setup to run all three services at `https://exemple.quebec:7070/`, users' domain `example.com` needs following TXT records:
- `asmail=exemple.quebec:7070/asmail` for ASMail
- `3nstorage=exemple.quebec:7070/3nstorage` for 3NStorage
- `mailerid=exemple.quebec:7070/mailerid` for MailerId

Note that initial `https://` and trailing `/` are not needed.


## Spec Server

### Executable from npm package

`spec-3nweb-server` is distributed as an [npm package](https://www.npmjs.com/package/spec-3nweb-server). Code from package is used by tests in [3nweb client core library](https://github.com/3nsoft/core-3nweb-client-lib), used by [PrivacySafe](https://github.com/PrivacySafe/privacysafe-platform-electron). `spec-3nweb-server` also comes with an executable script that will run 3NWeb services.

Install npm package to be globally available:
```bash
npm install -g spec-3nweb-server
```
and it will make `3nweb` executable available:
```bash
3nweb --help
```
All commands gonna need a configuration file, and you get a yaml template with:
```bash
3nweb show-sample-config
```
If `--config` option is not given, `/etc/3nweb/conf.yaml` path is assumed.


### Configuration file

It is yaml, so watch your white space at the line start.

`enabledServices` section enables 3NWeb services. For example, the following will turn on all services:
```yaml
enabledServices:
  asmail: true
  storage: true
  mailerId: true
```

`domain` text field tells running process under from what domain it operates, how clients see it. When users connect to their asmail and storage services, they use MailerId process to login. Server embeds own domain into the assertion so that it can't be reused. For example:
```yaml
domain: service-for.example.com
```

`servicesConnect` section sets connectivity options like port, hostname, and tls options, when service isn't running behind TLS proxy, like HAProxy, or Nginx. For example, the following is a simple setting that uses LetsEncrypt certificate that is provisioned by [`certbot`](https://certbot.eff.org/):
```yaml
servicesConnect:
  port: 443
  letsencrypt: /etc/letsencrypt/live/service-for.example.com
```

`rootFolder` text field sets a path to folder for user data. This folder should be writable for the process. Default value is:
```yaml
rootFolder: /var/3nweb
```

`mailerId` section is needed when MailerId service is enabled. It contains path to folder, where MailerId root certificates are stored. This folder should be writable for the process. For example:
```yaml
mailerId:
  certs: /etc/3nweb/mailerid/certs
```

`signup` section signifies that signup of new users is enabled. If removed (server needs a restart on config's update) no more user could be added. Empty signup section:
```yaml
signup: {}
```
indicates that signup is enabled, but all new users require signup tokens. These are created with command either for specific username, or a domain:
```bash
# creates token for single username
3nweb signup create-token -u bob@example.com

# creates token for users on a given domain
3nweb signup create-token -d example.com
```
If you want to allow signups without tokens, section should point to json formatted file. For example:
```yaml
signup:
  noTokenFile: /etc/3nweb/no-token-signup.json
```
And content of the file be:
```json
{
  "type": "multi-domain",
  "domains": [ "example.com" ]
}
```

### Notes

- Server can provide services to many user domains, as long as user domains' DNS records point to it, and corresponding signups are configured.
- Server will do DNS requests. Egress should allow it.
- If users' MailerId service is not handled by this process, egress will be needed for MailerId verifier to get respective MailerId root certificates.
- Server listens only on one port. When implementation will be bundled with auxiliary services like STUN & TURN for WebRTC connections, in that future more ports will be needed. But for now, it is just one tcp port, defined in configuration file for carrying HTTPS traffic, with occasional upgrades to WebSockets.

### Simple test from cli

If all three services were enabled on `service-for.example.com`, standard HTTPS port `443`, then the following `bash` command should output json formatted text of respective services:
```bash
for section in mailerid asmail 3nstorage
do
  echo " --- $section section check ---"
  curl "https://service-for.example.com/$section"
  echo ""
done
```


## For Docker

`docker-utils` folder here contains [docker file](./docker-utils/3nweb_node22_trixie.Dockerfile) and a [script](./docker-utils/build-image.sh) for building image with latest `spec-3nweb-server` in it.

Docker image build is simple: based on one with NodeJS, it install npm package globally in the image, and `3nweb` executable becomes available.

You can run this image in any combinations: via docker-compose, as Docker Stack, in Kubernetes. But only one instance should be run at any given moment.

Image needs `/etc/3nweb`, `/var/3nweb` volume binds, and readonly `/etc/letsencrypt`, when LetsEncrypt is used. The following is the simplest command to run services (assuming 3nweb:latest tag):
```bash
docker run \
  -v /etc/3nweb:/etc/3nweb \
  -v /var/3nweb:/var/3nweb \
  -v /etc/letsencrypt:/etc/letsencrypt:ro \
  -p 7070:7070 \
  --name 3nweb_services \
  -d 3nweb:latest
```
Inside of running container you can do all 3nweb commands:
```bash
docker exec -i -t 3nweb_services 3nweb --help
```
or you can even step into it, as it has bash from base image:
```bash
docker exec -i -t 3nweb_services bash
```


## For systemd

`systemd` folder contains [service file](./systemd/3nweb.service) that you may add to systemd. It uses `3nweb` executable, which you get by installing [`spec-3nweb-server` npm package](https://www.npmjs.com/package/spec-3nweb-server) globally.

Copy service file to `/etc/systemd/system/` (or where it should be on your linux) and control it with `systemctl` ([some tutorial](https://www.digitalocean.com/community/tutorials/how-to-use-systemctl-to-manage-systemd-services-and-units)).


## Scenario: dedicated VPS

With the above background we can tackle specific scenarios. For example:
- need to provide service to users at `example.com` domain,
- using a dedicated VPS, available at `vps.esempio.it` domain for all three services.

We can skip Docker's machinery in a dedicated system and:
1. install NodeJS with npm, following [their instructions](https://nodejs.org/en/download);
2. install `3nweb` with
```bash
npm install -g spec-3nweb-server
```
3. install certbot, and create certificate for `vps.esempio.it`, in `--standalone` mode, as there are no other web servers running on port `80`
4. add systemd service 
5. create configuration file `/etc/3nweb/conf.yaml`:
```yaml
domain: vps.esempio.it

servicesConnect:
  port: 443
  letsencrypt: /etc/letsencrypt/live/vps.esempio.it

enabledServices:
  asmail: true
  storage: true
  mailerId: true

rootFolder: /var/3nweb

mailerId:
  certs: /etc/3nweb/mailerid/certs

signup: {}
```
6. create folders `/etc/3nweb/mailerid/certs` and `/var/3nweb`
7. run simple check from cli from some other machine:
```bash
for section in mailerid asmail 3nstorage
do
  echo " --- $section section check ---"
  curl "https://vps.esempio.it/$section"
  echo ""
done
```
8. add following TXT records to `example.com` DNS:
  - `asmail=vps.esempio.it.com/asmail`
  - `3nstorage=vps.esempio.it.com/3nstorage`
  - `mailerid=vps.esempio.it.com/mailerid`
9. create token for users' signup with command
```bash
3nweb signup create-token -d example.com
```
10. download [PrivacySafe](https://download.privacysafe.app/nightly/) client side platform, install, open and in `Create New Account` choose `Custom Service`, where `vps.esempio.it/signup` should be used as `Custom Service URL` together with created token.

If unrestricted signup is desired, requiring no token with custom domain, then `signup` section of config file should be:
```yaml
signup:
  noTokenFile: /etc/3nweb/no-token-signup.json
```
with file `/etc/3nweb/no-token-signup.json` being:
```json
{
  "type": "multi-domain",
  "domains": [ "example.com" ]
}
```
