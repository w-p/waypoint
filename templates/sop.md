# Standing operating procedures

Rules distilled from lessons. Read every session (OPORD §3a), after the memory step.

Each rule is one or two imperative sentences that say what to do, not what happened. The
story behind a rule stays in the memory file it was promoted from; the citation in
parentheses points there. Add rules under the heading they belong to; add a heading only
when none fits.

## Reporting

- Every result sentence carries its scope: which input, which case, which scale it was
  checked at. Before claiming a goal is met, look at the output the developer judges by
  first and describe what is still wrong there. (baseline 2026-10-12)
- Lead with whether action is needed, then the answer; pick the right answer rather than
  offering a menu. (baseline 2026-10-12)

## Costs and alternatives

- A question about cost, time or risk is answered with whether the cost is necessary
  before its size, then the cheapest path that meets the goal, then the price of the path
  asked about. Before quoting the cost of a remote or automated path, check what is
  already done locally and what the project's existing tools can deliver. (baseline 2026-10-12)
- Cost needs gates like correctness has: before any action that could trigger expensive
  automated work, work out whether it will, and prefer a measurement to an estimate.
  (baseline 2026-10-12)

## Verification

## Documents versus artifacts

- A recorded plan step is a prior decision, not a constraint. When circumstances change
  (work finished elsewhere, a tool that exists, a measurement), re-check it before pricing
  or executing it. (baseline 2026-10-12)

## Cadence on long runs

- Before any step expected to take more than about thirty minutes or cost more than a few
  dollars, one line in the reply: what, why, the alternative rejected, even when proceeding
  without asking. (baseline 2026-10-12)

## Promotion convention

- A memory entry is an observation. It becomes a rule here when it generalizes beyond its
  incident or has recurred. Write the rule in the same turn you notice this, under the
  heading it belongs to, ending with `(promoted YYYY-MM-DD from memory/<file>)`.
- Mark the memory file `promoted: sop.md#<section>` on its second line. Never delete or
  rewrite the memory; it stays in the index as the evidence behind the rule.
- Rules shipped with the framework cite `(baseline YYYY-MM-DD)` instead; their
  observations live elsewhere.
