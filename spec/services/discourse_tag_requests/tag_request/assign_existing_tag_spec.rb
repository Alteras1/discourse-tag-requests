# frozen_string_literal: true

RSpec.describe DiscourseTagRequests::TagRequest::AssignExistingTag do
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
    fab!(:canonical_tag) { Fabricate(:tag, name: "rust") }
    fab!(:synonym) { Fabricate(:tag, name: "rust-lang", target_tag: canonical_tag) }

    let(:params) { { reviewable_id:, target_tag_id: } }
    let(:dependencies) { { guardian: acting_user.guardian } }
    let(:reviewable_id) { tag_request.reviewable_id }
    let(:target_tag_id) { synonym.id }

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

    context "when the target tag does not exist" do
      let(:target_tag_id) { 0 }

      it { is_expected.to fail_to_find_a_model(:tag) }
    end

    context "when everything's ok" do
      let(:reviewable) { ReviewableTagRequest.find(reviewable_id) }

      it { is_expected.to run_successfully }

      it "applies the canonical tag of the selected synonym without creating the requested name" do
        expect { result }.not_to change { Tag.count }

        expect(topic.reload.tags).to contain_exactly(canonical_tag)
      end

      it "records the resolution and deletes the request" do
        expect { result }.to change { DiscourseTagRequests::TagRequest.count }.by(-1)

        expect(reviewable.payload).to include(
          "resolution" => "existing",
          "tag_id" => canonical_tag.id,
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
