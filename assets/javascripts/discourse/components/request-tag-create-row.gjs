import SelectKitRow from "discourse/select-kit/components/select-kit/select-kit-row";
import { i18n } from "discourse-i18n";

/**
 * The tag chooser's "create" row, relabelled for users who can only request
 * new tags.
 */
export default class RequestTagCreateRow extends SelectKitRow {
  <template>
    <span class="name">
      {{i18n "discourse_tag_requests.composer.request_tag" name=this.rowName}}
    </span>
  </template>
}
