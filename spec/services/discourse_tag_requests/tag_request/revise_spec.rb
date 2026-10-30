# frozen_string_literal: true

RSpec.describe DiscourseTagRequests::TagRequest::Revise do
  before { enable_current_plugin }

  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:topic_id) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:acting_user) { Fabricate(:user, refresh_auto_groups: true) }
    fab!(:topic) { Fabricate(:topic_with_op, user: acting_user) }

    let(:params) { { topic_id:, tag_names: } }
    let(:dependencies) { { guardian: acting_user.guardian } }
    let(:topic_id) { topic.id }
    let(:tag_names) { [] }
    let(:pending_names) do
      DiscourseTagRequests::TagRequest.pending_on(topic).order(:name).pluck(:name)
    end

    before do
      SiteSetting.tagging_enabled = true
      SiteSetting.tag_topic_allowed_groups = Group::AUTO_GROUPS[:trust_level_0]
      SiteSetting.create_tag_allowed_groups = Group::AUTO_GROUPS[:staff]
    end

    context "when the topic does not exist" do
      let(:topic_id) { 0 }

      it { is_expected.to fail_to_find_a_model(:topic) }
    end

    context "when the user is not the topic author" do
      fab!(:acting_user) { Fabricate(:user, refresh_auto_groups: true) }
      fab!(:topic)

      it { is_expected.to fail_a_policy(:can_revise_tag_requests) }
    end

    context "when the user can no longer edit the topic's tags" do
      before { topic.first_post.update!(locked_by_id: Discourse.system_user.id) }

      it { is_expected.to fail_a_policy(:can_revise_tag_requests) }
    end

    context "with pending requests on the topic" do
      fab!(:rust) { Fabricate(:tag_request, name: "rust") }
      fab!(:go) { Fabricate(:tag_request, name: "go") }

      before do
        Fabricate(:tag_request_topic, tag_request: rust, topic:)
        Fabricate(:tag_request_topic, tag_request: go, topic:)
      end

      context "when a request is kept" do
        let(:tag_names) { %w[Rust go zig] }

        it "requests only the new names" do
          expect(result).to run_successfully
          expect(pending_names).to eq(%w[go rust zig])
        end
      end

      context "when a request is dropped" do
        let(:tag_names) { %w[rust] }

        it "detaches the topic and keeps the other request open" do
          other_topic = Fabricate(:topic)
          Fabricate(:tag_request_topic, tag_request: go, topic: other_topic)

          expect(result).to run_successfully
          expect(pending_names).to eq(%w[rust])
          expect(go.reload.tag_request_topics.pluck(:topic_id)).to eq([other_topic.id])
          expect(go.reviewable.reload).to be_pending
        end

        it "withdraws a request no other topic needs" do
          expect(result).to run_successfully
          expect(DiscourseTagRequests::TagRequest.exists?(go.id)).to eq(false)
          expect(go.reviewable.reload).to be_deleted
          expect(go.reviewable.payload["resolution"]).to eq("withdrawn")
        end
      end

      context "when no names are given" do
        it "withdraws every request" do
          expect(result).to run_successfully
          expect(pending_names).to be_empty
        end
      end

      context "when a dropped request was resolved in the meantime" do
        before { go.soft_rejected! }

        it "leaves the resolved request alone" do
          expect(result).to run_successfully
          expect(go.reload.tag_request_topics.pluck(:topic_id)).to eq([topic.id])
        end
      end

      context "when the new names exceed the topic's allowance" do
        let(:tag_names) { %w[rust go zig] }

        before { SiteSetting.max_tag_requests_per_topic = 2 }

        it "keeps the existing requests" do
          expect(result).to run_successfully
          expect(pending_names).to eq(%w[go rust])
        end
      end
    end

    context "without any pending requests" do
      let(:tag_names) { %w[rust] }

      it "submits the names" do
        expect(result).to run_successfully
        expect(pending_names).to eq(%w[rust])
      end
    end
  end
end
