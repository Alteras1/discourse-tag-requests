# frozen_string_literal: true

DiscourseTagRequests::Engine.routes.draw { put "/topics/:topic_id" => "topic_tag_requests#update" }

Discourse::Application.routes.draw { mount ::DiscourseTagRequests::Engine, at: "/tag-requests" }
