# frozen_string_literal: true

RSpec.describe TopicsController do
  fab!(:author, :user)
  fab!(:other_user, :user)
  fab!(:topic) { Fabricate(:topic_with_op, user: author) }

  before do
    enable_current_plugin
    Fabricate(:tag_request_topic, tag_request: Fabricate(:tag_request, name: "rust"), topic:)
  end

  describe "#show" do
    it "includes pending requested tags only for viewers who can see them" do
      sign_in(author)
      get "/t/#{topic.id}.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body["requested_tags"]).to eq(["rust"])

      sign_in(other_user)
      get "/t/#{topic.id}.json"

      expect(response.parsed_body).not_to have_key("requested_tags")
    end
  end
end
