require "securerandom"

module ArchiDep
  class CalloutTagBlock < Liquid::Block
    SYNTAX = /(#{Liquid::TagAttributes})?/
    TYPES = %w[danger exercise more warning]
    CLOSE = %w[
      Amazing!
      Awesome!
      Cool!
      Fabulous!
      Great!
      Outstanding!
      Terrific!
      Wonderful!
    ]
    AMAZING_EMOJIS = %w[🎉 🎊 🚀 👍 👏 🌟 ✨ 💫 😎]

    def self.callout_ids
      @callout_ids ||= Set.new
    end

    def initialize(tag_name, markup, tokens)
      @attributes = {}

      @attributes["type"] = "danger"

      # Parse parameters
      if markup =~ SYNTAX
        markup.scan(Liquid::TagAttributes) do |key, value|
          @attributes[key] = value
        end
      else
        raise SyntaxError.new("Bad options given to 'callout' plugin.")
      end

      @type = @attributes["type"]
      unless TYPES.include?(@type)
        raise SyntaxError.new("Unknown callout type: #{@type}")
      end

      @id = @attributes["id"]
      if @id
        if self.class.callout_ids.include?(@id)
          raise SyntaxError.new(
                  "Duplicate callout ID: '#{@id}' (IDs must be globally unique)"
                )
        elsif @id !~ /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/
          raise SyntaxError.new(
                  "Invalid callout ID: '#{@id}' (IDs must be lowercase, alphanumeric and hyphen-separated)"
                )
        end
        self.class.callout_ids.add(@id)
      elsif @type == "more"
        raise SyntaxError.new("More callout has no ID")
      end

      @icon =
        case @type
        when "danger"
          "exclamation-circle"
        when "exercise"
          %|<div class="icon text">🛠️</div>|
        when "more"
          %|<div class="icon image">:books:</div>|
        when "warning"
          "exclamation-triangle"
        else
          raise SyntaxError.new("Unknown callout type: #{@type}")
        end

      @animate = @attributes["animate"] == "true"

      super
    end

    def render(context)
      text = super

      callout_class = "callout callout-#{@type} group/callout"
      callout_class += " animate" if @animate
      icon_html =
        (
          if @icon.start_with?("<")
            @icon
          else
            render_icon(@icon, context, class: "icon")
          end
        )
      markdown = ArchiDep::Utils.render_markdown(text, context)

      more = ""
      more_id = ""
      more_control = ""
      if @type == "more"
        more_id =
          if @id
            page = context.registers[:page]
            "#{page["num"]}-#{page["course_slug"]}:#{@id}"
          else
            SecureRandom.hex
          end

        more_control =
          %|<input id="callout-#{more_id}" type="checkbox" class="peer hidden" />|
        more =
          %|
          <label for="callout-#{more_id}" class="more tell-me-more">
            Would you like to know more?
          </label>
          <div class="controls">
            <label for="callout-#{more_id}" class="less join-item">
              <span class="mr-1">#{AMAZING_EMOJIS.sample}</span> #{CLOSE.sample}
            </label>
            <button type="button" class="always-tell-me-more join-item">
              <span class="mr-1">📚</span> Always tell me more!
            </button>
          </div>
          <button type="button" class="stop-telling-me-more">
            <span class="mr-1">😵‍💫</span> Stop telling me more...
          </button>
        |
      end

      data_callout = more_id.empty? ? "" : %| data-callout="#{more_id}"|

      %|<div class="#{callout_class}" #{data_callout}>
          #{icon_html}

          <div class="container">
            #{more_control}
            <div class="content">
              #{markdown}
            </div>
            #{more}
          </div>
        </div>|
    end

    private

    def render_icon(name, context, options = {})
      ArchiDep::Utils.render_icon(name, context, options)
    end
  end
end

Liquid::Template.register_tag("callout", ArchiDep::CalloutTagBlock)

Jekyll::Hooks.register :site, :after_reset do |site|
  ArchiDep::CalloutTagBlock.callout_ids.clear
end
