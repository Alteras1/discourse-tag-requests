# frozen_string_literal: true

DiscourseTagRequests::Engine.routes.draw do
  get "/examples" => "examples#index"
  # define routes here
end

Discourse::Application.routes.draw { mount ::DiscourseTagRequests::Engine, at: "discourse-tag-requests" }
