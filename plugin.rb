# frozen_string_literal: true

# name: discourse-tag-requests
# about: Lets users request new tags on their topics for staff to review.
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

after_initialize do
  reloadable_patch { Topic.prepend(DiscourseTagRequests::TopicExtension) }

  register_reviewable_type ReviewableTagRequest

  add_permitted_post_create_param(:requested_tag_names, :array)
  allow_new_queued_post_payload_attribute(:requested_tag_names)

  # Requests never block topic creation, so the outcome is deliberately ignored.
  on(:topic_created) do |topic, opts, user|
    next if user.nil? || opts[:requested_tag_names].blank?

    DiscourseTagRequests::TagRequest::Submit.call(
      params: {
        topic_id: topic.id,
        tag_names: opts[:requested_tag_names],
      },
      guardian: user.guardian,
    )
  end

  add_filter_custom_filter("pending-tag") do |scope, values, guardian|
    DiscourseTagRequests::PendingTagFilter.new(scope:, values:, guardian:).call
  end

  # Authors always see requests on their own topics, so any signed-in user
  # may have something to filter by.
  register_modifier(:topics_filter_options) do |results, guardian|
    if guardian.authenticated? ||
         guardian.in_any_groups?(SiteSetting.tag_requests_visible_to_groups_map)
      results << {
        name: "pending-tag:",
        description: I18n.t("discourse_tag_requests.filter.description.pending_tag"),
        type: "text",
        delimiters: [
          {
            name: ",",
            description: I18n.t("discourse_tag_requests.filter.description.pending_tag_any"),
          },
          {
            name: "+",
            description: I18n.t("discourse_tag_requests.filter.description.pending_tag_all"),
          },
        ],
        prefixes: [
          {
            name: "-",
            description: I18n.t("discourse_tag_requests.filter.description.exclude_pending_tag"),
          },
        ],
      }
    end
    results
  end
end
