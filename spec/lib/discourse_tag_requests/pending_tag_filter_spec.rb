# frozen_string_literal: true

RSpec.describe DiscourseTagRequests::PendingTagFilter do
  fab!(:admin)
  fab!(:author, :user)
  fab!(:other_user, :user)
  fab!(:rust_and_go_topic) { Fabricate(:topic, user: author) }
  fab!(:rust_topic, :topic)
  fab!(:go_topic, :topic)
  fab!(:plain_topic, :topic)
  fab!(:rust) { Fabricate(:tag_request, name: "rust") }
  fab!(:go) { Fabricate(:tag_request, name: "go") }

  before do
    enable_current_plugin
    Fabricate(:tag_request_topic, tag_request: rust, topic: rust_and_go_topic)
    Fabricate(:tag_request_topic, tag_request: go, topic: rust_and_go_topic)
    Fabricate(:tag_request_topic, tag_request: rust, topic: rust_topic)
    Fabricate(:tag_request_topic, tag_request: go, topic: go_topic)
  end

  def filtered_topics(query, guardian: admin.guardian)
    TopicsFilter.new(guardian:).filter_from_query_string(query)
  end

  describe "pending-tag: filter" do
    it "matches topics with a pending request, ignoring case" do
      expect(filtered_topics("pending-tag:Rust")).to contain_exactly(rust_and_go_topic, rust_topic)
    end

    it "matches any of the comma-separated names" do
      expect(filtered_topics("pending-tag:rust,go")).to contain_exactly(
        rust_and_go_topic,
        rust_topic,
        go_topic,
      )
    end

    it "matches all of the plus-separated names" do
      expect(filtered_topics("pending-tag:rust+go")).to contain_exactly(rust_and_go_topic)
    end

    it "combines repeated keywords with AND" do
      expect(filtered_topics("pending-tag:rust pending-tag:go")).to contain_exactly(
        rust_and_go_topic,
      )
    end

    it "excludes topics with a negated name" do
      expect(filtered_topics("-pending-tag:rust")).to contain_exactly(go_topic, plain_topic)
    end

    it "matches nothing for a value that isn't a tag name list" do
      expect(filtered_topics("pending-tag:rust,go+ruby")).to be_empty
    end

    it "ignores real tags and requests that are no longer pending" do
      Fabricate(:tag, name: "go")
      rust.soft_rejected!
      Fabricate(:topic, tags: [Tag.find_by(name: "go")])
      go.destroy!

      expect(filtered_topics("pending-tag:rust,go")).to be_empty
    end

    it "only matches the author's own topics for users outside the configured groups" do
      expect(filtered_topics("pending-tag:rust", guardian: author.guardian)).to contain_exactly(
        rust_and_go_topic,
      )
      expect(filtered_topics("pending-tag:rust", guardian: other_user.guardian)).to be_empty
    end

    it "matches every visible request for members of the configured groups" do
      group = Fabricate(:group, users: [other_user])
      SiteSetting.tag_requests_visible_to_groups = "1|2|#{group.id}"

      expect(filtered_topics("pending-tag:rust", guardian: other_user.guardian)).to contain_exactly(
        rust_and_go_topic,
        rust_topic,
      )
    end

    it "keeps topics in categories the viewer can't see hidden" do
      group = Fabricate(:group, users: [other_user])
      SiteSetting.tag_requests_visible_to_groups = "1|2|#{group.id}"
      rust_topic.update!(category: Fabricate(:private_category, group: Fabricate(:group)))

      expect(filtered_topics("pending-tag:rust", guardian: other_user.guardian)).to contain_exactly(
        rust_and_go_topic,
      )
    end
  end

  describe "autocomplete option" do
    def option_names(guardian)
      TopicsFilter.option_info(guardian).map { |option| option[:name] }
    end

    it "is offered to signed-in users" do
      expect(option_names(other_user.guardian)).to include("pending-tag:")
    end

    it "is offered to anonymous users only when they may see requests" do
      expect(option_names(Guardian.new)).not_to include("pending-tag:")

      SiteSetting.tag_requests_visible_to_groups = "1|2|#{Group::AUTO_GROUPS[:anonymous_users]}"

      expect(option_names(Guardian.new)).to include("pending-tag:")
    end
  end
end
