# frozen_string_literal: true

module DiscourseTagRequests
  module TopicExtension
    extend ActiveSupport::Concern

    prepended do
      has_many :tag_suggestion_topics,
               class_name: "DiscourseTagRequests::TagSuggestionTopic",
               dependent: :delete_all
    end
  end
end
