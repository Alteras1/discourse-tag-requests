# frozen_string_literal: true

RSpec.describe ReviewableTagRequest do
  fab!(:moderator)
  fab!(:user)
  fab!(:tag_request) { Fabricate(:tag_request, name: "Rust") }
  fab!(:association) { Fabricate(:tag_request_topic, tag_request:) }

  let(:reviewable) { tag_request.reviewable }

  before { enable_current_plugin }

  it "is shown to moderators but not to regular users" do
    expect(Reviewable.viewable_by(moderator)).to contain_exactly(reviewable)
    expect(Reviewable.viewable_by(user)).to be_empty
  end

  describe "#associated_topics and #requesters" do
    it "reads from the live request while it exists" do
      expect(reviewable.associated_topics).to contain_exactly(association.topic)
      expect(reviewable.requesters).to contain_exactly(association.requested_by)
    end

    it "falls back to the payload snapshot once the request is gone" do
      reviewable.update!(
        payload:
          reviewable.payload.merge(topic_ids: [association.topic_id], requester_ids: [user.id]),
      )
      tag_request.destroy!

      expect(reviewable.reload.associated_topics).to contain_exactly(association.topic)
      expect(reviewable.requesters).to contain_exactly(user)
    end
  end

  describe "#sync_priority!" do
    it "adds one score per requesting topic, only for those missing a score" do
      reviewable.sync_priority!
      Fabricate(:tag_request_topic, tag_request:)

      expect { 2.times { reviewable.sync_priority! } }.to change {
        reviewable.reviewable_scores.count
      }.from(1).to(2)
    end
  end

  describe "#associated_topics" do
    it "excludes private messages" do
      Fabricate(:tag_request_topic, tag_request:, topic: Fabricate(:private_message_topic))

      expect(reviewable.associated_topics).to contain_exactly(association.topic)
    end
  end

  describe "#existing_tag" do
    it "returns nil when no tag uses the requested name" do
      expect(reviewable.existing_tag).to be_nil
    end

    it "returns the canonical tag when the name is now a synonym" do
      canonical = Fabricate(:tag, name: "rust-lang")
      Fabricate(:tag, name: "rust", target_tag: canonical)

      expect(reviewable.existing_tag).to eq(canonical)
    end
  end

  describe "#build_combined_actions" do
    subject(:actions) { reviewable.actions_for(acting_user.guardian) }

    fab!(:acting_user, :moderator)

    let(:action_ids) { actions.to_a.map(&:server_action) }

    before do
      SiteSetting.tagging_enabled = true
      SiteSetting.create_tag_allowed_groups = "1|2"
    end

    it "offers every resolution, with both rejections bundled together" do
      expect(action_ids).to contain_exactly(
        "approve_tag_request",
        "approve_and_edit_tag_request",
        "use_existing_tag",
        "add_as_synonym",
        "reject_tag_request",
        "reject_tag_request_permanently",
      )
      expect(
        actions.bundles.find { |bundle| bundle.id == "#{reviewable.id}-reject" },
      ).to have_attributes(
        actions:
          contain_exactly(
            have_attributes(server_action: "reject_tag_request", require_reject_reason: true),
            have_attributes(
              server_action: "reject_tag_request_permanently",
              require_reject_reason: true,
            ),
          ),
      )
    end

    context "when a tag with the requested name exists" do
      before { Fabricate(:tag, name: "rust") }

      it "hides the approve actions" do
        expect(action_ids).to contain_exactly(
          "use_existing_tag",
          "add_as_synonym",
          "reject_tag_request",
          "reject_tag_request_permanently",
        )
      end
    end

    context "when the user cannot create tags" do
      before { SiteSetting.create_tag_allowed_groups = Group::AUTO_GROUPS[:admins] }

      it "offers only using an existing tag or rejecting" do
        expect(action_ids).to contain_exactly(
          "use_existing_tag",
          "reject_tag_request",
          "reject_tag_request_permanently",
        )
      end
    end

    context "when the user can create tags but cannot edit tag names" do
      fab!(:acting_user) { Fabricate(:user, trust_level: TrustLevel[3], refresh_auto_groups: true) }

      before { SiteSetting.create_tag_allowed_groups = "1|2|#{Group::AUTO_GROUPS[:trust_level_3]}" }

      it "hides adding as a synonym" do
        expect(action_ids).to contain_exactly(
          "approve_tag_request",
          "approve_and_edit_tag_request",
          "use_existing_tag",
          "reject_tag_request",
          "reject_tag_request_permanently",
        )
      end
    end

    context "when the review item is resolved" do
      it "offers nothing once approved or rejected" do
        reviewable.update!(status: :approved)
        expect(reviewable.actions_for(acting_user.guardian).to_a).to be_empty

        reviewable.update!(status: :rejected)
        expect(reviewable.actions_for(acting_user.guardian).to_a).to be_empty
      end
    end
  end

  describe "#record_resolution!" do
    fab!(:tag)

    it "snapshots the request into the payload, keeping the link to a previous review item" do
      tag_request.soft_rejected!
      previous_reviewable_id = tag_request.reviewable_id
      tag_request.reopen!(requested_by: user)
      reopened = tag_request.reviewable

      reopened.record_resolution!(
        resolution: "existing",
        tag:,
        skipped: {
          association.topic_id => "deleted",
        },
      )

      expect(reopened.reload.payload).to eq(
        "name" => "Rust",
        "normalized_name" => "rust",
        "previous_reviewable_id" => previous_reviewable_id,
        "resolution" => "existing",
        "tag_id" => tag.id,
        "tag_name" => tag.name,
        "tag_slug" => tag.slug_for_url,
        "topic_ids" => [association.topic_id],
        "requester_ids" => [association.requested_by_id],
        "skipped" => {
          association.topic_id.to_s => "deleted",
        },
      )
    end

    it "leaves out the tag when there is none" do
      reviewable.record_resolution!(resolution: "rejected")

      expect(reviewable.reload.payload).to include("resolution" => "rejected", "skipped" => {})
      expect(reviewable.payload).not_to have_key("tag_id")
    end
  end
end
