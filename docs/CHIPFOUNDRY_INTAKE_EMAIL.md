# ChipFoundry / chipIgnite submission intake email (draft)

Use this as a copy/paste template to get the **minimum actionable facts** for a CI2605-style shuttle submission.

> Goal: avoid setting up the wrong flow (OpenMPW vs ChipFoundry-specific), and lock the shuttle record in `docs/SHUTTLE_LOCK_RECORD.md`.

---

Subject: Request: submission requirements + signoff gates for <SHUTTLE_NAME / CI2605> shuttle (sky130)

Hi <NAME/TEAM>,

We are preparing a small SoC/macro submission for the <SHUTTLE_NAME> shuttle and want to confirm the exact submission requirements so we can run the correct precheck/signoff flow locally.

Could you please confirm/provide the following:

1) **Submission package format**
   - Do you require a specific repository structure, tarball format, or manifest?
   - Are Git tags/releases acceptable as the submission artifact?

2) **PDK + toolchain**
   - Required PDK name/version (e.g., sky130A/sky130B) and where to obtain it
   - Required OpenLane/OpenROAD versions (or required Docker images)

3) **Deliverables / submission type**
   - Are you expecting a **full chip/top-level** submission, or a **macro/block** submission?
   - Required views (GDS/LEF/DEF/Liberty/SPEF/verilog netlist) and which blocks
   - Required reports (DRC/LVS/antenna/timing, etc.)

4) **Top-level/padframe expectations (wrapper compatibility)**
   - Do you provide a padframe/top-level harness, or do we provide a full top-level?
   - We currently have a **Caravel-style user-project wrapper repo** for integration/testing.
     Is a Caravel-style top-level acceptable for this program, or do you require a different wrapper/padframe?
   - IO voltage/ESD/pull requirements; clocking constraints

5) **Precheck / signoff gates**
   - Is there an official “precheck” script/CI equivalent?
   - What are the hard pass/fail criteria before submission is accepted?

6) **Deadlines**
   - Exact cutoff time/date/timezone and any intermediate milestones

If you have an official checklist or portal page for this shuttle, a link would be perfect.

Thanks,
<NAME>
<ORG>
<CONTACT>
