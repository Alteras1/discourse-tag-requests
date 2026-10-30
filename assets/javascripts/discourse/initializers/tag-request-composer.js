import { getOwner } from "@ember/owner";
import { makeArray } from "discourse/lib/helpers";
import { withPluginApi } from "discourse/lib/plugin-api";
import RequestTagCreateRow from "../components/request-tag-create-row.gjs";
import RequestedTagChoice from "../components/requested-tag-choice.gjs";
import { missingRequiredTags } from "../lib/missing-required-tags.js";
import { requestedTag } from "../lib/requested-tag.js";

// Requests ride along in `composer.tags` as core's "new tag" items
// (`isNew: true`), which users who can't create tags never otherwise have.
const tagName = (tag) => (typeof tag === "string" ? tag : tag?.name);

// Drafts and submitted tags lose the `isNew` flag, so requests are recognised
// as the id-less tags with a requested name; existing tags always have an id.
function withoutRequests(tags, names) {
  const requested = names.map((name) => name.toLowerCase());
  return makeArray(tags).filter(
    (tag) =>
      !tag?.isNew &&
      (tag?.id || !requested.includes(tagName(tag)?.toLowerCase()))
  );
}

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
          if (
            !getOwner(this).lookup("service:current-user")?.can_request_tags
          ) {
            return false;
          }

          return (
            !!this.options?.acceptsTagRequests ||
            (!!this.element?.closest("#reply-control") &&
              !!getOwner(this).lookup("service:composer").model?.creatingTopic)
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
      this.set("tags", [
        ...withoutRequests(this.tags, names),
        ...names.map(requestedTag),
      ]);
    },
  });

  // The composer counts requests toward a category's required tags, but the
  // server doesn't, so submitting would fail there.
  api.registerValueTransformer(
    "composer-service-cannot-submit-post",
    ({ value, context: { model } }) =>
      value ||
      (model?.requestedTagNames?.length > 0 && missingRequiredTags(model) > 0)
  );

  api.serializeOnCreate("requested_tag_names", "requestedTagNames");
  api.serializeToDraft("requested_tag_names", "requestedTagNames");

  // A requested name that matches a hidden tag would make the server reject
  // the topic, so requests are only sent as `requested_tag_names`.
  api.addModelCallback("post", "beforeCreate", function (props) {
    const names = makeArray(props.requested_tag_names);
    if (names.length && props.tags) {
      props.tags = withoutRequests(props.tags, names);
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
