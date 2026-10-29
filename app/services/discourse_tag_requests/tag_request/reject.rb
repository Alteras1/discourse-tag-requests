# frozen_string_literal: true

module DiscourseTagRequests
  class TagRequest::Reject
    include Service::Base
    include TagRequest::Concerns::Resolution

    params do
      attribute :reviewable_id, :integer
      attribute :permanently, :boolean, default: false

      validates :reviewable_id, presence: true

      def resolution
        permanently ? "rejected_permanently" : "rejected"
      end
    end

    transaction do
      # The row lock only holds inside a transaction, so the lookup lives in it.
      policy :can_review_tag_request
      model :tag_request
      policy :tag_request_pending
      step :record_resolution
      step :reject_tag_request
    end

    private

    # Recorded first: a permanent rejection deletes the topics it snapshots.
    def record_resolution(params:, tag_request:)
      tag_request.reviewable.record_resolution!(resolution: params.resolution)
    end

    def reject_tag_request(params:, tag_request:)
      tag_request.reject!(permanently: params.permanently)
    end
  end
end
