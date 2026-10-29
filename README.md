# **Discourse Tag Requests** Plugin

**Plugin Summary**

Lets users who can't create tags suggest new ones while creating a topic.
Staff review suggestions in the standard review queue and turn them into a
new tag, an existing tag, or a synonym.

For more information, please see: **url to meta topic**

> **Status:** in development. Not all features below are implemented yet.

## How it works

1. **Suggesting.** When a user who can't create tags types a name in the
   composer's tag chooser that doesn't match an existing tag, they can pick
   "Suggest new tag". The topic is created straight away with its real tags;
   suggested names are stored separately and never block topic creation.
2. **Reviewing.** Each suggested name gets one review item, shared by every
   topic that suggested it. Staff can:
   - **Approve** – create the tag and add it to the topics
   - **Approve & edit** – the same, then open the new tag's settings
   - **Use existing tag** – add a tag that already exists instead
   - **Add as synonym** – make the name a synonym of an existing tag
   - **Reject** – the name can be suggested again later
   - **Reject permanently** – the name can never be suggested again
3. **Applying.** On approval the tag is added to each topic that suggested
   it, following the usual category and tag group rules. Topics where the
   tag isn't allowed are skipped and listed on the review item.

Users are not notified about the outcome of their suggestions.

## Finding suggested tags

Pending suggestions appear as pills next to a topic's tags. Use the
`suggested-tag:` filter on `/filter` to find topics by suggested tag:

- `suggested-tag:rust` – topics with this suggested (or real) tag
- `suggested-tag:rust,go` – topics with any of these
- `suggested-tag:rust+go` – topics with all of these
- `-suggested-tag:rust` – topics without it

`suggested-tag:` also matches real tags, so links keep working after a
suggestion is approved.

## Who can see suggestions

- Staff can always see suggestions.
- A topic's author can always see suggestions on their own topic.
- Other users can see suggestions if they belong to a group in
  **suggested tags visible to groups**.

## Settings

| Setting | Description | Default |
|---|---|---|
| `discourse_tag_requests_enabled` | Enable the plugin | `false` |
| `max_suggested_tags_per_topic` | Maximum suggested tags per topic. Suggestions also count toward `max_tags_per_topic`. | `3` |
| `suggested_tags_visible_to_groups` | Groups that can see pending suggestions | admins, moderators |

Tagging must be enabled for the plugin to work.

## Screenshots

_TODO_
