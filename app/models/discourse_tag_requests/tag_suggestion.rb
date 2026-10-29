# frozen_string_literal: true

module DiscourseTagRequests
  class TagSuggestion < ActiveRecord::Base
    self.table_name = "tag_suggestions"

    enum :status, { pending: 0, soft_rejected: 1, hard_rejected: 2 }

    belongs_to :reviewable
    has_many :tag_suggestion_topics,
             class_name: "DiscourseTagRequests::TagSuggestionTopic",
             dependent: :delete_all
    has_many :topics, through: :tag_suggestion_topics

    validates :name, presence: true

    before_validation { self.normalized_name = name&.downcase }

    scope :for_name, ->(name) { where(normalized_name: name.downcase) }
  end
end

# == Schema Information
#
# Table name: tag_suggestions
#
#  id              :bigint           not null, primary key
#  name            :string           not null
#  normalized_name :string           not null
#  status          :integer          default("pending"), not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  reviewable_id   :bigint           not null
#
# Indexes
#
#  index_tag_suggestions_on_normalized_name  (normalized_name) UNIQUE
#  index_tag_suggestions_on_reviewable_id    (reviewable_id) UNIQUE
#
