/**
 * A request in the shape the tag chooser uses for tags it would create.
 *
 * @param {string} name
 * @returns {{id: string, name: string, isNew: true}}
 */
export function requestedTag(name) {
  return { id: name, name, isNew: true };
}
