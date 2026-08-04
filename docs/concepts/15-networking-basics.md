# Networking basics: VLANs, DNS, and TLS

## What this doc covers

This one's different from the others in this folder — it's not documenting a piece of *this repo*, it's the background you need to make two decisions currently sitting open in [TODO.md](../../TODO.md):

- Should the Proxmox Docker host go on its own VLAN?
- Should the dev VM get a real subdomain + Let's Encrypt cert?

Those two questions turn out to be more related than they look. This doc walks through the underlying concepts one at a time, then shows how they chain together into one request from a browser to your app, then lays out the actual decisions you need to make.

**Decided so far (see "Status in this project" for the running record):** use DNS-01 for certs, and the dev VM stays internal-only — no pfSense forwarding for it at all, ever. That second point turns out to sidestep the hostname-routing problem originally raised in decision #3 below; see the new piece 6 for why, and for what *would* eventually bring that problem back (hosting a second, unrelated site).

---

## The pieces

### 1. VLANs — cutting one physical network into separate logical ones

Every device on your home network — laptops, phones, the Proxmox box, a smart TV, whatever — normally shares one flat network. Any device on it can, in principle, talk directly to any other device on it. A **VLAN** (Virtual LAN) is a way of telling your switch/router "pretend these devices are on a completely separate network," even though they're plugged into the same physical hardware. Devices on different VLANs can't reach each other at all unless you explicitly add a routing rule allowing it.

Why this matters: it's about **blast radius**. If one device on your network gets compromised — a sketchy IoT gadget, a phone with a malicious app, whatever — a flat network means that compromised device can potentially probe and attack everything else on it, including your Docker host. Put the Docker host on its own VLAN, and a compromised device elsewhere on your network simply can't reach it, full stop, regardless of what vulnerabilities either side has.

The key thing for your decision: **VLANs protect against threats that originate from *inside* your network.** They do nothing about threats from the internet — that's a different piece (port forwarding, below). A LAN-only dev VM that nothing external can reach is already fairly well protected regardless of VLANs, simply because there's no way in from outside to begin with.

### 2. DNS and domains — turning a name into an address

The internet routes traffic by IP address, not by name. **DNS** is the system that translates a human-readable name like `coffeyclub-dev.example.com` into an IP address (an "A record"), so that typing a name into a browser actually goes somewhere. You manage these records through whoever your domain is registered with (a registrar) or a separate DNS provider (Cloudflare, Route53, etc. — some registrars also act as the DNS provider).

Important nuance: **getting DNS to resolve is not the same as the app being reachable.** Pointing `coffeyclub-dev.example.com` at your home's public IP just means a browser will now try to connect to your public IP when someone visits that name — whether anything answers depends entirely on the next two pieces.

### 3. TLS certificates and Let's Encrypt — proving identity and encrypting traffic

HTTPS (TLS) does two things: encrypts traffic between browser and server, and proves the server is actually who it claims to be, via a **certificate**. [Let's Encrypt](https://letsencrypt.org) is a free, automated certificate authority — `certbot` is the standard tool that requests and renews certs from it (this is what's referenced in [14-deployment-proxmox.md](../technology/14-deployment-proxmox.md) and the TLS block in [nginx/nginx.conf](../../nginx/nginx.conf)).

To issue you a cert for a domain, Let's Encrypt has to verify you actually control that domain. There are two ways to do this ("challenges"), and **which one you pick directly determines whether you need to expose anything to the internet yet**:

- **HTTP-01 challenge**: Let's Encrypt puts a random token in a URL and asks your server to serve it back over plain HTTP, from the actual public internet. This means **port 80 has to be reachable from the internet, pointed at that exact box**, at the moment you request/renew the cert. This is the default `certbot` behavior and what most guides assume.
- **DNS-01 challenge**: Let's Encrypt asks you to create a specific TXT record in your DNS instead, then checks DNS to confirm it. **No port needs to be open to the internet at all** — this can be done entirely from behind your firewall, since it only touches your DNS provider's API, not your home network. The tradeoff is it requires your DNS provider to support this (most modern ones do, via an API key certbot plugin — e.g., `certbot-dns-cloudflare`).

This is the crux of your VLAN-vs-domain sequencing question: **DNS-01 lets you get a real cert for the dev VM without any port-forwarding or internet exposure at all**, which means it doesn't need VLAN segmentation to be done safely first. HTTP-01 does require exposure, which means it should come *after* VLAN segmentation, not before.

### 4. Port forwarding — the actual moment of exposure

Nothing from the internet can reach any device on your home network by default — your router only knows how to send return traffic for connections *you* initiated. **Port forwarding** (configured in pfSense, in your case) is the explicit rule that says "traffic arriving at my public IP on port 443, send it to this specific internal device." This is the actual moment a device goes from "invisible from the internet" to "reachable from the internet" — DNS records alone don't do this; a domain pointing at your public IP with no port-forward rule just results in a timeout for anyone trying to connect.

pfSense is also frequently the same box that manages VLANs, so in practice "set up a VLAN" and "set up port forwarding" both usually happen in the same pfSense UI, just different sections.

### 5. Local DNS overrides — a real name for a box that's never exposed

If the dev VM never gets a port-forward rule (see decisions below), a public DNS A record for `coffeyclub-dev.example.com` wouldn't actually get you anywhere useful — even if it pointed at your home's public IP, there'd be nothing on the other end to answer it, and many home routers don't handle "calling your own public IP from inside your own network" cleanly anyway (this is sometimes called NAT hairpinning/reflection, and not every router supports it well).

The fix is pfSense's **DNS Resolver → Host Overrides** feature: it lets you tell pfSense's own DNS server "when anything on my LAN asks for `coffeyclub-dev.example.com`, answer with `<dev-vm's-internal-ip>` directly — don't even ask the internet." Anything on your network (your laptop, your phone) then resolves that name straight to the dev VM's real LAN address, with zero public exposure involved.

This is fully compatible with DNS-01 certs: DNS-01 only checks a TXT record in your domain's *public* DNS zone to prove ownership — it never checks that an A record exists or resolves to anything reachable. So you can get a real, valid, publicly-trusted certificate for a name that only ever resolves *inside* your own network. This is a common, unremarkable homelab pattern, not a hack.

### 6. Hosting more than one site from one public IP

Not relevant to this project's plan right now (dev stays internal, so there's only one thing — prod — ever needing exposure), but worth understanding since it'll matter the day you host something else from the same home connection: a pfSense port-forward can only send port 443 to *one* internal IP. It can't look at *which website* someone's trying to reach and decide between two backends — a port-forward rule doesn't inspect the request at all.

The fix, when you need it: don't forward port 443 straight to a backend VM. Forward it to one extra "front door" — a reverse proxy (common choices: Nginx Proxy Manager, Traefik, Caddy, or HAProxy as a pfSense package) that reads the **hostname being requested** and forwards the connection to the correct backend based on it. This works even over HTTPS before anything is decrypted, because the hostname is sent in the clear as part of the TLS handshake itself (a field called **SNI**, Server Name Indication — it exists specifically so a server can pick the right certificate to present).

Two ways to build that front door, if/when you get there:
1. **Front door terminates TLS for everything** — holds every domain's cert itself, decrypts there, forwards plain HTTP internally. Simpler, and the far more common pattern. This project's `nginx` would eventually just serve plain HTTP internally instead of doing its own TLS.
2. **Front door passes TLS straight through** — only reads the unencrypted SNI field, forwards the still-encrypted connection untouched; each backend (including this project's own `nginx`) keeps terminating TLS itself, unchanged from today. More setup work on the front door, no changes needed to existing backends.

---

## How it all chains together

A request to `https://coffeyclub-dev.example.com` in production-shaped form would flow like this:

```
Browser looks up coffeyclub-dev.example.com
    → DNS returns your home's public IP
        → request hits your public IP on port 443
            → pfSense port-forward rule sends it to the dev VM's internal IP
                → (VLAN, if configured, determines what else that VM can reach —
                   doesn't affect this inbound path itself)
                    → nginx on the VM terminates TLS using the Let's Encrypt cert
                        → proxies to the api container
```

Notice VLANs don't sit *in* this inbound path at all — they only constrain what the VM can do *after* it's reachable, i.e. lateral movement. That's why VLAN and domain/TLS are somewhat independent decisions rather than strictly sequential ones, except through the HTTP-01-requires-exposure link above.

The dev VM's path looks different — shorter, and never leaves the house:

```
Browser on your LAN looks up coffeyclub-dev.example.com
    → pfSense's DNS Resolver answers directly (Host Override) with the dev VM's internal IP
        → request goes straight there over the LAN — no public IP, no port-forward, involved at all
            → nginx on the dev VM terminates TLS using a DNS-01-issued cert
```

No pfSense port-forward rule exists for the dev VM in this picture — it simply isn't part of the inbound-from-the-internet story at all.

---

## Decisions to make

1. ~~Does your domain's DNS provider support an API-based DNS-01 plugin?~~ **Decided: use DNS-01.** It avoids exposure entirely (both for issuing and for every renewal after), and it's the only way to get a wildcard cert if that ever becomes useful. Still need to confirm your specific DNS provider has a certbot plugin for it — that's the remaining concrete step.
2. If DNS-01 turns out not to be available for some reason, are you comfortable doing VLAN segmentation before exposing anything for an HTTP-01 challenge? (Fallback plan only — not the current plan.)
3. ~~Do you want the dev VM and prod reachable on the same public IP at the same time?~~ **Decided: no.** The dev VM stays internal-only forever — no pfSense forwarding rule for it, ever. Only prod gets exposed. This means the SNI/Host-header routing problem doesn't apply to dev vs. prod at all; it would only come back if you host a *third*, unrelated site from the same home connection later (see piece 6 above) — explicitly deferred, not needed now.

## Status in this project

- No VLAN exists yet — the Proxmox host and dev VM currently sit on the flat home LAN. Given decision 3 above, this is lower priority than it looked originally, since the dev VM was never going to be internet-facing anyway.
- No pfSense port-forwarding is configured for either VM yet. The plan is for this to stay permanently true for the dev VM, and become true for prod only.
- No domain points at anything related to this project yet — `coffeyclub.example.com` and `coffeyclub-dev.example.com` are both placeholders throughout the repo and docs.
- No pfSense DNS Resolver Host Override is set up yet for internal-only resolution of the dev subdomain.
- The dev VM's nginx ([nginx/nginx.dev.conf](../../nginx/nginx.dev.conf)) runs plain HTTP with no TLS at all, which is what the dev-subdomain work will move past.
- Only one site (this project) is planned — piece 6's front-door reverse proxy isn't needed and isn't being built.

See the corresponding open items in [TODO.md](../../TODO.md) (Security section and the dev-subdomain item under External services / infra setup).
