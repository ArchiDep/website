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
        more_id = SecureRandom.hex
        more_control =
          %|<input id="#{more_id}" type="checkbox" class="peer hidden" />|
        more =
          %|
          <label for="#{more_id}" class="more">
            Would you like to know more?
          </label>
          <div class="controls">
            <label for="#{more_id}" class="less join-item">
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

      %|<div class="#{callout_class}">
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
