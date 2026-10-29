# frozen_string_literal: true

module DiscourseTagRequests
  # Step methods shared by the services that resolve a tag request from the
  # review queue. Each service still declares its own steps.
  module TagRequest::Concerns::Resolution
    extend ActiveSupport::Concern

    private

    def can_review_tag_request(params:, guardian:)
      Reviewable.viewable_by(guardian.user, preload: false).exists?(id: params.reviewable_id)
    end

    def fetch_tag_request(params:)
      TagRequest.lock.find_by(reviewable_id: params.reviewable_id)
    end

    def tag_request_pending(tag_request:)
      tag_request.pending?
    end

    def can_create_tag(guardian:)
      guardian.can_create_tag?
    end

    def fetch_tag(params:, guardian:)
      tag = DiscourseTagging.visible_tags(guardian).find_by(id: params.target_tag_id)
      tag&.target_tag || tag
    end

    def apply_tag(tag_request:, tag:, guardian:)
      TagRequest::Action::ApplyTag.call(
        tag:,
        topics: tag_request.tag_request_topics.includes(topic: :tags).map(&:topic),
        guardian:,
      )
    end

    def resolve_tag_request(tag_request:)
      tag_request.destroy!
    end
  end
end
