# Brainstorm: Review the Specs (per-repo Firebase project spec)

**Date**: 2026-06-10
**Type**: problem-solving / critical review
**Subject**: `cli/SPEC-per-repo-projects.md`

## Central Question
Is the per-repo Firebase project spec correct, safe, and complete enough to implement?
Where are the holes, footguns, and unchallenged assumptions?

## Review Lenses (mind map)
```
REVIEW THE SPEC
├── Correctness / footguns
│     - walk-up discovery has NO stop condition → could deploy from a parent repo's config
│     - multi-target vs top-level schema: both present = ambiguous
│     - migration rewrites .gitignore automatically → could un-ignore a secret
├── Security
│     - auto .gitignore narrowing must NEVER expose service-account.json
│     - config.json writer must strip secret fields (defense in depth)
│     - no preflight that the key has hosting perms (fails late)
├── Assumptions to challenge
│     - "repo-local key = portable/self-contained" is PARTLY FALSE (key is gitignored →
│       does not travel → re-auth per machine anyway; and re-auth per repo for same project)
│     - gcloud assumed available for minting
├── Missing pieces
│     - no "declare binding WITHOUT minting a key" path (config init/link) — needed by the
│       repo AUTHOR and by teams; today everything is bundled into `config use` (which mints)
│     - non-TTY/CI production-confirm behavior underspecified (hang? fail?)
│     - key rotation / expiry story absent (ok to defer, note it)
│     - what deploy SOURCE (zip/dir) — config.json could declare output dir/build
├── Internal consistency
│     - 5.1 writes config.json but old blanket `.netlaunch/` ignore would hide it until §7
│       migration runs → ordering bug on first commit
│     - CI recipe uses --target but simple schema has no targets (example mismatch)
│     - version:1 present but no unknown-version handling
└── Wild cards
      - `netlaunch status/doctor` → explain resolution ("why project X?")
      - config.json as seed for server-side repo→project map / dashboard
      - mismatch guard gives free drift detection (emergent win)
```

## Deep Dives → Resolutions (folded into SPEC v2)
1. **Walk-up footgun** → bound discovery to **git root**. Honor config.json only at/below the
   dir containing `.git`; outside a git repo only `./.netlaunch/` in cwd; never cross $HOME/root.
2. **.gitignore loaded gun** → **negation, never rewrite**. Blanket `.netlaunch/` gets
   `!.netlaunch/config.json`; key stays ignored. `git check-ignore` post-check warns if still
   hidden. Never delete a user's ignore pattern.
3. **"Portable key" assumption (was partly false)** → keep repo-local key as source of truth,
   add **global key cache** `~/.netlaunch/projects/<id>.json`; offer reuse when a repo lacks a
   key. Removes re-auth tax for same-project-many-repos without reversing the locked decision.
4. **Missing declare-only path** → new **`netlaunch link <project>`** writes config.json only
   (no gcloud/key). `config use` = link + mint.
5. **CI/prod confirm** → confirmation matrix; non-TTY + production + no `--yes` = HARD FAIL.
6. **Schema ambiguity** → `targets{}` wins over top-level; unknown `version` errors; CI examples
   made consistent; writer strips secret fields.

## Discussion Log
- Adversarial review of `cli/SPEC-per-repo-projects.md` v1.
- Found 2 red footguns (walk-up, gitignore), 3 yellow gaps (link cmd, CI/prod, schema), and a
  quietly-wrong assumption (repo-local key is not actually portable; re-auth tax).
- User chose: deep-dive all + revise spec.
- **Produced SPEC v2** with all fixes; changelog at top of the spec.

## Synthesis
### Key Insights
- Two of the scariest fixes (walk-up, gitignore) became simpler than expected: bound to git
  root; use ignore-negation instead of rewriting. Safety via narrowing, not editing.
- The repo-local decision was right for self-containment but mis-sold as "portable." Reframed:
  repo-local = authoritative, global = cache. Best of both.
- Separating **declare-binding (`link`)** from **mint-key (`config use`)** is the unlock for
  authors, teammates, and CI — the original spec conflated them.

### Decision Points (all resolved in v2)
- Discovery boundary = git root. ✓
- gitignore strategy = negation + check-ignore warn. ✓
- key model = repo-local authoritative + global cache. ✓
- new `link` command. ✓
- CI/prod = hard-fail without --yes. ✓
- schema precedence + version guard. ✓

### Next Steps
1. Implement in checklist order (SPEC §10); start with `findGitRoot()`+discovery and the
   gitignore negation routine (foundation + safety).
2. Then `config.json` read/write + `link`, then key lookup w/ cache, then deploy banner/guard.
3. README updates + a migration note for existing `.netlaunch/` users.
4. (Deferred, SPEC §11) key rotation, build/output in config, dashboard sync.
