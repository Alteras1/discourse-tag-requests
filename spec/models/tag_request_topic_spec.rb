# frozen_string_literal: true

RSpec.describe DiscourseTagRequests::TagRequestTopic do
  fab!(:author, :user)
  fab!(:other_user, :user)
  fab!(:moderator)
  fab!(:group)
  fab!(:topic) { Fabricate(:topic, user: author) }
  fab!(:other_topic, :topic)
  fab!(:association) { Fabricate(:tag_request_topic, topic:) }
  fab!(:other_association) { Fabricate(:tag_request_topic, topic: other_topic) }

  before { enable_current_plugin }

  describe ".visible_to" do
    it "shows staff every pending request" do
      expect(described_class.visible_to(moderator.guardian)).to contain_exactly(
        association,
        other_association,
      )
    end

    it "shows members of the configured groups every pending request" do
      group.add(other_user)
      SiteSetting.tag_requests_visible_to_groups = "1|2|#{group.id}"

      expect(described_class.visible_to(other_user.guardian)).to contain_exactly(
        association,
        other_association,
      )
    end

    it "shows other users only the requests on their own topics" do
      expect(described_class.visible_to(author.guardian)).to contain_exactly(association)
      expect(described_class.visible_to(other_user.guardian)).to be_empty
    end

    it "shows anonymous users requests only when the anonymous users group is configured" do
      expect(described_class.visible_to(Guardian.new)).to be_empty

      SiteSetting.tag_requests_visible_to_groups = "1|2|#{Group::AUTO_GROUPS[:anonymous_users]}"

      expect(described_class.visible_to(Guardian.new)).to contain_exactly(
        association,
        other_association,
      )
    end

    it "excludes rejected requests and deleted topics" do
      association.tag_request.soft_rejected!
      other_topic.trash!

      expect(described_class.visible_to(moderator.guardian)).to be_empty
    end
  end

  it "is removed when its topic is permanently deleted" do
    topic.destroy!

    expect(described_class.all).to contain_exactly(other_association)
  end
end
