# frozen_string_literal: true

module SessionsHelper
  def session_consent_period(session)
    open_at = session.open_consent_at
    close_at = session.close_consent_at

    if open_at.nil? || close_at.nil?
      "Not provided"
    elsif open_at.future?
      "Opens #{open_at.to_fs(:short)}"
    elsif close_at.future?
      "Open from #{open_at.to_fs(:short)} until #{close_at.to_fs(:short)}"
    else
      "Closed #{close_at.to_fs(:short)}"
    end
  end

  def session_dates(session)
    dates = session.dates

    if dates.empty?
      "No dates scheduled"
    elsif dates.length == 1
      dates.min.to_fs(:long)
    else
      min_date = dates.min
      max_date = dates.max

      max_date_str = max_date.to_fs(:long)

      min_date_str =
        if min_date.month == max_date.month && min_date.year == max_date.year
          min_date.day.to_s
        elsif min_date.year == max_date.year
          min_date.strftime("%-d %B")
        else
          min_date.to_fs(:long)
        end

      if dates.length == 2
        "#{min_date_str} to #{max_date_str}"
      else
        "#{min_date_str} to #{max_date_str} (#{dates.length} dates)"
      end
    end
  end

  def session_status(session)
    if session.unscheduled?
      "Unscheduled"
    elsif session.completed?
      "Completed"
    else
      "Scheduled"
    end
  end

  def session_title(session)
    programmes = session.programmes.map(&:name).to_sentence

    items =
      if session.generic_clinic?
        [programmes, "community clinic"].compact
      else
        [programmes, "session at", session.location.name].compact
      end

    items.join(" ")
  end

  def session_caption(session)
    dates = session_dates(session) if session.dates.present?
    year_groups = format_year_groups(session.year_groups)

    [dates, year_groups].compact.join(" – ")
  end

  def session_consent_style(session)
    session.outbreak ? "Outbreak request" : "Standard request"
  end

  def session_future_dates(session)
    session.future_dates.map { it.to_fs(:short_day_of_week) }.to_sentence
  end
end
