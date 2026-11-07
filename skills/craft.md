---
name: craft
description: >
  How to shape code so the project stays clean, organized, obvious and reusable: what to
  look for before adding anything, where a value or a helper belongs, when to share and
  when to split, and what to check before closing a task. Use it whenever you write or
  change code.
---

# Skill: Craft

## Purpose

The OPORD's code standards (§3e) say what good code looks like line by line. This skill is
about the decisions above the line: whether the thing you are about to write already
exists, where it belongs, and what the next reader will have to know to find it. Those
decisions are judgment, not rules, so this document explains the reasoning and leaves the
call to you.

The failure it guards against is slow and quiet. No single addition is wrong. A constant
declared beside its first use, a helper copied into a second module, a literal typed where
a named value already exists: each is reasonable in the moment. Over fifty sessions they
add up to a codebase where nobody, human or assistant, can answer "where is this decided?"
without a sweep of the tree. Every later task pays for that.

---

## When to Use

- Writing new code in Execution, or changing code in a debugging fix
- Adding a constant, a configuration value, a helper, a module or a file
- Before closing a task, as the last pass over the change

---

## The questions, in order

### 1. Does this already exist?

Before writing a value, a helper, a type or a name, look for it. Search the tree for the
literal, for the words of the concept, for the shape of the code you are about to write.
Read the module that owns the concept. Look in the layer below yours; shared things tend
to sink. The search takes seconds. A second copy costs everyone after you: two places to
change, two places to drift apart, and a reader who finds one and believes it is the only
one.

If it exists, use it. If it exists somewhere you cannot reach from your layer, moving it is
part of your task, not a diversion from it.

### 2. Who owns this fact?

Every value and every piece of logic has a natural owner: the part of the system that
knows why it is what it is. A request timeout belongs with the networking code. A file name
that a package format defines belongs with that format's definition, and everyone who reads
or writes the package references it there. A device's screen size belongs with that
device's description. The test is the explanation: if you cannot say why a value has its
value without visiting another module, the value is in the wrong module.

Everyone else references the owner. When the same literal appears in two files, one of them
is a copy, and the next person to change one will not know about the other.

### 3. Is this number a requirement?

A literal in the body of a function is a decision hidden from view. When a number is a
requirement, give it a name, record what happens when it is reached or runs out, and keep
it beside the other requirements of its kind, so the whole set can be read in one place and
judged together. "How do these limits fit together?" is a question that gets asked, and the
scattered form makes it unanswerable.

When it is not a requirement, do not invent one. A tuning constant added so it can be
changed later is a value nobody will ever understand well enough to change. If a value is
arbitrary, say so where it is declared.

Values that differ by environment, device or deployment belong in the description of that
environment, one place per environment, never spread through the code behind
conditionals.

### 4. Where would someone look?

A reader should be able to guess the file from the concept. That means a module's name is
the concept it holds, one concept per module, and the project's layout is followed even
when it is inconvenient. When you place something where a reader would not guess, write
down where and why, in the project's design records or at the OPORD's extension point, so
the knowledge outlives your session.

File size is a signal here, not a limit. A file nobody reads whole is where the next
duplicate appears, because the helper that already exists at line 1,900 is invisible from
line 4,000. When a file has grown past what you can hold in mind, look for the concept
boundary inside it and split there. Do not split on line count: a long but cohesive file,
a generated one, a table, is often right as it is.

### 5. Share at the second use

The first time you write something, write it where you need it. The second time you need
it is the moment to move it to the shared layer, not the third: the second copy is where
divergence starts. Move it to the lowest layer that every user can reach, and leave no
copy behind.

Do not share ahead of need. An abstraction built for one caller has to guess at the second
caller's needs and usually guesses wrong. Two real uses show you what the shared form is.

Templates, examples and the first instance of a kind get copied; whatever shape they have
becomes the project's shape. Keep them exemplary. A shortcut in a template is a shortcut in
every file made from it.

### 6. Respect the direction of dependency

The project's layers point one way: lower layers do not know about higher ones,
platform-specific code lives in its marked place, and the rest of the code reaches hardware
or outside services only through the interfaces built for that. Follow the direction that
exists. When a task seems to need the reverse, that is a design question, not something to
solve with a shortcut for now. Shortcuts for now become the architecture.

### 7. Prefer a check to a sentence

When a kind of mistake has happened twice, a sentence in a document will not stop the
third time. A long session forgets prose; it does not forget a failing test. Write the
check: a test that walks the tree and fails on the pattern, a lint rule, a build step. Have
it name the thing it found and the place it should have been, so the fix is obvious.

Keep checks for things that are always wrong. Judgment calls, a file's size for instance,
stay as guidance: a check that fires on reasonable code gets turned off or worked around,
and then it guards nothing.

---

## Before closing

The last pass over a change, before the memory entry:

1. List what you added: constants, values, helpers, names, modules, files. For each, is it
   where someone would look for it?
2. Is anything now defined in two places, including a place you did not write? Fold the
   copies into the owner.
3. Is a literal in a code body a requirement? Name it or justify it where it stands.
4. Did you remove what you replaced: the old path, the experiment, the diagnostic, the dead
   function? Code that is no longer called is still read.
5. Record the shared things you added or moved in this session's memory entry, so the next
   session searches for them instead of writing them again.

---

## Notes

- The project's own standards live at the OPORD's extension point in §3e, and any map of
  where things go belongs in `design/`. Read both before placing anything; add to them when
  you place something that is not obvious.
- None of this is a reason to refactor code the task did not touch. Fix what you found in
  your path, note the rest in memory, and let the developer decide whether a wider pass is
  worth its cost.
