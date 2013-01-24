module SCXML; end
class SCXML::Machine < SCXML::State
	extend SCXML
	attr_reader :name, :datamodel, :binding, :configuration
	undef_method :id
	def self.from_xml(el)
		new.tap{ |o| o.read_xml(el) }
	end
	def initialize(name="(unnamed)")
		super
		@name      = name
		@datamodel = 'ruby'
		@binding   = 'early'
		@configuration = Set.new
		@state_by_id = {}
	end
	def machine; self; end
	def interconnect!
		@state_by_id = states_by_id
		connect_references!
		set_order(0)
		self
	end
	def read_xml(el)
		super
		xml_properties(el,%w[name datamodel binding])
		self
	end
	def []( sid )
		@state_by_id[sid.to_s]
	end
	def validate
		raise "#{self.class} only supports the 'ruby' datamodel (not #{@datamodel.inspect})" unless @datamodel=='ruby'
	end
	def to_s
		"<#{self.class} '#{name}'>"
	end
end

