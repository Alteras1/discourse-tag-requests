import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { withPluginApi } from "discourse/lib/plugin-api";

export default {
  name: "tag-request-topic-edit",

  initialize(owner) {
    if (!owner.lookup("service:site-settings").discourse_tag_requests_enabled) {
      return;
    }

    withPluginApi((api) => {
      // Requests are saved after core's own edit: they count against the tags
      // the topic ends up with, and are skipped when that save fails.
      api.registerBehaviorTransformer(
        "topic-controller:finished-editing",
        async ({ next, context: { buffered, model } }) => {
          const controller = owner.lookup("controller:topic");
          const names = buffered.requested_tag_names;
          delete buffered.requested_tag_names;

          await next();

          if (!names) {
            return;
          }

          // Core keeps the editor open when its save fails.
          if (controller.editingTopic) {
            controller.buffered.set("requested_tag_names", names);
            return;
          }

          try {
            const result = await ajax(`/tag-requests/topics/${model.id}`, {
              type: "PUT",
              data: { tag_names: names },
            });
            model.set("requested_tags", result.requested_tags);
            // The header renders requests alongside the topic's tags.
            model.notifyPropertyChange("tags");
          } catch (error) {
            popupAjaxError(error);
          }
        }
      );
    });
  },
};
