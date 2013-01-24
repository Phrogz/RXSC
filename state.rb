module SCXML; end
class SCXML::State
	extend SCXML
	attr_reader :id, :states, :transitions, :invokes, :parent, :initial, :onenters, :onexits, :entry_ordering, :data
	alias_method :name, :id
	def initialize(parent,el=nil)
		@states      = []
		@transitions = []
		@invokes     = []
		@onexits     = []
		@onenters    = []
		@data        = []
		@parent      = parent
		@id          = self.class.to_s
		if el
			@el = el
			@id = el[:id]
			populate_states!
			populate_initial!
			@transitions.concat @el.xpath('./xmlns:transition').map{ |e| SCXML::Transition.new(self,element:e) }
			@onenters.concat @el.xpath('./xmlns:onentry/*').map(&SCXML::Executable)
			@onexits.concat  @el.xpath('./xmlns:onexit/*' ).map(&SCXML::Executable)
			@data.concat     @el.xpath('./xmlns:datamodel/xmlns:data').map(&SCXML::Datamodel::Datum)
		end		
	end

	def populate_states!
		names = %w[state final parallel initial history].map{ |s|"xmlns:#{s}" }
		@states.concat(@el.xpath("./#{names.join('|')}").map do |e|
			klass = case e.name
				when 'final'    then SCXML::Final
				when 'initial'  then SCXML::Initial
				when 'parallel' then SCXML::Parallel
				when 'history'  then SCXML::History
				else                 SCXML::State
			end
			klass.new(self,e)
		end)
	end

	def populate_initial!		
		if @el[:initial]
			@initial = SCXML::Initial.new(self)
			@initial.transitions << SCXML::Transition.new(@initial,targets:@el[:initial])
		elsif init_el = @el.at_xpath('./xmlns:initial')
			raise "`initial` attribute and element both supplied for #{el.to_s}" if @initial
			@initial = SCXML::Initial.new(self,init_el)
		end
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

	def machine
		@machine ||= parent ? parent.machine : self
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
		[*ancestors,self].map{ |s| s.name || '?' }.join('/')
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
	def initial(parent,el=nil)
		super
		# TODO: process <donedata>
	end
end
class SCXML::History  < SCXML::State
	def pure?;   false; end
	def history?; true; end
	attr_reader :type
	def initial(parent,el=nil)
		@type = el[:type] if el
		super
	end
end
