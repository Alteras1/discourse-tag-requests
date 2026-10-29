# **Discourse Tag Requests** Plugin

**Plugin Summary**

Lets users who can't create tags request new ones while creating a topic.
Staff review requests in the standard review queue and turn them into a new
tag, an existing tag, or a synonym.

For more information, please see: **url to meta topic**

> **Status:** in development. Not all features below are implemented yet.

## How it works

1. **Requesting.** When a user who can't create tags types a name in the
   composer's tag chooser that doesn't match an existing tag, they can pick
   "Request new tag". The topic is created straight away with its real tags;
   requested names are stored separately and never block topic creation.
2. **Reviewing.** Each requested name gets one review item, shared by every
   topic that requested it. Staff can:
   - **Approve** – create the tag and add it to the topics
   - **Approve & edit** – the same, then open the new tag's settings
   - **Use existing tag** – add a tag that already exists instead
   - **Add as synonym** – make the name a synonym of an existing tag
   - **Reject** – the name can be requested again later
   - **Reject permanently** – the name can never be requested again
3. **Applying.** On approval the tag is added to each topic that requested
   it, following the usual category and tag group rules. Topics where the
   tag isn't allowed are skipped and listed on the review item.

Users are not notified about the outcome of their requests.

## Finding requested tags

Pending requests appear as pills next to a topic's tags. Use the
`requested-tag:` filter on `/filter` to find topics by requested tag:

- `requested-tag:rust` – topics with this requested (or real) tag
- `requested-tag:rust,go` – topics with any of these
- `requested-tag:rust+go` – topics with all of these
- `-requested-tag:rust` – topics without it

`requested-tag:` also matches real tags, so links keep working after a
request is approved.

## Who can see requests

- Staff can always see requests.
- A topic's author can always see requests on their own topic.
- Other users can see requests if they belong to a group in
  **tag requests visible to groups**.

## Settings

| Setting | Description | Default |
|---|---|---|
| `discourse_tag_requests_enabled` | Enable the plugin | `false` |
| `max_tag_requests_per_topic` | Maximum requested tags per topic. Requested tags also count toward `max_tags_per_topic`. | `3` |
| `tag_requests_visible_to_groups` | Groups that can see pending requests | admins, moderators |

Tagging must be enabled for the plugin to work.

## Screenshots

_TODO_
