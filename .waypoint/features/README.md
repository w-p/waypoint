# Features

This directory is empty on purpose — in this repository, not in general.

In a project using Waypoint, `features/` holds the as-built record: one document per shipped
capability, written when it ships and kept current as the capability changes. It is not the
design record. A design in `design/` is a decision, frozen at the moment it was approved; a
feature doc describes what exists now. One design can produce several features, and a
long-lived feature can accumulate several designs. They own different facts — rationale
versus current state — so keeping both is not duplication.

This repository is the exception: Waypoint's product is its shipped artifacts — the
templates, skills, adapters, installer, and README. The as-built record of every capability
*is* the artifact itself, and a feature doc here could only restate it, which the
single-sourcing duty (OPORD §3d) forbids. How each capability came to be lives in `design/`,
`memory/`, and `CHANGELOG.md`.
