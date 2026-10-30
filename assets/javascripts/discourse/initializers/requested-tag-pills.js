import { withPluginApi } from "discourse/lib/plugin-api";
import renderRequestedTag from "../lib/render-requested-tag.js";

export default {
  name: "requested-tag-pills",

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
    });
  },
};
