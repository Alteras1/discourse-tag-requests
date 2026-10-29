# frozen_string_literal: true

RSpec.describe DiscourseTagRequests::TagRequest::Action::Open do
  before { enable_current_plugin }

  describe ".call" do
    subject(:tag_request) { described_class.call(name:, requested_by:) }

    fab!(:requested_by, :user)

    let(:name) { "Rust" }

    context "when the name has never been requested" do
      it "opens a pending request with a review item" do
        expect { tag_request }.to change { DiscourseTagRequests::TagRequest.count }.by(1)

        expect(tag_request).to have_attributes(
          name: "Rust",
          status: "pending",
          reviewable:
            have_attributes(
              created_by: requested_by,
              payload: include("name" => "Rust", "normalized_name" => "rust"),
            ),
        )
      end
    end

    context "when the name is pending" do
      fab!(:existing_request) { Fabricate(:tag_request, name: "rust") }

      it "returns the existing request without a new review item" do
        expect { tag_request }.not_to change { ReviewableTagRequest.count }
        expect(tag_request).to eq(existing_request)
      end
    end

    context "when the name was soft rejected" do
      fab!(:existing_request) { Fabricate(:tag_request, name: "rust", status: :soft_rejected) }

      it "reopens the existing request" do
        previous_reviewable_id = existing_request.reviewable_id

        expect(tag_request).to eq(existing_request)
        expect(existing_request.reload).to have_attributes(
          status: "pending",
          reviewable:
            have_attributes(payload: include("previous_reviewable_id" => previous_reviewable_id)),
        )
      end
    end

    context "when the name was hard rejected" do
      fab!(:existing_request) { Fabricate(:tag_request, name: "rust", status: :hard_rejected) }

      it "returns nothing and leaves the request rejected" do
        expect { tag_request }.not_to change { ReviewableTagRequest.count }
        expect(tag_request).to be_nil
        expect(existing_request.reload).to be_hard_rejected
      end
    end
  end
end
