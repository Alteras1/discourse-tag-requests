# frozen_string_literal: true

RSpec.describe DiscourseTagRequests::TagRequest::Submit do
  before { enable_current_plugin }

  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:topic_id) }
    it { is_expected.to validate_presence_of(:tag_names) }
    it { is_expected.not_to allow_values([" ", ""]).for(:tag_names) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:acting_user) { Fabricate(:user, refresh_auto_groups: true) }
    fab!(:topic) { Fabricate(:topic, user: acting_user) }

    let(:params) { { topic_id:, tag_names: } }
    let(:dependencies) { { guardian: acting_user.guardian } }
    let(:topic_id) { topic.id }
    let(:tag_names) { %w[rust go] }
    let(:tag_requests) { DiscourseTagRequests::TagRequest.order(:id) }

    before do
      SiteSetting.tagging_enabled = true
      SiteSetting.tag_topic_allowed_groups = Group::AUTO_GROUPS[:trust_level_0]
      SiteSetting.create_tag_allowed_groups = Group::AUTO_GROUPS[:staff]
    end

    context "when contract is invalid" do
      let(:tag_names) { [" "] }

      it { is_expected.to fail_a_contract }
    end

    context "when the topic does not exist" do
      let(:topic_id) { 0 }

      it { is_expected.to fail_to_find_a_model(:topic) }
    end

    context "when the user is not the topic author" do
      fab!(:acting_user) { Fabricate(:user, refresh_auto_groups: true) }

      it { is_expected.to fail_a_policy(:can_request_tags) }
    end

    context "when the topic is a private message" do
      fab!(:topic) { Fabricate(:private_message_topic, user: acting_user) }

      it { is_expected.to fail_a_policy(:can_request_tags) }
    end

    context "when the user can create tags directly" do
      before { SiteSetting.create_tag_allowed_groups = Group::AUTO_GROUPS[:trust_level_0] }

      it { is_expected.to fail_a_policy(:can_request_tags) }
    end

    context "when the user cannot tag topics" do
      before { SiteSetting.tag_topic_allowed_groups = Group::AUTO_GROUPS[:staff] }

      it { is_expected.to fail_a_policy(:can_request_tags) }
    end

    context "when tagging is disabled" do
      before { SiteSetting.tagging_enabled = false }

      it { is_expected.to fail_a_policy(:can_request_tags) }
    end

    context "when the user is not in the groups allowed to request tags" do
      before { SiteSetting.tag_requests_allowed_groups = Group::AUTO_GROUPS[:trust_level_4] }

      it { is_expected.to fail_a_policy(:can_request_tags) }
    end

    context "when no name is requestable" do
      let(:tag_names) { %w[none] }

      it { is_expected.to fail_to_find_a_model(:requestable_names) }
    end

    context "when the topic has no request allowance left" do
      fab!(:topic) { Fabricate(:topic, user: acting_user, tags: [Fabricate(:tag)]) }

      before { SiteSetting.max_tags_per_topic = 1 }

      it { is_expected.to fail_to_find_a_model(:requestable_names) }
    end

    context "when everything's ok" do
      it { is_expected.to run_successfully }

      it "opens a pending request with a review item and a score for each name" do
        expect { result }.to change { tag_requests.count }.by(2).and change {
                ReviewableTagRequest.count
              }.by(2)

        expect(tag_requests).to contain_exactly(
          have_attributes(
            name: "rust",
            status: "pending",
            topics: [topic],
            reviewable:
              have_attributes(created_by: acting_user, reviewable_scores: have_attributes(size: 1)),
          ),
          have_attributes(
            name: "go",
            status: "pending",
            topics: [topic],
            reviewable:
              have_attributes(created_by: acting_user, reviewable_scores: have_attributes(size: 1)),
          ),
        )
        expect(topic.tag_request_topics.pluck(:requested_by_id)).to eq([acting_user.id] * 2)
        expect(topic.reload.tags).to be_empty
      end
    end

    context "with names that need cleaning" do
      let(:tag_names) { ["Rust Lang", "RUST-LANG", "007", "abcdefghijkl"] }

      before do
        SiteSetting.force_lowercase_tags = false
        SiteSetting.max_tag_length = 9
      end

      it "requests the cleaned names, keeping the first casing of duplicates and numeric-looking names verbatim" do
        expect(result).to run_successfully
        expect(tag_requests.pluck(:name)).to eq(%w[Rust-Lang 007 abcdefghi])
      end
    end

    context "with more names than allowed per topic" do
      let(:tag_names) { %w[none one two] }

      before { SiteSetting.max_tag_requests_per_topic = 2 }

      it "considers only the first names up to the limit, even when some are invalid" do
        expect(result).to run_successfully
        expect(tag_requests.pluck(:name)).to eq(%w[one])
      end
    end

    context "when the topic already has tags and pending requests" do
      fab!(:topic) { Fabricate(:topic, user: acting_user, tags: [Fabricate(:tag)]) }
      fab!(:pending_request) { Fabricate(:tag_request_topic, topic:).tag_request }

      let(:tag_names) { %w[one two three] }

      before { SiteSetting.max_tags_per_topic = 3 }

      it "requests only as many names as the remaining slots allow" do
        expect(result).to run_successfully
        expect(tag_requests.pluck(:name)).to eq([pending_request.name, "one"])
      end
    end

    context "with names that are taken, reserved or permanently rejected" do
      fab!(:existing_tag) { Fabricate(:tag, name: "Rust") }
      fab!(:synonym) { Fabricate(:tag, name: "golang", target_tag: Fabricate(:tag, name: "go")) }
      fab!(:hard_rejected) { Fabricate(:tag_request, name: "cobol", status: :hard_rejected) }

      let(:tag_names) { %w[rust golang none COBOL elixir] }

      before do
        SiteSetting.max_tag_requests_per_topic = 5
        SiteSetting.max_tags_per_topic = 5
      end

      it "requests only the available names" do
        expect(result).to run_successfully
        expect(tag_requests.pending.pluck(:name)).to contain_exactly("elixir")
        expect(hard_rejected.reload).to have_attributes(status: "hard_rejected", topics: be_empty)
      end
    end

    context "when a name is already pending on another topic" do
      fab!(:tag_request) { Fabricate(:tag_request, name: "rust") }
      fab!(:other_topic_link) { Fabricate(:tag_request_topic, tag_request:) }

      let(:tag_names) { %w[Rust] }

      it "attaches the topic to the existing request and adds a score" do
        expect { result }.not_to change { ReviewableTagRequest.count }

        expect(result).to run_successfully
        expect(tag_request.reload.topics).to contain_exactly(other_topic_link.topic, topic)
        expect(tag_request.reviewable.reviewable_scores.count).to eq(2)
      end
    end

    context "when a name was soft rejected" do
      fab!(:tag_request) { Fabricate(:tag_request, name: "rust", status: :soft_rejected) }
      fab!(:earlier_topic_link) { Fabricate(:tag_request_topic, tag_request:) }

      let(:tag_names) { %w[rust] }

      it "reopens the request with a new review item linked to the previous one" do
        previous_reviewable = tag_request.reviewable

        expect { result }.to change { ReviewableTagRequest.count }.by(1)

        expect(result).to run_successfully
        expect(tag_request.reload).to have_attributes(
          status: "pending",
          topics: contain_exactly(earlier_topic_link.topic, topic),
        )
        expect(tag_request.reviewable).to have_attributes(
          payload: include("previous_reviewable_id" => previous_reviewable.id),
          reviewable_scores: have_attributes(size: 2),
        )
      end
    end

    context "when the names were already submitted for the topic" do
      fab!(:tag_request) { Fabricate(:tag_request, name: "rust") }
      fab!(:topic_link) do
        Fabricate(:tag_request_topic, tag_request:, topic:).tap do
          tag_request.reviewable.sync_priority!
        end
      end

      let(:tag_names) { %w[rust] }

      it "does not duplicate topic links, review items or scores" do
        expect { result }.to not_change {
          DiscourseTagRequests::TagRequestTopic.count
        }.and not_change { ReviewableTagRequest.count }.and not_change { ReviewableScore.count }

        expect(result).to run_successfully
      end
    end
  end
end
