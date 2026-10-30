import Component from "@glimmer/component";
import { get } from "@ember/object";
import { service } from "@ember/service";
import { makeArray } from "discourse/lib/helpers";
import DPopupInputTip from "discourse/ui-kit/d-popup-input-tip";
import { i18n } from "discourse-i18n";
import { missingRequiredTags } from "../../lib/missing-required-tags.js";

/**
 * Explains a blocked submit when requested tags make the composer's own tag
 * count look sufficient, but the existing tags alone don't meet the minimum.
 */
export default class RequestedTagsValidation extends Component {
  @service composer;
  @service currentUser;

  get validation() {
    const model = this.args.outletArgs.composer;
    // Read `tags` first and through `get`, so adding a request re-renders.
    const tags = makeArray(get(model, "tags"));
    const minimum = get(model, "minimumRequiredTags");

    // Core's own tip already covers a minimum that all tags together miss.
    if (
      !this.currentUser?.can_request_tags ||
      !tags.some((tag) => tag?.isNew) ||
      tags.length < minimum ||
      !missingRequiredTags(model)
    ) {
      return;
    }

    return {
      failed: true,
      reason: i18n("discourse_tag_requests.composer.existing_tags_required", {
        count: minimum,
      }),
      lastShownAt: get(this.composer, "lastValidatedAt"),
    };
  }

  <template>
    {{#if this.validation}}
      <DPopupInputTip @validation={{this.validation}} />
    {{/if}}
  </template>
}
