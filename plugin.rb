# frozen_string_literal: true

# name: discourse-tag-requests
# about: TODO
# meta_topic_id: TODO
# version: 0.0.1
# authors: Discourse
# url: TODO
# required_version: 2.7.0

enabled_site_setting :discourse_tag_requests_enabled

module ::DiscourseTagRequests
  PLUGIN_NAME = "discourse-tag-requests"
end

require_relative "lib/discourse_tag_requests/engine"

after_initialize do
  # Code which should run after Rails has finished booting
end
