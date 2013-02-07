class RXSC
	MAX_ITERATIONS = 1000 # Guard against infinite loops of instability in the internal queue

	STATES     = %w[scxml state final parallel initial history].map{ |s| s.prepend "xmlns:" }
	REALS      = %w[state final parallel].map{ |s| s.prepend "xmlns:" }
	TRANSITION = 'xmlns:transition'

	IS_STATE   = STATES.map{ |s| "self::#{s}" }.join(' or ')
	IS_REAL    = REALS.map{ |s| "self::#{s}" }.join(' or ')
	HAS_REAL   = REALS.join(' or ')
	REAL_KIDS  = REALS.join('|')

	NON_INITIAL_KIDS = %w[scxml state final parallel history].map{ |s| s.prepend "xmlns:" }.join('|')

	INITIAL_TRANSITION = "xmlns:initial/xmlns:transition"

	def self.matches_event_name?(transition,event_name)
		if events=transition['event']
			chunks = event_name.split('.')
			events.split.any?{ |n| n=='*' || n==chunks[0,n.split('.').length].join('.') }
		end
	end

	def active_state_ids
		Set.new @configuration.map{ |el| el['id'] }
	end

	def is_active?(id)
		@configuration.any?{ |s| s['id']==id }
	end

	def fire_event( name, data=nil, internal=false )
		p fire_event:name, data:data, internal:internal if $DEBUG
		(internal ? @internal_queue : @external_queue) << RXSC::Event.new(name,data)
		self
	end

	# Generate random IDs for any state without one
	def autogenerate_ids
		@state_by_id = Hash.new{ |h,k| raise "Cannot find state with id '#{k}'" }
		@scxml.xpath("//*[#{IS_STATE}][not(self::xmlns:scxml)]").each do |el|
			el['id'] ||= "#{el.name}-#{SecureRandom.uuid}"
			@state_by_id[el['id']] = el
		end
	end

	def autogenerate_initials
		# Convert initial="..." to <initial>...</initial>
		@scxml.xpath("//*[#{IS_STATE}][@initial]").each do |el|
			id = "autoinitial-#{SecureRandom.uuid}"
			@state_by_id[id] = el.add_child("<initial id='#{id}'><transition target='#{el['initial']}'/></initial>").first
			el.remove_attribute 'initial'
		end

		# Add <initial> for implicit initials
		@scxml.xpath("//*[#{IS_STATE}][#{HAS_REAL}][not(xmlns:initial)]").each do |el|
			id = "autoinitial-#{SecureRandom.uuid}"
			initial = el.at_xpath("*[#{IS_REAL}]")
			@state_by_id[id] = el.add_child("<initial id='#{id}'><transition target='#{initial['id']}'/></initial>").first
		end
	end

	def record_document_ordering
		@doc_order = Hash[ @scxml.xpath("//*[#{IS_STATE}]").to_a.each.with_index.to_a ]
	end

	def remove_empty_attributes
		@scxml.xpath("//#{TRANSITION}/@*[name()='event' or name()='target' or name()='cond'][.='']").remove
		@scxml.xpath("//*[#{IS_STATE}]/@id[.='']").remove
	end

	def set_default_attributes
		@scxml['binding'] ||= 'early'
		@scxml.xpath("//#{TRANSITION}[not(@type)]").each{ |t| t['type']='external' }
		@scxml.xpath("//xmlns:history[not(@type)]").each{ |t| t['type']='shallow' }
		@scxml.xpath("//xmlns:invoke[not(@autoforward)]").each{ |t| t['autoforward']='false' }
	end

	def normalize_event_names
		@scxml.xpath("//#{TRANSITION}[@event]").each{ |t| t['event']=t['event'].gsub(/\.\*?(?=\s|\z)/,'') }
	end

	def clear_caches
		@cache ||= {}
		@cache.clear
		@cache[:compound] ||= Set.new(@scxml.xpath("//*[self::xmlns:scxml or self::xmlns:state][#{HAS_REAL}]").to_a)
		@cache[:atomic]   ||= Set.new(@scxml.xpath("//*[#{IS_STATE}][#{REALS.map{|s| "not(#{s})" }.join(' and ')}]").to_a)
	end

	# -------------------------------------------------------------------------------
	# -------------------------------------------------------------------------------
	# -------------------------------------------------------------------------------

	def start
		fail_with_error unless validate
		autogenerate_ids
		autogenerate_initials
		record_document_ordering
		remove_empty_attributes
		set_default_attributes
		normalize_event_names
		clear_caches

		@configuration.clear
		@states_to_invoke.clear
		@history_value.clear
		@internal_queue.clear
		@external_queue.clear
		@datamodel.clear
		@datamodel['_name'] = @scxml['name']
		@running            = true

		@datamodel.init_all(@scxml) if @scxml['binding']=='early'

		transitions = @scxml.xpath(INITIAL_TRANSITION)
		run_transition(transitions.first)
		enter_states_for_transitions(transitions)

		step
	end

	def stop(msg=nil)
		puts "Stopping #{@scxml['name']} #{"because #{msg}" if msg}" if $DEBUG
		@running = false
	end

	def step
		return unless @running
		while @running
			enabled_transitions = nil
			stable = false

			# Handle eventless transitions and transitions triggered by internal events
			iterations = 0
			until !@running || stable || iterations >= MAX_ITERATIONS
				enabled_transitions = eventless_transitions
				if enabled_transitions.empty?
					if @internal_queue.empty?
						stable = true
					else
						evt = @internal_queue.shift
						@datamodel["_event"] = evt
						enabled_transitions = transitions_for(evt)
					end
				end
				microstep(enabled_transitions) unless enabled_transitions.empty?
				iterations += 1
			end

			warn "WARNING: stopped unstable system after #{iterations} iterations" if iterations >= MAX_ITERATIONS

			# TODO: Enable invoke
			# run_invokes(@states_to_invoke)  #.each{ |state| state.invokes.each(&:run) }.clear
			# next unless @internal_queue.empty? # Invoking may have raised internal error events and we need to back up and handle those too        

			# Normally this is an asynchronous blocking call that waits for an event; instead, RXSC runs #step as long as it can find events and then stops
			if evt = @external_queue.shift
				change = true
				if evt.quit?
					stop("Quit event received")
					break
				end
				@datamodel["_event"] = evt

				# TODO: Enable invoke
				# @configuration.each do |state|
				# 	state.invokes.each do |inv|
				# 		applyFinalize(inv, externalEvent) if inv.invokeid==evt.invokeid
				# 		send(inv.id, externalEvent) if inv.autoforward?
				# 	end
				# end

				enabled_transitions = transitions_for(evt)
				microstep(enabled_transitions) unless enabled_transitions.empty?
				puts "     step-external: #{inspect_config}" if $DEBUG
			else
				break
			end
		end
	
		exit_interpreter! unless @running
		puts "  post-step-config: #{inspect_config}" if $DEBUG
		self
	end

	private
	def microstep(transitions)
		puts "microstep using #{RXSC.inspect_transitions(transitions)}" if $DEBUG
		exit_states_for_transitions(transitions)
		transitions.each do |t|
			@on_trans[t] if @on_trans # Execute user-supplied callback
			run_transition(t)
		end
		enter_states_for_transitions(transitions)
	end

	def enter_states_for_transitions(transitions)
		states_to_enter          = Set.new
		states_for_default_entry = Set.new

		add_states_to_enter = ->(state) do
			if state.name=="history"
				if @history_value[state]
					@history_value[state].each do |s|
						add_states_to_enter[s]
						RXSC.ancestors(s,state).each{ |anc| states_to_enter << anc }
					end
				else
					# TODO: the specs iteration transitions; is there allowed to be more than one
					targets( state.at_xpath(TRANSITION) ).each(&add_states_to_enter)
				end
			else
				states_to_enter << state
				if compound?(state)
					states_for_default_entry << state
					targets(state.at_xpath(INITIAL_TRANSITION)).each(&add_states_to_enter)
				elsif state.name=='parallel'
					real_children(state).each(&add_states_to_enter)
				end
			end
		end

		transitions.each do |t|
			next unless t['target']
			targs = targets(t)
			ancestor = transition_ancestor(t,targs)
			targs.each(&add_states_to_enter)
			targs.each do |s|
				RXSC.ancestors(s,ancestor).each do |anc|
					states_to_enter << anc
					if anc.name=='parallel'
						real_children(anc).each do |child|
							add_states_to_enter.(child) unless states_to_enter.any?{ |s| descendant_of?(s,child) }
						end
					end
				end
			end
		end

		enter_states(states_to_enter,states_for_default_entry)
	end

	def enter_states(states,states_for_default_entry)
		sorted = states.sort_by{ |s| @doc_order[s] }
		puts "Entering states: #{sorted.map{|s| RXSC.state_path(s)}}" if $DEBUG
		sorted.each do |s|
			@configuration    << s
			@states_to_invoke << s
			if @scxml['binding']=="late" && !@states_inited.member?(s)
				@datamodel.init_state(s)
				@states_inited << s
			end
			run_onenters(s)
			run_transition(s.at_xpath(INITIAL_TRANSITION)) if states_for_default_entry.member?(s)
			if s.name=='final'
				parent = s.parent
				if parent==@scxml
					stop("Final state #{s['id']} entered.")
				else
					fire_event( "done.state.#{parent['id']}", donedata(s), true )
					grandparent = parent.parent
					if grandparent && grandparent.name=='parallel' && real_children(grandparent).all?(&:in_final_state?)
						fire_event( "done.state.#{grandparent['id']}", nil, true )
					end
				end
			end
		end
		sorted.each(&@on_enter) if @on_enter # Do this after entering all states, so we're in a new legal configuration
	end

	def exit_states_for_transitions(transitions)
		states_to_exit = Set.new
		transitions.each do |t|
			next unless t['target']
			ancestor = transition_ancestor(t,targets(t))
			@configuration.each{ |s| states_to_exit << s if descendant_of?(s,ancestor) }
		end

		@states_to_invoke.subtract states_to_exit
		exit_states(states_to_exit)
	end

	def exit_states(states_to_exit)
		puts exit_states:states_to_exit.map{ |s| s['id'] } if $DEBUG
		sorted = states_to_exit.sort_by{ |s| -@doc_order[s] }

		# Invoke any user-supplied callbacks _before_ exiting anything
		sorted.each(&@on_exit) if @on_exit

		# Record the history before exiting
		sorted.each do |s|
			s.xpath('xmlns:history').each do |h|
				@history_value[h] = Set.new(@configuration.select{ |s0| h['type'] == "deep" ? ( atomic?(s0) && descendant_of?(s0,s) ) : (s0.parent == s) })
			end
		end

		# Exit the states
		sorted.each do |s|
			run_onexits(s)
			# s.invokes.each(&:cancel) # TODO: Handle invokes
			@configuration.delete s
		end
	end

	def exit_interpreter!
		@configuration.sort_by{ |s| @doc_order[s] }.each do |s|
			run_onexits(s)
			# s.invokes.each(&:cancel) # TODO: invokes
			# @configuration.delete(s)
			if s.name=='final' && s.parent==@scxml
				break
				# TODO: return the done event with self.donedata to notify other machines
			end
		end
	end

	# ----------------------------------------------

	def transition_ancestor(transition,targets)
		if transition['type']=="internal" &&
		   compound?(transition.parent) &&
		   targets.all?{ |s| descendant_of?(s,transition.parent) }
			transition.parent
		else
			LCCA( transition.parent, *targets )
		end
	end

	def transitions_for(event)
		enabled_transitions = Set.new
		@configuration.select{ |s| atomic?(s) }.sort_by{ |s| @doc_order[s] }.each do |state|
			catch :found_matching do
				[state,*RXSC.ancestors(state)].each do |s|
					s.elements.each do |t|
						next unless t.name=='transition'
						if RXSC.matches_event_name?(t,event.name) && condition_matched?(t)
							enabled_transitions << t
							throw :found_matching
						end
					end
				end
			end
		end
		filter_preempted(enabled_transitions)
	end

	def eventless_transitions
		enabled_transitions = Set.new
		@configuration.select{ |s| atomic?(s) }.sort_by{ |s| @doc_order[s] }.each do |state|
			catch :found_matching_eventless do
				[state,*RXSC.ancestors(state)].each do |s|
					s.elements.each do |t|
						next unless t.name=='transition'
						if !t['event'] && condition_matched?(t)
							enabled_transitions << t
							throw :found_matching_eventless
						end
					end
				end
			end
		end
		filter_preempted(enabled_transitions)
	end

	# --------------------------------------------------

	def run_transition(transition)
		transition.elements.each{ |el| run_executable(el) }
	end

	def run_onenters(state)
		state.xpath('xmlns:onentry/*').each{ |el| run_executable(el) }
	end

	def run_onexits(state)
		state.xpath('xmlns:onexit/*').each{ |el| run_executable(el) }
	end

	def run_executable(el)
		if exec=@@exec[el.name]
			instance_exec(el,&exec)
		else
			warn "FIXME: Run #{el}"
		end
	end

	def donedata(state)
		if content = state.at_xpath('./xmlns:donedata/xmlns:content')
			content['expr'] ? @datamodel.run(content['expr']) : content.text
		elsif params = state.xpath('./xmlns:donedata/xmlns:param')
			# TODO: handle location instead of expr
			Hash[params.map{ |p| [p['name'],@datamodel.run(p['expr'])] }]
		end
	end

	def condition_matched?(transition)
		!transition['cond'] or @datamodel.run(transition['cond'])
	end

	def filter_preempted(transitions)
		Set.new.tap{ |filtered| transitions.each{ |t1|
			filtered << t1 unless filtered.any? do |t2|
				t2_cat = preempt_category(t2)
				(t2_cat==3) || (t2_cat==2 && preempt_category(t1)==3)
			end
		} }
	end

	def preempt_category(t)
		if !t['target'] then 1
		elsif LCPA( t['type']=="internal" ? t.parent : t.parent.parent, *targets(t) ) then 2
		else 3
		end
	end
	
	def LCCA(*states) # least common compound ancestor
		rest = states[1..-1]
		RXSC.ancestors(states.first).each do |anc|
			next unless compound?(anc)
			return anc if rest.all?{ |s| descendant_of?(s,anc) }
		end
		nil
	end

	def LCPA(*states) # least common parallel ancestor
		rest = states[1..-1]
		RXSC.ancestors(states.first).each do |anc|
			next unless anc.name=="parallel"
			return anc if rest.all?{ |s| descendant_of?(s,anc) }
		end
		nil
	end

	def self.ancestors(el,stop_state=nil)
		walker = el.parent
		[].tap do |a|
			until walker==stop_state || walker.xml?
				a << walker
				walker = walker.parent
			end
		end
	end
end
