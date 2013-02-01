module RXSC; end
class RXSC::Executable
	extend RXSC
	attr_accessor :parent
	def machine
		parent.machine
	end
	def self.from_xml(el)
		case el.name
			when 'log'    then RXSC::Executable::Log.new.read_xml(el)
			when 'assign' then RXSC::Executable::Assign.new(el[:location]).read_xml(el)
			when 'raise'  then RXSC::Executable::Raise.new(el[:event])
			when 'send'   then RXSC::Executable::Send.new.read_xml(el)
			else raise "Unsupported executable: #{el}"
		end
	end
	def xml_properties(el,names)
		names.each{ |n| instance_variable_set( :"@#{n}", el[n] ) if el[n]  }
	end
end

class RXSC::Executable::Assign < RXSC::Executable
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

class RXSC::Executable::Log < RXSC::Executable
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

class RXSC::Executable::Raise < RXSC::Executable
	attr_reader :event
	def initialize(event)
		@event = event
	end
	def run
		machine.fire_event(@event,nil,true)
	end
end

class RXSC::Executable::Send < RXSC::Executable
	attr_reader :eventexpr, :delay, :type, :id
	def initialize(eventexpr="'bogus-send'",delay=nil)
		@eventexpr = eventexpr
		@type = 'http://www.w3.org/TR/scxml/#SCXMLEventProcessor'
	end
	def read_xml(el)
		xml_properties(el,%w[id idlocation])
		@eventexpr = el[:event] ? el[:event].inspect : el[:eventexpr]
		unless @eventexpr
			if c = el.at_xpath('./scxml:content',RXSC::NAMESPACES)
				@eventexpr = c['expr'] || c.text.inspect
			else
				raise "Invalid <send>, must include one of event='...', eventexpr='...', or <content>\n#{el}"
			end
		end

		@delay = el[:delay] ? el[:delay].inspect : el[:delayexpr]
		warn "Delayed <send> events not supported" if @delay

		@namelist = el[:namelist].to_s.split(/\s+/) if el[:namelist]
		# TODO: support type/typeexpr, just to yell about non-support of non-SCXML types
		# TODO: support target/targetexpr, mostly for targetting other RXSC machines

		self
	end
	def run
		dm  = machine.datamodel
		evt = dm.run(@eventexpr)
		data = @namelist && Hash[ @namelist.map{ |n| [n,dm[n]] } ]
		dm[dm.run(@idlocation)] = @SecureRandom.uuid unless @id || !@idlocation

		# TODO: honor @delay by calling fire_event in a later threaded manner, after making the event queue thread safe?
		machine.fire_event(evt,data,false)
	end
end