# frozen_string_literal: true

module DiscourseTagRequests
  class TagRequest::Approve
    include Service::Base
    include TagRequest::Concerns::Resolution

    params do
      attribute :reviewable_id, :integer

      validates :reviewable_id, presence: true
    end

    transaction do
      # The row lock only holds inside a transaction, so the lookup lives in it.
      policy :can_review_tag_request
      model :tag_request
      policy :tag_request_pending
      policy :can_create_tag
      model :tag, :create_tag
      model :skipped_topics, :apply_tag, optional: true
      step :record_resolution
      step :resolve_tag_request
    end

    private

    # Re-cleaned so a `force_lowercase_tags` change since the request applies.
    def create_tag(tag_request:)
      Tag.create(name: DiscourseTagging.clean_tag(tag_request.name))
    end

    def record_resolution(tag_request:, tag:, skipped_topics:)
      tag_request.reviewable.record_resolution!(
        resolution: "created",
        tag:,
        skipped: skipped_topics,
      )
    end
  end
end
