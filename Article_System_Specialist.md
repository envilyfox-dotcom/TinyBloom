# Doctor-Reviewed Pregnancy Education App — Build Specification

## 1. Overview

A mobile app where doctors publish educational content related to pregnancy (pre-conception, during pregnancy, and postpartum). Before publishing, content must pass a two-approval peer review process performed by doctors in relevant specialty groups, ensuring medical accuracy without requiring every specialty to have a large reviewer pool.

---

## 2. Specialties and Review Groups

Doctors are assigned exactly one primary specialty on signup. Specialties are clustered into 5 review groups. Grouping is many-to-many at the schema level (a specialty maps to one primary group, but the mapping table should support future changes without a schema rewrite).

| Group ID | Group Name | Member Specialties |
|---|---|---|
| 1 | Core Obstetric & Birth Care | OB/GYN, Maternal-Fetal Medicine (Perinatologist), Midwife (CNM), Anesthesiologist |
| 2 | Fertility & Genetics | Reproductive Endocrinologist (REI), Genetic Counselor, Urologist/Andrologist |
| 3 | Medical Complications in Pregnancy | Endocrinologist, Cardiologist, Nephrologist, Hematologist |
| 4 | Newborn & Pediatric Care | Neonatologist, Pediatrician |
| 5 | Postpartum Recovery & Allied Health | Psychiatrist/Psychologist (perinatal), Pelvic Floor PT, Lactation Consultant (IBCLC), Dietitian/Nutritionist |

### Secondary group mapping (fallback reviewer pool)

Each group has one or more secondary groups. Secondary reviewers have equal approve/reject authority to primary reviewers **but only for the second approval slot** — never the first.

| Primary group | Secondary group(s) |
|---|---|
| 1. Core Obstetric & Birth Care | 3, 5 |
| 2. Fertility & Genetics | 1 |
| 3. Medical Complications | 1 |
| 4. Newborn & Pediatric Care | 1, 5 |
| 5. Postpartum Recovery | 1, 3 |

Content is tagged with exactly one primary group (based on topic) at submission. The system derives the eligible secondary group(s) automatically from the table above — do not let authors pick secondary manually.

---

## 3. Review & Approval Flow

### 3.1 States

`draft → pending_approval_1 → pending_approval_2 → publish_buffer → live`
Side states: `changes_requested`, `emergency_pending`

### 3.2 Approval 1 (Primary only)

- Reviewer pool: any doctor in the content's primary group, excluding the author.
- Requires exactly 1 approval to advance.
- Reviewer can: approve, or reject with a required category (`clinical` or `non_clinical`) and a written reason.
- On reject: state → `changes_requested`. Author edits and resubmits, which returns to `pending_approval_1`.

### 3.3 Approval 2 (Primary or Secondary)

- Triggered automatically once approval 1 is granted.
- Reviewer pool: any doctor in the primary group OR the mapped secondary group(s), excluding the author and excluding the reviewer who gave approval 1 (`reviewer_2_id != reviewer_1_id`, enforced at the database level).
- Requires exactly 1 approval to advance.
- Reviewer can approve or reject with the same category + reason requirement as approval 1.
- **Reject logic (reset scope):**
  - `clinical` reject → full reset. State returns to `pending_approval_1`. Approval 1 is voided; a new reviewer must approve again.
  - `non_clinical` reject → partial reset. Only approval 2 resets. Approval 1 is preserved (does not need to be redone). Author edits, then it returns straight to `pending_approval_2`.

### 3.4 Publish buffer

- Once 2/2 approvals are granted, state → `publish_buffer` for 24 hours.
- During this window, content is visible to author + primary group + secondary group only (same visibility as approval 2). It is NOT visible on the public Article tab yet.
- After 24 hours with no emergency pending trigger, state auto-advances to `live`.

### 3.5 Emergency pending (recall during buffer)

- Available only during `publish_buffer`.
- Eligible clickers: any doctor in the primary or secondary group for that content (same pool as approval 2), excluding no one (author cannot trigger this).
- Requires **2 clicks from 2 different specialists** (`click_1_user_id != click_2_user_id`, enforced at the database level).
- Each click requires a mandatory written reason and a category (`clinical` / `non_clinical`).
- On 2nd click confirmed:
  - `clinical` category → full reset to `pending_approval_1`
  - `non_clinical` category → partial reset to `pending_approval_2`
  - Buffer countdown pauses/cancels immediately on the 1st click (content is flagged "under review" but stays out of public view until resolved).
- If only 1 click is received before the 24-hour buffer expires, the click is discarded and content publishes normally (no partial lockout from a single click).

### 3.6 Live / public state

- Article tab becomes visible only once state = `live`.
- The Review tab (specialist-only thread) persists after publishing — historical record, and available for future flagging.
- A future "notify specialists" button on public comments will trigger a lightweight version of the approval-2 flow (visible to author + primary + secondary), treated as non-critical by default. Not required for MVP; design the comment schema so this can be added without migration pain (e.g. a `flagged_from_comment_id` nullable field on the review thread).

---

## 4. Comment / Thread System

Two entirely separate systems — do not merge them in the schema or UI.

### 4.1 Specialist Review Thread (Review tab)

- Scope: visible only to the author + members of the primary group + members of the secondary group tied to that specific content item. No one outside those groups can see or access this thread, at any state, including after publishing.
- Contains: approval/reject actions, edit suggestions, clarification replies, and emergency pending click reasons.
- Nothing is hidden between primary and secondary members once the content enters approval 2 — full transparency within that scope.
- Persists indefinitely, including post-publish.
- Any member of the primary/secondary group can reply/comment at any time (non-blocking), but only the two assigned reviewers can approve/reject at each stage.

### 4.2 Public Comments (Article tab)

- Scope: visible to all app users once content is `live`.
- Standard reader comments — no approval authority, no connection to the review pipeline by default.
- Article tab does not exist/render until content reaches `live` state.

---

## 5. Roles & Permissions Summary

| Action | Author | Primary group member | Secondary group member | Other doctors |
|---|---|---|---|---|
| View Review thread | Yes | Yes | Yes (once approval 2 opens) | No |
| Approve/reject (approval 1) | No | Yes | No | No |
| Approve/reject (approval 2) | No | Yes | Yes | No |
| Comment in Review thread | Yes | Yes | Yes | No |
| Trigger emergency pending | No | Yes | Yes | No |
| View Article tab (public) | Yes | Yes | Yes | Yes (once live) |
| Comment on Article tab | Yes | Yes | Yes | Yes (once live) |

---

## 6. Data Model (suggested)

```
specialties
  id, name

review_groups
  id, name

specialty_group_map
  specialty_id (FK), group_id (FK)   -- many-to-many, supports future re-grouping

group_secondary_map
  primary_group_id (FK), secondary_group_id (FK)  -- many-to-many

doctors
  id, name, specialty_id (FK), verified_at

content
  id, author_id (FK doctors), title, body, primary_group_id (FK),
  state (enum: draft, pending_approval_1, pending_approval_2, publish_buffer,
         changes_requested, emergency_pending, live),
  buffer_started_at, published_at

approvals
  id, content_id (FK), stage (1 or 2), reviewer_id (FK doctors),
  decision (approve / reject), reject_category (clinical / non_clinical / null),
  reason (text, nullable unless reject), created_at

emergency_pending_clicks
  id, content_id (FK), clicker_id (FK doctors), reason (text, required),
  category (clinical / non_clinical), created_at

review_comments
  id, content_id (FK), author_id (FK doctors), body, created_at,
  parent_comment_id (nullable, for threaded replies)

public_comments
  id, content_id (FK), user_id (FK app users), body, created_at
```

---

## 7. Key Business Rules to Enforce at the Backend (not just UI)

1. `reviewer_2_id != reviewer_1_id` for every approval pair.
2. `emergency_pending click_1.user_id != click_2.user_id`.
3. Approval 2 reviewer pool = primary group ∪ mapped secondary group(s), excluding author and reviewer 1.
4. Approval 1 reviewer pool = primary group only, excluding author.
5. Article tab query must filter `state = live` — never expose pre-live content via a public endpoint, even if the ID is guessed.
6. Review thread visibility query must always filter by `content.primary_group_id` and its mapped secondary group(s) against the requesting doctor's `specialty_id` → `group_id` — never by name-matching specialty strings.
7. Reject without a category + reason should be rejected by the API (validation error), not allowed as an empty reject.
8. `publish_buffer` state transition to `live` should be a scheduled job (24h after entering buffer), cancellable only by the emergency pending 2-click flow.

---

## 8. Suggested MVP Build Order

1. Specialty → group mapping tables (seed with the 16 specialties / 5 groups above), hooked into the existing verified doctor profile system.
2. Content submission + primary group auto-tagging.
3. Approval 1 flow (primary-only reviewer pool, approve/reject with category).
4. Approval 2 flow (primary + secondary pool, different-reviewer enforcement).
5. Review thread (comments, scoped visibility).
6. Publish buffer + scheduled auto-publish job.
7. Emergency pending (2-click, reasons, reset logic).
8. Article tab (public view) + public comments.
9. "Notify specialists" button linking public comments to the review thread, built on top of the existing `dashboard_screen.dart` notification system.

---

## 9. Already Resolved / Existing Systems to Reuse

- **Doctor verification:** Already implemented and live. Do not build a new verification flow — new specialty/group assignment should hook into the existing verified-doctor record.
- **"Notify specialists" escalation (public comment → review thread):** Do not build a new notification system. Reference and extend the existing in-app notification system in `dashboard_screen.dart`, which already has a working table design suited for this. The "notify specialists" button on a public comment should:
  - Create a `review_comments` entry linked to the flagged public comment (`flagged_from_comment_id`)
  - Fire a notification via the existing `dashboard_screen.dart` system to the primary + secondary group members for that content
  - Treated as non-critical/informational by default — same visibility scope as approval 2 (author + primary + secondary), no separate permission model needed

---

## 10. Volunteer Role (separate subsystem — do not merge with Specialist review groups)

Volunteers are a distinct, lower-stakes role: ex-specialists or experienced non-specialists who offer chat-based support only (no video call, no in-person consultation, no content review authority). This system is intentionally simpler than the Specialist review system above and must not be built using the 5 review groups or their primary/secondary logic.

### 10.1 Key differences from Specialist

| | Specialist | Volunteer |
|---|---|---|
| Tagging | Single primary specialty → mapped to 1 of 5 clinical review groups | Multiple free-select "area of expertise" tags, no groups |
| Purpose of tagging | Determines who can approve/reject content in the review pipeline | Helps users filter/search for a relevant chat partner |
| Cross-topic flexibility | Strict — only primary or mapped secondary group involvement | Loose — one volunteer can hold several unrelated tags |
| Capabilities | Video call, in-person consultation, content review (approve/reject) | Chat only |
| Verification | Full license verification (existing system, reused) | Documentation/proof required, but lighter weight — no clinical review authority granted regardless of verification |
| Content review pipeline access | Yes (per group assignment) | No — Volunteers never appear in any approval_1 / approval_2 / emergency_pending reviewer pool |

### 10.2 Area of Expertise (Volunteer)

Multi-select, flat tag list — no grouping, no primary/secondary structure:

- Preconception & fertility support
- Pregnancy (general / trimester-specific)
- High-risk pregnancy experience
- Postpartum recovery
- Breastfeeding & feeding support
- Mental health & emotional support
- Loss & grief support (miscarriage, stillbirth)
- Nutrition & lifestyle

### 10.3 Data model addition

```
volunteers
  id, name, verified_at, proof_document_url

volunteer_expertise_tags
  id, name   -- flat list, seed with the 8 tags above

volunteer_tag_map
  volunteer_id (FK), tag_id (FK)   -- many-to-many, multi-select
```

### 10.4 Backend rule

Any query or permission check for `approval_1`, `approval_2`, or `emergency_pending` reviewer pools must explicitly exclude the `volunteers` table — Volunteers should never be eligible reviewers under any circumstance, regardless of their expertise tags.
