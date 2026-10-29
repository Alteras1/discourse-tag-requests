# frozen_string_literal: true

RSpec.describe ListController do
  fab!(:author, :user)
  fab!(:topic) { Fabricate(:topic, user: author) }
  fab!(:other_topic, :topic)

  before do
    enable_current_plugin
    Fabricate(:tag_request_topic, tag_request: Fabricate(:tag_request, name: "rust"), topic:)
  end

  describe "#filter" do
    it "filters topics by pending tag request" do
      sign_in(author)

      get "/filter.json", params: { q: "pending-tag:rust" }

      expect(response.status).to eq(200)
      expect(response.parsed_body["topic_list"]["topics"].map { |listed| listed["id"] }).to eq(
        [topic.id],
      )
    end
  end
end
