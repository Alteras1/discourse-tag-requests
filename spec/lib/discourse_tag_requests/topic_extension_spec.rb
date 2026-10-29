# frozen_string_literal: true

RSpec.describe DiscourseTagRequests::TopicExtension do
  fab!(:topic) { Fabricate(:topic, tags: Fabricate.times(2, :tag)) }

  before { enable_current_plugin }

  describe "#tag_request_allowance" do
    it "is capped by the per-topic request limit" do
      SiteSetting.max_tags_per_topic = 10
      SiteSetting.max_tag_requests_per_topic = 3

      expect(topic.tag_request_allowance).to eq(3)
    end

    it "is capped by the tag slots left free, minus pending requests on the topic" do
      SiteSetting.max_tags_per_topic = 5
      Fabricate(:tag_request_topic, topic:)
      Fabricate(
        :tag_request_topic,
        topic:,
        tag_request: Fabricate(:tag_request, status: :soft_rejected),
      )

      expect(topic.tag_request_allowance).to eq(2)
    end

    it "is never negative" do
      SiteSetting.max_tags_per_topic = 1

      expect(topic.tag_request_allowance).to eq(0)
    end
  end
end
