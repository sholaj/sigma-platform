# Glossary of anonymisation placeholders

This file enumerates the placeholders that must appear in artifacts
in place of any real customer/partner/sector identifier. It is
allowlisted in `.gitleaks.toml` because it documents the
substitutions by design.

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
| Region                      | `uksouth`                         |
| Hostname pattern            | `bastion-01`, `aro-hub-01`, ...   |
| vCenter endpoint            | `vcenter.example.com`             |
| Datastore                   | `datastore-01`, `datastore-02`    |
| Portgroup                   | `pg-app-tier`, `pg-db-tier`       |
| VM names                    | `app-vm-01` through `app-vm-30`   |
