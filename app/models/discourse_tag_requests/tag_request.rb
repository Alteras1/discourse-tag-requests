# frozen_string_literal: true

module DiscourseTagRequests
  class TagRequest < ActiveRecord::Base
    self.table_name = "tag_requests"

    enum :status, { pending: 0, soft_rejected: 1, hard_rejected: 2 }

    belongs_to :reviewable
    has_many :tag_request_topics,
             class_name: "DiscourseTagRequests::TagRequestTopic",
             dependent: :delete_all
    has_many :topics, through: :tag_request_topics

    validates :name, presence: true

    before_validation { self.normalized_name = name&.downcase }

    scope :for_name, ->(name) { where(normalized_name: name.downcase) }

    # Names that are neither taken by a tag or synonym, reserved, nor permanently
    # rejected. Expects names already cleaned with `DiscourseTagging.clean_tag`.
    def self.requestable_names(names)
      downcased = names.map(&:downcase)
      blocked = hard_rejected.where(normalized_name: downcased).pluck(:normalized_name)
      existing = Tag.where_name(names).pluck("lower(tags.name)")
      names.select do |name|
        dn = name.downcase
        blocked.exclude?(dn) && existing.exclude?(dn) && Tag.new(name:).valid?
      end
    end

    def self.open!(name:, requested_by:)
      create!(name:, reviewable: ReviewableTagRequest.open!(name:, requested_by:))
    end

    def reopen!(requested_by:)
      update!(
        status: :pending,
        reviewable:
          ReviewableTagRequest.open!(name:, requested_by:, previous_reviewable_id: reviewable_id),
      )
    end

    # A soft rejection keeps the topics so a later request revives them; a
    # permanent one only needs the row itself to block the name.
    def reject!(permanently:)
      tag_request_topics.delete_all if permanently
      update!(status: permanently ? :hard_rejected : :soft_rejected)
    end
  end
end

# == Schema Information
#
# Table name: tag_requests
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
#  index_tag_requests_on_normalized_name  (normalized_name) UNIQUE
#  index_tag_requests_on_reviewable_id    (reviewable_id) UNIQUE
#
