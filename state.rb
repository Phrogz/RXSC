require 'securerandom'
module SCXML; end
class SCXML::State
	extend SCXML
	attr_reader :id, :entry_ordering, :initial, :machine
	attr_reader :states, :transitions, :invokes, :onenters, :onexits, :data
	alias_method :name, :id
	attr_accessor :parent
	def self.from_xml(el)
		case el.name
			when 'final'    then SCXML::Final
			when 'initial'  then SCXML::Initial
			when 'parallel' then SCXML::Parallel
			when 'history'  then SCXML::History
			else                 SCXML::State
		end.new.read_xml(el)
	end

	def initialize(id=SecureRandom.uuid)
		@id          = id
		@states      = []
		@transitions = []
		@invokes     = []
		@onexits     = []
		@onenters    = []
		@data        = []
	end

	def xml_properties(el,names,map={})
		names.each{ |n|     instance_variable_set( :"@#{n}",  el[n]  ) if el[n]  }
		map.each{   |n1,n2| instance_variable_set( :"@#{n2}", el[n1] ) if el[n1] }
	end

	def read_xml(el)
		xml_properties(el,%w[id initial])

		names = %w[state final parallel initial history].map{ |s| s.prepend('xmlns:') }.join('|')
		@states.concat el.xpath(names).map(&SCXML::State)
		@states.each{ |s| s.parent = self }

		# If there wasn't an initial attribute or element, pretend there was an attribute with the correct id
		unless @initial || @states.find(&:initial?)
			@initial = @states.first.id unless @states.empty?
		end
		if @initial # attribute
			@initial = SCXML::Initial.new("bob#{rand(9999)}").tap{ |i| i.parent=self; i.transitions << SCXML::Transition.new(i,targets:@initial) }
		else # either element or none
			unless @initial = @states.find(&:initial?)
				# TODO: this seems wrong, as it adds an @initial to atomic states…but what else do you do with an <scxml> doc with no sub-states?
				@initial = SCXML::Initial.new("whoa#{rand(9999)}").tap{ |i| i.parent=self; i.transitions << SCXML::Transition.new(i,targets:self) }
			end
		end
		@initial.parent = self if @initial

		@transitions.concat el.css('> transition').map{ |e| SCXML::Transition.new(self).read_xml(e) }
		@onenters.concat    el.css('> onentry > *').map(&SCXML::Executable)
		@onexits.concat     el.css('> onexit  > *').map(&SCXML::Executable)
		@data.concat        el.css('> datamodel > data').map(&SCXML::Datamodel::Datum)

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

	def machine=( scxml )
		@machine = scxml
		[@states,@transitions,@onenters,@onexits,@data].each{ |a| a.each{ |o| o.machine = scxml } }
		@initial.machine = scxml if @initial
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

	def path
		[*ancestors.reverse,self].map{ |s| s.name || '?' }.join('/')
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

class SCXML::Parallel < SCXML::State
	def pure?;    false; end
	def parallel?; true; end
end
class SCXML::Initial  < SCXML::State
	def pure?;   false; end
	def initial?; true; end
end

class SCXML::Final    < SCXML::State
	def pure?; false; end
	def final?; true; end
	attr_reader :donedata
	# TODO: process <donedata>
end

class SCXML::History  < SCXML::State
	def pure?;   false; end
	def history?; true; end
	attr_reader :type
	def read_xml(el)
		super.tap{ xml_properties(el,%w[type]) }
	end
end
