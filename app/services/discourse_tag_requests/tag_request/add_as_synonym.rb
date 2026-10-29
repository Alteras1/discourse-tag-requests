# frozen_string_literal: true

module DiscourseTagRequests
  class TagRequest::AddAsSynonym
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
      policy :can_create_tag
      model :tag
      policy :can_edit_target_tag
      step :add_synonym
      model :skipped_topics, :apply_tag, optional: true
      step :record_resolution
      step :resolve_tag_request
    end

    private

    def can_edit_target_tag(guardian:, tag:)
      guardian.can_edit_tag?(tag)
    end

    def add_synonym(tag_request:, tag:)
      outcome = DiscourseTagging.add_or_create_synonyms(tag, new_synonym_names: [tag_request.name])
      fail!(outcome.values.join(" ")) if outcome != true
    end

    def record_resolution(tag_request:, tag:, skipped_topics:)
      tag_request.reviewable.record_resolution!(
        resolution: "synonym",
        tag:,
        skipped: skipped_topics,
      )
    end
  end
end
