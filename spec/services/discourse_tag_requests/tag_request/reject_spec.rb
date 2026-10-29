# frozen_string_literal: true

RSpec.describe DiscourseTagRequests::TagRequest::Reject do
  before { enable_current_plugin }

  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:reviewable_id) }
    it { is_expected.to have_attributes(permanently: false, resolution: "rejected") }

    it "describes a permanent rejection" do
      expect(described_class.new(permanently: true).resolution).to eq("rejected_permanently")
    end
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:acting_user, :moderator)
    fab!(:tag_request) { Fabricate(:tag_request, name: "rust") }
    fab!(:topic)
    fab!(:topic_link) { Fabricate(:tag_request_topic, tag_request:, topic:) }

    let(:params) { { reviewable_id:, permanently: } }
    let(:dependencies) { { guardian: acting_user.guardian } }
    let(:reviewable_id) { tag_request.reviewable_id }
    let(:permanently) { false }
    let(:reviewable) { ReviewableTagRequest.find(reviewable_id) }

    context "when contract is invalid" do
      let(:reviewable_id) { nil }

      it { is_expected.to fail_a_contract }
    end

    context "when the user cannot review tag requests" do
      fab!(:acting_user, :user)

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

    context "when rejecting" do
      it { is_expected.to run_successfully }

      it "soft rejects the request, keeping its topics, and records the resolution" do
        result

        expect(tag_request.reload).to have_attributes(
          status: "soft_rejected",
          topics: contain_exactly(topic),
        )
        expect(reviewable.payload).to include(
          "resolution" => "rejected",
          "topic_ids" => [topic.id],
          "requester_ids" => [topic.user_id],
        )
      end
    end

    context "when rejecting permanently" do
      let(:permanently) { true }

      it { is_expected.to run_successfully }

      it "hard rejects the request, dropping its topics but keeping them in the snapshot" do
        result

        expect(tag_request.reload).to have_attributes(status: "hard_rejected", topics: be_empty)
        expect(reviewable.payload).to include(
          "resolution" => "rejected_permanently",
          "topic_ids" => [topic.id],
          "requester_ids" => [topic.user_id],
        )
      end
    end
  end
end
