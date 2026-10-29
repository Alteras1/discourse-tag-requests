# frozen_string_literal: true

RSpec.describe ReviewablesController do
  fab!(:admin)
  fab!(:tag_request) { Fabricate(:tag_request, name: "rust") }
  fab!(:topic)
  fab!(:topic_link) { Fabricate(:tag_request_topic, tag_request:, topic:) }

  let(:reviewable) { ReviewableTagRequest.find(tag_request.reviewable_id) }

  before do
    enable_current_plugin
    SiteSetting.tagging_enabled = true
    SiteSetting.tag_topic_allowed_groups = Group::AUTO_GROUPS[:trust_level_0]
    SiteSetting.create_tag_allowed_groups = "1|2"
  end

  describe "#perform" do
    context "when signed in as an admin" do
      fab!(:existing_tag) { Fabricate(:tag, name: "rust-lang") }

      before { sign_in(admin) }

      it "approves the request by creating the tag" do
        put "/review/#{reviewable.id}/perform/approve_tag_request.json",
            params: {
              version: reviewable.version,
            }

        expect(response.status).to eq(200)
        created_tag = Tag.find_by(name: "rust")
        expect(reviewable.reload).to have_attributes(
          status: "approved",
          payload:
            include(
              "resolution" => "created",
              "tag_id" => created_tag.id,
              "tag_name" => "rust",
              "tag_slug" => created_tag.slug_for_url,
            ),
        )
        expect(topic.reload.tags).to contain_exactly(created_tag)
        expect(DiscourseTagRequests::TagRequest.exists?(tag_request.id)).to eq(false)
      end

      it "approves the request through the approve and edit action" do
        put "/review/#{reviewable.id}/perform/approve_and_edit_tag_request.json",
            params: {
              version: reviewable.version,
            }

        expect(response.status).to eq(200)
        expect(reviewable.reload).to have_attributes(
          status: "approved",
          payload: include("resolution" => "created"),
        )
        expect(topic.reload.tags.map(&:name)).to contain_exactly("rust")
      end

      it "assigns an existing tag instead" do
        put "/review/#{reviewable.id}/perform/use_existing_tag.json",
            params: {
              version: reviewable.version,
              target_tag_id: existing_tag.id,
            }

        expect(response.status).to eq(200)
        expect(reviewable.reload).to have_attributes(
          status: "approved",
          payload: include("resolution" => "existing", "tag_id" => existing_tag.id),
        )
        expect(topic.reload.tags).to contain_exactly(existing_tag)
      end

      it "adds the requested name as a synonym of an existing tag" do
        put "/review/#{reviewable.id}/perform/add_as_synonym.json",
            params: {
              version: reviewable.version,
              target_tag_id: existing_tag.id,
            }

        expect(response.status).to eq(200)
        expect(reviewable.reload).to have_attributes(
          status: "approved",
          payload: include("resolution" => "synonym", "tag_id" => existing_tag.id),
        )
        expect(Tag.find_by(name: "rust")).to have_attributes(target_tag: existing_tag)
        expect(topic.reload.tags).to contain_exactly(existing_tag)
      end

      it "rejects the request, saving the reason" do
        put "/review/#{reviewable.id}/perform/reject_tag_request.json",
            params: {
              version: reviewable.version,
              reject_reason: "Too niche",
            }

        expect(response.status).to eq(200)
        expect(reviewable.reload).to have_attributes(
          status: "rejected",
          reject_reason: "Too niche",
          payload: include("resolution" => "rejected", "topic_ids" => [topic.id]),
        )
        expect(tag_request.reload).to have_attributes(
          status: "soft_rejected",
          topics: contain_exactly(topic),
        )
      end

      it "rejects the request permanently, saving the reason" do
        put "/review/#{reviewable.id}/perform/reject_tag_request_permanently.json",
            params: {
              version: reviewable.version,
              reject_reason: "Not a topic for this forum",
            }

        expect(response.status).to eq(200)
        expect(reviewable.reload).to have_attributes(
          status: "rejected",
          reject_reason: "Not a topic for this forum",
          payload: include("resolution" => "rejected_permanently", "topic_ids" => [topic.id]),
        )
        expect(tag_request.reload).to have_attributes(status: "hard_rejected", topics: be_empty)
      end

      it "refuses a reject reason over 2000 characters" do
        put "/review/#{reviewable.id}/perform/reject_tag_request.json",
            params: {
              version: reviewable.version,
              reject_reason: "a" * 2001,
            }

        expect(response.status).to eq(422)
        expect(response.parsed_body["errors"]).to contain_exactly(
          "Reject reason is too long (maximum is 2000 characters)",
        )
        expect(reviewable.reload).to have_attributes(status: "pending", reject_reason: nil)
        expect(tag_request.reload).to be_pending
      end

      it "refuses a target tag that no longer exists" do
        put "/review/#{reviewable.id}/perform/use_existing_tag.json",
            params: {
              version: reviewable.version,
              target_tag_id: 0,
            }

        expect(response.status).to eq(422)
        expect(response.parsed_body["errors"]).to contain_exactly(
          I18n.t("discourse_tag_requests.reviewables.tag_not_found"),
        )
        expect(reviewable.reload).to be_pending
      end

      it "explains a missing target tag" do
        put "/review/#{reviewable.id}/perform/use_existing_tag.json",
            params: {
              version: reviewable.version,
            }

        expect(response.status).to eq(422)
        expect(response.parsed_body["errors"]).to contain_exactly("Target tag can't be blank")
        expect(reviewable.reload).to be_pending
      end
    end

    context "when signed in as a moderator who cannot create tags" do
      fab!(:moderator)

      before do
        SiteSetting.create_tag_allowed_groups = Group::AUTO_GROUPS[:admins]
        sign_in(moderator)
      end

      it "forbids approving" do
        put "/review/#{reviewable.id}/perform/approve_tag_request.json",
            params: {
              version: reviewable.version,
            }

        expect(response.status).to eq(403)
        expect(reviewable.reload).to be_pending
      end
    end

    context "when signed in as a regular user" do
      fab!(:user)

      before { sign_in(user) }

      it "forbids access to the review queue" do
        put "/review/#{reviewable.id}/perform/approve_tag_request.json",
            params: {
              version: reviewable.version,
            }

        expect(response.status).to eq(403)
        expect(reviewable.reload).to be_pending
      end
    end
  end
end
