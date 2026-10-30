# frozen_string_literal: true

RSpec.describe DiscourseTagRequests::TopicTagRequestsController do
  fab!(:author) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:other_user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:topic) { Fabricate(:topic, user: author) }

  before do
    enable_current_plugin
    SiteSetting.tagging_enabled = true
    SiteSetting.tag_topic_allowed_groups = Group::AUTO_GROUPS[:trust_level_0]
    SiteSetting.create_tag_allowed_groups = Group::AUTO_GROUPS[:staff]
  end

  describe "#update" do
    it "requires a signed-in user" do
      put "/tag-requests/topics/#{topic.id}.json", params: { tag_names: %w[rust] }

      expect(response.status).to eq(403)
    end

    it "revises the topic's requests and returns the pending names" do
      sign_in(author)
      put "/tag-requests/topics/#{topic.id}.json", params: { tag_names: %w[rust go] }

      expect(response.status).to eq(200)
      expect(response.parsed_body["requested_tags"]).to eq(%w[go rust])

      put "/tag-requests/topics/#{topic.id}.json", params: { tag_names: %w[go] }

      expect(response.parsed_body["requested_tags"]).to eq(%w[go])
    end

    it "withdraws every request when no names are sent" do
      Fabricate(:tag_request_topic, tag_request: Fabricate(:tag_request, name: "rust"), topic:)
      sign_in(author)
      put "/tag-requests/topics/#{topic.id}.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body["requested_tags"]).to eq([])
    end

    it "rejects users who don't own the topic" do
      sign_in(other_user)
      put "/tag-requests/topics/#{topic.id}.json", params: { tag_names: %w[rust] }

      expect(response.status).to eq(403)
    end

    it "responds with not found for a missing topic" do
      sign_in(author)
      put "/tag-requests/topics/0.json", params: { tag_names: %w[rust] }

      expect(response.status).to eq(404)
    end
  end
end
