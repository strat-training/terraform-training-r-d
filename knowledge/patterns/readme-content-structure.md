# Pattern: Training Course README Structure

Use this pattern for a **self-paced, module-based training course repository**
(a bootcamp, curriculum, or workshop series built around progressive modules
and a capstone/final deliverable) — as opposed to
`project-documentation-template.md`, which documents a single delivered
software/data project.

The README is the trainee's front door and, in most courses, the **only**
file that names every other trainee-visible file. It must stand alone: a
trainee who has cloned the repo and opened nothing else should be able to
start from it with no other context.

```markdown
# [Course Name]: [One-line description of what the trainee builds]

[1-2 sentences: duration, format (self-paced/instructor-led), module count,
what the trainee builds by the end, where/how it runs, and the hard
constraint that matters most — a time box, an environment limit, a scope
boundary. State any cost/budget figure as guidance for sizing choices, not
as a guaranteed total (see Rules).]

## Project Overview

### [Subsection: what gets built — system/domain architecture]
- **[Component/tier]**: [what it is, key technology]
- **[Component/tier]**: [what it is, key technology]

### Expected Output _(or "Expected Infrastructure", "Expected Deliverable" —
name it after what the course actually produces)_

[One sentence framing what "done" looks like, and what persists between
sessions vs. what gets torn down/reset, if that distinction applies.]

```[mermaid or text — pick one diagram language and keep it simple]
[A single diagram of the end state. One diagram, not a wall of detail —
link out to a deeper doc for the full picture.]
```

[One-line pointer to a deeper architecture/requirements doc, with an anchor:
"The full [code map / component wiring / more diagrams] are in
[Deliverable requirements](./path#anchor)."]

### [Subsection: technical approach — the patterns/stack this course teaches]
- [Bullet: a notable technical decision or pattern taught, not exhaustive —
  just what a skimming reader needs before diving in]

## Quick Start

1. **Prerequisites**
   - [Tools + minimum versions]
   - [Accounts/access needed, and which module first requires each one]
   - [Any OS/shell notes]
   ```bash
   [verification commands the trainee runs before starting]
   ```

2. **Start the course**
   - Open [Module 1](link-to-first-module). Every module has: [the fixed
     shape every module follows in this course — e.g. lecture, guided lab,
     solved exercise, unsolved next-steps, self-assessed checkpoint].
   - [The one repeating rhythm/habit worth stating up front, if the course
     has one — e.g. a build→verify→reset loop.]

3. **Finish with [the capstone / final deliverable]**
   - Read [the capstone doc](link): requirements, validation steps, and
     grading, in one place.
   - [Where the supporting/reference material for it lives.]
   - [How the final deliverable is demonstrated or submitted.]

## Project Structure

```text
.
├── [trainee-visible folder]/      # [one-line purpose]
│   ├── [file]                       # [one-line: what it covers]
│   └── ...
└── [trainee-visible folder]/      # [one-line purpose]
```

[One line on where the trainee's own work-in-progress goes, if it is not
committed back into this repo.]

## Implementation Requirements

[The full numbered requirement list lives in the capstone/deliverable doc —
link to it here. This section gives only the grouped summary a skimming
reader needs, organized to match the module groupings above.]

The [capstone/deliverable] has [N] requirements[, M of which must also be
shown **failing correctly**, if the course grades failure handling]. The
full list is in [Deliverable requirements](link#anchor).

### 1. [Phase name] (Modules X–Y) — Req. [n, n, n]
- [1–2 line summary of what this phase covers]

_(One heading per phase, matching the module groupings in Project Structure
and Timeline.)_

## Documentation

- [Link to Module 1] - [why a reader starts here]
- [Link to a standout module] - [what makes it worth calling out, e.g. "what
  a correct run looks like, stage by stage"]
- [Link to the capstone/deliverable doc] - [what's in it]
- [Link to the reference/data folder] - [what's in it]

## Timeline

### [Week/Phase 1]: [Theme]
- [Session]: [Module] — [one-line topic]
- [Session]: [Module] — [one-line topic]

_(Repeat per week/phase. Keep to session-level granularity — hour-by-hour
detail belongs inside each module file, not here.)_

## Evaluation Criteria

_(Delete this whole section if the course is ungraded.)_

The [capstone/deliverable] uses a **weighted** rubric: [Criterion] **X%**,
[Criterion] **Y%**, [Criterion] **Z%**. [Any pass/fail gate that sits on top
of the score, e.g. a documentation gate.]

### [Lowest passing tier] ([range]%)
- [What's still missing or breaks at this level]

### [Target tier] ([range]%) — the target
- [What "meets expectations" looks like, concretely]

### [Top tier] ([range]%)
- [What goes beyond the baseline]

Hard caps, whatever the score:
- [condition] caps [criterion] at [value];
- [condition] caps [criterion] at [value].

## Optional Features

These don't add bonus points; they're the kind of work that earns
**[top tier]** scores.

1. **[Category]**
   - [Stretch task, phrased as an outcome, not a solution]

## Support

Need help?
1. [First self-serve step — usually "re-read the relevant module/lab"]
2. [Second step — how to correctly read an error/output]
3. [Third step — a sanity check specific to this course, e.g. confirming
   nothing is still running/billing/consuming a shared resource]
4. Official documentation:
   - [Link]
   - [Link]
```

## Section Definitions (Reusable Format)

- **Title + intro paragraph:** must work with zero other context. State
  format, duration, module count, the end deliverable, and the one
  constraint most likely to trip someone up. Never state a cost or time
  budget as a guaranteed cap here — see Rules.
- **Project Overview:** the "what," split into what gets built (component
  list) and what it looks like running (one diagram). Keep the diagram to
  the end-state system only; anything more detailed (a code map, a wiring
  diagram, a sequence) belongs in the capstone/deliverable doc, linked with
  an anchor.
- **Quick Start:** always three moves — get ready, start, finish — even if
  a course has no capstone (drop move 3 and rename move 2 to "Work through
  the course"). Every command shown must be copy-pasteable and, where
  possible, followed by a way to verify it worked.
- **Project Structure:** a file tree of the trainee-visible surface only.
  This is the one section most likely to leak internal paths — see Rules.
- **Implementation Requirements:** a *summary* only. If the full numbered
  list is duplicated here as well as in the capstone doc, the two will
  drift the moment either one is edited — link, don't copy.
- **Timeline:** session-level, not hour-level. It exists so a trainee can
  gut-check their pace, not so they can skip reading a module's own time
  estimate.
- **Evaluation Criteria / Optional Features:** only present if the course
  is graded. A rubric tier's bullets should be observable facts ("all N
  requirements met," "failure proofs fail with the expected message"), not
  restatements of effort ("tried hard").
- **Support:** self-serve steps first, official links last. Never make the
  first step "ask the instructor" — that's the fallback, not the opener.

## Rules

- **List only trainee-visible paths in Project Structure, Quick Start, and
  Documentation.** Never name an instructor-only, author-only, or internal
  design folder (a grading rubric, an instructor's solution, ADRs, a
  `knowledge/` directory) anywhere in the README — trainees have access to
  the README and the folders it points to, and nothing else. Confirm this
  by checking each linked path is one you'd hand a trainee the whole repo
  for.
- **One diagram in the Overview, not a gallery.** A single simple diagram
  of the end state earns its place at the top; a code map, a module-wiring
  diagram, or a sequence diagram belongs in the deliverable doc, referenced
  by an anchor link (`[Deliverable requirements](./path.md#architecture)`).
  Piling multiple diagrams into the README turns the front door into the
  reference manual.
- **State cost, time, or resource figures as sizing guidance, not
  guarantees.** A course whose README promises "under $X total" or "exactly
  N hours" is making a claim about someone else's environment, pricing
  changes, and pace — none of which the course controls. Say what the
  figure is *for* instead: "sized to keep [resource] minimal," "about N
  hours as a guide for planning your week." Per-module or per-task cost/time
  estimates are fine as *estimates* — the rule is about turning an estimate
  into an unqualified promise.
- **Every link must resolve inside the trainee-visible surface.** Before
  publishing, open every link in Quick Start, Documentation, and Support
  and confirm the target file and anchor both exist — a heading rename
  anywhere in the linked file silently breaks an anchor link without
  erroring.
- **Link syntax:** always inline links, `[Label](url)`. Never bare
  reference-definition syntax (`[Label]: url`) — see
  `module-content-structure.md` for why it silently fails to render when
  used standalone.
- **Never duplicate a full requirement list, rubric, or timeline detail
  that already lives in another trainee-facing doc.** Summarize and link.
  Two copies of the same list drift the first time one of them is edited.
- **File name and location:** `README.md`, capitalized, at the repository
  root. Never nested, never a different case.
