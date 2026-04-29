# frozen_string_literal: true

class AppSchoolSummaryComponent < ViewComponent::Base
  def initialize(schoolable, change_links: {})
    @schoolable = schoolable
    @change_links = change_links
  end

  def call = helpers.govuk_summary_list(rows:)

  private

  attr_reader :schoolable, :change_links

  def rows
    [
      urn_row,
      name_row,
      address_row,
      phase_row,
      year_groups_row,
      programmes_row
    ].compact
  end

  def address_row
    row = {
      key: {
        text: "Address"
      },
      value: {
        text: helpers.format_address_single_line(schoolable)
      }
    }
    if change_links[:address]
      row[:actions] = [
        {
          text: change_links[:address][:text] || "Change",
          href: change_links[:address][:link],
          visually_hidden_text: "address"
        }
      ]
    end

    row
  end

  def name_row
    row = { key: { text: "Name" }, value: { text: schoolable.name } }

    if change_links[:name]
      row[:actions] = [
        {
          text: change_links[:name][:text] || "Change",
          href: change_links[:name][:link],
          visually_hidden_text: "name"
        }
      ]
    end

    row
  end

  def phase_row
    row = {
      key: {
        text: "Phase"
      },
      value: {
        text: schoolable.human_enum_name(:phase)
      }
    }

    if change_links[:phase]
      row[:actions] = [
        {
          text: change_links[:phase][:text] || "Change",
          href: change_links[:phase][:link],
          visually_hidden_text: "phase"
        }
      ]
    end

    row
  end

  def programmes_row
    {
      key: {
        text: "Programmes"
      },
      value: {
        text: render(AppProgrammeTagsComponent.new(schoolable.programmes))
      }
    }
  end

  def urn_row
    row = {
      key: {
        text: "URN"
      },
      value: {
        text: tag.span(schoolable.urn_and_site, class: "app-u-code")
      }
    }

    if change_links[:urn]
      row[:actions] = [
        {
          text: change_links[:urn][:text] || "Change",
          href: change_links[:urn][:link]
        }
      ]
    end

    row
  end

  def year_groups_row
    row = {
      key: {
        text: "Year groups"
      },
      value: {
        text: helpers.format_year_groups(schoolable.year_groups)
      }
    }

    if change_links[:year_groups]
      row[:actions] = [
        {
          text: change_links[:year_groups][:text] || "Change",
          href: change_links[:year_groups][:link],
          visually_hidden_text: "year groups"
        }
      ]
    end

    row
  end
end
