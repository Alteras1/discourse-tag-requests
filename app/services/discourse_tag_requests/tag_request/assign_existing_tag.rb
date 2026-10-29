# frozen_string_literal: true

module DiscourseTagRequests
  class TagRequest::AssignExistingTag
    include Service::Base
    include TagRequest::Concerns::Resolution

    params do
      attribute :reviewable_id, :integer
      attribute :target_tag_id, :integer

      validates :reviewable_id, :target_tag_id, presence: true
    end

    transaction do
      # The row lock only holds inside a transaction, so the lookup lives in it.
      policy :can_review_tag_request
      model :tag_request
      policy :tag_request_pending
      model :tag
      model :skipped_topics, :apply_tag, optional: true
      step :record_resolution
      step :resolve_tag_request
    end

    private

    def record_resolution(tag_request:, tag:, skipped_topics:)
      tag_request.reviewable.record_resolution!(
        resolution: "existing",
        tag:,
        skipped: skipped_topics,
      )
    end
  end
end
