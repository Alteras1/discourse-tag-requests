# frozen_string_literal: true

Fabricator(:tag_suggestion, class_name: "DiscourseTagRequests::TagSuggestion") do
  name { sequence(:tag_suggestion_name) { |index| "suggested-tag-#{index}" } }
  reviewable
end

Fabricator(:tag_suggestion_topic, class_name: "DiscourseTagRequests::TagSuggestionTopic") do
  tag_suggestion
  topic
  suggested_by { |attrs| attrs[:topic].user }
end
