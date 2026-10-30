import { click, fillIn, visit } from "@ember/test-helpers";
import { test } from "qunit";
import pretender from "discourse/tests/helpers/create-pretender";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import { i18n } from "discourse-i18n";

acceptance("Discourse Tag Requests | composer", function (needs) {
  needs.user({ can_request_tags: true });
  needs.site({ can_tag_topics: true, can_create_tag: false });
  needs.settings({
    allow_uncategorized_topics: true,
    discourse_tag_requests_enabled: true,
    max_tag_requests_per_topic: 1,
    max_tags_per_topic: 5,
    tagging_enabled: true,
  });
  needs.pretender((server, helper) => {
    server.get("/tags/filter/search", () => helper.response({ results: [] }));
  });

  async function openComposer() {
    await visit("/");
    await click("#create-topic");
    await fillIn("#reply-title", "this is my new topic title");
    await fillIn(".d-editor-input", "this is the *content* of a post");
  }

  test("requests a new tag in the same list as regular tags", async function (assert) {
    await openComposer();
    const chooser = selectKit(".mini-tag-chooser");
    await chooser.expand();
    assert
      .dom(".mini-tag-chooser .filter-input")
      .hasAttribute(
        "placeholder",
        i18n("discourse_tag_requests.composer.filter_placeholder"),
        "invites requesting rather than creating"
      );

    await chooser.fillInFilter("Web Assembly");

    assert.dom(".mini-tag-chooser .select-kit-row").hasText(
      i18n("discourse_tag_requests.composer.request_tag", {
        name: "web-assembly",
      }),
      "offers to request the cleaned name"
    );

    await chooser.selectRowByIndex(0);

    assert.strictEqual(
      chooser.header().value(),
      "web-assembly",
      "shows the request with the selected tags"
    );
    assert
      .dom(".mini-tag-chooser .selected-content .requested-tag-choice")
      .hasText("web-assembly", "marks the request in the selected list");

    await click("#reply-control button.create");

    const request = pretender.handledRequests.find(
      ({ method, url }) => method === "POST" && url.startsWith("/posts")
    );
    const body = JSON.parse(request.requestBody);
    assert.deepEqual(
      body.requested_tag_names,
      ["web-assembly"],
      "sends the request separately"
    );
    assert.deepEqual(body.tags, [], "doesn't send it as a regular tag");
  });

  test("stops offering requests at the per-topic limit", async function (assert) {
    await openComposer();
    const chooser = selectKit(".mini-tag-chooser");
    await chooser.expand();
    await chooser.fillInFilter("rust");
    await chooser.selectRowByIndex(0);
    await chooser.fillInFilter("go");

    assert
      .dom(".mini-tag-chooser .select-kit-row")
      .doesNotExist("no request row once the limit is reached");
  });
});
