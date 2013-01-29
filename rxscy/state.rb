require 'securerandom'
module RXSCy
	NAMESPACES = { 'scxml'=>'http://www.w3.org/2005/07/scxml' }
end
class RXSCy::State
	extend RXSCy
	attr_reader :id, :entry_ordering, :initial
	attr_reader :states, :transitions, :invokes, :onenters, :onexits, :data
	alias_method :name, :id
	attr_accessor :parent
	def self.from_xml(el)
		case el.name
			when 'final'    then RXSCy::Final
			when 'initial'  then RXSCy::Initial
			when 'parallel' then RXSCy::Parallel
			when 'history'  then RXSCy::History
			else                 RXSCy::State
		end.new.read_xml(el)
	end

	def initialize(id=SecureRandom.uuid)
		@id          = id
		@states      = NotifyingArray.new
		@transitions = NotifyingArray.new
		@invokes     = NotifyingArray.new
		@onexits     = NotifyingArray.new
		@onenters    = NotifyingArray.new
		@data        = NotifyingArray.new
		[@states,@transitions,@invokes,@onexits,@onenters,@data].each{ |a| a.on_change{ |o| o.parent=self } }
	end

	def xml_properties(el,names,map={})
		names.each{ |n|     instance_variable_set( :"@#{n}",  el[n]  ) if el[n]  }
		map.each{   |n1,n2| instance_variable_set( :"@#{n2}", el[n1] ) if el[n1] }
	end

	def read_xml(el)
		xml_properties(el,%w[id initial])

		names = %w[state final parallel initial history].map{ |s| s.prepend('scxml:') }.join('|')
		@states.concat el.xpath(names,RXSCy::NAMESPACES).map(&RXSCy::State).each{|s| s.parent=self }

		# If there wasn't an initial attribute or element, pretend there was an attribute with the correct id
		unless @initial || @states.find(&:initial?)
			@initial = @states.first.id unless @states.empty?
		end
		if @initial # attribute
			@initial = RXSCy::Initial.new.tap{ |i| i.parent=self; i.transitions << RXSCy::Transition.new(i,targets:@initial) }
		else # either element or none
			@initial = @states.find(&:initial?)
		end
		@initial.parent = self if @initial

		@transitions.concat el.css('> transition').map{ |e| RXSCy::Transition.new(self).read_xml(e) }
		@onenters.concat    el.css('> onentry > *').map(&RXSCy::Executable)
		@onexits.concat     el.css('> onexit  > *').map(&RXSCy::Executable)
		@data.concat        el.css('> datamodel > data').map(&RXSCy::Datamodel::Datum)

		self
	end

	def pure?;     true;  end
	def final?;    false; end
	def parallel?; false; end
	def history?;  false; end
	def initial?;  false; end
	def real?;     !pseudo?;                                  end
	def pseudo?;   initial? || history?;                      end
	def compound?; pure? && !atomic?;                         end
	def atomic?;   pure? && @states.reject(&:pseudo?).empty?; end
		
	def states_by_id
		states.select(&:id).map{ |s| [{s.id=>s},s.states_by_id] }.flatten.inject({}) do |all,h|
			all.merge(h){ |id,_| raise "Multiple states with id #{id}" }
		end
	end

	def connect_references!
		@initial.connect_references! if @initial
		@states.each(&:connect_references!)
		@transitions.each(&:connect_references!)
	end

	def ancestors( stop_state=nil )
		walker = self.parent
		[].tap do |a|
			until walker==stop_state || !walker
				a << walker
				walker = walker.parent
			end
		end
	end

	def descendant_of?(s2)
		parent && (parent==s2 || parent.descendant_of?(s2))
	end

	def machine
		@parent && @parent.machine
	end

	def path
		[*ancestors.reverse,self].map{ |s| s.name || '?' }.join('/')
	end

	def events
		Set.new(@transitions.map(&:events).flatten) + @states.map(&:events).inject(Set.new,&:+)
	end

	def to_s
		"<#{self.class} '#{path}'>"
	end

	def exit_ordering
		-@entry_ordering
	end

	protected
		attr_writer :parent, :id
		def set_order(index=0)
			@entry_ordering = index
			@states.each{ |s| index = s.set_order(index+1) }
			index
		end
end

class RXSCy::Parallel < RXSCy::State
	def pure?;    false; end
	def parallel?; true; end
end
class RXSCy::Initial  < RXSCy::State
	def pure?;   false; end
	def initial?; true; end
end

class RXSCy::Final    < RXSCy::State
	def pure?;  false; end
	def final?;  true; end
	def atomic?; true; end
	def initialize(*a)
		super
		@done_expressions = []
	end
	def read_xml(el)
		super.tap{
			if c=el.at_xpath('./scxml:donedata/scxml:content',RXSCy::NAMESPACES)
				self.done_expr = c['expr'] || c.text.inspect
			else
				el.xpath('./scxml:donedata/scxml:param',RXSCy::NAMESPACES).each do |param|
					# TODO: handle location instead of expr
					add_named_done_expr(param['name'],param['expr'])
				end
			end
		}
	end
	def done_expr=( value )
		@done_expression = value
	end
	def add_named_done_expr(name,expr)
		@done_expressions << [name,expr]
	end
	def donedata
		if @done_expression
			run(@done_expression)
		elsif !@done_expressions.empty?
			Hash[@done_expressions.map{ |k,expr| [k,run(expr)] }]
		end
	end
	def run(expr)
		machine.datamodel.run(expr)
	end
end

class RXSCy::History  < RXSCy::State
	def pure?;   false; end
	def history?; true; end
	attr_reader :type
	def read_xml(el)
		super.tap{ xml_properties(el,%w[type]) }
	end
end
