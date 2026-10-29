# frozen_string_literal: true

module DiscourseTagRequests
  module TopicExtension
    extend ActiveSupport::Concern

    prepended do
      has_many :tag_request_topics,
               class_name: "DiscourseTagRequests::TagRequestTopic",
               dependent: :delete_all
    end
  end
end
