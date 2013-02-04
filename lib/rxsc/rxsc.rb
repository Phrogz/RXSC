def RXSC(xml)
	RXSC.new(xml)
end

class RXSC
	@@exec = {}
	def self.to_execute(name,&block)
		@@exec[name] = block
	end

	attr_reader :datamodel

	def initialize(xml)
		@scxml = Nokogiri.XML(xml){ |c| c.noblanks.xinclude }.root
		@scxml['name']      ||= '(RXSC)'
		@scxml['datamodel'] ||= 'ruby'

		@configuration    = Set.new
		@states_to_invoke = Set.new
		@history_value    = {} # Indexed by state element (not id)
		@internal_queue   = []
		@external_queue   = []

		@datamodel = RXSC::Datamodel.new(self)
		@running   = false
	end

	def on_entered(&block);     @on_enter = block; end
	def on_before_exit(&block); @on_exit  = block; end
	def on_transition(&block);  @on_trans = block; end

	def running?
		!!@running
	end

	def validate
		raise "RXSC only supports the 'ruby' datamodel (not #{@scxml['datamodel'].inspect})" unless @scxml['datamodel']=='ruby'
		true # TODO: validate
	end

	def events
		Set.new @scxml.xpath('//xmlns:transition/@event').map(&:text).flat_map(&:split)
	end

	def state_hierarchy
		nest = ->(state){ { (state['id'] || state['name'])=>diagram_children(state).map(&nest).inject(&:merge) } }
		nest[@scxml]
	end

	def active_state_ids
		Set.new @configuration.map{ |el| el['id'] }
	end

	def active_atomic_ids
		Set.new @configuration.map{ |el| el['id'] if atomic?(el) }.compact
	end

	def is_active?(id)
		@configuration.any?{ |s| s['id']==id }
	end

	def fire_event( name, data=nil, internal=false )
		p fire_event:name, data:data, internal:internal if $DEBUG
		(internal ? @internal_queue : @external_queue) << RXSC::Event.new(name,data)
		self
	end

	def to_s
		@scxml.to_s
	end
end

RXSC::Event = Struct.new(:name,:data) do
	def quit?; name=="quit-interpreter"; end
end
