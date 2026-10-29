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
end
