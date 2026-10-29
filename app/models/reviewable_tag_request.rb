# frozen_string_literal: true

class ReviewableTagRequest < Reviewable
  include ReviewableActionBuilder

  has_one :tag_request, class_name: "DiscourseTagRequests::TagRequest", foreign_key: :reviewable_id

  def self.additional_args(params)
    { target_tag_id: params[:target_tag_id], reject_reason: params[:reject_reason] }
  end

  def self.open!(name:, requested_by:, previous_reviewable_id: nil)
    create!(
      created_by: requested_by,
      reviewable_by_moderator: true,
      payload: { name:, normalized_name: name.downcase, previous_reviewable_id: }.compact,
    )
  end

  def serializer
    ReviewableTagRequestSerializer
  end

  # One score per requesting topic, so the item clears the queue's default
  # visibility threshold and frequently requested names rank higher. Only adds
  # missing scores, so it is safe to call repeatedly.
  def sync_priority!
    missing_scores = tag_request.topics.count - reviewable_scores.count
    missing_scores.times do
      add_score(Discourse.system_user, ReviewableScore.types[:needs_approval], force_review: true)
    end
  end

  def build_combined_actions(actions, guardian, _args)
    return unless pending?

    if guardian.can_create_tag? && existing_tag.nil?
      build_action(actions, :approve_tag_request, icon: "check")
      build_action(actions, :approve_and_edit_tag_request, icon: "pencil")
    end
    build_action(actions, :use_existing_tag, icon: "tag")
    if guardian.can_create_tag? && guardian.can_edit_tag_names?
      build_action(actions, :add_as_synonym, icon: "right-left")
    end

    reject =
      actions.add_bundle(
        "#{id}-reject",
        icon: "xmark",
        label: "discourse_tag_requests.reviewables.actions.reject.title",
      )
    build_action(
      actions,
      :reject_tag_request,
      icon: "xmark",
      bundle: reject,
      require_reject_reason: true,
    )
    build_action(
      actions,
      :reject_tag_request_permanently,
      icon: "ban",
      bundle: reject,
      require_reject_reason: true,
    )
  end

  def perform_approve_tag_request(performed_by, _args)
    resolve_with(DiscourseTagRequests::TagRequest::Approve, performed_by, :approved)
  end
  alias perform_approve_and_edit_tag_request perform_approve_tag_request

  def perform_use_existing_tag(performed_by, args)
    resolve_with(
      DiscourseTagRequests::TagRequest::AssignExistingTag,
      performed_by,
      :approved,
      target_tag_id: args[:target_tag_id],
    )
  end

  def perform_add_as_synonym(performed_by, args)
    resolve_with(
      DiscourseTagRequests::TagRequest::AddAsSynonym,
      performed_by,
      :approved,
      target_tag_id: args[:target_tag_id],
    )
  end

  def perform_reject_tag_request(performed_by, args)
    self.reject_reason = args[:reject_reason]
    return resolution_failure(errors.full_messages) if !valid?
    resolve_with(DiscourseTagRequests::TagRequest::Reject, performed_by, :rejected)
  end

  def perform_reject_tag_request_permanently(performed_by, args)
    self.reject_reason = args[:reject_reason]
    return resolution_failure(errors.full_messages) if !valid?
    resolve_with(
      DiscourseTagRequests::TagRequest::Reject,
      performed_by,
      :rejected,
      permanently: true,
    )
  end

  # Snapshot kept on the reviewable, since the request it describes is deleted
  # (or handed to a newer reviewable) once this one is resolved.
  def record_resolution!(resolution:, tag: nil, skipped: {})
    update!(
      payload:
        payload.merge(
          "resolution" => resolution,
          "tag_id" => tag&.id,
          "topic_ids" => associated_topic_ids,
          "requester_ids" => requester_ids,
          "skipped" => skipped,
        ).compact,
    )
  end

  def requested_name
    payload["name"]
  end

  # Once resolved or hard-rejected the associations are deleted, so fall back
  # to the snapshot written into the payload at that point.
  def associated_topic_ids
    if tag_request
      tag_request.tag_request_topics.pluck(:topic_id)
    else
      payload["topic_ids"] || []
    end
  end

  def requester_ids
    if tag_request
      tag_request.tag_request_topics.distinct.pluck(:requested_by_id)
    else
      payload["requester_ids"] || []
    end
  end

  def associated_topics
    Topic.where(id: associated_topic_ids, archetype: Archetype.default).order(:id)
  end

  def requesters
    User.where(id: requester_ids).order(:id)
  end

  # The canonical tag that already uses the requested name, if any.
  def existing_tag
    tag = Tag.where_name(requested_name).includes(:target_tag).first
    tag&.target_tag || tag
  end

  private

  def resolve_with(service, performed_by, status, **params)
    service.call(params: { reviewable_id: id, **params }, guardian: performed_by.guardian) do
      on_success { create_result(:success, status) }
      on_failed_contract { |contract| resolution_failure(contract.errors.full_messages) }
      on_model_not_found(:tag) do
        resolution_failure([I18n.t("discourse_tag_requests.reviewables.tag_not_found")])
      end
      on_model_errors(:tag) { |tag| resolution_failure(tag.errors.full_messages) }
      on_failed_step(:add_synonym) { |step| resolution_failure([step.error]) }
      on_failure do
        resolution_failure([I18n.t("discourse_tag_requests.reviewables.resolution_failed")])
      end
    end
  end

  def resolution_failure(messages)
    create_result(:failure) do |result|
      result.errors = ActiveModel::Errors.new(self)
      messages.each { |message| result.errors.add(:base, message) }
    end
  end
end

# == Schema Information
#
# Table name: reviewables
#
#  id                      :bigint           not null, primary key
#  force_review            :boolean          default(FALSE), not null
#  latest_score            :datetime
#  payload                 :json
#  potential_spam          :boolean          default(FALSE), not null
#  potentially_illegal     :boolean          default(FALSE)
#  reject_reason           :text
#  reviewable_by_moderator :boolean          default(FALSE), not null
#  score                   :float            default(0.0), not null
#  status                  :integer          default("pending"), not null
#  target_type             :string
#  type                    :string           not null
#  type_source             :string           default("unknown"), not null
#  version                 :integer          default(0), not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  category_id             :integer
#  created_by_id           :integer          not null
#  target_created_by_id    :integer
#  target_id               :integer
#  topic_id                :integer
#
# Indexes
#
#  idx_reviewables_score_desc_created_at_desc                  (score DESC,created_at DESC)
#  index_reviewables_on_reviewable_by_group_id                 (reviewable_by_group_id)
#  index_reviewables_on_status_and_created_at                  (status,created_at)
#  index_reviewables_on_status_and_score                       (status,score)
#  index_reviewables_on_status_and_type                        (status,type)
#  index_reviewables_on_target_created_by_id                   (target_created_by_id)
#  index_reviewables_on_target_id_where_post_type_eq_post      (target_id) WHERE ((target_type)::text = 'Post'::text)
#  index_reviewables_on_topic_id_and_status_and_created_by_id  (topic_id,status,created_by_id)
#  index_reviewables_on_type_and_target_id                     (type,target_id) UNIQUE
#
