# frozen_string_literal: true

require_dependency "reviewable_serializer"

class ReviewableTagRequestSerializer < ReviewableSerializer
  payload_attributes :name,
                     :previous_reviewable_id,
                     :resolution,
                     :tag_id,
                     :tag_name,
                     :tag_slug,
                     :skipped

  attributes :existing_tag

  has_many :associated_topics, serializer: BasicTopicSerializer, embed: :objects
  has_many :requesters, serializer: BasicUserSerializer, embed: :objects

  def existing_tag
    { id: found_existing_tag.id, name: found_existing_tag.name, slug: found_existing_tag.slug }
  end

  def include_existing_tag?
    object.pending? && found_existing_tag.present?
  end

  private

  def found_existing_tag
    return @found_existing_tag if defined?(@found_existing_tag)
    @found_existing_tag = object.existing_tag
  end
end
