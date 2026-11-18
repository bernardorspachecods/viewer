---
bkf: document
description: "How to decide what a Viewer document holds, what belongs in a code comment, and when a document should be split. The structural rules themselves are in AGENTS.md."
tags: [documentacao, documentation]
---

# Deciding what a document holds

The structural rules (the sentence test as a rule, one owner per topic, docs updated with
the behavior) are in `AGENTS.md`. This module only covers how to apply them.

## Navigation map

| If you need to decide... | Section |
| --- | --- |
| Whether one sentence stays | [Applying the test](#applying-the-test) |
| Whether a fact goes in a comment | [Code comments](#code-comments) |
| How to point at code without going stale | [Pointing to code](#pointing-to-code) |
| Whether a document should be split | [Splitting a document](#splitting-a-document) |
| What to avoid when editing a document | [Traps](#traps) |
| Where decisions and history go | [Decisions and history](#decisions-and-history) |

## Applying the test

Ask whether the sentence would become false if the code changed while the intent stayed
the same. If yes, it describes the code: cut it, or point to the folder that holds it. If
no, it states a rule, a reason, a boundary, or a known gap: keep it.

Before cutting a rule because the code "already says" it, check whether a constraint or a
test guarantees it. If nothing does, keep the rule.

## Code comments

Write a comment where the reason is not visible from the code and a reader changing that
spot needs it: a lock order, a trigger that looks redundant, an accepted limit. Put it at
the mechanism, in a few lines, and state any known limit there. Do not repeat what the
code does, and do not cite line numbers or document sections. If the rule affects
user-visible behavior, the owner document keeps the rule; the comment keeps the mechanism.

## Pointing to code

Point to a folder (`Sources/BPViewerCore/`), not to a function, type, or property. Name a
file only when the rule cannot be understood without it, such as the file that owns a
compatibility key. Lists of files and types describe the code and do not belong in a
document; the member maps already list them.

## Splitting a document

Split only when an agent that opens the document for one task does not need the rest.
Measure with the history before splitting:

- `git log --follow -p -U0 -- <file>` lists the hunks each commit changed. Map each hunk to
  the heading that contains it in that commit's version of the file.
- Sections that rarely change in the same commits can be split. Sections that change
  together stay together.
- A section that other documents only link to, such as a reference table, does not have to
  stay with its neighbours.

## Traps

- Do not write history. Notes on phases, temporary decisions, and migration order belong
  to plans or to git.
- A schema document is not a column dictionary. A list of fields or keys with no rule
  behind it is description of the code; cut it.
- Prefer a stated rule to a description of a mechanism. "Draft previews are not cached"
  stays true when the cache changes; a diagram of the cache does not.
- When a document shrinks, check the anchors and links that point to it and fix those that
  no longer make sense.

## Decisions and history

There is no decision file and no history file. The owner document records the current
state. A decision that still matters is a present-tense rule with its reason. When it is a
prohibition, write it as "do not X, because Y" so that a reader does not undo it by
accident. What only explains how the state was reached belongs to git.
