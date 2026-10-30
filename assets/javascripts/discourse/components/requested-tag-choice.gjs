import SelectedChoice from "discourse/select-kit/components/selected-choice";
import dIcon from "discourse/ui-kit/helpers/d-icon";

/** Marks requested tags in the tag chooser's list of selected tags. */
const RequestedTagChoice = <template>
  {{#if @item.isNew}}
    <SelectedChoice
      @extraClass="requested-tag-choice"
      @item={{@item}}
      @mandatoryValues={{@mandatoryValues}}
      @mandatoryValueTitle={{@mandatoryValueTitle}}
      @selectKit={{@selectKit}}
    >
      {{dIcon "circle-dashed"}}
      <span class="d-button-label">{{@item.name}}</span>
    </SelectedChoice>
  {{else}}
    <SelectedChoice
      @item={{@item}}
      @mandatoryValues={{@mandatoryValues}}
      @mandatoryValueTitle={{@mandatoryValueTitle}}
      @selectKit={{@selectKit}}
    />
  {{/if}}
</template>;

export default RequestedTagChoice;
