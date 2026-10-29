# frozen_string_literal: true

RSpec.describe DiscourseTagRequests::TagRequest::AddAsSynonym do
  before { enable_current_plugin }

  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:reviewable_id) }
    it { is_expected.to validate_presence_of(:target_tag_id) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:acting_user, :moderator)
    fab!(:tag_request) { Fabricate(:tag_request, name: "rustlang") }
    fab!(:topic)
    fab!(:topic_link) { Fabricate(:tag_request_topic, tag_request:, topic:) }
    fab!(:target_tag) { Fabricate(:tag, name: "rust") }

    let(:params) { { reviewable_id:, target_tag_id: } }
    let(:dependencies) { { guardian: acting_user.guardian } }
    let(:reviewable_id) { tag_request.reviewable_id }
    let(:target_tag_id) { target_tag.id }

    before do
      SiteSetting.tagging_enabled = true
      SiteSetting.tag_topic_allowed_groups = Group::AUTO_GROUPS[:trust_level_0]
      SiteSetting.create_tag_allowed_groups = "1|2"
    end

    context "when contract is invalid" do
      let(:target_tag_id) { nil }

      it { is_expected.to fail_a_contract }
    end

    context "when the user cannot review tag requests" do
      fab!(:acting_user) { Fabricate(:user, trust_level: TrustLevel[3], refresh_auto_groups: true) }

      it { is_expected.to fail_a_policy(:can_review_tag_request) }
    end

    context "when the tag request was already resolved" do
      before { tag_request.destroy! }

      it { is_expected.to fail_to_find_a_model(:tag_request) }
    end

    context "when the tag request is not pending" do
      before { tag_request.soft_rejected! }

      it { is_expected.to fail_a_policy(:tag_request_pending) }
    end

    context "when the user cannot create tags" do
      before { SiteSetting.create_tag_allowed_groups = Group::AUTO_GROUPS[:admins] }

      it { is_expected.to fail_a_policy(:can_create_tag) }
    end

    context "when the target tag does not exist" do
      let(:target_tag_id) { 0 }

      it { is_expected.to fail_to_find_a_model(:tag) }
    end

    # Only category group moderators can review without being allowed to edit tags.
    context "when the user can create tags but cannot edit the target tag" do
      fab!(:acting_user) { Fabricate(:user, trust_level: TrustLevel[3], refresh_auto_groups: true) }

      before do
        SiteSetting.enable_category_group_moderation = true
        SiteSetting.create_tag_allowed_groups = "1|2|#{Group::AUTO_GROUPS[:trust_level_3]}"
        moderation = Fabricate(:category_moderation_group, group: Fabricate(:group))
        moderation.group.add(acting_user)
        tag_request.reviewable.update!(category: moderation.category)
      end

      it { is_expected.to fail_a_policy(:can_edit_target_tag) }
    end

    context "when the requested name is a tag that has its own synonyms" do
      before { Fabricate(:tag, name: "rs", target_tag: Fabricate(:tag, name: "rustlang")) }

      it { is_expected.to fail_a_step(:add_synonym) }
    end

    context "when everything's ok" do
      let(:reviewable) { ReviewableTagRequest.find(reviewable_id) }

      it { is_expected.to run_successfully }

      it "makes the requested name a synonym of the target and applies the target" do
        result

        expect(Tag.find_by(name: "rustlang")).to have_attributes(target_tag: target_tag)
        expect(topic.reload.tags).to contain_exactly(target_tag)
      end

      it "records the resolution and deletes the request" do
        expect { result }.to change { DiscourseTagRequests::TagRequest.count }.by(-1)

        expect(reviewable.payload).to include(
          "resolution" => "synonym",
          "tag_id" => target_tag.id,
          "topic_ids" => [topic.id],
          "requester_ids" => [topic.user_id],
          "skipped" => {
          },
        )
        expect(DiscourseTagRequests::TagRequestTopic.where(topic:)).to be_empty
      end
    end
  end
end
