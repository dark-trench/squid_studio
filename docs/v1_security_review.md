# V1 Trust Boundary Review

This review covers the V1 Studio surface that exists in the repository today:

- embedded workflow and editor LiveViews
- resolver callbacks for workflows, drafts, catalog data, save, and publish
- host-provided connector metadata rendered in the node catalog
- read-only versus editable access boundaries

## Conclusion

No known blocking security issue remains open in the current V1 surface.

The current implementation keeps execution, authorization, persistence, and
secret handling on the host side. The repo already has regression coverage for
the highest-risk boundaries that the UI exposes today.

## Verified Boundaries

### Resolver errors are normalized before they reach the UI

Studio does not surface raw resolver exceptions or secret-bearing failure text.
Runtime and data-loading failures are converted into generic availability
messages instead.

Evidence:

- `test/squid_studio/web/router_test.exs` covers failing resolver states and
  asserts that `secret=abc123` and raw exception text do not render.

### Edit controls are blocked in read-only mode

Read-only sessions cannot mutate draft state through hidden or direct LiveView
events. The editor blocks node moves, catalog insertion, save, and publish
actions at the server boundary.

Evidence:

- `test/squid_studio/web/router_test.exs` exercises read-only drag, node
  insertion, save, and publish paths and asserts the draft remains unchanged.

### Connector catalog rendering does not expose credential values

Studio renders only host-safe connector metadata. Credential requirements are
reduced to labels and keys, while disabled or unauthorized entries stay
non-runnable in the UI.

Evidence:

- `test/squid_studio/connector_catalog_test.exs` verifies normalization strips
  credential values and rejects non-JSON-safe metadata.
- `test/squid_studio/web/router_test.exs` verifies unauthorized or disabled
  connectors cannot be inserted into the draft graph.

### Save and publish stay host-owned

The library does not choose storage or runtime execution semantics. When the
host does not implement save or publish callbacks, Studio keeps edits local and
reports safe capability errors instead of mutating external state.

Evidence:

- `test/squid_studio/web/resolver_test.exs` verifies the default resolver
  returns unsupported save and publish results.
- `test/squid_studio/web/router_test.exs` verifies those unsupported paths keep
  the editor state intact and render generic capability messages.

## Deferred Or Host-Owned Surfaces

The following issue areas are still out of the current V1 implementation or are
intentionally left to host policy:

- Draft import and export (`#30`) are not shipped yet. When added, imported
  specs must be validated before they enter editable state and must exclude
  runtime-owned history or secrets.
- Manual pause, resume, cancel, replay, approval, and rejection controls
  (`#33`, `#34`) are not yet exposed. Those actions must remain host-authorized
  even if Studio later renders them.
- HTTP action configuration (`#20`) and controlled Elixir actions (`#21`) are
  not currently exposed in the embedded catalog. Their execution policy must
  stay on the host allowlist side of the resolver boundary.

These deferred areas are not blockers for the current V1 surface because the
repo does not yet expose them as runnable UI flows.

## Host Responsibilities That Remain Mandatory

Hosts embedding Studio still need to:

1. Authenticate the current user before mounting Studio routes.
2. Return only authorized workflows, drafts, and connector metadata.
3. Enforce edit versus read-only access through resolver callbacks, not client
   affordances.
4. Keep action allowlists, runtime execution, persistence, and secret redaction
   outside Studio.
5. Re-validate and policy-check drafts before publish or execution.

`docs/host_integration.md` remains the normative integration guide for those
responsibilities.
