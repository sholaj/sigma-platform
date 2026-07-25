---
name: anonymisation
description: |
  Enforces the sigma-platform anonymisation policy. ALWAYS use this skill
  when the user mentions writing, editing, or reviewing any file that may
  contain client-identifying information, vendor names, geographic
  identifiers, financial sector references, real ASNs, real public IPs,
  real hostnames, or any internal codename other than "sigma-platform".
  Use BEFORE writing commits, README content, ADRs, comments, or any
  documentation. Use whenever the user pastes content from chat,
  Slack, Teams, or Jira/Linear into the conversation.
---

# Anonymisation policy

This repo is anonymised by design. Treat every artifact as
world-readable forever, even while the GitHub repo is private. The
following identity rules are non-negotiable.

## Forbidden terms (case-insensitive, including obvious obfuscations)

- The client trading name or its abbreviation
- The vendor partner consulting firm name
- The strings: "bank", "banking", "insurance", "trading floor",
  "wealth management", "private banking", any regulator acronym
- City, country, region, building, datacentre, or campus names tied
  to the engagement
- Real public ASNs from the customer estate
- Real public IPs from the customer estate
- Real internal hostnames, FQDNs, or DNS suffixes
- Any internal project codename other than `sigma-platform`

## Required placeholders

Use these substitutes EVERY TIME real values would appear:

| Concept                     | Placeholder                       |
|-----------------------------|-----------------------------------|
| Client                      | `Example Org`                     |
| Vendor partner              | `Example Partner`                 |
| IPv4 example (any)          | `192.0.2.0/24` (TEST-NET-1)       |
| IPv4 example (alt)          | `198.51.100.0/24` (TEST-NET-2)    |
| IPv4 example (alt 2)        | `203.0.113.0/24` (TEST-NET-3)     |
| Public DNS suffix           | `example.com`                     |
| Internal DNS suffix         | `internal.example`                |
| ASN                         | `64512` (private ASN range)       |
| Region                      | `uksouth` (Azure region OK)       |
| Hostname pattern            | `bastion-01`, `aro-hub-01`, ...   |

## Workflow when asked to write content

1. Scan the user's request for any term that matches the forbidden list.
2. If found, STOP and ask the user to confirm the placeholder mapping
   before producing output. Do not silently rewrite — explicit consent
   only.
3. After writing, re-scan the diff. If a forbidden term slipped through,
   refuse to write the file and explain which term triggered.
4. For pasted content from external systems (Slack, Jira, email),
   ALWAYS produce a sanitised version first, get user approval,
   THEN commit.

## When the user insists on a forbidden term

Refuse. Cite this skill. Suggest the placeholder. Do NOT comply.

## CI back-stop

A gitleaks rule with a `forbidden-terms` custom ruleset runs in the
`anon-scan` pre-commit hook (and in CI when Phase 0 workflows land).
The hook concatenates the public `.gitleaks.toml` (structural only)
with the private `~/.config/sigma-platform/gitleaks-forbidden.toml`.
Your job is to prevent leaks reaching CI, not to rely on it.
