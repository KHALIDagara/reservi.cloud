---
name: hotwire-inbox
description: "Build and review Reservi's collaborative inbox with Rails/Hotwire using surgical DOM updates, bounded realtime fan-out, windowed messages, stage-derived work UI, and browser proof."
---

# Reservi Collaborative Inbox / Hotwire Contract

Load this skill for any work touching:

- inbox workspace;
- conversation list or conversation detail;
- messages, unread state, composer, attachments, audio;
- Turbo Frames / Turbo Streams;
- Action Cable / Solid Cable;
- realtime jobs/broadcasts;
- the stage-derived conversation work panel;
- field, catalog, assignment, or appointment pickers inside a conversation;
- responsive/mobile conversation UX.

Read root `AGENTS.md`, `docs/architecture.md`, `docs/invariants.md`, and `docs/testing.md` before meaningful implementation.

The target is a very fast collaborative CRM for many simultaneous conversations and agents. Do not turn Stimulus into a SPA and do not use whole-page refreshes as the normal realtime mechanism.

## 1. Runtime ownership

The contract is:

```text
PostgreSQL = authoritative truth
        ↓
explicit domain operation
        ↓
Flow/Rules evaluate
        ↓
outer transaction commits
        ↓
reload authoritative state
        ↓
render smallest affected ERB partial
        ↓
Turbo surgically updates open clients
```

Rails owns state and business decisions.
ERB owns HTML presentation.
Turbo moves server-rendered HTML.
Stimulus owns temporary browser behavior only.
Action Cable notifies already-open screens after committed state changes.

Never duplicate Flow completion, assignment eligibility, appointment availability, unread truth, or catalog-selection truth in JavaScript.

## 2. Canonical inbox resource shape

`/a/:account_id/inboxes/:id` is the agent workspace, not technical provider settings.

Provider/webhook/default-assignment settings belong under an explicit settings resource such as:

```text
/a/:account_id/inboxes/:id/settings
```

A nested URL must have nested authorization/scoping:

```ruby
@inbox = current_account.channels.find(params[:inbox_id])
@conversation = @inbox.conversations.find(params[:id] || params[:conversation_id])
```

Never resolve a nested inbox conversation with only:

```ruby
current_account.conversations.find(...)
```

Views must be owned by the resource they render. Do not create a new `accounts/inboxes/...` hierarchy that secretly renders old `accounts/inbox` or legacy conversation god-partials. If presentation is genuinely shared, extract a deliberately named shared partial/component.

Target ownership:

```text
accounts/inboxes/
  show
  settings/
  conversations/
    index
    show
    _conversation_row
    _conversation
    messages/
      _message
      _form
      ...
    panel/
      show
      blocks/
        _field
        _catalog
        _appointment
```

## 3. Stable workspace shell

The inbox page is a stable shell:

```text
conversation list | selected conversation | stage-derived work panel
```

The shell must not be replaced for ordinary realtime changes.

Desktop:
- bounded left conversation column;
- flexible message column;
- bounded right work panel.

Tablet:
- list + conversation;
- work panel becomes a slide-over.

Phone:
- conversation list screen;
- selected conversation screen;
- work panel as accessible overlay/sheet.

Use CSS for layout/breakpoints. Stimulus may manage open/close/focus/inert/escape behavior.

## 4. Realtime budget — non-negotiable

Physical/logical subscriptions must remain bounded.

Normal open workspace target:

```text
one active-inbox/list stream
one selected-conversation stream
optional user/account notification stream
```

Forbidden:
- `turbo_stream_from` in every conversation row;
- one subscription per message;
- one subscription per field/catalog/appointment block;
- broadcast-refresh of the whole inbox for routine mutations;
- several model callbacks broadcasting independently for one logical action.

One logical business action should produce one consolidated realtime projection after commit.

Examples:

```text
incoming message
  -> append one message if that conversation is open
  -> replace/reposition one conversation row

delivery status
  -> replace only that message/status

field/item/appointment change
  -> morph/replace only relevant work-panel projection
  -> update row only if row-visible data changed

assignment
  -> update assignment/header + affected row

read cursor
  -> update only viewer-specific unread projection
```

### Stream correctness

Prefer standard Turbo stream subscriptions unless a custom channel is actually required.

The subscription stream name and broadcast stream name MUST be identical. If a custom channel is used, pass it through the actual Turbo subscription `channel:` API and prove the parameters/authorization match. Do not assume putting a Channel class in the streamables list changes the Action Cable channel.

Do not keep custom channels that nothing subscribes to.

A selected conversation must actually subscribe to the stream that receives message/panel changes.

Authorization is enforced at subscription time and every rendered projection must remain Account-scoped.

### Fan-out

Do not loop over every active human agent on every mutation merely because they exist.

Viewer-specific projections such as unread counts may require viewer-specific updates, but fan-out must be deliberate and bounded. Prefer shared viewer-neutral broadcasts plus the smallest viewer-specific projection where practical.

Never couple conversation-detail updates only to `conversation.owner`; collaborative viewers may be reading a conversation they do not own, and assignment can change while the page is open.

### Stale/out-of-order work

Realtime jobs reload current persisted state before rendering.

If revision/generation checks are used, define their semantics clearly and test out-of-order jobs. Never allow an old queued broadcast to overwrite newer visible state.

## 5. Conversation list contract

The conversation list is a read projection, not N controller queries.

Each row should expose at least:

- push/provider contact name with Customer fallback;
- latest customer-visible message preview;
- last activity timestamp;
- current Stage label/progress summary;
- owner/team;
- current viewer unread count;
- attention state.

Ordering is authoritative and deterministic:

```text
last_activity_at DESC
id DESC
```

Use keyset/cursor pagination. No OFFSET pagination for the live conversation list.

When activity changes, replace/reposition only that row. Do not reload the whole list.

Unread count is viewer-specific and derives from `ConversationRead.last_read_message_id` (or its canonical replacement). Do not issue one COUNT query per row. Use one scoped query/subquery/join for the page.

Opening a conversation updates the read cursor and the visible unread badge without requiring a page refresh.

Selected-row state must visibly change when navigating inside the conversation Turbo Frame. Do not leave the left list with stale selection styling.

## 6. Message window contract

Never load the entire conversation history.

Initial window:
- latest ~20–30 messages.

Older history:
- bounded window before a stable cursor.

Reconnect/catch-up:
- bounded messages after the last known cursor; cap the response (for example 100) and continue if needed.

The DOM is chronological: oldest -> newest.

Do not run `COUNT(*)` over a long message table merely to decide whether older messages exist. Prefer an `exists?` query around the oldest loaded cursor.

Every `data-turbo-frame="X"` target must reference an actual `<turbo-frame id="X">`. A plain `<div id="X">` is not a Turbo Frame.

Loading older messages must preserve already-rendered messages and preserve scroll position. Do not replace the current 30-message window with the previous 30.

Use one of these coherent patterns:
- Turbo Stream prepend + replace older-control; or
- a real nested pagination frame that accumulates older pages before the current messages.

Stimulus may measure scrollHeight before/after prepending and restore visual position. It must not own message truth.

If the user is at/near the bottom, a new message may auto-scroll. If the user is reading older messages, do not steal scroll; expose a small "new messages" affordance.

## 7. Exactly one outbound Message

Sending one logical customer message MUST create exactly one canonical `Message`.

That same Message owns:
- text;
- attachments;
- author;
- delivery status;
- provider delivery intent / remote identity.

Forbidden shape:

```text
Composer operation creates Message A
then MessageDeliveries::Send creates Message B
attachments remain on A
provider delivery points at B
```

Choose one canonical orchestration:
- either the delivery operation creates the Message and accepts/attaches media;
- or the composer creates the Message and the delivery operation accepts that existing Message.

Never both.

An idempotency/operation key must prevent duplicate customer-visible sends on retries.

Do not claim success until a test proves:
- one submit -> one Message;
- one MessageDelivery;
- attachments belong to that delivered Message;
- retry does not create a duplicate Message.

## 8. Attachments and audio

Message may be valid with text, attachments, or both.

Use Active Storage through a first-class attachment association.

Validate:
- permitted type;
- size;
- Account/conversation authorization on access;
- safe rendering.

The composer needs a real file input/attachment picker and preview state.

Audio recording uses a small Stimulus controller around browser `MediaRecorder`:
- start;
- stop;
- preview/remove;
- turn Blob into a File;
- submit through the SAME attachment pipeline.

Do not create a separate voice-message domain.

Provider delivery must support the media being offered by the composer. If a provider/channel cannot deliver a media type yet, the UI must not pretend the attachment was sent successfully; implement the adapter support or disable that unsupported action explicitly.

The adapter contract must be uniform from `MessageDeliveryJob` through every provider. Do not test only `WhatsappCloudAdapter.new.send_message(...)` / `InstagramAdapter.new.send_message(...)` while the production job calls a different class-method signature. Add integration/job proof that the real queued job successfully invokes each supported adapter using the same contract.

## 9. Stage-derived work panel

The right panel is not a static CRM sidebar.

It is a live projection of:

```text
conversation.current_stage
+ stage.blocks
+ current Conversation/Customer state
+ current ItemSelections
+ current Appointments
+ assignment
+ stage history/progress
```

The operator sees requirements and state, not raw Flow JSON.

Use an allowlisted block renderer, e.g.:

```ruby
{
  "field" => ...,
  "catalog" => ...,
  "appointment" => ...
}
```

Do not dynamically render arbitrary partial paths from configuration strings.

A stage mutation may advance the Stage. After the domain operation completes and Flow evaluation runs, reload the Conversation and render the NEW current Stage. The browser never predicts the next Stage.

Prefer morph/replace on the smallest stable panel target. Preserve unrelated message scroll, composer draft, upload state, and open workspace shell.

## 10. Pickers are real conversation resources/modals

### Field
Click requirement -> server-rendered modal -> control derived from FieldDefinition -> save -> Flow evaluates -> panel morphs.

Do not reuse a legacy partial merely because it exists if that keeps the old resource hierarchy alive. Move genuinely shared field controls to an intentional shared location.

### Catalog / Item
The panel shows selected state and a "Choose/Change" action.

Do NOT dump an unbounded catalog into pills in a 350px sidebar.

Open a conversation-aware modal:
- correct configured catalog/role;
- search/filter/pagination when needed;
- current selection;
- select/clear;
- operation validates that Item belongs to the stage-configured Catalog.

A generic catalog listing page is not a conversation item-picker modal.

### Appointment
"Book appointment" must open the appointment flow for THIS conversation and THIS stage role. It must never link to "new conversation" or another placeholder route.

Target flow:

```text
select schedulable human agent
 -> select available day
 -> select available slot
 -> review
 -> book
```

The server owns availability and conflict rules. Prefer Turbo Frame HTML steps. Stimulus may handle animation only.

### Assignment
Assignment picker uses the canonical assignable-Agent policy, not merely `Agent.active`.

Humans and eligible AI can appear. Draft/paused/unconfigured AI must not.

Assignment/handoff is an explicit atomic domain operation and the panel/list update from the committed result.

## 11. Current inbox repair mandate

When reviewing/refactoring the existing inbox implementation, verify these known failure classes before doing cosmetic work:

1. Exactly-one-message send path; eliminate Message A/Message B duplication.
2. Prove inbox and selected-conversation Turbo subscriptions actually match their broadcast streams.
3. Remove dead custom channels or wire them correctly; never keep comments claiming subscriptions that do not exist.
4. Realtime detail updates must reach authorized collaborative viewers, not owner only.
5. Avoid unconditional broadcast fan-out to every active human.
6. Pass pagination state/locals all the way into the message partials.
7. Fix "load older" to target a real frame/stream and preserve existing messages + scroll.
8. Bound the `:after` reconnect query.
9. Update unread state/list row immediately when a conversation is opened/read.
10. Ensure attachment/audio UI exists AND provider delivery sends the same canonical Message/media.
11. Replace catalog sidebar pill dumps with a conversation-aware picker modal.
12. Replace appointment placeholder links with agent -> day -> slot -> confirm flow.
13. Use `Agent.assignable`/canonical eligibility in assignment UI and server validation.
14. Ensure panel Stage content re-renders from the post-evaluation current Stage.
15. Remove remaining legacy resource/view dependencies instead of hiding them behind new namespaces.
16. The new workspace must not submit claim/release/reassign/cancel/item/appointment actions to legacy endpoints that redirect back through the old `/inbox` route and lose the selected inbox/conversation context. Extract nested/resourceful actions or preserve an explicit safe nested return path.
17. Audit route helpers against `bin/rails routes`; do not use the legacy `account_inbox_path` helper as though it were the nested `inbox_path`. A commit named "fix route helpers" is not proof—exercise each link/form.
18. Pass `has_older_messages` / oldest-cursor data into the partial that renders the load-older control; test that the control actually appears for > window-size histories.
19. Catalog "Browse/Choose" must load a conversation + role aware picker and submit an ItemSelection; a generic catalog-items page is not sufficient.
20. Appointment "Book/Reschedule" must target the current conversation + appointment role; a link to `new_account_conversation_path` is a blocking placeholder defect.
21. Panel assignment uses canonical `Agent.assignable` in both controller render and realtime render. Do not use `Agent.active` and accidentally expose paused/draft AI.
22. If the old standalone `Accounts::ConversationsController` remains temporarily, do not let the new workspace depend on its unwindowed message show, legacy redirects, or duplicate panel code. Migrate actions deliberately, then delete compatibility code.
23. Exercise `MessageDeliveryJob` through the actual provider adapter factory for dev, WhatsApp, and Instagram. Make the method/signature contract identical; direct adapter unit tests that bypass the job are insufficient.

Do not mark the task complete while any required path is still a placeholder.

## 12. Testing / proof gates

For inbox/realtime work, tests must include meaningful request/domain/job tests plus browser/system proof.

Minimum browser proof for a major inbox change:
- desktop viewport;
- phone viewport;
- open inbox;
- select conversation;
- selected row changes;
- latest messages appear in chronological order;
- load older messages without losing current messages/scroll;
- send text;
- send attachment;
- record/send audio when supported;
- second browser/session receives incoming message without reload;
- conversation row moves to correct ordered position;
- unread badge changes independently per agent;
- field edit can advance Stage and panel morphs to the new Stage;
- catalog picker selects the configured role;
- appointment picker agent -> day -> slot -> confirmation;
- work panel opens/closes accessibly on mobile;
- reassignment remains live for viewers.

Realtime tests must prove actual subscription/broadcast compatibility, not merely that a job method was called.

Performance-oriented proof:
- no one-subscription-per-row pattern;
- no unbounded message query;
- no N+1 unread COUNT;
- no whole-inbox refresh for one message;
- no per-model callback broadcast storm;
- reasonable query count for a 25-row list.

## 13. CI integrity

Never make CI green by:
- excluding failing tests;
- rescuing the suite and `exit 0`;
- suppressing failure exit codes;
- relabeling failures as "pre-existing" without keeping them visible;
- deleting assertions that reveal a real defect.

If a test is genuinely unrelated and pre-existing, it may be separately documented/triaged, but the normal test command must still return failure while the suite is failing.

A completion report must state the real test command, exit status, failures/errors, browser flows actually exercised, and remaining defects.

"598 runs, 0 failures" is not a valid claim if the wrapper exits zero after the underlying test command failed.
