import Component from "@glimmer/component";
import { concat } from "@ember/helper";
import { action } from "@ember/object";
import Form from "discourse/form-kit/components/fk/form";
import DModal from "discourse/ui-kit/d-modal";
import { i18n } from "discourse-i18n";

/**
 * Picks the tag to resolve a tag request with, for the "use existing tag" and
 * "add as synonym" review actions.
 */
export default class ChooseTagForRequestModal extends Component {
  get formData() {
    const existingTag = this.args.model.reviewable.existing_tag;
    return { tags: existingTag ? [existingTag] : [] };
  }

  get translationPrefix() {
    return `discourse_tag_requests.reviewables.choose_tag.${this.args.model.action.server_action}`;
  }

  @action
  async submit(data) {
    this.args.closeModal();
    await this.args.model.performConfirmed(this.args.model.action, {
      target_tag_id: data.tags[0].id,
    });
  }

  <template>
    <DModal
      class="choose-tag-for-request-modal"
      @closeModal={{@closeModal}}
      @title={{i18n (concat this.translationPrefix ".title")}}
    >
      <:body>
        <p>{{i18n
            (concat this.translationPrefix ".description")
            name=@model.reviewable.payload.name
          }}</p>

        <Form @data={{this.formData}} @onSubmit={{this.submit}} as |form|>
          <form.Field
            @format="full"
            @name="tags"
            @title={{i18n "discourse_tag_requests.reviewables.choose_tag.tag"}}
            @type="tag-chooser"
            @validation="required"
            as |field|
          >
            <field.Control
              @excludeSynonyms={{true}}
              @maximum={{1}}
              @showAllTags={{true}}
            />
          </form.Field>

          <form.Submit @label={{concat this.translationPrefix ".submit"}} />
        </Form>
      </:body>
    </DModal>
  </template>
}
