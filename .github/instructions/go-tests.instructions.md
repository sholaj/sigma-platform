---
applyTo: "tests/**/*.go"
---
- Use Ginkgo v2 `Describe / Context / It` structure.
- Use Gomega's `Expect(...).To(...)` matchers, never `assert.*`.
- e2e tests must NEVER hit external customer hostnames. Test only
  against the dynamically-provisioned ARO clusters in uksouth or the
  local kind cluster.
- Terratest fixtures must clean up with `defer terraform.Destroy(...)`.
- Always run `t.Parallel()` where state is independent.
