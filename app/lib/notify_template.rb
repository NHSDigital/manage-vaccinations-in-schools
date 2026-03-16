# frozen_string_literal: true

class NotifyTemplate
  class << self
    def find(name, channel:)
      local_templates(channel)[name]
    end

    def find_by_id(template_id, channel:)
      return nil if template_id.blank?

      local_templates(channel).values.find { _1.id == template_id.to_s }
    end

    def exists?(name, channel:)
      local_templates(channel).key?(name)
    end

    def all_ids(channel:)
      local_templates(channel).values.map(&:id).freeze
    end

    private

    def local_templates(channel)
      channel = channel.to_sym
      @local_templates ||= {}
      @local_templates[channel] ||= scan_templates(channel)
    end

    def scan_templates(channel)
      channel = channel.to_sym
      dir = Rails.root.join("app/views/notify_templates", channel.to_s)
      return {}.freeze unless dir.exist?

      Dir
        .glob(dir.join("*.text.erb"))
        .each_with_object(
          ActiveSupport::HashWithIndifferentAccess.new
        ) do |path, hash|
          name = File.basename(path, ".text.erb")
          content = File.read(path, encoding: "UTF-8")
          template = new(name:, channel:, content:)
          next unless template.id

          hash[name] = template
        end
    end
  end

  attr_reader :name, :channel, :id, :body, :subject

  def initialize(name:, channel:, content:)
    @name = name.to_sym
    @channel = channel.to_sym
    frontmatter, @body = parse_frontmatter(content)
    @id = frontmatter["template_id"]
    @subject = frontmatter["subject"].to_s
  end

  def render(personalisation)
    ctx = personalisation.instance_eval { binding }
    body = ERB.new(@body, trim_mode: nil).result(ctx)
    return { body: } if @channel == :sms

    { subject: ERB.new(@subject, trim_mode: nil).result(ctx), body: }
  rescue NameError => e
    raise NameError, "#{e.message} in #{@channel} template '#{@name}'"
  end

  private

  def parse_frontmatter(content)
    delimiter = "---\n"
    separator = "\n---\n"
    return {}, content unless content.start_with?(delimiter)

    frontmatter_block, body_content = content.split(separator, 2)
    return {}, content if body_content.nil?

    frontmatter_str = frontmatter_block.delete_prefix(delimiter)
    frontmatter = YAML.safe_load(frontmatter_str) || {}
    [frontmatter, body_content]
  end
end
