module ExpansionsHelper
  # Highlight the prefix of a set code that matches the given query.
  # Returns HTML with the matching part wrapped in a span tag with accent color.
  #
  # @param code [String] the scryfall_set_code to highlight
  # @param query [String] the search query to match against
  # @return [String] HTML with highlighted prefix (safe to render)
  def highlight_set_code(code, query)
    return tag.span(code, class: "font-bold text-stone-800") if query.blank?

    uppercased_code = code.upcase
    uppercased_query = query.upcase

    # Check if code starts with query (case-insensitive)
    if uppercased_code.start_with?(uppercased_query)
      prefix = uppercased_code[0, uppercased_query.length]
      suffix = uppercased_code[uppercased_query.length..]

      # Wrap prefix with accent styling, suffix with default styling
      prefix_span = tag.span(prefix, class: "text-accent font-bold")
      suffix_span = tag.span(suffix, class: "font-bold text-stone-800")
      "#{prefix_span}#{suffix_span}".html_safe
    else
      # No match, return as-is
      tag.span(uppercased_code, class: "font-bold text-stone-800")
    end
  end
end
