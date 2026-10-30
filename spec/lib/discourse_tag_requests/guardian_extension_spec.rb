# frozen_string_literal: true

RSpec.describe DiscourseTagRequests::GuardianExtension do
  fab!(:user) { Fabricate(:user, trust_level: 1, refresh_auto_groups: true) }

  before do
    enable_current_plugin
    SiteSetting.tagging_enabled = true
    SiteSetting.tag_topic_allowed_groups = Group::AUTO_GROUPS[:trust_level_0]
    SiteSetting.create_tag_allowed_groups = Group::AUTO_GROUPS[:staff]
    SiteSetting.tag_requests_allowed_groups = Group::AUTO_GROUPS[:trust_level_1]
  end

  describe "#can_request_tags?" do
    it "allows members of the allowed groups who can tag but not create tags" do
      expect(user.guardian.can_request_tags?).to eq(true)
    end

    it "refuses users outside the allowed groups" do
      SiteSetting.tag_requests_allowed_groups = Group::AUTO_GROUPS[:trust_level_4]

      expect(user.guardian.can_request_tags?).to eq(false)
    end

    it "defers to tag creation when the user is also allowed to create tags" do
      SiteSetting.create_tag_allowed_groups = Group::AUTO_GROUPS[:trust_level_1]

      expect(user.guardian.can_request_tags?).to eq(false)
    end

    it "refuses users who can't tag topics" do
      SiteSetting.tag_topic_allowed_groups = Group::AUTO_GROUPS[:staff]

      expect(user.guardian.can_request_tags?).to eq(false)
    end

    it "refuses anonymous users and disabled plugins" do
      expect(Guardian.new.can_request_tags?).to eq(false)

      SiteSetting.discourse_tag_requests_enabled = false

      expect(user.guardian.can_request_tags?).to eq(false)
    end
  end

  it "is exposed to the client on the current user" do
    json = CurrentUserSerializer.new(user, scope: user.guardian, root: false).as_json

    expect(json[:can_request_tags]).to eq(true)
  end
end
