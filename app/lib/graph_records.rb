# frozen_string_literal: true

require "digest"

# Spit out a Mermaid-style graph of records.
#
# Usage:
#  graph = GraphRecords.new.graph(patients: [patient])
#  puts graph
#
class GraphRecords
  BOX_STYLES = %w[
    fill:#e6194B,color:white
    fill:#3cb44b,color:white
    fill:#ffe119,color:black
    fill:#4363d8,color:white
    fill:#f58231,color:white
    fill:#911eb4,color:white
    fill:#42d4f4,color:black
    fill:#f032e6,color:white
    fill:#bfef45,color:black
    fill:#fabed4,color:black
    fill:#469990,color:white
    fill:#dcbeff,color:black
    fill:#9A6324,color:white
    fill:#fffac8,color:black
    fill:#800000,color:white
    fill:#aaffc3,color:black
    fill:#808000,color:white
    fill:#ffd8b1,color:black
    fill:#000075,color:white
    fill:#a9a9a9,color:white
    fill:#ffffff,color:black
    fill:#000000,color:white
  ].freeze

  DEFAULT_NODE_ORDER = %w[
    programme
    organisation
    team
    location
    session
    session_date
    patient_location
    class_import
    cohort_import
    session_attendance
    gillick_assessment
    patient
    vaccine
    batch
    vaccination_record
    triage
    user
    consent
    consent_form
    parent_relationship
    parent
  ].freeze

  ALLOWED_TYPES = DEFAULT_NODE_ORDER

  DEFAULT_TRAVERSALS = {
    batch: {
      batch: %i[team vaccine],
      vaccine: %i[programme]
    },
    class_import: {
      class_import: %i[team uploaded_by]
    },
    cohort_import: {
      cohort_import: %i[team uploaded_by]
    },
    consent: {
      consent: %i[consent_form parent patient programme],
      parent: %i[patients],
      patient: %i[parents]
    },
    consent_form: {
      consent_form: %i[consents]
    },
    gillick_assessment: {
      gillick_assessment: %i[performed_by programme],
      session: %i[location]
    },
    location: {
      location: %i[sessions teams]
    },
    organisation: {
      organisation: %i[teams]
    },
    parent: {
      class_import: %i[session],
      consent: %i[parent patient],
      parent: %i[class_imports cohort_imports consents patients],
      patient: %i[consents parents sessions],
      session: %i[location]
    },
    patient: {
      consent: %i[consent_form parent patient],
      location: %i[sessions],
      parent: %i[class_imports cohort_imports consents patients],
      patient: %i[
        class_imports
        cohort_imports
        consents
        parents
        patient_locations
        school
        triages
        vaccination_records
      ],
      patient_location: %i[location patient],
      session: %i[location programmes],
      vaccination_record: %i[session]
    },
    patient_location: {
      patient_location: %i[location patient]
    },
    programme: {
      programme: %i[teams vaccines]
    },
    session: {
      session: %i[location programmes]
    },
    session_attendance: {
      session: %i[location],
      session_attendance: %i[session_date],
      session_date: %i[session]
    },
    team: {
      team: %i[organisation programmes]
    },
    triage: {
      triage: %i[patient performed_by programme]
    },
    user: {
      team: %i[programmes],
      user: %i[programmes teams]
    },
    vaccination_record: {
      consent: %i[programme],
      patient: %i[consents],
      session: %i[location],
      vaccination_record: %i[
        patient
        performed_by_user
        programme
        session
        vaccine
      ]
    },
    vaccine: {
      vaccine: %i[batches programme]
    }
  }.freeze

  DETAIL_WHITELIST = {
    batch: %i[archived_at expiry number],
    class_import: %i[
      changed_record_count
      csv_filename
      exact_duplicate_record_count
      new_record_count
      processed_at
      rows_count
      status
      year_groups
    ],
    cohort_import: %i[
      changed_record_count
      csv_filename
      exact_duplicate_record_count
      new_record_count
      processed_at
      rows_count
      status
    ],
    consent: %i[
      created_at
      invalidated_at
      response
      route
      updated_at
      withdrawn_at
    ],
    consent_form: %i[archived_at recorded_at response],
    gillick_assessment: %i[
      created_at
      knows_consequences
      knows_delivery
      knows_disease
      knows_side_effects
      knows_vaccination
    ],
    location: %i[address_postcode gias_year_groups name type],
    organisation: %i[ods_code],
    parent: %i[],
    parent_relationship: %i[type],
    patient: %i[
      date_of_death_recorded_at
      invalidated_at
      restricted_at
      updated_from_pds_at
    ],
    patient_location: %i[academic_year],
    programme: %i[type],
    session: %i[academic_year clinic? dates slug],
    session_attendance: %i[attending created_at updated_at],
    subteam: %i[name],
    team: %i[name workgroup],
    triage: %i[created_at invalidated_at status updated_at],
    user: %i[fallback_role uid],
    vaccination_record: %i[
      created_at
      discarded_at
      outcome
      performed_at
      updated_at
      uuid
    ],
    vaccine: %i[upload_name]
  }.freeze

  EXTRA_DETAIL_WHITELIST_WITH_PII = {
    consent_form: %i[address_postcode date_of_birth family_name given_name],
    parent: %i[email full_name phone],
    parent_relationship: %i[other_name],
    patient: %i[
      address_line_1
      address_line_2
      address_postcode
      address_town
      date_of_birth
      date_of_death
      family_name
      given_name
      nhs_number
      pending_changes
    ],
    user: %i[email fallback_role family_name given_name uid]
  }.freeze

  DETAIL_WHITELIST_WITH_PII =
    DETAIL_WHITELIST.merge(
      EXTRA_DETAIL_WHITELIST_WITH_PII
    ) { |_, base_fields, pii_fields| (base_fields + pii_fields).uniq }

  # @param focus_config [Hash] Hash of model names to ids to focus on (make bold)
  # @param node_order [Array] Array of model names in order to render nodes
  # @param traversals_config [Hash] Hash of model names to arrays of associations to traverse
  # @param node_limit [Integer] The maximum number of nodes which can be displayed
  def initialize(
    focus_config: {},
    node_order: DEFAULT_NODE_ORDER,
    traversals_config: {},
    node_limit: 1000,
    primary_type: nil,
    clickable: false,
    show_pii: false
  )
    @focus_config = focus_config
    @node_order = node_order
    @traversals_config = traversals_config
    @node_limit = node_limit
    @primary_type = primary_type
    @clickable = clickable
    @detail_whitelist = show_pii ? DETAIL_WHITELIST_WITH_PII : DETAIL_WHITELIST
  end

  # @param objects [Hash] Hash of model name to ids to be graphed
  def graph(**objects)
    @nodes = Set.new
    @edges = Set.new
    @inspected = Set.new
    @focus = @focus_config.map { _1.to_s.classify.constantize.where(id: _2) }

    @primary_type ||=
      if objects.keys.size >= 1
        objects.keys.first.to_s.singularize.to_sym
      else
        :patient
      end

    objects.map do |klass, ids|
      class_name = klass.to_s.singularize
      class_sym = class_name.to_sym

      # Skip objects whose type is not in the traversal configuration
      next unless traversals.key?(class_sym)

      associated_objects =
        load_association(class_name.classify.constantize.where(id: ids))

      @focus += associated_objects

      associated_objects.each do |obj|
        @nodes << obj
        introspect(obj)
      end
    end
    ["flowchart TB"] + render_styles + render_nodes + render_edges +
      (@clickable ? render_clicks : [])
  rescue StandardError => e
    if e.message.include?("Recursion limit")
      # Create a Mermaid diagram with a red box containing the error message.
      [
        "flowchart TB",
        "    error[#{e.message}]",
        "    style error fill:#f88,stroke:#f00,stroke-width:2px"
      ]
    else
      raise e
    end
  end

  def traversals
    @traversals ||=
      (DEFAULT_TRAVERSALS[@primary_type] || {}).merge(@traversals_config)
  end

  def render_styles
    object_types = @nodes.map { |node| node.class.name.underscore.to_sym }.uniq

    styles =
      object_types.each_with_object({}) do |type, hash|
        color_index =
          Digest::MD5.hexdigest(type.to_s).to_i(16) % BOX_STYLES.length
        hash[type] = "#{BOX_STYLES[color_index]},stroke:#000"
      end

    focused_styles =
      styles.each_with_object({}) do |(type, style), hash|
        hash["#{type}_focused"] = "#{style},stroke-width:3px"
      end

    styles.merge!(focused_styles)

    styles
      .with_indifferent_access
      .slice(*@nodes.map { class_text_for_obj(it) })
      .map { |klass, style| "  classDef #{klass} #{style}" }
  end

  def render_nodes
    @nodes.to_a.map { "  #{node_with_class(it)}" }
  end

  def render_edges
    @edges.map { |from, to| "  #{node_name(from)} --> #{node_name(to)}" }
  end

  def render_clicks
    @nodes.map { "  click #{node_name(it)} \"#{node_link(it)}\"" }
  end

  def introspect(obj)
    associations_list = traversals[obj.class.name.underscore.to_sym]
    return if associations_list.blank?

    return if @inspected.include?(obj)
    @inspected << obj

    associations_list.each do
      get_associated_objects(obj, it).each do
        @nodes << it
        @edges << order_nodes(obj, it)

        if @nodes.length > @node_limit
          raise "Recursion limit of #{@node_limit} nodes has been exceeded. Try restricting the graph."
        end

        introspect(it)
      end
    end
  end

  def get_associated_objects(obj, association_name)
    obj
      .send(association_name)
      .then { |associated_objects| load_association(associated_objects) }
  end

  def load_association(associated_objects)
    Array(
      if associated_objects.is_a?(ActiveRecord::Relation)
        associated_objects.strict_loading!(false)
      else
        associated_objects
      end
    )
  end

  def order_nodes(*nodes)
    nodes.sort_by do |node|
      @node_order.index(node.class.name.underscore) || Float::INFINITY
    end
  end

  def node_link(obj)
    "/inspect/graph/#{obj.class.name.underscore.pluralize}/#{obj.id}"
  end

  def node_name(obj)
    klass = obj.class.name.underscore
    "#{klass}-#{obj.id}"
  end

  def class_text_for_obj(obj)
    obj.class.name.underscore + (obj.in?(@focus) ? "_focused" : "")
  end

  def node_display_name(obj)
    klass = obj.class.name.underscore.humanize
    "#{klass} #{obj.id}"
  end

  def patients_with_pii_in_graph
    result = Set.new(@nodes.select { |node| node.is_a?(Patient) })

    @nodes.each do |node|
      # Skip if not a type with potential PII
      node_type = node.class.name.underscore.to_sym
      next unless EXTRA_DETAIL_WHITELIST_WITH_PII.key?(node_type)
      next if node.is_a?(Patient) # Already handled these

      if node.respond_to?(:patient) && node.patient
        result << node.patient
      elsif node.respond_to?(:consent) && node.consent&.patient
        result << node.consent.patient
      elsif node.respond_to?(:patients)
        result.merge(node.patients.to_a)
      end
    end

    result.to_a
  end

  def node_types_in_graph
    @nodes.map { |node| node.class.name.underscore.to_sym }.uniq
  end

  def non_breaking_text(text)
    # Insert non-breaking spaces and hyphens to prevent Mermaid from breaking the line
    text.gsub(" ", "&nbsp;").gsub("-", "#8209;")
  end

  def escape_special_chars(text)
    text.to_s.gsub("@", "\\@")
  end

  def node_text(obj)
    text = "\"#{node_display_name(obj)}"

    unless @clickable
      command = "#{obj.class.to_s.classify}.find(#{obj.id})"
      text +=
        "<br><span style=\"font-size:10px\"><i>#{non_breaking_text(command)}</i></span>"
      command =
        "puts GraphRecords.new.graph(#{obj.class.name.underscore}: #{obj.id})"
      text +=
        "<br><span style=\"font-size:10px\"><i>#{non_breaking_text(command)}</i></span>"
    end

    if @detail_whitelist.key?(obj.class.name.underscore.to_sym)
      @detail_whitelist[obj.class.name.underscore.to_sym].each do |detail|
        value = obj.send(detail)
        name = detail.to_s
        detail_text = "#{name}: #{escape_special_chars(value)}"
        text +=
          "<br><span style=\"font-size:14px\">#{non_breaking_text(detail_text)}</span>"
      end
    end

    "#{text}\""
  end

  def node_with_class(obj)
    "#{node_name(obj)}[#{node_text(obj)}]:::#{class_text_for_obj(obj)}"
  end
end
