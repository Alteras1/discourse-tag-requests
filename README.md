# **Discourse Tag Requests** Plugin

**Plugin Summary**

Lets users who can't create tags request new ones while creating a topic.
Staff review requests in the standard review queue and turn them into a new
tag, an existing tag, or a synonym.

For more information, please see: **url to meta topic**

## How it works

1. **Requesting.** In the composer's tag chooser, a user who can request tags
   types a name that doesn't exist yet and picks **Request new tag**. The
   request sits alongside the topic's other tags, marked as pending, and can be
   removed like any tag. Requested tags share the topic's
   `max_tags_per_topic` limit and survive saving a draft.
2. **Posting.** The topic is created straight away with its existing tags;
   requests are stored separately and never block topic creation. Names that
   can't be requested (reserved, already a tag, or permanently rejected) are
   dropped silently.
3. **Reviewing.** Each requested name gets one review item, shared by every
   topic that requested it. Staff can:
   - **Approve** – create the tag and add it to the topics
   - **Approve and edit** – the same, then open the new tag's settings
   - **Use existing tag** – add a tag that already exists instead
   - **Add as synonym** – make the name a synonym of an existing tag
   - **Reject** – the name can be requested again later
   - **Reject permanently** – the name can never be requested again
4. **Applying.** On approval the tag is added to each topic that requested
   it, following the usual category and tag group rules. Topics where the tag
   isn't allowed are skipped and listed on the review item.

Users are not notified about the outcome of their requests.

Requested tags don't count toward a category's required tags: a topic still
needs enough existing tags to be posted.

## Finding requested tags

Pending requests appear as pills next to a topic's tags, in topic lists, on
the topic page, and in suggested topics. Use the `pending-tag:` filter on
`/filter` to find topics with pending requests:

- `pending-tag:rust` – topics with this pending request
- `pending-tag:rust,go` – topics with any of these
- `pending-tag:rust+go` – topics with all of these
- `-pending-tag:rust` – topics without it

Once a request is approved, use the regular `tag:` filter instead.

## Who can request and see requests

Users can request tags when they can tag topics, can't create tags, and
belong to a group in **tag requests allowed groups**. Anyone who can create
tags creates them directly instead.

Requests are visible to:

- staff
- a topic's author, on their own topic
- members of a group in **tag requests visible to groups**

## Settings

| Setting | Description | Default |
|---|---|---|
| `discourse_tag_requests_enabled` | Enable the plugin | `false` |
| `tag_requests_allowed_groups` | Groups that can request tags. Members who can also create tags (`create_tag_allowed_groups`) create them directly instead. | trust level 1 |
| `max_tag_requests_per_topic` | Maximum requested tags per topic. Requested tags also count toward `max_tags_per_topic`. | `3` |
| `tag_requests_visible_to_groups` | Groups that can see pending requests | admins, moderators |

Tagging must be enabled for the plugin to work.

## Credits

The `circle-dashed` pending icon is from [Lucide](https://lucide.dev), used
under the ISC License.
