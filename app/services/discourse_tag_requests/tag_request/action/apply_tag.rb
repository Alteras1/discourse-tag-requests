# frozen_string_literal: true

module DiscourseTagRequests
  class TagRequest::Action::ApplyTag < Service::ActionBase
    option :tag
    option :topics
    option :guardian

    # Returns the topics that didn't get the tag, as `{ topic_id => reason }`.
    def call
      topics.each_with_object({}) do |topic, skipped|
        reason = skip_reason(topic)
        skipped[topic.id] = reason if reason
      end
    end

    private

    def skip_reason(topic)
      return "deleted" if topic.trashed?
      return "private_message" if topic.private_message?
      return if topic.tags.include?(tag)
      return "tag_limit_reached" if topic.tags.size >= SiteSetting.max_tags_per_topic

      if !DiscourseTagging.tag_topic_by_names(topic, guardian, [tag.name], append: true)
        return topic.errors.full_messages.first
      end

      # Core drops tags the category doesn't allow without reporting an error.
      "not_allowed_in_category" if topic.tags.exclude?(tag)
    end
  end
end
