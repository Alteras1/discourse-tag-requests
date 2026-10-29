import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import { cloneJSON } from "discourse/lib/object";
import { fixturesByUrl } from "discourse/tests/helpers/create-pretender";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Discourse Tag Requests | requested tags", function (needs) {
  needs.user();
  needs.settings({
    discourse_tag_requests_enabled: true,
    tagging_enabled: true,
  });
  needs.pretender((server, helper) => {
    server.get("/latest.json", () => {
      const json = cloneJSON(fixturesByUrl["/latest.json"]);
      json.topic_list.topics[0].requested_tags = ["rust"];
      return helper.response(json);
    });
  });

  test("shows pending requested tags in the topic list", async function (assert) {
    await visit("/latest");

    assert
      .dom(".topic-list-item:first-of-type .discourse-tag.requested-tag")
      .hasText("rust", "renders the requested tag on its topic")
      .hasAttribute(
        "href",
        "/filter?q=pending-tag%3Arust",
        "links to the topics that requested it"
      );
    assert
      .dom(".topic-list-item:nth-of-type(2) .requested-tag")
      .doesNotExist("leaves other topics alone");
  });
});
