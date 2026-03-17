---
name: document-review
description: |
  Review and improve meeting minutes documents for completeness, clarity, and actionability.
  Adapted from: everyinc/compound-engineering-plugin@document-review (skills.sh)
  Activate when: reviewing meeting minutes, checking minutes quality, validating draft minutes.
  Keywords: document review, 文档审查, minutes review, 会议纪要审查, quality check.
  Do NOT use for: brainstorm refinement, plan document review, code review.
allowed-tools: Read, Write
---

# Meeting Minutes Document Review

Improve meeting minutes documents through structured review focused on completeness, clarity, and actionability.

## Step 1: Get the Document

**If a document path is provided:** Read it, then proceed to Step 2.

**If no document is specified:** Ask which meeting minutes document to review, or look for `draft-minutes.md` or files matching `*-minutes.md` pattern.

---

## Step 2: Assess Meeting Minutes Quality

Read through the minutes document and ask:

### Completeness Questions

- **Metadata**: Are title, date, organizer, and attendees listed?
- **Agenda**: Is the agenda captured with clear item titles?
- **Decisions**: Are all decisions recorded with rationale?
- **Action Items**: Does each action item have owner AND due date?
- **Parking Lot**: Are unresolved items documented?

### Clarity Questions

- Is the summary concise (1-3 sentences)?
- Are decisions stated clearly without vague language?
- Can action items be understood without additional context?
- Are timestamps and dates in consistent format (ISO 8601)?

### Accuracy Questions

- Do the notes align with what was discussed (if transcript provided)?
- Are speaker attributions correct?
- Are there contradictions within the document?

---

## Step 3: Evaluate Against Meeting Minutes Criteria

Score the document against these criteria:

| Criterion | What to Check | Weight |
|-----------|---------------|--------|
| **Metadata Completeness** | Title, date, organizer, attendees, distribution list present | High |
| **Decision Coverage** | All significant decisions captured with rationale | High |
| **Action Item Quality** | Every action has owner + due date + acceptance criteria | High |
| **Agenda Alignment** | Notes match agenda items, no orphan topics | Medium |
| **Clarity** | No vague language, actionable statements | Medium |
| **Formatting** | Consistent structure, ISO dates, bullet lists | Low |

### Pass/Fail Threshold

- **Pass**: All High-weight criteria met, at most 2 Medium issues
- **Revise**: Any High-weight criteria not met, or 3+ Medium issues

---

## Step 4: Identify Critical Issues

Among all issues found, identify the most critical:

1. **Missing action item owner or due date** — blocks task tracking
2. **Missing decision rationale** — reduces transparency
3. **Incomplete metadata** — affects document traceability
4. **Vague action items** — causes execution confusion

Highlight the top 1-3 critical issues prominently in the review output.

---

## Step 5: Generate Review Feedback

Present findings in structured format:

### Review Output Format

```markdown
---
round: [N]
max_rounds: 2
status: [pass / revise]
reviewed_at: [ISO 8601 timestamp]
---

## Review Summary

[1-2 sentence overall assessment]

## Critical Issues (must fix)

- [ ] Issue 1: [description]
- [ ] Issue 2: [description]

## Suggestions (improve quality)

- [ ] Suggestion 1: [description]

## Strengths

- [What the document does well]

## Specific Edits

[List specific line-by-line suggestions if applicable]

## Next Steps

- [What the drafter should do next]
```

---

## Step 6: Issue Classification

Classify each issue using this severity system:

| Marker | Severity | Description |
|--------|----------|-------------|
| 🔴 | Blocker | Missing owner/due date on action item; missing decision; critical metadata absent |
| 🟡 | Major | Vague action item; missing rationale; unclear attribution |
| 💭 | Minor | Formatting inconsistency; minor clarity improvement |

---

## Review Checklist for Meeting Minutes

Use this checklist during review:

### Metadata Section
- [ ] Title present and descriptive
- [ ] Date in YYYY-MM-DD format
- [ ] Start/end time or duration included
- [ ] Organizer identified
- [ ] Attendance list complete

### Decisions Section
- [ ] Each decision has clear statement
- [ ] Decision maker/approver identified
- [ ] Rationale provided (1-2 sentences)
- [ ] Effective date if applicable

### Action Items Section
- [ ] Unique ID assigned (e.g., A1, A2)
- [ ] Owner specified with team
- [ ] Due date in YYYY-MM-DD format
- [ ] Acceptance criteria defined
- [ ] Linked artifacts if available

### Summary Section
- [ ] Concise (1-3 sentences)
- [ ] Captures meeting objective
- [ ] States high-level outcome

### Parking Lot
- [ ] Unresolved items documented
- [ ] Next steps suggested
- [ ] Owner assigned if known

---

## DO / DON'T

**DO:**

- Check every action item for owner AND due date
- Verify decision statements are unambiguous
- Provide specific line-by-line suggestions when possible
- Acknowledge what the document does well

**DON'T:**

- Rewrite the entire document
- Add decisions or action items not discussed
- Accept vague language like "will try to" or "probably"
- Skip checking action item due dates

---

## Workflow Integration

This skill is designed to work with the meeting minutes generation workflow:

1. **minutes-drafter** creates `draft-minutes.md`
2. **document-review** (this skill) reviews and outputs `review-feedback.md`
3. If status is `revise`, **minutes-drafter** modifies and resubmits
4. Maximum 2 revision rounds before `final-minutes.md` is generated

---

## Adaptation Notes

This skill was adapted from `everyinc/compound-engineering-plugin@document-review` (skills.sh) with the following changes:

1. **Narrowed scope**: General document review → Meeting minutes review
2. **Added criteria**: Meeting-specific checks (attendees, decisions, action items)
3. **Added severity system**: 🔴/🟡/💭 classification for issues
4. **Workflow integration**: Designed for draft-review-revise cycle
5. **YAML frontmatter**: Added round tracking and status fields