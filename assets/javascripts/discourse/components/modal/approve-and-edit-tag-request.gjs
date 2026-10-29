import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DButton from "discourse/ui-kit/d-button";
import DModal from "discourse/ui-kit/d-modal";
import { i18n } from "discourse-i18n";

/**
 * Approves a tag request, then opens the new tag's settings. The perform
 * result doesn't include the tag, so it is read back from the review item.
 */
export default class ApproveAndEditTagRequestModal extends Component {
  @service router;

  @action
  async approve() {
    const {
      reviewable,
      performConfirmed,
      action: reviewAction,
    } = this.args.model;

    this.args.closeModal();
    await performConfirmed(reviewAction);

    try {
      const result = await ajax(`/review/${reviewable.id}.json`);
      const { resolution, tag_id, tag_slug } = result.reviewable.payload;
      if (resolution === "created") {
        this.router.transitionTo("tag.edit", tag_slug, tag_id);
      }
    } catch (error) {
      popupAjaxError(error);
    }
  }

  <template>
    <DModal
      class="approve-and-edit-tag-request-modal"
      @closeModal={{@closeModal}}
      @title={{i18n
        "discourse_tag_requests.reviewables.approve_and_edit.title"
      }}
    >
      <:body>
        {{i18n
          "discourse_tag_requests.reviewables.approve_and_edit.description"
          name=@model.reviewable.payload.name
        }}
      </:body>
      <:footer>
        <DButton
          class="btn-primary"
          @action={{this.approve}}
          @label="discourse_tag_requests.reviewables.approve_and_edit.submit"
        />
        <DButton class="btn-flat" @action={{@closeModal}} @label="cancel" />
      </:footer>
    </DModal>
  </template>
}
