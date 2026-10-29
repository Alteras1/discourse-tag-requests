# frozen_string_literal: true

RSpec.describe DiscourseTagRequests::TagRequest do
  before { enable_current_plugin }

  it "treats names differing only by case as the same request" do
    Fabricate(:tag_request, name: "Rust")

    expect { Fabricate(:tag_request, name: "rust") }.to raise_error(ActiveRecord::RecordNotUnique)
  end

  describe ".for_name" do
    it "finds a request regardless of case and keeps the original casing" do
      tag_request = Fabricate(:tag_request, name: "Rust")

      expect(described_class.for_name("RUST")).to contain_exactly(tag_request)
      expect(tag_request.name).to eq("Rust")
    end
  end

  describe ".requestable_names" do
    it "keeps names in order, dropping those taken by a tag or synonym, reserved or hard rejected" do
      Fabricate(:tag, name: "Rust")
      Fabricate(:tag, name: "golang", target_tag: Fabricate(:tag, name: "go"))
      Fabricate(:tag_request, name: "cobol", status: :hard_rejected)
      Fabricate(:tag_request, name: "perl", status: :soft_rejected)
      Fabricate(:tag_request, name: "elixir")

      expect(described_class.requestable_names(%w[zig rust GOLANG none Cobol perl elixir])).to eq(
        %w[zig perl elixir],
      )
    end
  end

  describe "#reopen!" do
    fab!(:requester, :user)
    fab!(:tag_request) { Fabricate(:tag_request, name: "Rust", status: :soft_rejected) }
    fab!(:association) { Fabricate(:tag_request_topic, tag_request:) }

    it "makes the request pending again under a new review item linked to the previous one" do
      previous_reviewable_id = tag_request.reviewable_id

      tag_request.reopen!(requested_by: requester)

      expect(tag_request.reload).to have_attributes(
        status: "pending",
        topics: contain_exactly(association.topic),
      )
      expect(tag_request.reviewable).to have_attributes(
        created_by: requester,
        payload: include("name" => "Rust", "previous_reviewable_id" => previous_reviewable_id),
      )
    end
  end

  describe "#destroy" do
    it "removes its topic associations" do
      tag_request = Fabricate(:tag_request)
      Fabricate(:tag_request_topic, tag_request:)

      tag_request.destroy!

      expect(DiscourseTagRequests::TagRequestTopic.count).to eq(0)
    end
  end
end
