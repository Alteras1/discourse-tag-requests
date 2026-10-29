# frozen_string_literal: true

RSpec.describe PostsController do
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:admin)

  let(:topic_params) do
    { title: "This is a topic requesting new tags", raw: "This is the body of the topic." }
  end
  let(:tag_requests) { DiscourseTagRequests::TagRequest.order(:id) }

  before do
    enable_current_plugin
    SiteSetting.tagging_enabled = true
    SiteSetting.tag_topic_allowed_groups = Group::AUTO_GROUPS[:trust_level_0]
    SiteSetting.create_tag_allowed_groups = Group::AUTO_GROUPS[:staff]
  end

  describe "#create" do
    before { sign_in(user) }

    it "requests the tags without tagging the topic" do
      post "/posts.json", params: topic_params.merge(requested_tag_names: %w[rust go])

      expect(response.status).to eq(200)
      topic = Topic.find(response.parsed_body["topic_id"])
      expect(tag_requests).to contain_exactly(
        have_attributes(name: "rust", topics: [topic]),
        have_attributes(name: "go", topics: [topic]),
      )
      expect(topic.tags).to be_empty
    end

    it "still creates the topic when no requested name is valid" do
      post "/posts.json", params: topic_params.merge(requested_tag_names: %w[none])

      expect(response.status).to eq(200)
      expect(Topic.find(response.parsed_body["topic_id"])).to be_present
      expect(tag_requests).to be_empty
    end

    context "when the topic requires approval" do
      before { SiteSetting.approve_post_count = 1 }

      it "requests the tags only once the queued topic is approved" do
        post "/posts.json", params: topic_params.merge(requested_tag_names: %w[rust])

        expect(response.parsed_body["action"]).to eq("enqueued")
        expect(tag_requests).to be_empty

        queued_post = ReviewableQueuedPost.find_by!(target_created_by: user)
        sign_in(admin)
        put "/review/#{queued_post.id}/perform/approve_post.json",
            params: {
              version: queued_post.version,
            }

        expect(response.status).to eq(200)
        topic = queued_post.reload.target.topic
        expect(tag_requests).to contain_exactly(have_attributes(name: "rust", topics: [topic]))
        expect(topic.tags).to be_empty
      end
    end
  end
end
