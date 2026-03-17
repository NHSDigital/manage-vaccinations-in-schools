# frozen_string_literal: true

class AppSessionStatsComponent < ViewComponent::Base
  erb_template <<-ERB
    <% programmes.each do |programme| %>
      <section>
        <h3 class="nhsuk-heading-m nhsuk-u-margin-bottom-2">
          <%= programme.name %>
        </h3>

        <p class="nhsuk-caption-m nhsuk-u-margin-bottom-4">
          <%= t(".caption", count: total_count(programme)) %>
        </p>

        <% cards = cards_for_programme(programme) %>

        <ul class="nhsuk-grid-row nhsuk-card-group">
          <% cards.each do |card_data| %>
            <li class="nhsuk-grid-column-<%= grid_column_class(cards.length) %> nhsuk-card-group__item">
              <%= render AppCardComponent.new(compact: true,
                                              colour: card_data[:colour],
                                              link_to: card_data[:link_to]) do |card| %>
                <% card.with_heading(level: 4, size: "xs") { card_data[:heading] } %>
                <% card.with_data { card_data[:count].to_s } %>
              <% end %>
            </li>
          <% end %>
        </ul>
      </section>
    <% end %>
  ERB

  def initialize(session)
    @session = session
  end

  private

  attr_reader :session

  delegate :academic_year, :dates, :location, :programmes, :team, to: :session

  delegate :grid_column_class,
           :govuk_table,
           :govuk_button_link_to,
           :govuk_inset_text,
           :govuk_summary_list,
           :session_consent_period,
           :policy,
           to: :helpers

  def cards_for_programme(programme)
    stats = stats_for_programme(programme).except(:total).stringify_keys

    stats.map { |key, value| card_for(key, value, programme:) }
  end

  def card_for(key, value, programme:)
    {
      heading: card_heading_for(key),
      colour: card_colour_for(key),
      count: value.to_s,
      link_to: card_link_to_for(key, programme:)
    }
  end

  def card_heading_for(key)
    I18n.t(key, scope: %i[status programme label])
  end

  def card_colour_for(key)
    I18n.t(key, scope: %i[status programme colour])
  end

  def card_link_to_for(key, programme:)
    programme_types = [programme.type]

    if programme.flu? && key.starts_with?("due_")
      case key
      when "due_nasal"
        session_patients_path(
          session,
          programme_types:,
          programme_status_group: "due",
          vaccine_criteria: %w[flu_nasal flu_nasal_injection]
        )
      when "due_injection"
        session_patients_path(
          session,
          programme_types:,
          programme_status_group: "due",
          vaccine_criteria: %w[flu_injection_without_gelatine]
        )
      end
    elsif programme.mmr? && key.starts_with?("due_")
      case key
      when "due_no_preference"
        session_patients_path(
          session,
          programme_types:,
          programme_status_group: "due",
          vaccine_criteria: %w[mmr_injection]
        )
      when "due_without_gelatine"
        session_patients_path(
          session,
          programme_types:,
          programme_status_group: "due",
          vaccine_criteria: %w[mmr_injection_without_gelatine]
        )
      end
    else
      session_patients_path(
        session,
        programme_types:,
        programme_status_group: key,
        vaccine_criteria: []
      )
    end
  end

  def total_count(programme)
    stats_for_programme(programme).fetch(:total)
  end

  def stats_for_programme(programme)
    @stats_by_programme ||= {}
    @stats_by_programme[programme.type] ||= Stats::Session.call(
      session,
      programme:
    )
  end
end
