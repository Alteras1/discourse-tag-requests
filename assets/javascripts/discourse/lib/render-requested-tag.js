import getURL from "discourse/lib/get-url";
import { iconHTML } from "discourse/lib/icon-library";
import { escapeExpression } from "discourse/lib/utilities";
import { i18n } from "discourse-i18n";

/**
 * Renders a pending requested tag in the same shape as a real tag, linking
 * to the topics that requested it.
 *
 * @param {string} name
 * @param {object} [options]
 * @param {string} [options.tagName] - element to render; only `a` gets a link
 * @param {string} [options.style] - the site's tag style class
 * @returns {string} HTML
 */
export default function renderRequestedTag(
  name,
  { tagName = "a", style } = {}
) {
  const classes = ["discourse-tag", style, "requested-tag"]
    .filter(Boolean)
    .join(" ");
  const query = encodeURIComponent(`pending-tag:${name}`);
  const link =
    tagName === "a"
      ? ` href="${getURL(`/filter?q=${query}`)}" data-auto-route="true"`
      : "";
  const title = escapeExpression(
    i18n("discourse_tag_requests.requested_tag.title")
  );

  return `<${tagName}${link} class="${classes}" title="${title}">${iconHTML("circle-info")}${escapeExpression(name)}</${tagName}>`;
}
