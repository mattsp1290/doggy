# Publishing doggy to nimble.directory

## Pre-publish checklist

### Code quality
- [ ] All unit tests pass: `nimble test`
- [ ] All library modules check clean: `nimble check`
- [ ] All examples compile: `nim check examples/*.nim`
- [ ] Integration tests pass with real Datadog credentials (see `docs/ci-secrets.md`)
- [ ] CI is green on `main` branch

### Package metadata (doggy.nimble)
- [ ] `version` is bumped (use semantic versioning: `MAJOR.MINOR.PATCH`)
- [ ] `author` correct (`Matt Spurlin`)
- [ ] `description` accurate and concise
- [ ] `license` is `MIT` — verify `LICENSE` file exists
- [ ] `srcDir = "src"` is set
- [ ] `skipDirs = @["tests", "examples", "docs"]` excludes non-library content
- [ ] `requires "nim >= 2.0.0"` is the minimum supported version

### Repository
- [ ] `README.md` is complete and all quick-start snippets compile
- [ ] `LICENSE` file exists with the correct MIT license text
- [ ] `CHANGELOG.md` updated (or first-release entry created)
- [ ] Git tag created: `git tag v0.1.0 && git push origin v0.1.0`

## Version bump workflow

1. Update `version` in `doggy.nimble`
2. Add a CHANGELOG entry
3. Run `nimble test` and `nimble check` to verify
4. Commit: `git commit -am "chore: bump version to v0.1.0"`
5. Tag: `git tag v0.1.0`
6. Push: `git push origin main --tags`

## Publishing to nimble.directory

```bash
# Verify the package is well-formed
nimble check

# Publish (requires nimble login first)
nimble publish
```

Or submit via the nimble.directory website by registering the package URL:
`https://github.com/mattsp1290/doggy`

## Name conflict check

Before publishing, verify the name `doggy` is not already taken:

```bash
nimble search doggy
```

If the name is taken, choose an alternative (e.g., `nim-doggy`, `dd-observability`).

## Minimum Nim version

The package targets `nim >= 2.0.0` (requires ORC memory management). It is tested against the latest stable Nim release via GitHub Actions (`nim-lang/setup-nim-action@v2` with `nim-version: stable`).
