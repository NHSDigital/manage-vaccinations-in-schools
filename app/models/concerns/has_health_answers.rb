# frozen_string_literal: true

module HasHealthAnswers
  extend ActiveSupport::Concern

  included do
    serialize :health_answers, coder: HealthAnswer::ArraySerializer

    encrypts :health_answers if respond_to?(:encrypts)
  end

  def health_answers_require_triage?
    health_answers.any? do
      it.response_yes? && it.would_require_triage?(team_id:)
    end
  end

  def who_responded
    if via_self_consent?
      "Child (Gillick competent)"
    elsif parent_relationship_type == "other" &&
          parent_relationship_other_name.present?
      "Other – #{parent_relationship_other_name}"
    elsif parent_relationship_type.present?
      ParentRelationship.human_enum_name(
        :type,
        parent_relationship_type
      ).capitalize
    else
      parent_relationship&.label || parent&.relationship_type_label
    end
  end
end
