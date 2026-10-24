# pstack model configuration

Per-role model overrides for pstack skills. Each pstack SKILL.md names its defaults in a Models section; the values here override those defaults. Delete a line to fall back to the skill default. A value of `inherit-parent` or `auto` runs that role on the parent session's model (the `Agent` call omits `model`); an alias entry in a panel list still counts toward that panel's fan-out. A model may carry a reasoning effort, as in `opus @xhigh` (levels: low, medium, high, xhigh, max); the role's subagent then runs at that level, each entry of a panel list on its own. `default effort` sets the level for a value without one; `session` keeps the parent session's effort. `session hook: off` stops the Claude Code, Codex, or Muse SessionStart hook, or the pstack Pi extension, from injecting the poteto-mode mandate; any other value, or no line, leaves it on.

feature, refactoring: sonnet
bug-fix: opus
perf-issue: opus
hillclimb: opus
judgment and prose: opus
strongest judgment: fable
how explorer: opus
how explainer: opus
why investigators: opus
why synthesizer: opus
reflect tooling: opus
reflect judgment, divergent, synthesizer: opus
arena runners: opus, fable, sonnet, xai/grok-4.7
arena cross-judge pool: opus, fable, sonnet, xai/grok-4.7
swarm workers: opus
architect runners: opus, fable, sonnet, xai/grok-4.7
interrogate reviewers: opus, fable, sonnet, xai/grok-4.7

default effort: session
session hook: on
pi models: opus=claude-code/claude-opus-5-5, fable=claude-code/claude-fable-5-1, sonnet=claude-code/claude-sonnet-5-5, haiku=claude-code/claude-haiku-5-5
