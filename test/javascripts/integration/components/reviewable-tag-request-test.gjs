import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { i18n } from "discourse-i18n";
import ReviewableTagRequest from "discourse/plugins/discourse-tag-requests/discourse/components/reviewable/tag-request";

module("Integration | Component | ReviewableTagRequest", function (hooks) {
  setupRenderingTest(hooks);

  test("shows a pending request", async function (assert) {
    const reviewable = {
      payload: { name: "rust", previous_reviewable_id: 12 },
      existing_tag: { id: 3, name: "rust-lang" },
      associated_topics: [
        { id: 5, title: "Learning Rust", slug: "learning-rust" },
      ],
      requesters: [
        { id: 1, username: "alice" },
        { id: 2, username: "bob" },
      ],
    };

    await render(
      <template><ReviewableTagRequest @reviewable={{reviewable}} /></template>
    );

    assert
      .dom(".reviewable-tag-request__existing-tag")
      .includesText("rust-lang", "warns that a tag with the name exists");
    assert
      .dom(".reviewable-tag-request__name")
      .hasText("rust", "shows the requested name");
    assert
      .dom(".reviewable-tag-request__topic a")
      .hasAttribute("href", "/t/learning-rust/5", "links each topic")
      .hasText("Learning Rust");
    assert
      .dom(".reviewable-tag-request__requesters a")
      .exists({ count: 2 }, "lists every requester");
    assert.dom(`a[href="/review/12"]`).exists("links to the previous request");
    assert
      .dom(".reviewable-tag-request__resolution")
      .doesNotExist("has no resolution while pending");
  });

  test("shows how a request was resolved and which topics were skipped", async function (assert) {
    const reviewable = {
      payload: {
        name: "rust",
        resolution: "created",
        tag_name: "rust",
        skipped: {
          5: "tag_limit_reached",
          6: "The tag you selected cannot be used",
        },
      },
      associated_topics: [
        { id: 5, title: "Full topic", slug: "full-topic" },
        { id: 6, title: "Restricted topic", slug: "restricted-topic" },
        { id: 7, title: "Tagged topic", slug: "tagged-topic" },
      ],
      requesters: [],
    };

    await render(
      <template><ReviewableTagRequest @reviewable={{reviewable}} /></template>
    );

    assert.dom(".reviewable-tag-request__resolution").hasText(
      i18n("discourse_tag_requests.reviewables.resolutions.created", {
        tag: "rust",
      }),
      "describes the outcome"
    );
    assert
      .dom(".reviewable-tag-request__skip-reason")
      .exists({ count: 2 }, "marks only the skipped topics");
    assert
      .dom(
        ".reviewable-tag-request__topic:nth-child(1) .reviewable-tag-request__skip-reason"
      )
      .hasText(
        i18n(
          "discourse_tag_requests.reviewables.skip_reasons.tag_limit_reached"
        ),
        "translates the plugin's own reasons"
      );
    assert
      .dom(
        ".reviewable-tag-request__topic:nth-child(2) .reviewable-tag-request__skip-reason"
      )
      .hasText(
        "The tag you selected cannot be used",
        "shows core's messages as they are"
      );
  });
});
