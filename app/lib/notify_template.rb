# frozen_string_literal: true

class NotifyTemplate
  # Retired Notify-hosted template UUIDs, kept so we can display the template
  # name when rendering old notify_log_entries that reference them.
  RETIRED_TEMPLATE_IDS = {
    "e871e7d5-06be-48d1-81ba-38ddecae46e2" => :consent_confirmation_refused,
    "b9c0c3fb-24f1-4647-a2a1-87389cec9942" => :consent_school_reminder,
    "12f90b2d-33a5-429c-9ed7-0aa2823eb3ac" => :consent_school_request,
    "07516fbf-6d51-4c17-a046-305f5baa6744" => :vaccination_administered_flu,
    "3179b434-4f44-4d47-a8ba-651b58c235fd" => :consent_confirmation_given,
    "8eb8d05e-b8d8-4bf9-8a38-c009ae989a4e" => :consent_confirmation_given,
    "c6c8dbfc-b429-4468-bd0b-176e771b5a8e" => :consent_confirmation_given,
    "eb34f3ab-0c58-4e56-b6b1-2c179270dfc3" => :consent_confirmation_refused,
    "ee3d36b1-4682-4eb0-a74a-7e0f6c9d0598" => :consent_school_reminder,
    "c7bd8150-d09e-4607-817d-db75c9a6a966" => :consent_school_request,
    "88d21cfc-39f6-44a2-98c3-9588e7214ae4" => :invitation_to_clinic,
    "fc99ac81-9eeb-4df8-9aa0-04f0eb48e37f" => :invitation_to_clinic_ryg,
    "e1b6a2f6-728a-4de3-88ec-40194b354eac" => :invitation_to_clinic_rt5,
    "16ae7602-c2b1-4731-bb74-fd4f1357feca" => :vaccination_administered_menacwy,
    "25473aa7-2d7c-4d1d-b0c6-2ac492f737c3" => :consent_confirmation_given,
    "4c616b22-eee8-423f-84d6-bd5710f744fd" => :vaccination_administered_td_ipv,
    "55d35c86-7365-406b-909f-1b7b78529ea8" =>
      :consent_school_subsequent_reminder_doubles,
    "6410145f-dac1-46ba-82f3-a49cad0f66a6" =>
      :consent_school_subsequent_reminder_hpv,
    "69612d3a-d6eb-4f04-8b99-ed14212e7245" => :vaccination_administered_hpv,
    "6aa04f0d-94c2-4a6b-af97-a7369a12f681" => :consent_school_request_hpv,
    "79e131b2-7816-46d0-9c74-ae14956dd77d" => :session_school_reminder,
    "7cda7ae5-99a2-4c40-9a3e-1863e23f7a73" => :consent_confirmation_given,
    "8835575d-be69-442f-846e-14d41eb214c7" =>
      :consent_school_initial_reminder_doubles,
    "ceefd526-d44c-4561-b0d2-c9ef4ccaba4f" =>
      :consent_school_initial_reminder_hpv,
    "e9aa7f0f-986f-49be-a1ee-6d1d1c13e9ec" => :consent_school_request_doubles,
    "fa3c8dd5-4688-4b93-960a-1d422c4e5597" => :triage_vaccination_will_happen,
    "6e4c514d-fcc9-4bc8-b7eb-e222a1445681" => :session_school_reminder,
    "604ee667-c996-471e-b986-79ab98d0767c" => :consent_confirmation_triage,
    "f2921e23-4b73-4e44-abbb-38b0e235db8e" => :consent_confirmation_clinic
  }.freeze

  attr_reader :name, :channel, :id

  def self.find(name, channel:)
    name = name.to_sym
    channel = channel.to_sym

    if (template = CommsTemplate.find(name, channel:))
      new(name:, channel:, id: template.id, local: true)
    end
  end

  def self.find_by_id(template_id, channel:)
    return nil if template_id.blank?

    channel = channel.to_sym

    if (template = CommsTemplate.find_by_id(template_id, channel:))
      new(name: template.name, channel:, id: template_id.to_s, local: true)
    elsif (name = RETIRED_TEMPLATE_IDS[template_id.to_s])
      new(name:, channel:, id: template_id.to_s, local: false)
    end
  end

  def self.exists?(name, channel:, source: :any)
    channel = channel.to_sym
    case source
    when :local, :any
      CommsTemplate.exists?(name, channel:)
    else
      raise ArgumentError, "Unknown source: #{source}"
    end
  end

  def self.all_ids(channel:)
    CommsTemplate.all_ids(channel:).freeze
  end

  def initialize(name:, channel:, id:, local:)
    @name = name.to_sym
    @channel = channel.to_sym
    @id = id
    @local = local
  end

  def local? = @local

  def render(personalisation)
    CommsTemplate.find(@name, channel: @channel).render(personalisation)
  end
end
