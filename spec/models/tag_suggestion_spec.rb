# frozen_string_literal: true

RSpec.describe DiscourseTagRequests::TagSuggestion do
  before { enable_current_plugin }

  it "treats names differing only by case as the same suggestion" do
    Fabricate(:tag_suggestion, name: "Rust")

    expect { Fabricate(:tag_suggestion, name: "rust") }.to raise_error(
      ActiveRecord::RecordNotUnique,
    )
  end

  describe ".for_name" do
    it "finds a suggestion regardless of case and keeps the original casing" do
      suggestion = Fabricate(:tag_suggestion, name: "Rust")

      expect(described_class.for_name("RUST")).to contain_exactly(suggestion)
      expect(suggestion.name).to eq("Rust")
    end
  end

  describe "#destroy" do
    it "removes its topic associations" do
      suggestion = Fabricate(:tag_suggestion)
      Fabricate(:tag_suggestion_topic, tag_suggestion: suggestion)

      suggestion.destroy!

      expect(DiscourseTagRequests::TagSuggestionTopic.count).to eq(0)
    end
  end
end
