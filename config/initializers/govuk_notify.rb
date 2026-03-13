# frozen_string_literal: true

GOVUK_NOTIFY_EMAIL_TEMPLATES = {
  clinic_initial_invitation: "ceea5ff5-2250-4eb2-ab35-4e9e840b2a6f",
  clinic_initial_invitation_rt5: "17e63d67-53fc-4e9a-a533-74974412aac0",
  clinic_initial_invitation_ryg: "5fe4fb4d-6f0a-4149-a80a-232bdfdf4f73",
  clinic_subsequent_invitation: "a86a3b3f-a848-41d8-9a6f-d38174981388",
  clinic_subsequent_invitation_ryg: "eee59c1b-3af4-4ccd-8653-940887066390",
  session_school_reminder: "8b8a9566-bb03-4b3c-8abc-5bd5a4b8797d",
  triage_vaccination_at_clinic_rt5: "5cacefcd-44f2-43ff-8fc0-008890406504",
  triage_vaccination_at_clinic_ryg: "9faef718-bd76-4c30-93ea-fbe8584388a6",
  vaccination_administered_flu: "7238ee27-5840-40e5-b9b9-3130ba4cd4fa",
  vaccination_administered_hpv: "8a65d7b5-045c-4f26-8f76-6e593c14cb6d",
  vaccination_administered_menacwy: "38727494-9a81-42b3-9c1f-5c31e55333e7",
  vaccination_administered_mmr: "0b1095db-fb38-4105-9f01-a364fa8bbb1c",
  vaccination_administered_td_ipv: "3abe7ca8-a889-484b-ab9f-07523302eb6a",
  vaccination_already_had: "e37fe0a2-7584-4c25-983a-8f5a11c818a1",
  vaccination_deleted: "1caf1459-abc9-4944-b8c0-deba906ea005",
  vaccination_not_administered: "130fe52a-014a-45dd-9f53-8e65c1b8bb79"
}.freeze

GOVUK_NOTIFY_SMS_TEMPLATES = {
  clinic_initial_invitation: "790c9c72-729a-40d6-b44d-d480e38f0990",
  clinic_initial_invitation_rt5: "7be79abb-7295-4e6f-8cfb-9597bfad2f56",
  clinic_initial_invitation_ryg: "8ef5712f-bb7f-4911-8f3b-19df6f8a7179",
  clinic_subsequent_invitation: "ce7a6a1b-465e-4be4-b9e0-47ddb64f3adb",
  clinic_subsequent_invitation_ryg: "018f146d-e7b7-4b63-ae26-bb07ca6fe2f9",
  session_school_reminder: "cc4a7f89-d260-461c-80f0-7e6e9af75e7a",
  vaccination_administered: "395a3ea1-df07-4dd6-8af1-64cc597ef383",
  vaccination_already_had: "fab1e355-bde1-47d5-835c-103bfd232b93",
  vaccination_not_administered: "aae061e0-b847-4d4c-a87a-12508f95a302"
}.freeze

# Here we track email and SMS templates that we used to send but no longer
# do. We need these to be able to display the names of the templates.
GOVUK_NOTIFY_UNUSED_TEMPLATES = {
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
