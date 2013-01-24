module SCXML; end
class SCXML::Executable
	extend SCXML
	attr_reader :kind
	def initialize(el)
		@el   = el
		@kind = @el.name
	end
	def run
		case @kind
			when 'log' then puts(eval(@el['expr']))
			else warn "Do not know how to execute #{@el.to_s}"
		end
	end
end