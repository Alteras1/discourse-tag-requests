import Component from "@glimmer/component";
import getURL from "discourse/lib/get-url";
import { i18n } from "discourse-i18n";

const SKIP_REASONS = [
  "deleted",
  "private_message",
  "tag_limit_reached",
  "not_allowed_in_category",
];

export default class ReviewableTagRequest extends Component {
  get topics() {
    const skipped = this.args.reviewable.payload?.skipped || {};

    return (this.args.reviewable.associated_topics || []).map((topic) => ({
      id: topic.id,
      title: topic.title,
      url: getURL(`/t/${topic.slug}/${topic.id}`),
      skipReason: this.#skipReason(skipped[topic.id]),
    }));
  }

  get requesters() {
    return (this.args.reviewable.requesters || []).map((user) => ({
      username: user.username,
      url: getURL(`/u/${user.username}`),
    }));
  }

  get resolution() {
    const { resolution, tag_name } = this.args.reviewable.payload || {};
    if (!resolution) {
      return;
    }

    return i18n(
      `discourse_tag_requests.reviewables.resolutions.${resolution}`,
      {
        tag: tag_name,
      }
    );
  }

  get previousReviewableUrl() {
    const id = this.args.reviewable.payload?.previous_reviewable_id;
    return id && getURL(`/review/${id}`);
  }

  // Core's skip reasons are already translated messages; ours are keys.
  #skipReason(reason) {
    if (!reason) {
      return;
    }

    return SKIP_REASONS.includes(reason)
      ? i18n(`discourse_tag_requests.reviewables.skip_reasons.${reason}`)
      : reason;
  }

  <template>
    {{#if @reviewable.existing_tag}}
      <div class="alert alert-info reviewable-tag-request__existing-tag">
        {{i18n
          "discourse_tag_requests.reviewables.existing_tag"
          tag=@reviewable.existing_tag.name
        }}
      </div>
    {{/if}}

    <div class="review-item__meta-content">
      <div class="review-item__meta-label">
        {{i18n "discourse_tag_requests.reviewables.requested_tag"}}
      </div>
      <div class="review-item__meta-value">
        <span
          class="discourse-tag requested-tag reviewable-tag-request__name"
        >{{@reviewable.payload.name}}</span>
      </div>

      {{#if this.resolution}}
        <div class="review-item__meta-label">
          {{i18n "discourse_tag_requests.reviewables.resolution"}}
        </div>
        <div class="review-item__meta-value reviewable-tag-request__resolution">
          {{this.resolution}}
        </div>
      {{/if}}

      <div class="review-item__meta-label">
        {{i18n "discourse_tag_requests.reviewables.topics"}}
      </div>
      <div class="review-item__meta-value">
        {{#if this.topics.length}}
          <ul class="reviewable-tag-request__topics">
            {{#each this.topics as |topic|}}
              <li class="reviewable-tag-request__topic">
                <a href={{topic.url}}>{{topic.title}}</a>
                {{#if topic.skipReason}}
                  <span class="reviewable-tag-request__skip-reason">
                    {{topic.skipReason}}
                  </span>
                {{/if}}
              </li>
            {{/each}}
          </ul>
        {{else}}
          {{i18n "discourse_tag_requests.reviewables.no_topics"}}
        {{/if}}
      </div>

      <div class="review-item__meta-label">
        {{i18n "discourse_tag_requests.reviewables.requested_by"}}
      </div>
      <div class="review-item__meta-value">
        <ul class="reviewable-tag-request__requesters">
          {{#each this.requesters as |requester|}}
            <li>
              <a
                data-user-card={{requester.username}}
                href={{requester.url}}
              >{{requester.username}}</a>
            </li>
          {{/each}}
        </ul>
      </div>

      {{#if this.previousReviewableUrl}}
        <div class="review-item__meta-label">
          {{i18n "discourse_tag_requests.reviewables.previous_request"}}
        </div>
        <div class="review-item__meta-value">
          <a href={{this.previousReviewableUrl}}>
            {{i18n "discourse_tag_requests.reviewables.view_previous_request"}}
          </a>
        </div>
      {{/if}}
    </div>

    {{yield}}
  </template>
}
