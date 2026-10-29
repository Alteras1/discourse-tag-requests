# frozen_string_literal: true

RSpec.describe DiscourseTagRequests::TagRequest::RequestedName do
  before { enable_current_plugin }

  describe "#id" do
    it "identifies names case-insensitively while keeping the original casing" do
      requested_name = described_class.new(name: "Rust")

      expect(requested_name).to have_attributes(id: "rust", name: "Rust")
      expect(described_class.new(name: "RUST").id).to eq(requested_name.id)
    end
  end
end
