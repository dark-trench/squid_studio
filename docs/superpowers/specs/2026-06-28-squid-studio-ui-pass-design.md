# Squid Studio UI Pass Design

## Goal

Refactor the Squid Studio management and editor surfaces so action ownership is obvious, the editor header is no longer crowded, and the right-hand properties rail feels like a compact workflow tool rather than a tall form-driven settings page.

## References

This pass should be heavily inspired by, but not copy, two existing workflow UIs:

1. OpenAI agent-builder style surfaces for quiet chrome, restrained top-level actions, and clear draft-state emphasis.
2. Retool Workflows for dense operator-facing panels, practical list/detail behavior, and compact input treatment.

The result should still look and feel like Squid Studio, not a clone of either reference.

## Design Principles

1. Keep global chrome calm. The app shell should communicate location and state before actions.
2. Put actions on the surface that owns them. Workflow inventory actions stay on the workflows page; draft lifecycle actions stay inside the editor.
3. Prefer compact operator UI over oversized marketing-style spacing.
4. Keep the canvas visually central. Side panels should support the canvas, not compete with it.
5. Preserve current workflow behavior. This pass changes structure, density, and affordances rather than introducing new workflow semantics.

## Scope

This refactor covers:

1. The workflows index page.
2. The editor shell and top command structure.
3. The left navigation/catalog rail inside the editor.
4. The right-hand properties rail and form density.
5. Supporting tests that assert the intended structure and workflow controls.

This refactor does not cover:

1. New workflow execution features.
2. New draft lifecycle behavior beyond moving or relabeling existing controls.
3. Rewriting the canvas interaction model.
4. A visual copy of any reference product.

## Information Architecture

### Workflows Page

The workflows page becomes the clear inventory and entry surface for workflow-level actions.

1. Keep the global page header minimal: wordmark/title on the left, theme switcher on the right.
2. Keep `New draft` on this page as the primary create action.
3. Add draft-management affordances here rather than in the editor header. Draft deletion should live in the workflows page draft list or draft detail context, not the active editing command bar.
4. Keep search and status filters, but make them read as practical inventory controls instead of decorative hero-page elements.
5. Shift the page layout closer to a list/detail operations surface than a marketing landing page. The empty state should stay helpful but more matter-of-fact.

### Editor Shell

The editor becomes a clearer workspace with three explicit zones:

1. A restrained top context bar.
2. A left rail for workflow/draft/catalog navigation.
3. A central canvas with a compact draft command bar.
4. A pinned right inspector that stays visible but uses less width and less vertical padding.

The top context bar should no longer be a catch-all toolbar. It should communicate:

1. Back navigation to workflows.
2. Workflow name.
3. Draft status.
4. Validation status.
5. Lightweight graph metrics only if they still fit without crowding.

The top context bar should not contain:

1. `Create draft`.
2. `Delete draft`.
3. A full row of mixed lifecycle and inventory actions.

### Draft Command Bar

The editor should own only active-draft actions. Introduce a compact in-workspace command bar that contains:

1. `Save draft`
2. `Validate`
3. `Publish version`

This bar should visually sit with the canvas workspace rather than the global app header. It can live above the canvas controls or as a compact row aligned with the editor content area. The important boundary is that it reads as "actions for the draft I am editing now."

### Left Rail

The left rail should remain always visible and should become more intentionally tool-like.

1. Keep workflow browsing, draft switching, and node catalog access in the rail.
2. Tighten spacing and hierarchy so the rail feels closer to Retool’s practical operator panels than to stacked marketing cards.
3. Reduce decorative copy and keep labels concrete.
4. Keep search for the node catalog, but make the field slimmer and visually integrated with the rail.
5. Preserve current capabilities: selecting workflows, selecting drafts, and adding catalog nodes.

### Properties Rail

The inspector remains always visible.

1. Reduce its width modestly so the canvas regains space.
2. Tighten section spacing, field spacing, and header padding.
3. Shorten input heights across text inputs, selects, and textareas.
4. Keep labels readable, but use a denser rhythm with less empty space between label, control, and help text.
5. Make connection/metadata sections look like compact inspection rows rather than large cards.
6. Preserve readability for validation and field errors while reducing vertical bloat.

The right rail should feel closer to a compact configuration pane used by operators every day.

## Visual Direction

The visual update should borrow patterns, not branding.

1. Use calmer chrome and lighter visual separation between header and workspace.
2. Keep canvas framing subtle so nodes remain the focal point.
3. Use slimmer pills, badges, and buttons in the editor shell.
4. Keep the existing Squid Studio theme system, but reduce visual noise in the shell.
5. Preserve enough contrast and affordance for dark, light, and system themes.

## Interaction Rules

1. `New draft` is initiated from the workflows page.
2. `Delete draft` is initiated from workflow or draft inventory context, not from the editor topbar.
3. `Save`, `Validate`, and `Publish` remain available while editing a draft.
4. Read-only mode still disables mutation controls wherever they move.
5. Validation state remains visible without requiring the user to open a separate panel.
6. The inspector is always present, so empty-state messaging inside it should remain useful when no node is selected.

## Content and Copy Direction

1. Prefer direct operator copy over promotional framing.
2. Shorten labels where possible: `Validate` instead of `Validate draft` if context is already obvious.
3. Avoid duplicate concepts appearing in multiple places at once.
4. Keep workflow and draft terminology consistent across index and editor views.

## Implementation Boundaries

This refactor should stay inside the current LiveView/CSS structure unless a small template split is clearly needed for readability. Preferred files to update:

1. `lib/squid_studio/web/live/workflows_live.html.heex`
2. `lib/squid_studio/web/live/editor_live.html.heex`
3. `assets/css/app.css`
4. The router and smoke tests that currently assert the old header and control layout

If the editor template becomes meaningfully easier to maintain by extracting a small function component or helper partial, that is acceptable, but broad LiveView restructuring is out of scope.

## Testing Strategy

Use UI contract tests to protect the new ownership model.

1. Update router assertions for the workflows page so they continue to confirm `New draft` belongs there.
2. Update editor assertions so the top context bar no longer expects create/delete controls.
3. Add or adjust assertions for the new draft command bar containing save/validate/publish controls.
4. Preserve smoke coverage for validate/save/publish flows after the controls move.
5. Keep read-only coverage so disabled states still apply in the refactored layout.
6. Add targeted CSS assertions only for meaningful structural tokens that define the new shell and inspector density.

Tests should assert intended structure and behavior, not brittle incidental copy where a stable selector or layout hook is available.

## Risks

1. Moving controls can break existing LiveView tests and smoke selectors if the new structure is not introduced with stable IDs.
2. A denser inspector can become harder to scan if spacing is reduced too aggressively.
3. Narrowing the properties rail too much can make multi-line fields uncomfortable to edit.
4. Over-borrowing from references could erase Squid Studio’s own visual identity.

## Success Criteria

This pass is successful when:

1. The workflows page clearly owns workflow inventory actions, especially draft creation.
2. The editor header feels materially calmer and no longer mixes inventory actions with active-draft actions.
3. The editor exposes a compact action set centered on `save`, `validate`, and `publish`.
4. The properties rail remains always visible but is noticeably more compact.
5. The updated shell feels inspired by OpenAI and Retool workflow tooling without reading as a direct copy.
6. Existing workflow editing behavior still works after the refactor, with updated tests proving the new UI contract.
