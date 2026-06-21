# V1 Release Checklist

Use this checklist before cutting the first public Squid Studio release. The
goal is to make packaging and release notes repeatable instead of relying on a
one-off memory of local steps.

## 1. Confirm Release Scope

- Pick the target version and tag before changing files.
- Confirm the release commit is already merged into `main`.
- Summarize the intended public surface for the release in `CHANGELOG.md`.

## 2. Verify Package Contents

Squid Studio publishes only the files declared in `mix.exs`:

```elixir
files: ~w(assets config lib priv .formatter.exs CHANGELOG.md LICENSE mix.exs README.md)
```

Release verification should confirm the package excludes:

- `_build/`
- `deps/`
- local worktrees, scratch files, and machine-local notes
- CI artifacts and generated coverage reports
- standalone development state that is not required by the library itself

Recommended verification:

```sh
mix hex.build
mix hex.build --unpack
find pkg -maxdepth 3 -type f | sort
```

Review the unpacked tarball before publishing.

## 3. Run Release Gates

- Run `mix precommit`.
- Rebuild package assets through the normal release path.
- Re-run any targeted smoke checks for user-facing editor changes merged since
  the last release candidate.

If any step requires a local workaround, document it in the release notes or
the maintainer handoff before tagging.

## 4. Finalize Changelog

Before tagging, replace planning notes with a complete `0.1.0` entry that
includes:

- Host integration and embedding support.
- Editor capabilities shipped in V1.
- Current shipped trust-boundary decisions in `docs/v1_security_review.md`.
- Runtime or security boundary expectations that host applications must know.
- Any breaking changes, notable limitations, or deferred follow-ups.

Do not publish `0.1.0` with an empty or placeholder changelog entry.

## 5. Pre-1.0 Versioning Policy

Until `1.0.0`, treat version bumps as follows:

- Patch (`0.x.y`) for fixes, small docs updates, and low-risk polish that does
  not materially change the public embedding contract.
- Minor (`0.y.0`) for meaningful host-facing additions, new editor capabilities,
  resolver contract changes, or packaging changes that alter expected behavior.
- Call out contract shifts explicitly even when SemVer allows them under `0.x`.

Pre-1.0 does not remove the need for clear release notes. If a host
implementation must change, document that requirement in the changelog and
release notes.

## 6. Tag And Publish

- Create an annotated tag from merged `main`.
- Push the tag.
- Draft GitHub release notes from the finalized changelog.
- Publish the Hex package only after the tag and release notes match the
  packaged artifact.

## 7. Post-Release Verification

- Confirm the GitHub release points at the tagged commit.
- Confirm the Hex package version is available.
- Verify the README installation snippet matches the published versions.
- Capture any follow-up fixes as new issues instead of editing the released tag.
