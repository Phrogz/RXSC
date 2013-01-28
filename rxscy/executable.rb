module RXSCy; end
class RXSCy::Executable
	extend RXSCy
	attr_accessor :parent
	def machine
		parent.machine
	end
	def self.from_xml(el)
		case el.name
			when 'log'    then RXSCy::Executable::Log.new.read_xml(el)
			when 'assign' then RXSCy::Executable::Assign.new(el[:location]).read_xml(el)
		end
	end
	def xml_properties(el,names)
		names.each{ |n|     instance_variable_set( :"@#{n}",  el[n]  ) if el[n]  }
	end
end

class RXSCy::Executable::Assign < RXSCy::Executable
	attr_reader :location, :expr
	def initialize(location,expr=nil)
		@location = location
		@expr = expr
	end
	def read_xml(el)
		xml_properties(el,%w[location expr])
		@expr ||= el.text
		self
	end
	def run
		machine.datamodel[@location] = machine.datamodel.run(@expr)
	end
end

class RXSCy::Executable::Log < RXSCy::Executable
	attr_reader :label, :expr
	def initialize(expr=nil,label=nil)
		@label = label
		@expr  = expr
	end
	def read_xml(el)
		@expr  = el[:expr]  if el[:expr]
		@label = el[:label] if el[:label]
		self
	end
	def run
		return unless $DEBUG
		puts [@label,@expr && machine.datamodel.run(@expr)].compact.join(': ') if @label || @expr
	end
end