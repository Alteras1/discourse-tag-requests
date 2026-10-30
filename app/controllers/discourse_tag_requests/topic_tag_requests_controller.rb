# frozen_string_literal: true

module DiscourseTagRequests
  class TopicTagRequestsController < ::ApplicationController
    requires_plugin PLUGIN_NAME

    before_action :ensure_logged_in

    def update
      TagRequest::Revise.call(service_params) do
        on_success do |topic:|
          render json: {
                   requested_tags:
                     TagRequestTopic.pending_names_by_topic_id([topic.id], guardian)[topic.id] ||
                       [],
                 }
        end
        on_failed_contract { |contract| render_json_error(contract) }
        on_model_not_found(:topic) { raise Discourse::NotFound }
        on_failed_policy(:can_revise_tag_requests) { raise Discourse::InvalidAccess }
        on_failure { render json: failed_json, status: :unprocessable_entity }
      end
    end
  end
end
