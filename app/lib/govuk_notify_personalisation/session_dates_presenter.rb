# frozen_string_literal: true

class GovukNotifyPersonalisation
  class SessionDatesPresenter
    def initialize(personalisation)
      @personalisation = personalisation
    end

    attr_reader :personalisation

    delegate :consent_form, :session, to: :personalisation

    def has_multiple_dates?
      return false if session.nil?

      session.future_dates.length > 1
    end

    def next_or_today_session_date
      return "" unless session_dates_are_accurate?

      session&.next_date(include_today: true)&.to_fs(:short_day_of_week)
    end

    def next_or_today_session_dates
      return "" unless session_dates_are_accurate?

      session
        &.today_or_future_dates
        &.map { it.to_fs(:short_day_of_week) }
        &.to_sentence
    end

    def next_or_today_session_dates_or
      return "" unless session_dates_are_accurate?

      session
        &.today_or_future_dates
        &.map { it.to_fs(:short_day_of_week) }
        &.to_sentence(last_word_connector: ", or ", two_words_connector: " or ")
    end

    def next_session_date
      return "" unless session_dates_are_accurate?

      session&.next_date(include_today: false)&.to_fs(:short_day_of_week)
    end

    def next_session_dates
      return "" unless session_dates_are_accurate?

      session&.future_dates&.map { it.to_fs(:short_day_of_week) }&.to_sentence
    end

    def next_session_dates_or
      return "" unless session_dates_are_accurate?

      session
        &.future_dates
        &.map { it.to_fs(:short_day_of_week) }
        &.to_sentence(last_word_connector: ", or ", two_words_connector: " or ")
    end

    def subsequent_session_dates_offered_message
      return nil if session.nil?

      dates = session.future_dates.drop(1)
      return "" if dates.empty?

      "If they’re not seen, they’ll be offered the vaccination on #{
        dates.map { it.to_fs(:short_day_of_week) }.to_sentence
      }."
    end

    private

    def session_dates_are_accurate?
      consent_form ? consent_form.session_dates_are_accurate? : true
    end
  end
end
