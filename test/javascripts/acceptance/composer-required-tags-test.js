import { click, fillIn, visit } from "@ember/test-helpers";
import { test } from "qunit";
import Category from "discourse/models/category";
import pretender from "discourse/tests/helpers/create-pretender";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import { i18n } from "discourse-i18n";

acceptance("Discourse Tag Requests | required tags", function (needs) {
  needs.user({
    can_request_tags: true,
    staff: false,
    moderator: false,
    admin: false,
  });
  needs.site({ can_tag_topics: true, can_create_tag: false });
  needs.settings({
    allow_uncategorized_topics: true,
    discourse_tag_requests_enabled: true,
    max_tag_requests_per_topic: 3,
    max_tags_per_topic: 5,
    tagging_enabled: true,
  });
  needs.pretender((server, helper) => {
    server.get("/tags/filter/search", () =>
      helper.response({ results: [{ id: 3, name: "golang", count: 1 }] })
    );
  });

  async function composeInCategoryRequiringOneTag() {
    await visit("/");
    await click("#create-topic");
    await fillIn("#reply-title", "this is my new topic title");
    await fillIn(".d-editor-input", "this is the *content* of a post");

    Category.findById(2).set("minimum_required_tags", 1);
    const categoryChooser = selectKit(".category-chooser");
    await categoryChooser.expand();
    await categoryChooser.selectRowByValue(2);
  }

  function postRequests() {
    return pretender.handledRequests.filter(
      ({ method, url }) => method === "POST" && url.startsWith("/posts")
    );
  }

  test("requested tags don't satisfy a category's required tags", async function (assert) {
    await composeInCategoryRequiringOneTag();
    const tagChooser = selectKit(".mini-tag-chooser");
    await tagChooser.expand();
    await tagChooser.fillInFilter("rust");
    await tagChooser.selectRowByValue("rust");
    await tagChooser.collapse();

    await click("#reply-control button.create");

    assert.strictEqual(postRequests().length, 0, "doesn't submit");
    assert.dom(".popup-tip.bad").includesText(
      i18n("discourse_tag_requests.composer.existing_tags_required", {
        count: 1,
      }),
      "explains that requests don't count"
    );
  });

  test("submits once an existing tag meets the requirement", async function (assert) {
    await composeInCategoryRequiringOneTag();
    const tagChooser = selectKit(".mini-tag-chooser");
    await tagChooser.expand();
    await tagChooser.fillInFilter("rust");
    await tagChooser.selectRowByValue("rust");
    await tagChooser.fillInFilter("golang");
    await tagChooser.selectRowByValue(3);
    await tagChooser.collapse();

    await click("#reply-control button.create");

    assert.strictEqual(postRequests().length, 1, "submits the topic");
  });
});
