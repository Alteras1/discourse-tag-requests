# frozen_string_literal: true

# name: discourse-tag-requests
# about: Lets users suggest new tags on their topics for staff to review.
# meta_topic_id: TODO
# version: 0.0.1
# authors: Alteras1
# url: https://github.com/Alteras1/discourse-tag-requests
# required_version: 2.7.0

enabled_site_setting :discourse_tag_requests_enabled

module ::DiscourseTagRequests
  PLUGIN_NAME = "discourse-tag-requests"
end

require_relative "lib/discourse_tag_requests/engine"

after_initialize { reloadable_patch { Topic.prepend(DiscourseTagRequests::TopicExtension) } }
