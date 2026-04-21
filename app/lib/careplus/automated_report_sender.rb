# frozen_string_literal: true

class Careplus::AutomatedReportSender
  FailedResponseError = Class.new(StandardError)
  BATCH_SIZE = 10_000

  def self.call(...) = new(...).call

  def initialize(team_id:)
    @team = Team.find(team_id)
  end

  def call
    return unless team.eligible_for_automated_careplus_reports?

    export_date = Date.yesterday
    academic_year = export_date.academic_year
    records_scope =
      Reports::AutomatedCareplusExporter.vaccination_records_scope(
        team:,
        academic_year:,
        start_date: export_date,
        end_date: export_date
      )

    records_scope
      .unscope(:order)
      .in_batches(of: BATCH_SIZE) do |batch_scope|
        batch_records = records_scope.where(id: batch_scope.select(:id))
        next if batch_records.none?

        send_batch!(
          vaccination_records: batch_records,
          academic_year:,
          date: export_date
        )
      end
  end

  private

  attr_reader :team

  def send_batch!(vaccination_records:, academic_year:, date:)
    csv =
      Reports::AutomatedCareplusExporter.from_records(
        vaccination_records:,
        team:,
        academic_year:
      )
    programme_types =
      vaccination_records.unscope(:order).distinct.pluck(:programme_type)
    careplus_report =
      create_export!(academic_year:, csv:, date:, programme_types:)

    attach_records!(careplus_report:, vaccination_records:)

    response =
      Careplus::Client.send_csv(
        username: team.careplus_username,
        password: team.careplus_password,
        namespace: team.careplus_namespace,
        payload: csv
      )

    unless response.is_a?(Net::HTTPSuccess)
      careplus_report.update!(status: :failed)

      raise FailedResponseError,
            "CarePlus request failed with HTTP #{response.code}: #{response.message}"
    end

    mark_as_sent!(careplus_report:)
  rescue StandardError
    careplus_report&.update!(status: :failed)
    raise
  end

  def create_export!(academic_year:, csv:, date:, programme_types:)
    timestamp = Time.current

    CareplusReport.create!(
      team:,
      academic_year:,
      date_from: date,
      date_to: date,
      programme_types:,
      scheduled_at: timestamp,
      status: :sending,
      csv_filename: csv_filename(date:, timestamp:),
      csv_data: csv
    )
  end

  def attach_records!(careplus_report:, vaccination_records:)
    timestamp = Time.current

    CareplusReportVaccinationRecord.insert_all!(
      vaccination_records.map do |record|
        {
          careplus_report_id: careplus_report.id,
          vaccination_record_id: record.id,
          change_type: 0,
          created_at: timestamp,
          updated_at: timestamp
        }
      end
    )
  end

  def mark_as_sent!(careplus_report:)
    careplus_report.update!(status: :sent, sent_at: Time.current)
  end

  def csv_filename(date:, timestamp:)
    "#{
      [
        "automated-careplus",
        team.workgroup.parameterize,
        date.iso8601,
        timestamp.strftime("%H%M%S%6N")
      ].join("-")
    }.csv"
  end
end
