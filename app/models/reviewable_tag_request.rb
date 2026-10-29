# frozen_string_literal: true

class ReviewableTagRequest < Reviewable
  has_one :tag_request, class_name: "DiscourseTagRequests::TagRequest", foreign_key: :reviewable_id

  def serializer
    ReviewableTagRequestSerializer
  end

  def build_actions(actions, guardian, args)
  end

  def requested_name
    payload["name"]
  end

  # Once resolved or hard-rejected the associations are deleted, so fall back
  # to the snapshot written into the payload at that point.
  def associated_topic_ids
    if tag_request
      tag_request.tag_request_topics.pluck(:topic_id)
    else
      payload["topic_ids"] || []
    end
  end

  def requester_ids
    if tag_request
      tag_request.tag_request_topics.distinct.pluck(:requested_by_id)
    else
      payload["requester_ids"] || []
    end
  end

  def associated_topics
    Topic.where(id: associated_topic_ids).order(:id)
  end

  def requesters
    User.where(id: requester_ids).order(:id)
  end

  # The canonical tag that already uses the requested name, if any.
  def existing_tag
    tag = Tag.where_name(requested_name).includes(:target_tag).first
    tag&.target_tag || tag
  end
end

# == Schema Information
#
# Table name: reviewables
#
#  id                      :bigint           not null, primary key
#  force_review            :boolean          default(FALSE), not null
#  latest_score            :datetime
#  payload                 :json
#  potential_spam          :boolean          default(FALSE), not null
#  potentially_illegal     :boolean          default(FALSE)
#  reject_reason           :text
#  reviewable_by_moderator :boolean          default(FALSE), not null
#  score                   :float            default(0.0), not null
#  status                  :integer          default("pending"), not null
#  target_type             :string
#  type                    :string           not null
#  type_source             :string           default("unknown"), not null
#  version                 :integer          default(0), not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  category_id             :integer
#  created_by_id           :integer          not null
#  target_created_by_id    :integer
#  target_id               :integer
#  topic_id                :integer
#
# Indexes
#
#  idx_reviewables_score_desc_created_at_desc                  (score DESC,created_at DESC)
#  index_reviewables_on_reviewable_by_group_id                 (reviewable_by_group_id)
#  index_reviewables_on_status_and_created_at                  (status,created_at)
#  index_reviewables_on_status_and_score                       (status,score)
#  index_reviewables_on_status_and_type                        (status,type)
#  index_reviewables_on_target_created_by_id                   (target_created_by_id)
#  index_reviewables_on_target_id_where_post_type_eq_post      (target_id) WHERE ((target_type)::text = 'Post'::text)
#  index_reviewables_on_topic_id_and_status_and_created_by_id  (topic_id,status,created_by_id)
#  index_reviewables_on_type_and_target_id                     (type,target_id) UNIQUE
#
