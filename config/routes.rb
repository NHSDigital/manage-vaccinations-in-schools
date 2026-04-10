# frozen_string_literal: true

require "sidekiq/web"
require "sidekiq-scheduler/web"
require "sidekiq/throttled/web"
require "sidekiq_unique_jobs/web"

Rails.application.routes.draw do
  # Redirect www subdomain to root in production envs
  unless Rails.env.local?
    match "(*any)",
          to: redirect(subdomain: ""),
          via: :all,
          constraints: {
            subdomain: "www"
          }
  end

  get "/logout", to: "users/logout#show"

  if Settings.cis2.enabled
    devise_for :users,
               module: :users,
               controllers: {
                 omniauth_callbacks: "users/omniauth_callbacks"
               }
    devise_scope :user do
      post "/users/auth/cis2/backchannel-logout",
           to: "users/omniauth_callbacks#cis2_logout"
      delete "/logout", to: "users/omniauth_callbacks#logout"
    end
  else
    devise_for :users,
               module: :users,
               path_names: {
                 sign_in: "sign-in",
                 sign_out: "sign-out"
               }
    devise_scope :user do
      delete "/logout", to: "users/sessions#destroy"
    end
  end

  root to: redirect("/start")

  Sidekiq::Web.use Rack::Auth::Basic do |username, password|
    ActiveSupport::SecurityUtils.secure_compare(
      Rails.application.credentials.support_username,
      username
    ) &&
      ActiveSupport::SecurityUtils.secure_compare(
        Rails.application.credentials.support_password,
        password
      )
  end
  mount Sidekiq::Web => "/sidekiq"

  get "/start", to: "start#index"
  get "/dashboard", to: "dashboard#index"
  get "/accessibility-statement", to: "accessibility_statement#index"

  get "/manifest/:name-:digest.json", to: "manifest#show", as: :manifest
  get "/manifest/:name.json", to: "manifest#show"

  get "/up", to: "rails/health#show", as: :rails_health_check

  flipper_app =
    Flipper::UI.app do |builder|
      builder.use Rack::Auth::Basic do |username, password|
        ActiveSupport::SecurityUtils.secure_compare(
          Rails.application.credentials.support_username,
          username
        ) &&
          ActiveSupport::SecurityUtils.secure_compare(
            Rails.application.credentials.support_password,
            password
          )
      end
    end
  mount flipper_app, at: "/flipper"

  unless Rails.env.production?
    get "/random-consent-form(/:slug)", to: "dev/random_consent_form#call"
  end

  get "/csrf", to: "csrf#new"

  namespace :parent_interface, path: "/" do
    resources :consent_forms, path: "/consents", only: %i[create] do
      collection do
        get ":session_slug_or_team_location_id/:programme_types/start",
            action: :start,
            as: :start
        get ":session_slug_or_team_location_id/:programme_types/deadline-passed",
            action: :deadline_passed,
            as: :deadline_passed
      end

      member do
        get "cannot-consent-responsibility",
            action: :cannot_consent_responsibility
        get "confirm"
        put "record"
        get "submitted"
      end

      resources :edit, only: %i[show update], controller: "consent_forms/edit"
    end
  end

  namespace :api do
    unless Rails.env.production?
      namespace :testing do
        resources :locations, only: :index
        delete "teams/:workgroup/locations", to: "teams#destroy_locations"
        resources :teams, only: :destroy, param: :workgroup
        post "/onboard", to: "onboard#create"
        get "refresh-reporting", to: "reporting_refresh#create"
      end
    end

    namespace :reporting do
      post "authorize", to: "one_time_tokens#authorize"
      get "totals", controller: :totals, action: :index
    end
  end

  resources :class_imports, path: "class-imports", except: %i[index destroy] do
    member do
      get :re_review, to: "class_imports#re_review"
      get :imported_records, to: "class_imports#imported_records"
      post :approve, to: "class_imports#approve"
      post :cancel, to: "class_imports#cancel"
    end
  end

  resources :cohort_imports,
            path: "cohort_imports",
            except: %i[index destroy] do
    member do
      get :re_review, to: "cohort_imports#re_review"
      get :imported_records, to: "cohort_imports#imported_records"
      post :approve, to: "cohort_imports#approve"
      post :cancel, to: "cohort_imports#cancel"
    end
  end

  resources :consent_forms, path: "consent-forms", only: %i[index show] do
    member do
      get "search"

      get "match/:patient_id", action: :edit_match, as: :match
      post "match/:patient_id", action: :update_match

      get "archive", action: :edit_archive
      post "archive", action: :update_archive

      get "patient", action: :new_patient
      post "patient", action: :create_patient
    end
  end

  resource :draft_import, only: %i[show update], path: "draft-import/:id"
  resource :draft_consent, only: %i[show update], path: "draft-consent/:id"
  resource :draft_session, only: %i[show update], path: "draft-session/:id"
  resource :draft_vaccination_record,
           only: %i[show update],
           path: "draft-vaccination-record/:id"

  resource :draft_school, only: %i[show update], path: "draft-school/:id"

  resources :immunisation_imports,
            path: "immunisation-imports",
            except: %i[index destroy]

  resources :imports, only: %i[index create] do
    collection { get :records }
  end

  namespace :imports do
    resources :issues, path: "issues", only: %i[index] do
      get ":type", action: :show, on: :member, as: ""
      patch ":type", action: :update, on: :member
    end

    resources :notices, only: %i[index destroy] do
      member { get :dismiss }
    end

    get "bulk_remove_parents/:import_type/:import_id",
        to: "bulk_remove_parents#new",
        as: :bulk_remove_parents

    post "bulk_remove_parents/:import_type/:import_id",
         to: "bulk_remove_parents#create"
  end

  resources :notifications, only: :create

  resources :patients, only: %i[index show edit] do
    post "", action: :index, on: :collection

    resource :archive,
             path: "archive",
             only: %i[new create],
             controller: "patients/archive"

    resources :parent_relationships,
              path: "parents",
              only: %i[new create edit update destroy] do
      get "destroy", action: :confirm_destroy, on: :member, as: "destroy"
    end

    resources :programmes,
              only: :show,
              param: :type,
              controller: "patients/programmes" do
      member do
        post "invite-to-clinic", action: :invite_to_clinic
        post "record-already-vaccinated", action: :record_already_vaccinated
        post "record-new-vaccination", action: :record_new_vaccination
        post "send-consent-request", action: :send_consent_request
      end
    end

    member do
      get "pds-search-history"

      get "edit/nhs-number",
          controller: "patients/edit",
          action: "edit_nhs_number"
      put "edit/nhs-number",
          controller: "patients/edit",
          action: "update_nhs_number"
      put "edit/nhs-number-merge",
          controller: "patients/edit",
          action: "update_nhs_number_merge"

      get "edit/ethnic-group", to: "patients/edit#edit_ethnic_group"
      put "edit/ethnic-group", to: "patients/edit#update_ethnic_group"

      get "edit/ethnic-background", to: "patients/edit#edit_ethnic_background"
      put "edit/ethnic-background", to: "patients/edit#update_ethnic_background"

      get "edit/school", controller: "patients/edit", action: "edit_school"
      put "edit/school", controller: "patients/edit", action: "update_school"
    end
  end

  resources :reports, only: :index

  resources :school_moves, path: "school-moves", only: %i[index show update]
  resources :school_move_exports,
            path: "school-moves/exports",
            controller: "school_moves/exports",
            only: %i[create show update] do
    get "download", on: :member
  end

  resources :schools, only: :index, param: :urn_and_site do
    resource :invite_to_clinic,
             only: %i[edit update],
             path: "invite-to-clinic",
             controller: "schools/invite_to_clinic"

    resources :import, only: :new, controller: "schools/import"
    resources :patients, only: :index, controller: "schools/patients"
    resources :sessions, only: :index, controller: "schools/sessions"
  end

  resources :sessions, only: %i[index new show edit], param: :slug do
    resource :patients, only: :show, controller: "sessions/patients" do
      post ":patient_id/register/:status", as: :register, action: :register
    end
    resource :patient_specific_directions,
             path: "patient-specific-directions",
             only: %i[show new create],
             controller: "sessions/patient_specific_directions"
    resource :record, only: :show, controller: "sessions/record" do
      get "batch/:programme_type/:vaccine_method",
          action: :edit_batch,
          as: :batch
      post "batch/:programme_type/:vaccine_method", action: :update_batch
    end

    resource :invite_to_clinic,
             path: "invite-to-clinic",
             only: %i[edit update],
             controller: "sessions/invite_to_clinic"

    resource :manage_consent_reminders,
             path: "manage-consent-reminders",
             only: %i[show create],
             controller: "sessions/manage_consent_reminders"

    member do
      get "import"

      constraints -> { Flipper.enabled?(:dev_tools) } do
        put "make-in-progress", to: "sessions#make_in_progress"
      end
    end

    resources :patient_sessions,
              path: "patients",
              as: :patient,
              only: [],
              module: :patient_sessions do
      resource :activity, only: %i[show create]
      resource :attendance, only: %i[edit update]

      resources :programmes, path: "", param: :type, only: :show do
        get "record-already-vaccinated"

        resources :consents, only: %i[index create show] do
          post "send-request", on: :collection, action: :send_request

          member do
            get "follow-up", action: :edit_follow_up
            post "follow-up", action: :update_follow_up

            get "confirm-refusal", action: :edit_confirm_refusal
            post "confirm-refusal", action: :update_confirm_refusal

            get "withdraw", action: :edit_withdraw
            post "withdraw", action: :update_withdraw

            get "invalidate", action: :edit_invalidate
            post "invalidate", action: :update_invalidate
          end
        end

        resource :gillick_assessment, path: "gillick", only: %i[edit update]
        resource :triages, only: %i[new create]
        resource :vaccinations, only: %i[create]
      end
    end
  end

  resource :team, only: [] do
    member do
      get :contact_details
      get :schools
      get :sessions
      get :clinics
    end
    resources :schools,
              only: %i[new create edit update],
              param: :urn_and_site,
              controller: "teams/schools" do
      collection { get :new_site }
    end
  end

  resources :vaccination_records,
            path: "vaccination-records",
            only: %i[show update destroy] do
    get "destroy", action: :confirm_destroy, on: :member, as: "destroy"
  end

  resource :vaccination_report, path: "vaccination-report", only: %i[new create]

  get "consent-form/:type",
      to: "consent_form_downloads#show",
      as: :consent_form_download

  resources :vaccines, only: %i[index show] do
    resources :batches, only: %i[create edit new update] do
      member do
        get "archive", action: "edit_archive"
        post "archive", action: "update_archive"

        post "make-default", as: :make_default
      end
    end
  end

  namespace :users do
    get "organisation-not-found", controller: :errors
    get "workgroup-not-found", controller: :errors
    get "role-not-found", controller: :errors

    resource :teams, only: %i[new create]

    devise_scope :user do
      get "sessions/time-remaining", to: "sessions#time_remaining"
      post "sessions/refresh", to: "sessions#refresh"
    end
  end

  scope via: :all do
    get "/404", to: "errors#not_found"
    get "/422", to: "errors#unprocessable_entity"
    get "/429", to: "errors#too_many_requests"
    get "/500", to: "errors#internal_server_error"
  end

  get "/oidc/jwks", to: "jwks#jwks"

  namespace :inspect do
    get "dashboard", to: "dashboard#index"
    get "graph/:object_type/:object_id", to: "graphs#show"
    namespace :timeline do
      resources :patients, only: [:show]
    end
  end
end
