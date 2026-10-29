# frozen_string_literal: true

RSpec.describe DiscourseTagRequests::TagRequest::Action::ApplyTag do
  before do
    enable_current_plugin
    SiteSetting.tagging_enabled = true
  end

  describe ".call" do
    subject(:skipped) { described_class.call(tag:, topics:, guardian: moderator.guardian) }

    fab!(:moderator)
    fab!(:tag) { Fabricate(:tag, name: "rust") }
    fab!(:other_tag) { Fabricate(:tag, name: "go") }
    fab!(:topic) { Fabricate(:topic, tags: [other_tag]) }

    let(:topics) { [topic] }

    context "when the topic can be tagged" do
      it "adds the tag, keeps the existing ones and skips nothing" do
        expect(skipped).to be_empty
        expect(topic.reload.tags).to contain_exactly(other_tag, tag)
      end
    end

    context "with several topics, some of which are skipped" do
      fab!(:deleted_topic) { Fabricate(:topic).tap(&:trash!) }

      let(:topics) { [topic, deleted_topic] }

      it "tags the eligible topics and reports only the skipped ones" do
        expect(skipped).to eq(deleted_topic.id => "deleted")
        expect(topic.reload.tags).to contain_exactly(other_tag, tag)
      end
    end

    context "when the topic is deleted" do
      before { topic.trash! }

      it "skips it" do
        expect(skipped).to eq(topic.id => "deleted")
        expect(topic.reload.tags).to contain_exactly(other_tag)
      end
    end

    context "when the topic is a private message" do
      fab!(:topic, :private_message_topic)

      it "skips it" do
        expect(skipped).to eq(topic.id => "private_message")
        expect(topic.reload.tags).to be_empty
      end
    end

    context "when the topic already has the tag" do
      fab!(:topic) { Fabricate(:topic, tags: [tag]) }

      before { SiteSetting.max_tags_per_topic = 1 }

      it "does not skip it, even at the tag limit" do
        expect(skipped).to be_empty
        expect(topic.reload.tags).to contain_exactly(tag)
      end
    end

    context "when the topic has reached the tag limit" do
      before { SiteSetting.max_tags_per_topic = 1 }

      it "skips it" do
        expect(skipped).to eq(topic.id => "tag_limit_reached")
        expect(topic.reload.tags).to contain_exactly(other_tag)
      end
    end

    context "when core refuses the tag with an error" do
      before { Fabricate(:tag_group, tags: [tag, other_tag], one_per_topic: true) }

      it "skips it with core's error message" do
        expect(skipped).to eq(
          topic.id =>
            I18n.t("tags.limited_to_one_tag_from_group", tags: "#{other_tag.name}, #{tag.name}"),
        )
        expect(topic.reload.tags).to contain_exactly(other_tag)
      end
    end

    context "when the topic's category does not allow the tag" do
      fab!(:topic) do
        Fabricate(:topic, category: Fabricate(:category, allowed_tags: ["go"]), tags: [other_tag])
      end

      it "skips it even though core silently drops the tag" do
        expect(skipped).to eq(topic.id => "not_allowed_in_category")
        expect(topic.reload.tags).to contain_exactly(other_tag)
      end
    end
  end
end
