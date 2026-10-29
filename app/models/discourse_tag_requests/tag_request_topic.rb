# frozen_string_literal: true

module DiscourseTagRequests
  class TagRequestTopic < ActiveRecord::Base
    self.table_name = "tag_request_topics"

    belongs_to :tag_request, class_name: "DiscourseTagRequests::TagRequest"
    belongs_to :topic, -> { with_deleted }
    belongs_to :requested_by, class_name: "User"

    # Does not check topic visibility; callers must already be scoped to topics
    # the viewer can see.
    scope :visible_to,
          ->(guardian) do
            visible =
              joins(:tag_request, :topic).merge(TagRequest.pending).where(
                topics: {
                  deleted_at: nil,
                },
              )

            if guardian.is_staff? ||
                 guardian.in_any_groups?(SiteSetting.tag_requests_visible_to_groups_map)
              visible
            elsif guardian.anonymous?
              visible.none
            else
              visible.where(topics: { user_id: guardian.user.id })
            end
          end

    # `{ topic_id => [requested names] }` for the pending requests the viewer may see.
    def self.pending_names_by_topic_id(topic_ids, guardian)
      visible_to(guardian)
        .where(topic_id: topic_ids)
        .order("tag_requests.name")
        .pluck(:topic_id, "tag_requests.name")
        .group_by(&:first)
        .transform_values { |pairs| pairs.map(&:last) }
    end
  end
end

# == Schema Information
#
# Table name: tag_request_topics
#
#  id              :bigint           not null, primary key
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  requested_by_id :integer          not null
#  tag_request_id  :bigint           not null
#  topic_id        :integer          not null
#
# Indexes
#
#  index_tag_request_topics_on_tag_request_id_and_topic_id  (tag_request_id,topic_id) UNIQUE
#  index_tag_request_topics_on_topic_id                     (topic_id)
#
