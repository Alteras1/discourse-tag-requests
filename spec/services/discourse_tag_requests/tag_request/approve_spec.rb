# frozen_string_literal: true

RSpec.describe DiscourseTagRequests::TagRequest::Approve do
  before { enable_current_plugin }

  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:reviewable_id) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:acting_user, :moderator)
    fab!(:tag_request) { Fabricate(:tag_request, name: "Rust") }
    fab!(:topic)
    fab!(:topic_link) { Fabricate(:tag_request_topic, tag_request:, topic:) }

    let(:params) { { reviewable_id: } }
    let(:dependencies) { { guardian: acting_user.guardian } }
    let(:reviewable_id) { tag_request.reviewable_id }

    before do
      SiteSetting.tagging_enabled = true
      SiteSetting.tag_topic_allowed_groups = Group::AUTO_GROUPS[:trust_level_0]
      SiteSetting.create_tag_allowed_groups = "1|2"
    end

    context "when contract is invalid" do
      let(:reviewable_id) { nil }

      it { is_expected.to fail_a_contract }
    end

    context "when the user can create tags but cannot review tag requests" do
      fab!(:acting_user) { Fabricate(:user, trust_level: TrustLevel[3], refresh_auto_groups: true) }

      before { SiteSetting.create_tag_allowed_groups = "1|2|#{Group::AUTO_GROUPS[:trust_level_3]}" }

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

    context "when a tag with the requested name already exists" do
      before { Fabricate(:tag, name: "rust") }

      it { is_expected.to fail_with_an_invalid_model(:tag) }
    end

    context "when everything's ok" do
      fab!(:private_message, :private_message_topic)
      fab!(:private_message_link) do
        Fabricate(:tag_request_topic, tag_request:, topic: private_message)
      end

      let(:reviewable) { ReviewableTagRequest.find(reviewable_id) }
      let(:created_tag) { Tag.find_by(name: "rust") }

      before { SiteSetting.force_lowercase_tags = true }

      it { is_expected.to run_successfully }

      it "creates the tag with the current cleaning rules and applies it to the requesting topics" do
        expect { result }.to change { Tag.count }.by(1)

        expect(created_tag).to be_present
        expect(topic.reload.tags).to contain_exactly(created_tag)
        expect(private_message.reload.tags).to be_empty
      end

      it "records the resolution on the review item" do
        result

        expect(reviewable.payload).to include(
          "resolution" => "created",
          "tag_id" => created_tag.id,
          "topic_ids" => contain_exactly(topic.id, private_message.id),
          "requester_ids" => contain_exactly(topic.user_id, private_message.user_id),
          "skipped" => {
            private_message.id.to_s => "private_message",
          },
        )
      end

      it "deletes the request and its topic links" do
        expect { result }.to change { DiscourseTagRequests::TagRequest.count }.by(-1).and change {
                DiscourseTagRequests::TagRequestTopic.count
              }.by(-2)
      end
    end
  end
end
