import { withPluginApi } from "discourse/lib/plugin-api";
import ApproveAndEditTagRequestModal from "../components/modal/approve-and-edit-tag-request.gjs";
import ChooseTagForRequestModal from "../components/modal/choose-tag-for-request.gjs";
import renderRequestedTag from "../lib/render-requested-tag.js";

export default {
  name: "discourse-tag-requests",

  initialize(owner) {
    const siteSettings = owner.lookup("service:site-settings");
    if (!siteSettings.discourse_tag_requests_enabled) {
      return;
    }

    withPluginApi((api) => {
      api.addTagsHtmlCallback((topic, params = {}) =>
        (topic.requested_tags || []).map((name) =>
          renderRequestedTag(name, {
            tagName: params.tagName,
            style: params.style || siteSettings.tag_style,
          })
        )
      );

      api.registerReviewableComponent(
        "ReviewableTagRequest",
        async () =>
          (await import("../components/reviewable/tag-request.gjs")).default
      );
      api.registerReviewableActionModal(
        "approve_and_edit_tag_request",
        ApproveAndEditTagRequestModal
      );
      api.registerReviewableActionModal(
        "use_existing_tag",
        ChooseTagForRequestModal
      );
      api.registerReviewableActionModal(
        "add_as_synonym",
        ChooseTagForRequestModal
      );
    });
  },
};
