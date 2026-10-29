import { click, render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import ModalContainer from "discourse/components/modal-container";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import ApproveAndEditTagRequestModal from "discourse/plugins/discourse-tag-requests/discourse/components/modal/approve-and-edit-tag-request";

module(
  "Integration | Component | Modal | ApproveAndEditTagRequest",
  function (hooks) {
    setupRenderingTest(hooks);

    async function approve(owner, payload) {
      pretender.get("/review/7.json", () =>
        response({ reviewable: { id: 7, payload } })
      );
      const performConfirmed = sinon.stub().resolves();
      const transitionTo = sinon.stub(
        owner.lookup("service:router"),
        "transitionTo"
      );

      await render(<template><ModalContainer /></template>);
      owner.lookup("service:modal").show(ApproveAndEditTagRequestModal, {
        model: {
          reviewable: { id: 7, payload: { name: "rust" } },
          action: { server_action: "approve_and_edit_tag_request" },
          performConfirmed,
        },
      });
      await settled();
      await click(".approve-and-edit-tag-request-modal .btn-primary");

      return { performConfirmed, transitionTo };
    }

    test("opens the new tag's settings after approving", async function (assert) {
      const { performConfirmed, transitionTo } = await approve(this.owner, {
        resolution: "created",
        tag_id: 9,
        tag_slug: "rust",
      });

      assert.true(performConfirmed.calledOnce, "approves the request");
      assert.true(
        transitionTo.calledOnceWith("tag.edit", "rust", 9),
        "opens the tag's edit page"
      );
    });

    test("stays put when the request wasn't approved", async function (assert) {
      const { transitionTo } = await approve(this.owner, { name: "rust" });

      assert.false(transitionTo.called, "doesn't navigate");
    });
  }
);
