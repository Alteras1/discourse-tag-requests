# frozen_string_literal: true

module DiscourseTagRequests
  class TagRequest::Action::Open < Service::ActionBase
    option :name
    option :requested_by

    # Returns the pending request for the name, or nil when the name is
    # permanently rejected.
    def call
      tag_request = TagRequest.for_name(name).first
      return TagRequest.open!(name:, requested_by:) if tag_request.nil?
      return if tag_request.hard_rejected?

      tag_request.reopen!(requested_by:) if tag_request.soft_rejected?
      tag_request
    end
  end
end
