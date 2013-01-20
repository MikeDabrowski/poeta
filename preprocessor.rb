# -*- encoding: utf-8 -*-

require './randomized_choice'

module Poeta
	# preprocessor accepting a subset of commands known to C preprocessor
	class Preprocessor
		def initialize
			@vars = {}
			@functions = {'CHANCE' => lambda { |chance| ch = chance.to_f ; validate_chance(ch) && check_chance(ch) } }
		end

		# Returns processed source.
		# Output should be iterated with each_line method.
		# After processing one source, the processor instance will remember
		# all defined variables when called to process an another source.
		def process(source)
			@source = source.respond_to?(:path) ? source.path : 'unknown'
			@line_no = 0
			@outputting = true
			out_lines = []
			source.each_line do |line|
				@line_no += 1
				if is_from_preprocessor?(line)
					parse(line)
				else
					if @outputting
						out_lines << line
					end
				end
			end
			FakeIO.new(out_lines)
		end

		def set_function(name, func)
			@functions[name] = func
		end

		private

		include ChanceChecker

		def is_from_preprocessor?(line)
			line =~ /^#(define|if|else|endif)\b/
		end

		def parse(line)
			line.chomp!
			accepted = false
			case line
				when /^#define\s+(\w+)\s+(.+)/
					accepted = handle_definition($1, $2)
				when /#if\s+(\w+)/
					handle_if($1)
					accepted = true
				when /#else\s*$/
					handle_else
					accepted = true
				when /#endif\s*$/
					handle_endif
					accepted = true
				else
					puts "#@source:#@line_no:warn: preprocessor cannot handle command '#{line}'"
			end
			accepted
		end

		def handle_definition(name, body)
			if body =~ /^(\d+)$/
				@vars[name] = $1.to_i
				true
			elsif body =~ /^\s*(\w+)\s*\(([^)]+)\)\s*$/
				func_name = $1
				unless @functions.include?(func_name)
					puts "#@source:#@line_no:error: preprocessor: no function with name '#{func_name}'"
					return false
				end
				args = $2.split(',').map { |s| s.strip }
				begin
					@vars[name] = @functions[func_name].call(*args)
					true
				rescue
					puts "#@source:#@line_no:error: invalid call: '#{body}'; reason: #{$!}"
					false
				end
			else
				puts "#@source:#@line_no:error: preprocessor: cannot define variable with value '#{body}'"
				false
			end
		end

		def handle_if(name)
			if @vars.include?(name) && @vars[name] != 0
				@outputting = true
			else
				@outputting = false
			end
		end

		def handle_else
			@outputting = ! @outputting
		end

		def handle_endif
			@outputting = true
		end

		class FakeIO
			def initialize(lines)
				@lines = lines
			end

			def each_line
				@lines.each { |l| yield l }
			end
		end
	end
end
