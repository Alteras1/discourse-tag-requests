# frozen_string_literal: true

module DiscourseTagRequests
  module TopicExtension
    extend ActiveSupport::Concern

    prepended do
      has_many :tag_request_topics,
               class_name: "DiscourseTagRequests::TagRequestTopic",
               dependent: :delete_all

      # Pending request names visible to the current viewer, or nil unless a
      # topic list preloaded them (they depend on the viewer, so there's no
      # fallback query here).
      attr_reader :requested_tag_names
    end

    def preload_requested_tag_names(names)
      @requested_tag_names = names
    end

    # Requested tags count toward the topic's tag limit, so they only fill
    # slots real tags leave free.
    def tag_request_allowance
      pending_requests = tag_request_topics.joins(:tag_request).merge(TagRequest.pending).count
      limit = [
        SiteSetting.max_tag_requests_per_topic,
        SiteSetting.max_tags_per_topic - tags.count,
      ].min
      [limit - pending_requests, 0].max
    end
  end
end
