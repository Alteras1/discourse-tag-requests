import { get } from "@ember/object";
import { makeArray } from "discourse/lib/helpers";

/**
 * How many more existing tags a new topic needs to meet its category's
 * minimum. Requested tags don't count: the server only counts tags that exist.
 *
 * Reads through `get` so callers on the classic composer model stay reactive.
 *
 * @param {object} composer - the composer model
 * @returns {number}
 */
export function missingRequiredTags(composer) {
  const minimum = get(composer, "minimumRequiredTags");
  if (
    !minimum ||
    !get(composer, "topicFirstPost") ||
    get(composer, "user.staff")
  ) {
    return 0;
  }

  const existingTagCount = makeArray(get(composer, "tags")).filter(
    (tag) => !tag?.isNew
  ).length;
  return Math.max(minimum - existingTagCount, 0);
}
