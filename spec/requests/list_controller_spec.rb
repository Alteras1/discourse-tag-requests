# frozen_string_literal: true

RSpec.describe ListController do
  fab!(:author, :user)
  fab!(:other_user, :user)
  fab!(:topic) { Fabricate(:topic, user: author) }
  fab!(:other_topic, :topic)

  before do
    enable_current_plugin
    Fabricate(:tag_request_topic, tag_request: Fabricate(:tag_request, name: "rust"), topic:)
  end

  def listed_requested_tags
    response.parsed_body["topic_list"]["topics"].to_h do |listed|
      [listed["id"], listed["requested_tags"]]
    end
  end

  describe "#latest" do
    it "lists pending requested tags only for viewers who can see them" do
      sign_in(author)
      get "/latest.json"

      expect(response.status).to eq(200)
      expect(listed_requested_tags).to eq(topic.id => ["rust"], other_topic.id => nil)

      sign_in(other_user)
      get "/latest.json"

      expect(listed_requested_tags).to eq(topic.id => nil, other_topic.id => nil)
    end

    it "loads requested tags for the whole list in a single query" do
      sign_in(Fabricate(:admin))
      get "/latest.json"
      initial_queries = track_sql_queries { get "/latest.json" }.count

      3.times do
        Fabricate(
          :tag_request_topic,
          tag_request: Fabricate(:tag_request),
          topic: Fabricate(:topic),
        )
      end

      expect(track_sql_queries { get "/latest.json" }.count).to eq(initial_queries)
    end
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
