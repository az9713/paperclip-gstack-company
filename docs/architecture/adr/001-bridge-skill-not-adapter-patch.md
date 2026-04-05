# ADR 001: Use Bridge Skill (Prompt Layer) Rather Than Adapter-Level AskUserQuestion Interception

**Status:** Accepted
**Date:** 2026-04-04
**Deciders:** Engineering Company template authors

---

## Context

gstack skills are designed for interactive use with Claude Code. At judgment-call moments, they call `AskUserQuestion` — a Claude Code tool that presents a question to the human in the terminal and waits for a response before continuing.

Paperclip runs agents headlessly: `claude --print - --output-format stream-json --verbose --dangerously-skip-permissions`. There is no human at the terminal. When an agent calls `AskUserQuestion` in this mode, one of two failure modes occurs:

1. The call blocks indefinitely waiting for stdin input that never comes, eventually timing out
2. The call fails immediately with a tool-unavailable error, aborting the skill mid-workflow

This mismatch needed to be resolved for gstack skills to function inside Paperclip.

---

## Alternatives Considered

### Alternative A: Bridge Skill (prompt-layer translation) — Selected

Create a custom `gstack-bridge` skill that teaches agents, via prompt instructions, to replace `AskUserQuestion` with the Paperclip approval protocol. The skill defines:

- Which checkpoints to auto-decide mechanically (no human interaction needed)
- Which checkpoints to escalate as Paperclip approvals (human decision via UI)
- The exact API calls to make for each approval step
- The resume protocol when woken after approval resolution

The bridge skill is mounted for every agent alongside their gstack skills. No changes to gstack or Paperclip are required.

**Pros:**
- Zero coupling — gstack and Paperclip remain independent, unmodified codebases
- Pure prompt engineering — the integration is entirely in Markdown
- Forkable — anyone can create their own bridge skill with different checkpoint policies
- Testable — the behavior is visible in the prompt and auditable in issue comments
- Upgradeable — updating the bridge skill does not require updating gstack or Paperclip

**Cons:**
- Relies on the model following instructions correctly — if Claude ignores the bridge skill rules, it could call `AskUserQuestion` anyway
- No hard enforcement — there is no mechanism that prevents `AskUserQuestion` from being called; it is only prevented by the model following the prompt
- Complexity is in the prompt, not in code — harder to unit test

### Alternative B: Modify gstack SKILL.md Templates

Add Paperclip-specific conditional logic to every gstack skill template. When `PAPERCLIP_AGENT_ID` is set, skip `AskUserQuestion` and use approval API calls instead.

**Pros:**
- Logic is colocated with the workflow that uses it
- Could be more reliable if each skill handles its own checkpoints explicitly

**Cons:**
- Couples gstack to Paperclip. gstack is an independent open-source project used by many people who do not use Paperclip
- Every new gstack skill or checkpoint would need Paperclip-aware code
- Breaks the separation of concerns: gstack defines workflows, Paperclip defines orchestration
- Would require forking gstack or contributing Paperclip-specific code upstream (inappropriate for an independent tool)
- Harder to update: adding a new Paperclip feature could require updating 25+ skill templates

### Alternative C: Intercept at the Adapter Level

Modify the `claude_local` adapter to intercept `AskUserQuestion` tool calls. When Claude Code emits an `AskUserQuestion` tool call in the JSON stream, the adapter:

1. Parses the question and options from the tool call
2. Creates a Paperclip approval
3. Buffers Claude's context
4. Wakes the agent with the approval answer as synthetic stdin

**Pros:**
- Hard enforcement — `AskUserQuestion` is intercepted regardless of whether Claude follows prompt instructions
- No bridge skill needed — transparent to the model

**Cons:**
- Significantly increases adapter complexity — the adapter must implement full approval lifecycle handling
- `AskUserQuestion` is not a standard Paperclip concept: it is a Claude Code-specific tool, and implementing gstack-specific logic in a general-purpose adapter creates inappropriate coupling
- Context buffering across adapter restarts is fragile
- Does not handle cross-role delegation at all — `/autoplan`'s phase delegation would still require separate handling
- Tight coupling between Paperclip and the specific behavior of a Claude Code tool that could change in future Claude versions

---

## Decision

Use the bridge skill (Alternative A).

The bridge skill is the right integration layer because it lives entirely in the domain of "how agents operate gstack skills in a specific environment." This is exactly what a skill is for: structured instructions that teach an agent how to behave in its operating context.

The alternative approaches violate the independence of the underlying systems. gstack should not contain Paperclip-specific code. The adapter should not contain gstack-specific behavior. The engineering company template is the appropriate place for integration logic, and the bridge skill is the right form for that logic.

---

## Rationale

**Zero coupling** is the strongest argument. gstack and Paperclip each have their own development velocity, communities, and release cycles. Coupling them at the code level creates maintenance burdens that outweigh the reliability benefits of hard enforcement.

**The model instruction-following risk is acceptable.** In practice, Claude consistently follows the bridge skill's rules when they are clearly stated. The bridge skill is short, explicit, and checked by the model at the start of every workflow. The failure mode (agent calls `AskUserQuestion`) is easily detected in run logs and correctable by updating the bridge skill prompt.

**The prompt approach is more observable.** When an agent follows the bridge skill correctly, the evidence is visible in the issue's comment thread (checkpoint questions) and in the approval record. When it does not, the failure is also visible. This observability is harder to achieve with intercepted tool calls or modified templates.

---

## Trade-offs

| Concern | Impact | Mitigation |
|---------|--------|-----------|
| Model may not follow bridge skill instructions | Could call `AskUserQuestion`, fail, abort workflow | Bridge skill is loaded first, explicitly requires reading before any gstack skill; tested in practice |
| No hard enforcement | Cannot guarantee `AskUserQuestion` never fires | Acceptable — failure is detectable and correctable |
| Bridge skill must be updated when gstack adds new checkpoints | Maintenance cost | Bridge skill's checkpoint-map.md is a reference document that makes updates straightforward |
| Cross-role delegation not obvious from gstack skills | Could be missed by a reader of gstack skills alone | Documentation (this codebase's docs) explains the Paperclip-specific behavior |

---

## Consequences

- The bridge skill (`companies/engineering/skills/gstack-bridge/`) is the authoritative source for how agents handle checkpoints and delegation in Paperclip mode
- All agent skill lists must include `gstack-bridge` as the first skill (ensuring it is read before any gstack skill)
- When gstack adds a new skill with new checkpoints, the bridge skill's `references/checkpoint-map.md` must be updated
- Changes to the checkpoint handling policy are made in the bridge skill, not in gstack or the Paperclip adapter
- The `gstack_checkpoint` approval type is registered in Paperclip's constants (`paperclip/packages/shared/src/constants.ts`) to support the bridge skill's approval API calls
