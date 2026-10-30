import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance(
  "Discourse Tag Requests | composer requestedTagNames",
  function (needs) {
    needs.user({ can_request_tags: true });
    needs.settings({ discourse_tag_requests_enabled: true });

    function createComposer(owner, tags) {
      return owner.lookup("service:store").createRecord("composer", { tags });
    }

    test("lists new tags as requests for users who can't create tags", async function (assert) {
      await visit("/");
      const composer = createComposer(this.owner, [
        { id: 1, name: "ruby" },
        { id: "rust", name: "rust", isNew: true },
      ]);
      assert.deepEqual(composer.requestedTagNames, ["rust"]);
    });

    test("lists nothing for users who can't request tags", async function (assert) {
      await visit("/");
      this.owner.lookup("service:current-user").set("can_request_tags", false);
      const composer = createComposer(this.owner, [
        { id: "rust", name: "rust", isNew: true },
      ]);

      assert.deepEqual(composer.requestedTagNames, []);
    });

    test("restores requests from a draft", async function (assert) {
      await visit("/");
      const composer = createComposer(this.owner, [
        { id: 1, name: "ruby" },
        { name: "rust" },
      ]);

      composer.set("requestedTagNames", ["rust"]);

      assert.deepEqual(composer.tags, [
        { id: 1, name: "ruby" },
        { id: "rust", name: "rust", isNew: true },
      ]);
    });
  }
);
