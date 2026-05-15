# Security policy

`sigma-platform` is a reference sandbox repository. It does not host
production code or process production data. There is no SLA on
responses to security reports.

If you nonetheless wish to report a concern:

- **Anonymisation slip**: if you spot what looks like a real
  customer/partner/sector identifier in the public history, please
  open a private security advisory via the GitHub UI
  (Security → Advisories → "New draft security advisory"). Do NOT
  open a public issue — that would amplify the leak.
- **Vulnerability in tooling**: this repo wraps third-party CLIs
  and operators. Report upstream first; open a courtesy issue here
  only if the upstream report has a public CVE that this repo's
  configuration aggravates.

This repo follows the GitHub Advanced Security defaults — secret
scanning, push protection, Dependabot alerts.
