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

  describe "#destroy" do
    it "removes its topic associations" do
      tag_request = Fabricate(:tag_request)
      Fabricate(:tag_request_topic, tag_request:)

      tag_request.destroy!

      expect(DiscourseTagRequests::TagRequestTopic.count).to eq(0)
    end
  end
end
