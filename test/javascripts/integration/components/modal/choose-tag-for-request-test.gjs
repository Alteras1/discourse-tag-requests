import { click, render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import ModalContainer from "discourse/components/modal-container";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { i18n } from "discourse-i18n";
import ChooseTagForRequestModal from "discourse/plugins/discourse-tag-requests/discourse/components/modal/choose-tag-for-request";

module(
  "Integration | Component | Modal | ChooseTagForRequest",
  function (hooks) {
    setupRenderingTest(hooks);

    async function showModal(owner, model) {
      await render(<template><ModalContainer /></template>);
      owner.lookup("service:modal").show(ChooseTagForRequestModal, { model });
      await settled();
    }

    test("resolves with the pre-selected existing tag", async function (assert) {
      const performConfirmed = sinon.spy();
      const action = { server_action: "use_existing_tag" };

      await showModal(this.owner, {
        reviewable: {
          payload: { name: "rust" },
          existing_tag: { id: 3, name: "rust-lang" },
        },
        action,
        performConfirmed,
      });

      assert
        .dom(".d-modal__title")
        .hasText(
          i18n(
            "discourse_tag_requests.reviewables.choose_tag.use_existing_tag.title"
          ),
          "uses the action's title"
        );

      await click(".form-kit__button");

      assert.true(
        performConfirmed.calledOnceWith(action, { target_tag_id: 3 }),
        "performs the action with the chosen tag"
      );
    });

    test("requires a tag", async function (assert) {
      const performConfirmed = sinon.spy();

      await showModal(this.owner, {
        reviewable: { payload: { name: "rust" } },
        action: { server_action: "add_as_synonym" },
        performConfirmed,
      });
      await click(".form-kit__button");

      assert.false(performConfirmed.called, "doesn't perform without a tag");
    });
  }
);
