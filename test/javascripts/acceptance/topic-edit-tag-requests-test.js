import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { cloneJSON } from "discourse/lib/object";
import pretender, {
  fixturesByUrl,
  response,
} from "discourse/tests/helpers/create-pretender";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";

acceptance("Discourse Tag Requests | topic edit", function (needs) {
  needs.user({ id: 1, can_request_tags: true });
  needs.site({ can_tag_topics: true, can_create_tag: false });
  needs.settings({
    discourse_tag_requests_enabled: true,
    max_tag_requests_per_topic: 3,
    max_tags_per_topic: 5,
    tagging_enabled: true,
  });
  needs.pretender((server, helper) => {
    server.get("/tags/filter/search", () => helper.response({ results: [] }));
    server.get("/t/280.json", () => {
      const json = cloneJSON(fixturesByUrl["/t/280/1.json"]);
      json.user_id = 1;
      json.requested_tags = ["rust"];
      return response(json);
    });
    server.put("/tag-requests/topics/280", ({ requestBody }) => {
      const names = new URLSearchParams(requestBody).getAll("tag_names[]");
      return response({ requested_tags: names });
    });
  });

  function handledRequest(method, url) {
    return pretender.handledRequests.find(
      (request) => request.method === method && request.url.startsWith(url)
    );
  }

  test("shows pending requests and requests another tag", async function (assert) {
    await visit("/t/280");
    await click(".title-wrapper .edit-topic");

    const chooser = selectKit(".edit-tags__wrapper .mini-tag-chooser");
    assert
      .dom(".edit-tags__wrapper .requested-tag-choice")
      .hasText("rust", "shows the topic's pending request");

    await chooser.expand();
    await chooser.fillInFilter("go");
    await chooser.selectRowByIndex(0);
    await click("#topic-title .submit-edit");

    assert.dom("#topic-title .edit-tags__wrapper").doesNotExist("saves");
    assert.deepEqual(
      new URLSearchParams(
        handledRequest("PUT", "/tag-requests/topics/280").requestBody
      ).getAll("tag_names[]"),
      ["rust", "go"],
      "sends the kept and the new request"
    );
    assert.false(
      handledRequest(
        "PUT",
        "/t/internationalization-localization/280"
      ).requestBody.includes("requested_tag"),
      "keeps requests out of the topic update"
    );
  });

  test("withdraws a pending request", async function (assert) {
    await visit("/t/280");
    await click(".title-wrapper .edit-topic");

    await click(".edit-tags__wrapper .requested-tag-choice");
    await click("#topic-title .submit-edit");

    assert.deepEqual(
      new URLSearchParams(
        handledRequest("PUT", "/tag-requests/topics/280").requestBody
      ).getAll("tag_names[]"),
      [],
      "sends no names"
    );
  });
});
