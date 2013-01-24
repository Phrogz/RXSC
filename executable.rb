module SCXML; end
class SCXML::Executable
	extend SCXML
	attr_accessor :machine
	def self.from_xml(el)
		case el.name
			when 'log'    then SCXML::Executable::Log.new.read_xml(el)
			when 'assign' then SCXML::Executable::Assign.new(el[:location]).read_xml(el)
		end
	end
	def xml_properties(el,names)
		names.each{ |n|     instance_variable_set( :"@#{n}",  el[n]  ) if el[n]  }
	end
end

class SCXML::Executable::Assign < SCXML::Executable
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

class SCXML::Executable::Log < SCXML::Executable
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
		puts [@label,@expr && machine.datamodel.run(@expr)].compact.join(': ') if @label || @expr
	end
end