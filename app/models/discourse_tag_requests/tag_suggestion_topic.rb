# frozen_string_literal: true

module DiscourseTagRequests
  class TagSuggestionTopic < ActiveRecord::Base
    self.table_name = "tag_suggestion_topics"

    belongs_to :tag_suggestion, class_name: "DiscourseTagRequests::TagSuggestion"
    belongs_to :topic
    belongs_to :suggested_by, class_name: "User"

    # Does not check topic visibility; callers must already be scoped to topics
    # the viewer can see.
    scope :visible_to,
          ->(guardian) do
            visible =
              joins(:tag_suggestion, :topic).merge(TagSuggestion.pending).where(
                topics: {
                  deleted_at: nil,
                },
              )

            if guardian.is_staff? ||
                 guardian.in_any_groups?(SiteSetting.suggested_tags_visible_to_groups_map)
              visible
            elsif guardian.anonymous?
              visible.none
            else
              visible.where(topics: { user_id: guardian.user.id })
            end
          end
  end
end

# == Schema Information
#
# Table name: tag_suggestion_topics
#
#  id                :bigint           not null, primary key
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  suggested_by_id   :integer          not null
#  tag_suggestion_id :bigint           not null
#  topic_id          :integer          not null
#
# Indexes
#
#  index_tag_suggestion_topics_on_tag_suggestion_id_and_topic_id  (tag_suggestion_id,topic_id) UNIQUE
#  index_tag_suggestion_topics_on_topic_id                        (topic_id)
#
