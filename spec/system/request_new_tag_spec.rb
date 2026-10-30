# frozen_string_literal: true

RSpec.describe "Request new tag" do
  fab!(:author) { Fabricate(:user, trust_level: 1, refresh_auto_groups: true) }
  fab!(:admin)
  fab!(:category)

  let(:composer) { PageObjects::Components::Composer.new }
  let(:topic_page) { PageObjects::Pages::Topic.new }
  let(:topic_list) { PageObjects::Components::TopicList.new }
  let(:review_page) { PageObjects::Pages::Review.new }

  before do
    enable_current_plugin
    SiteSetting.tagging_enabled = true
    SiteSetting.tag_topic_allowed_groups = Group::AUTO_GROUPS[:trust_level_0]
    SiteSetting.create_tag_allowed_groups = Group::AUTO_GROUPS[:staff]
  end

  it "lets a user request a tag that staff then approve onto their topic" do
    sign_in(author)
    visit("/new-topic?category_id=#{category.id}")
    composer.fill_title("Getting started with Rust")
    composer.fill_content("Notes and questions from my first week learning Rust.")
    composer.request_tag("rust")
    composer.create

    expect(topic_page).to have_requested_tag("rust")

    topic = Topic.find_by(title: "Getting started with Rust")
    visit("/filter?q=#{CGI.escape("pending-tag:rust")}")

    expect(topic_list).to have_topic(topic)

    sign_in(admin)
    reviewable = ReviewableTagRequest.last
    review_page.visit_reviewable(reviewable)
    review_page.select_action(reviewable, "approve_tag_request")

    expect(review_page).to have_reviewable_with_approved_status(reviewable)

    topic_page.visit_topic(topic)

    expect(topic_page).to have_topic_tag("rust")
    expect(topic_page).to have_no_requested_tag("rust")
  end

  it "lets an author change their topic's requests from the topic title" do
    topic = Fabricate(:topic, user: author, category:)
    Fabricate(:post, topic:, user: author)
    Fabricate(:tag_request_topic, tag_request: Fabricate(:tag_request, name: "rust"), topic:)

    sign_in(author)
    topic_page.visit_topic(topic)

    expect(topic_page).to have_requested_tag("rust")

    topic_page.edit_requested_tags(request: "go", withdraw: "rust")

    expect(topic_page).to have_requested_tag("go")
    expect(topic_page).to have_no_requested_tag("rust")
    expect(DiscourseTagRequests::TagRequest.pending_on(topic).pluck(:name)).to eq(["go"])
  end
end
