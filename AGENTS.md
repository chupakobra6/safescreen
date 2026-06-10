# AGENTS.md

## Project Overview
- SafeScreen is a macOS privacy-first presentation tool.
- The product creates a controlled shareable output where allowed windows are visible and private
  content is excluded from the transmitted pixels.
- The project is currently documentation-first. Do not invent build commands before code exists.

## Product Boundary
- SafeScreen controls the selected output stream or virtual display. It does not claim to hide the
  real Mac state from local software with Screen Recording, Accessibility, MDM, or root-level access.
- Activity Monitor/process hiding is out of scope.
- Browser companion work must be transparent diagnostics, compatibility checks, and user-facing
  warnings. Do not implement browser event spoofing, proctoring bypass, deceptive process masking,
  injection into call apps, private API hacks, SIP bypass, or kernel tampering.
- DriverKit/System Extension work is allowed only when it uses documented Apple APIs, explicit user
  approval, proper signing, and a documented rollback path.

## Source of Truth
- Three-stage roadmap: `docs/stages.md`
- Architecture: `docs/architecture.md`
- Browser benchmark plan: `docs/browser-benchmark.md`
- Development workflow: `docs/development-process.md`
- Research references: `docs/research-sources.md`

## Working Rules
- Start non-trivial implementation work with a short plan and touched-file list.
- Keep changes small and milestone-shaped.
- Update documentation when behavior, scope, validation, or product boundaries change.
- Do not add backwards-compatibility aliases, alternate env/profile names, shims, or fallback paths
  unless explicitly requested.
- Do not add dependencies or choose a build stack until the implementation milestone requires it.
- Prefer observable validation: screenshots, recordings, browser harness logs, and command output.
- Do not claim "no leaks" without a captured output artifact or a reproducible validation command.

## Commands
- Current repo has documentation only.
- Inspect files: `find . -maxdepth 2 -type f | sort`
- Check git status: `git status --short`

Add real build/test commands here in the same commit that introduces the corresponding code.
