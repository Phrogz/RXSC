class RXSC
	def compound?(state)
		@cache[:compound].member?(state)
		# (state.name=='scxml' || state.name=='state') && !state.xpath(REAL_KIDS).empty?
	end

	def atomic?(state)
		@cache[:atomic].member?(state)
		# state.xpath(REAL_KIDS).empty?
	end

	def descendant_of?( el, possible_ancestor )
		el.ancestors.to_a.include? possible_ancestor
	end

	def targets(transition)
		transition['target'].split.map{ |sid| @state_by_id[sid] }
	end

	def real_children(state)
		state.xpath(REAL_KIDS)
	end

	def diagram_children(state)
		state.xpath(NON_INITIAL_KIDS)
	end

	def inspect_config
		"{ " << @configuration.map{ |s| RXSC.state_path(s) }.join(' :: ') << " }"
	end

	def self.state_path(state)
		[state,*ancestors(state,@scxml)].reverse.map{ |s| s['id']||s['name'] }.join('/')
	end

	def self.inspect_transitions(ts)
		"{ " << ts.map{ |t| inspect_transition(t) }.join(' :: ') << " }"
	end

	def self.inspect_transition(t)
		"<transition on #{state_path(t.parent)}#{" event='#{t['event']}'" if t['event']}#{" cond='#{t['cond']}'" if t['cond']}#{" target='#{t['target']}'" if t['target']}/>"
	end

end