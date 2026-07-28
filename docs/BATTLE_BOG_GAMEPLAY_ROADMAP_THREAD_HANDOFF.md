# Battle Bog Gameplay Roadmap Thread Handoff

Status: paste-ready prompt for a separate implementation task

Compiled: 2026-07-28

```text
You are continuing Battle Bog gameplay and PvAI implementation in:

C:\Users\fishe\Documents\hitmasters

This task owns the non-visual roster-completion roadmap. A separate task owns
visual reference mining, look exploration and visual-direction selection.
Do not absorb the visual mine into this task and do not begin production art
migration before the roadmap's visual-production gate permits it.

The annotated planning checkpoint is:

- tag: battle-bog-roster-plan-v2
- commit: 5eb65419b10091fa4c75dee49bd5fa557acc701d

Work from the current shared `master` only when that checkpoint is its
ancestor. Later documentation-only visual commits are allowed. Do not detach
or reset to the tag when the current branch already contains it.

Before changing files:

1. Verify the checkout is the intended repository.
2. Run:
   git status --short --branch
   git rev-parse HEAD
   git rev-parse origin/master
   git show-ref --tags battle-bog-roster-plan-v2
   git rev-list -n 1 battle-bog-roster-plan-v2
   git merge-base --is-ancestor battle-bog-roster-plan-v2 HEAD
3. Stop on an unexpected dirty worktree. Do not stash, reset, overwrite or
   incorporate unknown changes.
4. Read these files in this authority order:
   - docs/BATTLE_BOG_DECISIONS.md
   - docs/BATTLE_BOG_WEAK_MODEL_EXECUTION_RUNBOOK.md
   - docs/BATTLE_BOG_ROSTER_WIDE_CHARACTER_COMPLETION_ROADMAP.md
   - docs/BATTLE_BOG_DAMAGING_ACTION_INVENTORY.md
   - every phase-specific authority document named by the active packet
5. Treat the runbook as the operational contract and the roster roadmap as the
   phase/dependency contract.

Initial objective:

Execute the exact queue beginning at R0.5. Do not skip to production visuals,
roster-wide animation, or multiplayer. The gameplay path must first complete
the locked PvAI exit gate and later gameplay-content freeze.

Execution rules:

- Work one phase packet at a time.
- Use subagents for independent bounded tasks and verification whenever useful.
- Give writing agents disjoint files or separate worktrees.
- Keep one integration owner for shared files, canonical tests, staging and
  commits.
- Do not let a subagent change locked decisions or invent missing contracts.
- Follow every packet's preconditions, owned files, exact commands, artifacts,
  promotion record, failure routing and recovery scope.
- Run focused tests during implementation and the required canonical suite at
  each checkpoint.
- Preserve immutable evidence under the packet's run-specific artifact root.
- Never call a phase complete from compile success or state tests when the
  packet requires raster, video, performance or human evidence.
- Stop and report the exact contract conflict when the runbook says human input
  is required. Continue unaffected parallel jobs when permitted.
- Commit only files owned by the completed packet.
- Push reviewed checkpoints to the current branch only after confirming the
  intended remote and branch.

Thread boundary:

- This task may implement simulation, AI, PvAI, action contracts, deterministic
  fixtures, gameplay evidence, and runtime presentation substrate when its
  active phase owns them.
- The visual task may independently research references and generate
  non-shipping look studies.
- Do not select a final visual pipeline from concept images.
- Do not import generated production assets or migrate the renderer until the
  selected visual direction and the Alligator/Kingfisher/Mosquito gates are
  handed back through the documented roadmap.

At the start, report:

- verified HEAD, branch, remote and worktree state;
- the first executable phase;
- its exact dependencies, write set, commands and pass criteria;
- any user decision that is already open but does not block the first phase.

Then proceed with implementation rather than stopping at a restated plan.
```
