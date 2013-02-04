class RXSC::Datamodel
	def initialize(scxml=nil)
		@scxml = scxml
		@__scope = binding
		@inited = Set.new
	end
	def []( key )
		run(key.to_s)
	end
	def []=( key, value )
		p key=>value if $DEBUG
		run("#{key}=nil; ->(v){ #{key}=v }").call(value)
	end
	def clear
		@__scope = binding
		@inited.clear
	end
	def run(code)
		p code if $DEBUG
		@__scope.eval(code,'rxsc_datamodel_evaluator')
	end
	def In(state_id)
		@scxml.is_active?(state_id)
	end
	def init_all(root)
		root.xpath("//*[#{RXSC::IS_STATE}]").each{ |state| init_state(state) }
	end
	def init_state(state)
		unless @inited.member?(state)
			state.xpath('xmlns:datamodel/xmlns:data').each do |data|
				raise "<data src='...'> not supported (#{data})" if data['src']
				self[data['id']] = run(data['expr'] || data.text)
			end
			@inited << state
		end
	end
end
