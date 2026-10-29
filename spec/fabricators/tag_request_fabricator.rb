# frozen_string_literal: true

Fabricator(:reviewable_tag_request) do
  reviewable_by_moderator true
  created_by { Fabricate(:user) }
  payload { { name: "requested-tag", normalized_name: "requested-tag" } }
end

Fabricator(:tag_request, class_name: "DiscourseTagRequests::TagRequest") do
  name { sequence(:tag_request_name) { |index| "requested-tag-#{index}" } }
  reviewable do |attrs|
    Fabricate(
      :reviewable_tag_request,
      payload: {
        name: attrs[:name],
        normalized_name: attrs[:name].downcase,
      },
    )
  end
end

Fabricator(:tag_request_topic, class_name: "DiscourseTagRequests::TagRequestTopic") do
  tag_request
  topic
  requested_by { |attrs| attrs[:topic].user }
end
