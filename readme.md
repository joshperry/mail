# Mail

A stack for deploying a personal mail system on kubernetes

![Topo](docs/topo.svg)

## Why

I've ran my own mail server, for business and personal use, since before the days of gmail, and even hotmail.
I have since mostly stopped admining mail servers on the business side in deference to services like Google Apps for Business an Office 365.

However, I still run my personal mail on a dedicated stack.
I do this for a number of reasons, but security, privacy and flexibility are some of the top.
I particularly don't feel the cost asked of free users is equitable.

As deployment technology has progressed, my system was quietly humming along as a set of packages installed on a Gentoo server.

A monolithic stack like this begins to show its inertia, in the world of containers and orchestration, when attempting a change or move.
It make sense to modernize this now that you can get kubernetes at digital ocean,
and Google will give you a single-instance k8s cluster on even a free-tier machine.

This modernization project seemed a good opportunity to share my little project much more easily.
And because installing, running, and monitoring a mail system is still a PITA, and I want more normal people to run their own.

## Features

- SMTP Server (postfix)
- IMAP Server (dovecot)
- Preconfigured Strict Policies
- Virtual Domains
- Virtual Users
- Per-User Delivery Rules (dovecot pigeonhole sieves)
- Unified Datastore (couchmail)
- DKIM Signing (opendkim)
- Greylisting (postgrey)
- Envelope Validation and Spam Filtering (spamassasin)
- Spam Training
- Per-User Filtering Rules and Training Sets
- Per-User Spam Folder

This system features a central datastore where all user, domain, alias, and sieve scripts are stored.
A simple service called couchmail mediates between the services in the stack and the datastore.

This allows the simple hosting of any number of domains, and aliasing any email on one of those domains to any other address.

Dovecot plays a central role in mail delivery to clients and as a sasl authentication target for other services.
The Dovecot sasl service is configured to request user information from couchmail, so all services ultimately authenticate against the datastore.

Postfix plays a central role in receiving inbound mail and filtering it through policy, content, and spam filters.
It checks RBLs known relays and/or spammers and queries couchmail for realtime information on valid domains, users, aliases every time a message is received.

Postfix also hosts a client submission service for the delivery of outbound emails, authentication is handled via Dovecot's SASL service.

Spamassassin is used for processing inbound messages for spamminess and to validate the envelope of the email (DKIM, etc).
When a message is determined to be spam, it will be placed in the target user's Spam folder.

Every night Spamassassin is trained on ham from a user's Inbox and spam from their Spam folder, and stores a per-user fingerprint database for scoring future messages.
If the user catches ham in the Spam folder or spam in the Inbox, the user can move the message to the appropriate folder to update the training database.

## ToDo

- UI for managing domains/users/aliases
- Webmail (roundcube?)
- Letsencrypt
- Monitoring (prometheus, grafana)
- Helm?

# Implementation

We'll be using alpine docker containers running on a kubernetes cluster.

This repository contains the Dockerfiles for building each of the service containers, and all manifests required for deploying them onto a k8s cluster.
The images for each of the service containers will be hosted on (and built by) docker hub.

We will try to make all services run within a resource-constrained micro instance.
Some services may be optional (e.g. monitoring) in order to stay within this target footprint.

## Base Image

We're using Alpine Linux as our base OS image. The main reason is the small size and high-quality (and blazing fast) packaging system.

## Configuration

The default configuration should be enough for most mail handling systems of a reasonable size.
However, each of the pods will watch for custom config maps which can be used to override the default service configs.

When a config map for a service is changed, the pod will detect that and automatically reload or restart to effect the change.

### Configurables
While as many things as possible are generated, a number of values can be configured when generating the stack.

project:
region:
zone:
email: The email for the domain administrator (used for letsencrypt)
domain: The domain for this email server, example.com is used in examples throughout.


### DNS
A common method in simple DNS setups is to CNAME `mail` to your root domain and add records there:

```
A example.com <public-cluster-ip>
CNAME mail example.com
MX example.com mail.example.com
TXT dkim._domainkey v=DKIM1; k=...; p=...
TXT example.com 
```

### opendkim
OpenDKIM verifies DKIM-signed inbound messages and signs outbound messages.
The private key for opendkim represents this server's identity. This identity is then trusted by entries in DNS.

#### files
/etc/opendkim/opendkim.config: config file for opendkim
/var/secure/dkim.private: private key for signing outgoing messages
#### sockets
8891: milter service internal cluster port that verifies/signs messages

### dovecot

### postfix

main.cf
master.cf


## Network Policy
We want to control network policy using kubernetes to ensure that containers can only talk where we allow.

### Internal
postfix -> opendkim port 8891 - dkim filter
postfix -> postgrey port 10030 - greyfilter
postfix -> couchmail port 40571 - domain db
postfix -> couchmail port 40572 - mailbox db
postfix -> couchmail port 40573 - alias db
postfix -> dovecot port 12345 - dovecot sasl auth
postfix -> dovecot port 2424 - lmtp message delivery
postfix -> spamd port 783 - spamc client connection
dovecot -> couchmail port 40574 - socat proxy from dovecot dict proxy socket
spamd -> opendkim port 8891

### External 
postfix -> inet port 25 - outbound mail delivery
letsencrypt -> inet port 443 - TLS certificate signing
spamd -> inet port 53 - DNS for checking RBLs
inet port 25 -> postfix - inbound mail delivery
inet port 587 -> postfix - client mail submission
inet port 143 -> dovecot - email client connection
?inet port 443 -> roundcube
?roundcube -> dovecot port 143 - email client


## Let's Encrypt
We want to automate the process of retrieving any required publicly-signed certs using Let's Encrypt, stuffing the results into a k8s secret.

After an initial issuance, certbot stores the renewal config in /
/etc/letsencrypt/renewal/6bit.com.conf

### Needed Certs
SMTPS for TLS specified in postfix/main.cf
IMAPS for TLS specified in dovecot/conf.d/10-ssl.conf
TODO: HTTPS for webmail

# A Good Mail System

It seems desirable to continue having a presence on the SMTP network.
It is still a primary mode for many transactional and financial communications. Why?

## Open

The primary reasons a target email user need not reside in the same logical or physical domain as the source user, are the opinionated set of coordinating conventions that we call standards.

The physical, addressing, and transport-layer standards that enabled the heterogeneous singularity that spawned our modern packet-switched Internet are a good analog for the application layer standards that define the public discovery and communication interfaces for email server software.
Allowing for the free and open interconnection of heterogeneous software running the application layer of the SMTP network was a key to its success and a driver for its staying power.

Through modern extensions for encrypted communication and the identification of authoritative server instances, the SMTP network has continued to be used for high-value communications like financial interactions and identity verification.

This openness, however, has also seen many of the same problems that the baser Internet standards struggled with.
As more and varied users connect their networks to the global communications web and the network effects of return-on-attack by motivated entities, we see abuse of network resources and affinity fraud for mostly illicit financial gain.

## Goals

We want to communicate, in a secure fashion, with other email network users.
We want to ensure the identity of a message sender to the greatest level possible.
We want to assert our identity to the greatest level possible.
We want our stored communications to be resistant to inspection by either a remote, local, or midspan attacker.
We want our communication system to be resistant to failure of physical or logical resources.
We want to drive diversification of the email network by creating an email system that can be deployed and managed by anyone.
We want a system that can be easily iterated and updated to keep pace with security and feature changes in the email application layer.
We want to be able to support authoritative instances for the routing, storage, and delivery of any number of email domains.
We want each user to be able to script the acceptance and collation criteria for email messages.
We want messages to be analyzed for UCE, forging, and illicit contents.
We want to make end-to-end high-assurance identity and confidentiality a realistic default use-case for anyone.

## Needs
