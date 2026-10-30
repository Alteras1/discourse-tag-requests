# frozen_string_literal: true

module DiscourseTagRequests
  # Makes a topic's pending requests match the given names: requests that were
  # dropped are withdrawn, and names not yet requested are submitted.
  class TagRequest::Revise
    include Service::Base

    params do
      attribute :topic_id, :integer
      # Untyped: the `:array` cast turns numeric-looking names like "007" into integers.
      attribute :tag_names

      validates :topic_id, presence: true

      before_validation { self.tag_names = TagRequest.clean_names(tag_names) }
    end

    model :topic
    policy :can_revise_tag_requests
    model :dropped_tag_requests, optional: true

    each :dropped_tag_requests, as: :tag_request do
      transaction do
        # The row lock only holds inside a transaction, so the lookup lives in it.
        model :locked_tag_request, :lock_pending_tag_request, optional: true
        only_if(:tag_request_pending) do
          step :detach_topic
          only_if(:tag_request_unused) do
            step :record_withdrawal
            step :destroy_tag_request
            step :close_reviewable
          end
        end
      end
    end

    model :new_tag_names, :select_new_tag_names, optional: true
    only_if(:any_new_tag_names) { step :submit_new_tag_names }

    private

    def fetch_topic(params:)
      Topic.find_by(id: params.topic_id)
    end

    def can_revise_tag_requests(guardian:, topic:)
      guardian.can_request_tags_on?(topic) && guardian.can_edit_tags?(topic)
    end

    def fetch_dropped_tag_requests(params:, topic:)
      TagRequest.pending_on(topic).where.not(normalized_name: params.tag_names.map(&:downcase))
    end

    def lock_pending_tag_request(tag_request:)
      TagRequest.pending.lock.find_by(id: tag_request.id)
    end

    def tag_request_pending(locked_tag_request:)
      locked_tag_request.present?
    end

    def detach_topic(locked_tag_request:, topic:)
      locked_tag_request.tag_request_topics.where(topic:).delete_all
    end

    def tag_request_unused(locked_tag_request:)
      !locked_tag_request.tag_request_topics.exists?
    end

    def record_withdrawal(locked_tag_request:)
      locked_tag_request.reviewable.record_resolution!(resolution: "withdrawn")
    end

    def destroy_tag_request(locked_tag_request:)
      locked_tag_request.destroy!
    end

    def close_reviewable(locked_tag_request:)
      locked_tag_request.reviewable.transition_to(:deleted, Discourse.system_user)
    end

    # Names already pending on the topic are left out so they don't use up the
    # topic's remaining allowance.
    def select_new_tag_names(params:, topic:)
      pending_names = TagRequest.pending_on(topic).pluck(:normalized_name)
      params.tag_names.reject { |name| pending_names.include?(name.downcase) }
    end

    def any_new_tag_names(new_tag_names:)
      new_tag_names.present?
    end

    def submit_new_tag_names(topic:, new_tag_names:, guardian:)
      TagRequest::Submit.call(params: { topic_id: topic.id, tag_names: new_tag_names }, guardian:)
    end
  end
end
