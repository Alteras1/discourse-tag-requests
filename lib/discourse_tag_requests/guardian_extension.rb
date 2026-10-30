# frozen_string_literal: true

module DiscourseTagRequests
  module GuardianExtension
    # Users who can create tags create them directly, so they never request.
    def can_request_tags?
      SiteSetting.discourse_tag_requests_enabled && authenticated? && can_tag_topics? &&
        !can_create_tag? && in_any_groups?(SiteSetting.tag_requests_allowed_groups_map)
    end

    def can_request_tags_on?(topic)
      topic.regular? && can_request_tags? && topic.user_id == user.id
    end
  end
end
