module RXSC
	def self.Machine(xml)
		RXSC::Machine.from_xml( Nokogiri.XML(xml,&:xinclude).root )
	end
end

class RXSC::Machine < RXSC::State
	extend RXSC
	attr_reader :name, :datamodel, :binding
	def scxml?; true; end
	def id; name; end
	def self.from_xml(el)
		new.read_xml(el).interconnect!
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

	def on_entered(&block);     @on_enter = block; end
	def on_before_exit(&block); @on_exit  = block; end
	def on_transition(&block);  @on_trans = block; end

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

