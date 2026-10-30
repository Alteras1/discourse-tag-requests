# frozen_string_literal: true

# name: discourse-tag-requests
# about: Lets users request new tags on their topics for staff to review.
# meta_topic_id: TODO
# version: 0.0.1
# authors: Alteras1
# url: https://github.com/Alteras1/discourse-tag-requests
# required_version: 2.7.0

enabled_site_setting :discourse_tag_requests_enabled

register_asset "stylesheets/requested-tags.scss"
register_svg_icon "circle-dashed"

module ::DiscourseTagRequests
  PLUGIN_NAME = "discourse-tag-requests"
end

require_relative "lib/discourse_tag_requests/engine"

after_initialize do
  reloadable_patch do
    Topic.prepend(DiscourseTagRequests::TopicExtension)
    Guardian.prepend(DiscourseTagRequests::GuardianExtension)
  end

  register_reviewable_type ReviewableTagRequest

  add_to_serializer(:current_user, :can_request_tags) { scope.can_request_tags? }

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

  TopicList.on_preload do |topics, topic_list|
    next if !SiteSetting.discourse_tag_requests_enabled || topics.empty?

    names_by_topic_id =
      DiscourseTagRequests::TagRequestTopic.pending_names_by_topic_id(
        topics.map(&:id),
        Guardian.new(topic_list.current_user),
      )
    topics.each { |topic| topic.preload_requested_tag_names(names_by_topic_id[topic.id]) }
  end

  # Suggested and related topics are serialized separately from topic lists,
  # but their topics are still loaded through `TopicList`, so they're preloaded.
  %i[topic_list_item suggested_topic].each do |serializer|
    add_to_serializer(
      serializer,
      :requested_tags,
      include_condition: -> { object.requested_tag_names.present? },
    ) { object.requested_tag_names }
  end

  add_to_serializer(
    :topic_view,
    :requested_tags,
    include_condition: -> { requested_tags.present? },
  ) do
    @requested_tags ||=
      DiscourseTagRequests::TagRequestTopic.pending_names_by_topic_id([object.topic.id], scope)[
        object.topic.id
      ]
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
