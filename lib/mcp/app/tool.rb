# frozen_string_literal: true

module MCP
  class App
    # Include this module in your app to add tool functionality
    module Tool
      def self.included(base)
        base.extend(ClassMethods)
      end

      module ClassMethods
        def tools
          @tools ||= {}
        end

        def tool(tool, &block)
          tool = ToolBuilder.new(tool, &block) if block_given?

          tool_hash = tool.to_h
          name = tool_hash[:name]

          raise ArgumentError, "Tool name cannot be nil or empty" if name.nil? || name.empty?
          raise ArgumentError, "Handler must be provided" if tool_hash[:handler].nil?

          tools[name] = tool_hash
        end

        def reset!
          @tools = nil
        end
      end

      # Builds schemas for arguments, supporting simple types, nested objects, and arrays
      class SchemaBuilder
        def initialize
          @schema = nil
          @properties = {}
          @required = []
        end

        def argument(name, type = nil, required: false, description: "", items: nil, &block)
          if type == Array
            if block_given?
              sub_builder = SchemaBuilder.new
              sub_builder.instance_eval(&block)
              item_schema = sub_builder.to_schema
            elsif items
              item_schema = {type: ruby_type_to_schema_type(items)}
            else
              raise ArgumentError, "Must provide items or a block for array type"
            end
            @properties[name] = {type: :array, description: description, items: item_schema}
          elsif block_given?
            raise ArgumentError, "Type not allowed with block for objects" if type
            sub_builder = SchemaBuilder.new
            sub_builder.instance_eval(&block)
            @properties[name] = sub_builder.to_schema.merge(description: description)
          else
            raise ArgumentError, "Type required for simple arguments" if type.nil?
            @properties[name] = {type: ruby_type_to_schema_type(type), description: description}
          end
          @required << name if required
        end

        def type(t)
          @schema = {type: ruby_type_to_schema_type(t)}
        end

        def to_schema
          @schema || {type: :object, properties: @properties, required: @required}
        end

        private

        def ruby_type_to_schema_type(type)
          if type == String
            :string
          elsif type == Integer
            :integer
          elsif type == Float
            :number
          elsif type == TrueClass || type == FalseClass
            :boolean
          elsif type == Array
            :array
          else
            raise ArgumentError, "Unsupported type: #{type}"
          end
        end
      end

      class ToolBuilder
        attr_reader :name, :arguments, :handler

        def initialize(name, &block)
          @name = name
          @description = ""
          @schema_builder = SchemaBuilder.new
          @handler = nil
          instance_eval(&block) if block_given?
        end

        def description(text = nil)
          text ? @description = text : @description
        end

        def argument(*args, **kwargs, &block)
          @schema_builder.argument(*args, **kwargs, &block)
        end

        def call(&block)
          @handler = block if block_given?
        end

        def to_h
          {
            name: @name,
            description: @description,
            input_schema: @schema_builder.to_schema,
            handler: @handler
          }
        end
      end

      def tools
        self.class.tools
      end

      # Lists tools with pagination
      def list_tools(cursor: nil, page_size: 10)
        start = cursor ? cursor.to_i : 0
        paginated = tools.values[start, page_size]

        next_cursor = (start + page_size < tools.length) ? (start + page_size).to_s : nil
        {tools: paginated.map { |t| {name: t[:name], description: t[:description], inputSchema: t[:input_schema]} }, nextCursor: next_cursor}.compact
      end

      # Calls a tool with the provided arguments
      def call_tool(name, **args)
        tool = tools[name]
        raise ArgumentError, "Tool not found: #{name}" unless tool

        validate_arguments(tool[:input_schema], args)
        {content: [{type: "text", text: tool[:handler].call(args).to_s}], isError: false}
      rescue => e
        {content: [{type: "text", text: "Error: #{e.message}"}], isError: true}
      end

      private

      def validate(schema, arg, path = "")
        errors = []
        type = schema[:type]

        if type == :object
          if !arg.is_a?(Hash)
            errors << (path.empty? ? "Arguments must be a hash" : "Expected object for #{path}, got #{arg.class}")
          else
            schema[:required]&.each do |req|
              unless arg.key?(req)
                errors << (path.empty? ? "Missing required param :#{req}" : "Missing required param #{path}.#{req}")
              end
            end
            schema[:properties].each do |key, subschema|
              if arg.key?(key)
                sub_path = path.empty? ? key : "#{path}.#{key}"
                sub_errors = validate(subschema, arg[key], sub_path)
                errors.concat(sub_errors)
              end
            end
          end
        elsif type == :array
          if !arg.is_a?(Array)
            errors << "Expected array for #{path}, got #{arg.class}"
          else
            arg.each_with_index do |item, index|
              sub_path = "#{path}[#{index}]"
              sub_errors = validate(schema[:items], item, sub_path)
              errors.concat(sub_errors)
            end
          end
        else
          valid = case type
          when :string then arg.is_a?(String)
          when :integer then arg.is_a?(Integer)
          when :number then arg.is_a?(Float)
          when :boolean then arg.is_a?(TrueClass) || arg.is_a?(FalseClass)
          else false
          end
          unless valid
            errors << "Expected #{type} for #{path}, got #{arg.class}"
          end
        end
        errors
      end

      def validate_arguments(schema, args)
        errors = validate(schema, args, "")
        unless errors.empty?
          raise ArgumentError, errors.join("\n").to_s
        end
      end
    end
  end
end
