# frozen_string_literal: true

RSpec.describe ReviewableTagRequestSerializer do
  fab!(:moderator)
  fab!(:tag_request) { Fabricate(:tag_request, name: "rust") }
  fab!(:association) { Fabricate(:tag_request_topic, tag_request:) }

  let(:reviewable) { tag_request.reviewable }
  let(:json) { described_class.new(reviewable, scope: moderator.guardian, root: nil).as_json }

  before { enable_current_plugin }

  it "serializes the requested name, topics and requesters" do
    expect(json[:payload]).to include("name" => "rust")
    expect(json[:associated_topics].map { |topic| topic[:id] }).to contain_exactly(
      association.topic_id,
    )
    expect(json[:requesters].map { |requester| requester[:id] }).to contain_exactly(
      association.requested_by_id,
    )
    expect(json).not_to have_key(:existing_tag)
  end

  it "includes the conflicting tag while the request is pending" do
    tag = Fabricate(:tag, name: "rust")

    expect(json[:existing_tag]).to eq(id: tag.id, name: tag.name, slug: tag.slug)
  end
end
