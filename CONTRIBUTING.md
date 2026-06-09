# Contributing

Thanks for contributing to Squid Studio.

## Development Setup

Requirements:

- Elixir `~> 1.19`
- Erlang/OTP compatible with the current CI matrix

Install dependencies and build assets:

```sh
mix deps.get
mix assets.build
```

## Local Verification

Run the root verification gate before opening a pull request:

```sh
mix precommit
```

For UI and asset changes, also run:

```sh
mix assets.build
```

## Workflow For Changes

1. Start from `main`.
2. Create a short-lived branch for one focused slice.
3. Keep commits small and intentional.
4. Add or update tests with behavior changes.
5. Run the relevant verification before opening a pull request.

## Pull Requests

Pull requests should:

- describe the final net change
- explain why the change is needed
- stay focused on one reviewable slice
- reference the issues they close when applicable

## Questions And Discussion

If a change affects runtime contracts, editor specs, persistence, authorization,
or host integration boundaries, open an issue or draft pull request before the
implementation gets large.
