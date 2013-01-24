module SCXML; end
class SCXML::Machine < SCXML::State
	extend SCXML
	attr_reader :name, :datamodel, :binding
	def initialize(el=nil)
		@state_by_id = {}
		if el
			@name      = el[:name]
			@datamodel = el[:datamodel] || 'ruby'
			@binding   = el[:binding]   || 'early'
			raise "#{self.class} does not support a #{datamodel.inspect} datamodel, only 'ruby'." unless @datamodel=='ruby'
		end
		super(nil,el)
		@state_by_id = states_by_id
		connect_references!
		set_order(0)
	end
	def []( sid )
		@state_by_id[sid.to_s]
	end
	def configuration
		@configuration || Set.new
	end
	def to_s
		"<#{self.class} '#{name || id}'>"
	end
end

