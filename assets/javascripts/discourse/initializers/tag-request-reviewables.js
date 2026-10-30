import { withPluginApi } from "discourse/lib/plugin-api";
import ApproveAndEditTagRequestModal from "../components/modal/approve-and-edit-tag-request.gjs";
import ChooseTagForRequestModal from "../components/modal/choose-tag-for-request.gjs";

export default {
  name: "tag-request-reviewables",

  initialize(owner) {
    const siteSettings = owner.lookup("service:site-settings");
    if (!siteSettings.discourse_tag_requests_enabled) {
      return;
    }

    withPluginApi((api) => {
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
