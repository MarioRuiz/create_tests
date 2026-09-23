
class CreateTests

  class << self

    # Extracts the resource dependency chain from a request path.
    # Works with both placeholder paths ({param}) and interpolated paths
    # (where params are resolved, possibly to empty strings).
    #
    # @param request [Hash] Request hash containing :path and :method keys
    # @param params [Array<String>] Positional parameter names (e.g. ["@subscription_id", "@pool_name"])
    # @return [Array<Hash>, Hash|nil] Two values: prerequisite chain array and target resource hash (or nil).
    #   Each hash has keys: resource (String), param (String), params_up_to (Array)
    private def extract_resource_chain(request, params)
      return [], nil unless request.key?(:path)
      return [], nil if params.size < 2

      path = request[:path].split("?").first
      param_names = params.map { |p| p.gsub("@", "") }

      placeholder_mode = path.include?("{")

      if placeholder_mode
        segments = path.split("/").reject(&:empty?)
        resource_pairs = []
        i = 0
        while i < segments.size
          seg = segments[i]
          next_seg = segments[i + 1]
          if next_seg && next_seg.match?(/\A\{.+\}\z/)
            placeholder = next_seg.gsub(/[{}]/, "")
            resource_pairs << { segment: seg, placeholder: placeholder }
            i += 2
          else
            i += 1
          end
        end
      else
        segments = path.split("/")
        segments.shift if segments.first == ""

        resource_pairs = []
        param_idx = 0
        i = 0
        while i < segments.size && param_idx < param_names.size
          seg = segments[i]
          next_seg = segments[i + 1]
          if seg != "" && (next_seg.nil? || next_seg == "")
            resource_pairs << { segment: seg, placeholder: param_names[param_idx] }
            param_idx += 1
            i += 2
          else
            i += 1
          end
        end
      end

      return [], nil if resource_pairs.size <= 1

      all_entries = resource_pairs.each_with_index.map do |pair, idx|
        resource_name = to_snake_case(pair[:segment])

        matching_param = param_names.find { |p| p == pair[:placeholder] || p.end_with?("_#{pair[:placeholder]}") || p.include?(pair[:placeholder]) }
        matching_param ||= pair[:placeholder]

        params_up_to = []
        (0..idx).each do |j|
          ph = resource_pairs[j][:placeholder]
          mp = param_names.find { |p| p == ph || p.end_with?("_#{ph}") || p.include?(ph) }
          params_up_to << "@#{mp || ph}"
        end

        { resource: resource_name, param: matching_param, params_up_to: params_up_to }
      end

      prerequisites = all_entries[0..-2]
      target = all_entries.last

      return prerequisites, target
    end

    private def to_snake_case(str)
      str.gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
         .gsub(/([a-z\d])([A-Z])/, '\1_\2')
         .downcase
    end
  end
end
