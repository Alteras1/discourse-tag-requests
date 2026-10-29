# frozen_string_literal: true

module DiscourseTagRequests
  # Narrows a `/filter` topic scope by `pending-tag:` values, using the same
  # syntax as core's `tag:`: `a,b` matches any name, `a+b` matches all.
  class PendingTagFilter
    NAME = /[\p{N}\p{L}\-_.]+/
    VALUE_PATTERN = /\A#{NAME}(?:(?<delimiter>[,+])#{NAME}(?:\k<delimiter>#{NAME})*)?\z/

    def initialize(scope:, values:, guardian:)
      @scope = scope
      @values = values
      @guardian = guardian
    end

    def call
      @values.reduce(@scope) { |scope, value| narrow(scope, value.to_s) }
    end

    private

    def narrow(scope, value)
      match = value.match(VALUE_PATTERN)
      return scope.none if match.nil?

      names = value.downcase.split(match[:delimiter] || ",")
      if match[:delimiter] == "+"
        names.reduce(scope) { |narrowed, name| narrowed.where(id: topic_ids_for([name])) }
      else
        scope.where(id: topic_ids_for(names))
      end
    end

    def topic_ids_for(names)
      TagRequestTopic
        .visible_to(@guardian)
        .where(tag_requests: { normalized_name: names })
        .select(:topic_id)
    end
  end
end
