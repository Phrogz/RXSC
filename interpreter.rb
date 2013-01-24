module SCXML; end
class SCXML::Machine
	def running?
		!!@running
	end
	def start
		fail_with_error unless validate

		connect_model!

		@configuration.clear
		@states_to_invoke = Set.new
		@history_value    = {} # Indexed by state
		@datamodel        = SCXML::Datamodel.new
		@states_inited    = Set.new
		@internal_queue   = []
		@external_queue   = []
		@running          = true

		@datamodel.crawl(self,@states_inited) if self.binding=="early"

		initial.transitions.first.run
		enter_states(initial.transitions)

		step
	end

	def fire_event( name, data=nil )
		@external_queue << SCXML::Event.new(name,data)
	end

	def step
		loop do # Run-once loop, used for the ability to redo
			enabled_transitions = nil
			stable = false

			# Handle eventless transitions and transitions triggered by internal events
			while @running && !stable
				enabled_transitions = eventless_transitions
				if enabled_transitions.empty?
					if @internal_queue.empty?
						stable = true
					else
						evt = internal_queue.shift
						@datamodel["_event"] = evt
						enabled_transitions = transitions_for(evt)
					end
				end
				microstep(enabled_transitions) unless enabled_transitions.empty?
			end

			# TODO: Run all invocations
			# @states_to_invoke.each{ |state| state.invokes.each(&:run) }
			# @states_to_invoke.clear

			# Invoking may have raised internal error events and we need to back up and handle those too        
			next unless @internal_queue.empty?

			# Normally this is an asynchronous blocking call that waits for an event; instead, we'll bail if we can't find an event
			evt = @external_queue.shift
			break unless evt

			if evt.quit?
				@running = false
				break
			end

			@datamodel["_event"] = evt

			# TODO: enable invoke
			# @configuration.each do |state|
			# 	state.invokes.each do |inv|
			# 		applyFinalize(inv, externalEvent) if inv.invokeid==evt.invokeid
			# 		send(inv.id, externalEvent) if inv.autoforward?
			# 	end
			# end

			enabled_transitions = transitions_for(evt)
			microstep(enabled_transitions) unless enabled_transitions.empty?

			break if @external_queue.empty? # We only run one iteration of processing per `step` command
		end if @running
		exit_interpreter! unless @running
		self
	end

	private

	def enter_states(transitions)
		states_to_enter          = Set.new
		states_for_default_entry = Set.new

		add_states_to_enter = ->(state) do
			if state.history?
				if @history_value[state]
					@history_value[state].each do |s|
						add_states_to_enter[s]
						s.ancestors(state).each{ |anc| states_to_enter << anc }
					end
				else
					state.transitions.each{ |t| t.targets.each{ |s| add_states_to_enter[s] } }
				end
			else
				states_to_enter << state
				if state.compound?
					states_for_default_entry << state
					state.initial.transitions.first.targets.each{ |s| add_states_to_enter[s] }
				elsif state.parallel?
					state.states.each{ |s| add_states_to_enter[s] }
				end
			end
		end

		transitions.select(&:has_targets?).each do |t|
			if t.type == "internal" && t.source.compound? && t.targets.every{ |s| s.descendant_of?(t.source) }
				ancestor = t.source
			else
				ancestor = SCXML.least_common_ancestor( t.source, *t.targets )
			end
			t.targets.each{ |s| add_states_to_enter[s] }
			t.targets.each do |s|
				s.ancestors.each do |anc|
					states_to_enter << anc
					next unless anc.parallel?
					anc.states.each do |child| # TODO: should this only be proper states?
						add_states_to_enter[child] unless states_to_enter.any?{ |s| s.descendant_of?(child) }
					end
				end
			end
		end

		states_to_enter.sort_by(&:entry_ordering).each do |s|
			@configuration    << s
			@states_to_invoke << s
			if binding=="late" && !@states_inited.member?(s)
				@datamodel.populate_from(s)
				@states_inited << s
			end
			s.onenters.each(&:run)
			s.initial.transitions.first.run if states_for_default_entry.member?(s)
			if s.final?
				parent      = s.parent
				grandparent = parent.parent
				@internal_queue << SCXML::Event.new( "done.state."+parent.id, s.donedata )
				if grandparent.parallel? && grandparent.states.all?{ |s| in_final_state?(s) }
					@internal_queue << SCXML::Event.new( "done.state."+parent.id )
				end	
			end
		end
		@configuration.each{ |s| @running = false if s.final? && s.parent==self }
	end

	def exit_states(transitions)
		states_to_exit = Set.new
		transitions.select(&:has_targets?).each do |t|
			if t.type=="internal" && t.source.compound? && t.states.all?{ |s| s.descendant_of(t.source) }
				ancestor = t.source
			else
				ancestor = SCXML.least_common_ancestor(t.source,*t.targets)
			end
			@configuration.each{ |s| states_to_exit << s if s.descendant_of?(ancestor) }
		end

		states_to_exit.each{ |s| @states_to_invoke.delete s }
		states_to_exit = states_to_exit.sort_by(&:exit_ordering)

		# Record the history before exiting
		states_to_exit.each do |s|
			s.states.select(&:history?).each do |h|
				@history_value[h] = Set.new(@configuration.select{ |s0| h.type == "deep" ? ( s0.atomic? && s0.descendant_of?(s) ) : (s0.parent == s) })
			end
		end

		# Exit the states
		states_to_exit.each do |s|
			s.onexits.each(&:run)
			s.invokes.each(&:cancel)
			@configuration.delete s
		end
	end

	def microstep(transitions)
		exit_states(transitions)
		transitions.each(&:run)
		enter_states(transitions)
	end

	def exit_interpreter!
		@configuration.sort_by(&:exit_ordering).each do |s|
			s.onexits.each(&:run)
			s.invokes.each(&:cancel)
			@configuration.delete(s)
			fire_event('quit') if s.final? && s.parent == self
		end
	end

	def transitions_for(event)
		enabled_transitions = Set.new
		@configuration.select(&:atomic?).sort_by(&:entry_ordering).each do |state|
			catch :found_matching do
				[state,*state.ancestors].each do |s|
					s.transitions.each do |t|
						if !t.events.empty? && t.matches_event_name?(event.name) && t.condition_matched?(@datamodel)
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
		@configuration.select(&:atomic?).sort_by(&:entry_ordering).each do |state|
			catch :found_matching_eventless do
				[state,*state.ancestors].each do |s|
					s.transitions.each do |t|
						if t.events.empty? && t.test_condition
							enabled_transitions << t
							throw :found_matching_eventless
						end
					end
				end
			end
		end
		filter_preempted(enabled_transitions)
	end

	def filter_preempted(transitions)
		Set.new.tap{ |filtered| transitions.each{ |t1|
			filtered << t1 unless filtered.any?{ |t2| (t2.type==3) || (t2.type==2 && t1.type==3)  }
		} }
	end

	def in_final_state?( state )
		if state.compound?
			state.states.any?{ |s| @configuration.member?(s) && in_final_state?(s) }
		elsif state.parallel?
			state.states.all?{ |s| in_final_state?(s) }
		end		
	end

	def validate
		# warn "TODO: validate document fully"
		true
	end
end