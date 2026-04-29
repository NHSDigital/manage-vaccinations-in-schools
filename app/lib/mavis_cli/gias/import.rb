#frozen_string_literal: true

module MavisCLI
  module GIAS
    class Import < Dry::CLI::Command
      desc "Import GIAS schools data"

      option :input_file,
             aliases: ["-i"],
             default: "db/data/dfe-schools.zip",
             desc: "GIAS database file to use"

      def call(input_file:, **)
        unless File.exist?(input_file)
          warn "Input file (#{input_file}) not found. Run `bin/mavis gias download` first."
          exit 1 # rubocop:disable Rails/Exit
        end

        MavisCLI.load_rails

        logger = Logger.new($stdout)
        logger.formatter =
          proc { |_severity, _datetime, _progname, msg| "#{msg}\n" }

        row_count = ::GIAS.row_count(input_file)
        progress_bar = MavisCLI.progress_bar(row_count)

        ::GIAS.import(input_file:, progress_bar:, logger:)
      end
    end
  end

  register "gias" do |prefix|
    prefix.register "import", GIAS::Import
  end
end
