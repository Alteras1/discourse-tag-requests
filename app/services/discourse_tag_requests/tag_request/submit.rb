# frozen_string_literal: true

module DiscourseTagRequests
  class TagRequest::Submit
    include Service::Base

    params do
      attribute :topic_id, :integer
      # Untyped: the `:array` cast turns numeric-looking names like "007" into integers.
      attribute :tag_names

      validates :topic_id, presence: true
      validates :tag_names, presence: true

      before_validation { self.tag_names = TagRequest.clean_names(tag_names) }
    end

    model :topic
    policy :can_request_tags
    model :requestable_names

    each :requestable_names, as: :requested_name do
      lock(:requested_name) do
        transaction do
          model :tag_request, :open_tag_request, optional: true
          only_if(:tag_request_open) { model :tag_request_topic, :attach_topic }
        end
      end
      only_if(:tag_request_open) { step :sync_priority }
    end

    private

    def fetch_topic(params:)
      Topic.find_by(id: params.topic_id)
    end

    def can_request_tags(guardian:, topic:)
      guardian.can_request_tags_on?(topic)
    end

    def fetch_requestable_names(params:, topic:)
      TagRequest
        .requestable_names(params.tag_names)
        .first(topic.tag_request_allowance)
        .map { |name| TagRequest::RequestedName.new(name:) }
    end

    def open_tag_request(requested_name:, guardian:)
      TagRequest::Action::Open.call(name: requested_name.name, requested_by: guardian.user)
    end

    def tag_request_open(tag_request:)
      tag_request.present?
    end

    def attach_topic(tag_request:, topic:, guardian:)
      tag_request
        .tag_request_topics
        .find_or_create_by(topic:) do |tag_request_topic|
          tag_request_topic.requested_by = guardian.user
        end
    end

    def sync_priority(tag_request:)
      tag_request.reviewable.sync_priority!
    end
  end
end
