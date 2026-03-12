# frozen_string_literal: true

module GIAS
  class << self
    DEFAULT_FILE_PATH = "db/data/dfe-schools.zip"

    def download(output_file: DEFAULT_FILE_PATH, logger: Rails.logger)
      # 1. Go to https://get-information-schools.service.gov.uk/Downloads
      # 2. Check "Establishment fields CSV"
      # 3. Check "Establishment links CSV"
      # 4. Submit
      # 5. Download the zip file
      # 6. Move the downloaded file to db/data/dfe-schools.zip

      logger.info "Starting schools data download process..."

      require "mechanize"

      agent = Mechanize.new
      agent.user_agent_alias = "Mac Safari"

      page =
        agent.get("https://get-information-schools.service.gov.uk/Downloads")
      form = page.form_with(action: "/Downloads/Collate")
      form.checkbox_with(id: "establishment-fields-csv-checkbox").check
      form.checkbox_with(id: "establishment-links-csv-checkbox").check
      download_page = form.submit

      wait_time = 0
      until (
              download_form =
                download_page.form_with(action: "/Downloads/Download/Extract")
            ) || wait_time > 60
        sleep(2)
        wait_time += 2
        download_page = agent.get(download_page.uri)
      end

      if download_form
        download_button = download_form.button_with(value: "Results.zip")
        download_file = agent.click(download_button)
        download_file.save!(output_file)
        logger.info "File downloaded successfully to #{output_file}"
        true
      else
        logger.info "Download button never appeared, aborting"
        false
      end
    rescue StandardError => e
      logger.error "#{e.class}: #{e.message}"
      raise
    end

    def import(
      input_file: DEFAULT_FILE_PATH,
      progress_bar: nil,
      logger: Rails.logger
    )
      logger.info "Starting import of #{row_count(input_file) - 1} schools."
      open_csv(input_file) do |rows|
        batch_size = 1000
        schools = []

        rows.each do |row|
          gias_establishment_number = row["EstablishmentNumber"]
          next if gias_establishment_number.blank?

          schools << Location.new(
            type: :school,
            urn: row["URN"],
            gias_local_authority_code: row["LA (code)"],
            gias_establishment_number:,
            gias_phase: Integer(row["PhaseOfEducation (code)"]),
            gias_year_groups: process_year_groups(row),
            name: row["EstablishmentName"],
            address_line_1: row["Street"],
            address_line_2: [
              row["Locality"],
              row["Address3"]
            ].compact_blank.join(", "),
            address_town: row["Town"],
            address_postcode: row["Postcode"],
            status: Integer(row["EstablishmentStatus (code)"]),
            url: process_url(row["SchoolWebsite"].presence)
          )

          if schools.size >= batch_size
            import_schools(schools)
            update_sites(schools)
            schools.clear
          end

          progress_bar&.increment
        end

        unless schools.empty?
          import_schools(schools)
          update_sites(schools)
        end
      end

      logger.info "Import complete"
    rescue StandardError => e
      logger.error "#{e.class}: #{e.message}"
      raise
    end

    def check_import(input_file: DEFAULT_FILE_PATH, progress_bar: nil)
      schools_with_future_sessions = {
        existing:
          Set.new(
            Location
              .school
              .joins(:sessions)
              .merge(Session.scheduled)
              .pluck(:urn)
          ),
        closed: {
        },
        closing: {
        },
        year_group_changes: {
        }
      }
      schools_without_future_sessions = {
        closed: {
        },
        closing: {
        },
        year_group_changes: {
        }
      }

      existing_schools = Set.new(Location.school.pluck(:urn))
      team_schools =
        Set.new(
          TeamLocation
            .joins(:location)
            .merge(Location.school)
            .pluck(:"locations.urn")
        )

      new_schools = Set.new

      Zip::File.open(input_file) do |zip|
        links_csv = zip.glob("links_edubasealldata*.csv").first
        links_csv_content = links_csv.get_input_stream.read

        successors = {}
        CSV.parse(
          links_csv_content,
          headers: true,
          encoding: "ISO-8859-1:UTF-8"
        ) do |row|
          next unless row["LinkType"]&.include?("Successor")

          successors[row["URN"]] ||= []
          successors[row["URN"]] << row["LinkURN"]
        end

        school_data_csv = zip.glob("edubasealldata*.csv").first
        school_csv_content = school_data_csv.get_input_stream.read

        CSV.parse(
          school_csv_content,
          headers: true,
          encoding: "ISO-8859-1:UTF-8"
        ) do |row|
          gias_establishment_number = row["EstablishmentNumber"]
          next if gias_establishment_number.blank?

          urn = row["URN"]
          new_status = row["EstablishmentStatus (name)"]

          if urn.in?(schools_with_future_sessions[:existing])
            check_for_school_closure(
              row,
              schools_with_future_sessions,
              successors
            )
            check_for_year_group_changes(
              row,
              schools_with_future_sessions,
              existing_schools
            )
          elsif urn.in?(team_schools)
            check_for_school_closure(
              row,
              schools_without_future_sessions,
              successors
            )
            check_for_year_group_changes(
              row,
              schools_without_future_sessions,
              existing_schools
            )
          elsif !urn.in?(existing_schools) &&
                new_status.in?(["Open", "Open, but proposed to close"])
            new_schools << urn
          end
        ensure
          progress_bar&.increment
        end
      end

      {
        new_schools:,
        schools_with_future_sessions:,
        schools_without_future_sessions:
      }
    end

    def log_import_check_results(results, logger: Rails.logger)
      new_schools = results[:new_schools]
      schools_with_future_sessions = results[:schools_with_future_sessions]
      schools_without_future_sessions =
        results[:schools_without_future_sessions]

      closed_schools_count =
        schools_without_future_sessions[:closed].count +
          schools_with_future_sessions[:closed].count
      closing_schools_count =
        schools_without_future_sessions[:closing].count +
          schools_with_future_sessions[:closing].count

      closed_schools_with_future_sessions_pct =
        calculate_percentage(schools_with_future_sessions, :closed)
      closing_schools_with_future_sessions_pct =
        calculate_percentage(schools_with_future_sessions, :closing)
      schools_with_changed_year_groups_pct =
        calculate_percentage(schools_with_future_sessions, :year_group_changes)

      logger.info <<~OUTPUT
                  New schools (total): #{new_schools.count}
               Closed schools (total): #{closed_schools_count}
Proposed to be closed schools (total): #{closing_schools_count}

   Existing schools with future sessions: #{schools_with_future_sessions[:existing].count}
               That are closed in import: #{schools_with_future_sessions[:closed].count} (#{closed_schools_with_future_sessions_pct * 100}%)
That are proposed to be closed in import: #{schools_with_future_sessions[:closing].count} (#{closing_schools_with_future_sessions_pct * 100}%)
            That have year group changes: #{schools_with_future_sessions[:year_group_changes].count} (#{schools_with_changed_year_groups_pct * 100}%)
      OUTPUT

      if schools_with_future_sessions[:closed].any?
        logger.info "\nURNs of closed schools with future sessions:"
        schools_with_future_sessions[:closed].sort.each do |urn, successors|
          if successors.any?
            successor_info = format_successors_with_teams(successors)
            logger.info "  #{urn} -> successor(s): #{successor_info}"
          else
            logger.info "  #{urn}"
          end
        end
      end

      if schools_with_future_sessions[:closing].any?
        logger.info "\nURNs of schools that will be closing, with future sessions:"
        schools_with_future_sessions[:closing].sort.each do |urn, successors|
          if successors.any?
            successor_info = format_successors_with_teams(successors)
            logger.info "  #{urn} -> successor(s): #{successor_info}"
          else
            logger.info "  #{urn}"
          end
        end
      end

      if schools_with_future_sessions[:year_group_changes].any?
        logger.info "\nURNs of schools with year group changes, with future sessions:"
        schools_with_future_sessions[:year_group_changes].each do |urn, change|
          logger.info "  #{urn}:"
          logger.info "    Current:  #{change[:current]}"
          logger.info "    New:      #{change[:new]}"
        end
      end
    rescue StandardError => e
      logger.error "#{e.class}: #{e.message}"
      raise
    end

    def process_url(url)
      return nil if url.blank?

      # Legh Vale school has a URL of http:www.leghvale.st-helens.sch.uk
      # which is not a valid URL.
      url = url.gsub("http:www", "http://www")

      # Some school URLs don't start with http:// and https://
      url.start_with?("http://", "https://") ? url : "https://#{url}"
    end

    def process_year_groups(row)
      low_year_group = row["StatutoryLowAge"].to_i - 4
      high_year_group = row["StatutoryHighAge"].to_i - 5
      (low_year_group..high_year_group).to_a
    end

    def row_count(input_file)
      Zip::File.open(input_file) do |zip|
        csv_entry = zip.glob("edubasealldata*.csv").first
        csv_entry.get_input_stream.read.lines.count
      end
    end

    private

    def open_csv(input_file)
      Zip::File.open(input_file) do |zip|
        csv_entry = zip.glob("edubasealldata*.csv").first
        csv_content = csv_entry.get_input_stream.read
        rows =
          CSV.parse(csv_content, headers: true, encoding: "ISO-8859-1:UTF-8")
        yield rows
      end
    end

    def import_schools(schools)
      Location.import!(
        schools,
        on_duplicate_key_update: {
          conflict_target: %i[urn],
          index_predicate: "type = 0 AND site IS NULL",
          columns: %i[
            address_line_1
            address_line_2
            address_postcode
            address_town
            gias_establishment_number
            gias_local_authority_code
            gias_phase
            gias_year_groups
            name
            status
            url
          ]
        }
      )
    end

    def update_sites(schools)
      schools_by_urn = schools.index_by(&:urn)

      sites =
        Location
          .where(urn: schools_by_urn.keys)
          .where.not(site: nil)
          .distinct
          .map do |site|
            school = schools_by_urn[site.urn]

            site.assign_attributes(
              gias_establishment_number: school.gias_establishment_number,
              gias_local_authority_code: school.gias_local_authority_code,
              gias_phase: school.gias_phase,
              gias_year_groups: school.gias_year_groups,
              status: school.status,
              url: school.url
            )

            site
          end

      return if sites.empty?

      Location.import!(
        sites,
        on_duplicate_key_update: {
          conflict_target: %i[urn site],
          columns: %i[
            gias_establishment_number
            gias_local_authority_code
            gias_phase
            gias_year_groups
            status
            url
          ]
        }
      )
    end

    def check_for_school_closure(row, school_set, successors = {})
      urn = row["URN"]
      new_status = row["EstablishmentStatus (name)"]

      if new_status == "Closed"
        school_set[:closed][urn] = successors[urn] || []
      elsif new_status == "Open, but proposed to close"
        school_set[:closing][urn] = successors[urn] || []
      end
    end

    def check_for_year_group_changes(row, school_set, existing_schools)
      urn = row["URN"]
      return unless urn.in? existing_schools

      new_year_groups = process_year_groups(row)
      current_year_groups = Location.school.find_by(urn:).gias_year_groups

      if new_year_groups != current_year_groups
        school_set[:year_group_changes][urn] = {
          current: current_year_groups,
          new: new_year_groups
        }
      end
    end

    def calculate_percentage(schools_set, metric)
      if schools_set[:existing].count.positive?
        schools_set[metric].count.to_f / schools_set[:existing].count
      else
        0.0
      end
    end

    def format_successors_with_teams(successor_urns)
      annotated_successor_urns =
        successor_urns.map do |successor_urn|
          locations = Location.school.where(urn: successor_urn)

          if locations.count == 1
            teams = locations.sole.teams.uniq
            if teams.any?
              team_names = teams.map(&:name).join(", ")
              "#{successor_urn} (Team: #{team_names})"
            else
              "#{successor_urn} (no team)"
            end
          elsif locations.count > 1
            site_urns =
              locations.where.not(site: nil).map(&:urn_and_site).join(", ")
            team_names =
              locations
                .where.not(site: nil)
                .flat_map(&:teams)
                .uniq
                .map(&:name)
                .join(", ")
            "#{site_urns} (Teams: #{team_names})"
          else
            "#{successor_urn} (not found)"
          end
        end

      annotated_successor_urns.join(", ")
    end
  end
end
