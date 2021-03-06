# frozen_string_literal: true
require 'cucumber/gherkin/formatter/ansi_escapes'

module Cucumber
  module RbSupport
    # Defines the basic DSL methods availlable in all Cucumber step definitions.
    #
    # You can, and probably should, extend this DSL with your own methods that
    # make sense in your domain. For more on that, see {Cucumber::RbSupport::RbDsl#World}
    module RbWorld

      # @private
      AnsiEscapes = Cucumber::Gherkin::Formatter::AnsiEscapes

      # Call a Transform with a string from another Transform definition
      def Transform(arg)
        rb = @__cucumber_runtime.support_code.ruby
        rb.execute_transforms([arg]).first
      end

      # @private
      attr_writer :__cucumber_runtime, :__natural_language

      # Extend the World with user-defined modules
      def add_modules!(world_modules, namespaced_world_modules)
        add_world_modules!(world_modules)
        add_namespaced_modules!(namespaced_world_modules)
      end

      # Run a single Gherkin step
      # @example Call another step
      #   step "I am logged in"
      # @example Call a step with quotes in the name
      #   step %{the user "Dave" is logged in}
      # @example Passing a table
      #   step "the following users exist:", table(%{
      #     | name  | email           |
      #     | Matt  | matt@matt.com   |
      #     | Aslak | aslak@aslak.com |
      #   })
      # @example Passing a multiline string
      #   step "the email should contain:", "Dear sir,\nYou've won a prize!\n"
      # @param [String] name The name of the step
      # @param [String,Cucumber::Ast::DocString,Cucumber::Ast::Table] multiline_argument
      def step(name, raw_multiline_arg=nil)
        location = Core::Ast::Location.of_caller
        @__cucumber_runtime.invoke_dynamic_step(name, MultilineArgument.from(raw_multiline_arg, location))
      end

      # Run a snippet of Gherkin
      # @example
      #   steps %{
      #     Given the user "Susan" exists
      #     And I am logged in as "Susan"
      #   }
      # @param [String] steps_text The Gherkin snippet to run
      def steps(steps_text)
        location = Core::Ast::Location.of_caller
        @__cucumber_runtime.invoke_dynamic_steps(steps_text, @__natural_language, location)
      end

      # Parse Gherkin into a {Cucumber::Ast::Table} object.
      #
      # Useful in conjunction with the #step method.
      # @example Create a table
      #   users = table(%{
      #     | name  | email           |
      #     | Matt  | matt@matt.com   |
      #     | Aslak | aslak@aslak.com |
      #   })
      # @param [String] text_or_table The Gherkin string that represents the table
      def table(text_or_table, file=nil, line_offset=0)
        @__cucumber_runtime.table(text_or_table, file, line_offset)
      end

      # Print a message to the output.
      #
      # @note Cucumber might surprise you with the behaviour of this method. Instead
      #   of sending the output directly to STDOUT, Cucumber will intercept and cache
      #   the message until the current step has finished, and then display it.
      #
      #   If you'd prefer to see the message immediately, call {Kernel.puts} instead.
      def puts(*messages)
        # Even though they won't be output until later, converting the messages to
        # strings right away will protect them from modifications to their original
        # objects in the mean time
        messages.collect! { |message| "#{message}" }

        @__cucumber_runtime.puts(*messages)
      end

      # Pause the tests and ask the operator for input
      def ask(question, timeout_seconds=60)
        @__cucumber_runtime.ask(question, timeout_seconds)
      end

      # Embed an image in the output
      def embed(file, mime_type, label='Screenshot')
        @__cucumber_runtime.embed(file, mime_type, label)
      end

      # Mark the matched step as pending.
      def pending(message = "TODO")
        if block_given?
          begin
            yield
          rescue Exception
            raise Pending, message
          end
          raise Pending, "Expected pending '#{message}' to fail. No Error was raised. No longer pending?"
        else
          raise Pending, message
        end
      end

      # Skips this step and the remaining steps in the scenario
      def skip_this_scenario(message = "Scenario skipped")
        raise Core::Test::Result::Skipped, message
      end

      # Prints the list of modules that are included in the World
      def inspect
        modules = [self.class]
        (class << self; self; end).instance_eval do
          modules += included_modules
        end
        modules << stringify_namespaced_modules
        sprintf("#<%s:0x%x>", modules.join('+'), self.object_id)
      end

      # see {#inspect}
      def to_s
        inspect
      end

      private

      # @private
      def add_world_modules!(modules)
        modules.each do |world_module|
          extend(world_module)
        end
      end

      # @private
      def add_namespaced_modules!(modules)
        @__namespaced_modules = modules
        modules.each do |namespace, world_modules|
          world_modules.each do |world_module|
            variable_name = "@__#{namespace}_world"

            inner_world = if self.class.respond_to?(namespace)
                            instance_variable_get(variable_name)
                          else
                            Object.new
                          end
            instance_variable_set(variable_name,
                                  inner_world.extend(world_module))
            self.class.send(:define_method, namespace) do
              instance_variable_get(variable_name)
            end
          end
        end
      end

      def stringify_namespaced_modules
        @__namespaced_modules.map { |k, v| "#{v.join(',')} (as #{k})" }.join('+')
      end
    end
  end
end
