import { getOwner } from "@ember/owner";
import { makeArray } from "discourse/lib/helpers";
import { withPluginApi } from "discourse/lib/plugin-api";
import RequestTagCreateRow from "../components/request-tag-create-row.gjs";
import RequestedTagChoice from "../components/requested-tag-choice.gjs";

// Requests ride along in `composer.tags` as core's "new tag" items
// (`isNew: true`), which users who can't create tags never otherwise have.
const tagName = (tag) => (typeof tag === "string" ? tag : tag?.name);

// A module function rather than a `#` method: `modifyClass` copies members onto
// the patched class, which JS private methods don't survive.
function enableTagRequests(chooser) {
  if (chooser.acceptsTagRequests) {
    chooser.selectKit.options.setProperties({
      allowAny: true,
      filterPlaceholder: "discourse_tag_requests.composer.filter_placeholder",
      selectedChoiceComponent: RequestedTagChoice,
    });
  }
}

function extendTagChooser(api) {
  api.modifyClass(
    "component:mini-tag-chooser",
    (Superclass) =>
      class extends Superclass {
        get acceptsTagRequests() {
          return (
            !!getOwner(this).lookup("service:current-user")?.can_request_tags &&
            !!this.element?.closest("#reply-control") &&
            !!getOwner(this).lookup("service:composer").model?.creatingTopic
          );
        }

        // Options are resolved before the element exists, so they're checked
        // again once it's inserted.
        didReceiveAttrs() {
          super.didReceiveAttrs(...arguments);
          enableTagRequests(this);
        }

        didInsertElement() {
          super.didInsertElement(...arguments);
          enableTagRequests(this);
        }

        validateCreate(filter, content) {
          if (this.acceptsTagRequests) {
            const requestCount = makeArray(this.value).filter(
              (tag) => tag?.isNew
            ).length;
            if (requestCount >= this.siteSettings.max_tag_requests_per_topic) {
              return false;
            }
          }

          return super.validateCreate(filter, content);
        }

        modifyComponentForRow(collection, item) {
          if (this.acceptsTagRequests && item?.isNew) {
            return RequestTagCreateRow;
          }

          return super.modifyComponentForRow(collection, item);
        }
      }
  );
}

function extendComposer(api) {
  // For tag creators, "new tag" items are real tags to create, not requests.
  api.addModelAccessor("composer", "requestedTagNames", {
    get() {
      if (!getOwner(this).lookup("service:current-user")?.can_request_tags) {
        return [];
      }
      return makeArray(this.tags)
        .filter((tag) => tag?.isNew)
        .map(tagName);
    },
    // Restores requests from a draft, where tags lose their `isNew` flag.
    set(names) {
      if (!names?.length) {
        return;
      }
      const requested = names.map((name) => name.toLowerCase());
      const tags = makeArray(this.tags).filter(
        (tag) => !requested.includes(tagName(tag)?.toLowerCase())
      );
      this.set("tags", [
        ...tags,
        ...names.map((name) => ({ id: name, name, isNew: true })),
      ]);
    },
  });

  api.serializeOnCreate("requested_tag_names", "requestedTagNames");
  api.serializeToDraft("requested_tag_names", "requestedTagNames");

  // A requested name that matches a hidden tag would make the server reject
  // the topic, so requests are only sent as `requested_tag_names`.
  api.addModelCallback("post", "beforeCreate", function (props) {
    const requested = makeArray(props.requested_tag_names).map((name) =>
      name.toLowerCase()
    );
    if (requested.length && props.tags) {
      props.tags = props.tags.filter(
        (tag) => tag.id || !requested.includes(tagName(tag).toLowerCase())
      );
    }
  });
}

export default {
  name: "tag-request-composer",

  initialize(owner) {
    if (!owner.lookup("service:site-settings").discourse_tag_requests_enabled) {
      return;
    }

    withPluginApi((api) => {
      extendTagChooser(api);
      extendComposer(api);
    });
  },
};
