---
description: Draft and create a YouTrack task in the What / Why / How format
argument-hint: "[project key] [what the task is about]"
---

Create a YouTrack task for: $ARGUMENTS

If that's empty or thin, take the task from what this chat has been working on. If the project key
isn't given and isn't obvious from context, ask me for it.

## Format

**Summary:** one short imperative line, under ~80 chars (e.g. `Add taxonomy GCS notification on supplymonitor inbox`).

**Description:** exactly these three Q/A pairs, plain text, no extra headings:

```
Q. What is this task?
A. <the concrete change, in 1–2 sentences — name the actual resources>

Q. Why are we doing it?
A. <the reason / who needs it, in 1 sentence>

Q. How is it being implemented?
A. <the approach in 1–2 sentences — tool, files or components touched, how it's rolled out>
```

Reference example:

```
Q. What is this task?
A. Add a GCS storage notification on supplymonitor-mediadotnet-inbox so OBJECT_FINALIZE events under curated/supplymonitor/taxonomy/ publish to the mnet-dmp-taxonomy-data Pub/Sub topic, and grant dmp-data-sa roles/storage.objectViewer on the bucket.

Q. Why are we doing it?
A. The DMP taxonomy pipeline needs to be notified of new taxonomy drops and read them, matching the setup on the other inbox buckets.

Q. How is it being implemented?
A. Terraform changes in terraform/mnet/gcp-oregon/storage-notification/main.tf (notification) and terraform/mnet/gcp-oregon/gcs/main.tf (IAM), applied via Atlantis.
```

## Rules

- Be specific (real bucket, service, file names) but brief. No acceptance criteria, step lists,
  code snippets, bullet points, or implementation detail beyond what fits in "How".
- Don't invent facts. If the why or how is unknown, ask me rather than filling it with filler.

## Steps

1. Call `get_issue_fields_schema` for the project and fill the custom fields that are required
   (e.g. Type = Task); ask me if a required field has no obvious value. Always also set:
   - **Stage:** `Incoming`
   - **Priority:** `P2`, unless I say otherwise (in MS the field is named `Priority - SRE`)
   Match the exact field and value names from the schema.
   If the schema call fails or comes back empty, retry it once; if it still fails, stop and tell me.
   Don't copy custom fields from another issue — existing issues carry stale values (Stage
   `Complete`, Sprint Goal `Go Live`, an old Sprint) that are wrong for a new task.
2. Show me the summary, description and custom fields, and wait for my approval.
3. Only then call `create_issue`.
4. Add the issue to the **SRE Incoming** agile board (via the board/sprint field or command
   the schema exposes). If it can't be added with the available tools, tell me instead of skipping silently.
5. Reply with the issue ID and URL.
