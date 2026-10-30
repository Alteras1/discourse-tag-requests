import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { action, get } from "@ember/object";
import { makeArray } from "discourse/lib/helpers";
import Category from "discourse/models/category";
import MiniTagChooser from "discourse/select-kit/components/mini-tag-chooser";
import { requestedTag } from "../../lib/requested-tag.js";

/**
 * Replaces the topic title's tag chooser for authors who can only request new
 * tags. Requests are kept apart from `buffered.tags`, which is what core saves.
 */
export default class RequestableTagChooser extends Component {
  static shouldRender({ model }, _context, owner) {
    const currentUser = owner.lookup("service:current-user");
    return !!currentUser?.can_request_tags && model.user_id === currentUser.id;
  }

  get buffered() {
    return this.args.outletArgs.buffered;
  }

  get categoryId() {
    return get(this.buffered, "category_id");
  }

  get minimumRequiredTags() {
    return Category.findById(this.categoryId)?.minimumRequiredTags || 0;
  }

  get value() {
    const names =
      get(this.buffered, "requested_tag_names") ??
      this.args.outletArgs.model.requested_tags ??
      [];

    return [
      ...makeArray(get(this.buffered, "tags")),
      ...names.map(requestedTag),
    ];
  }

  @action
  onChange(value) {
    const tags = makeArray(value);

    this.buffered.set(
      "tags",
      tags.filter((tag) => !tag.isNew)
    );
    this.buffered.set(
      "requested_tag_names",
      tags.filter((tag) => tag.isNew).map((tag) => tag.name)
    );
  }

  <template>
    <MiniTagChooser
      @onChange={{this.onChange}}
      @options={{hash
        acceptsTagRequests=true
        filterable=true
        categoryId=this.categoryId
        minimum=this.minimumRequiredTags
        filterPlaceholder="tagging.choose_for_topic"
        useHeaderFilter=true
        prioritizeRecentTags=true
      }}
      @value={{this.value}}
    />
  </template>
}
