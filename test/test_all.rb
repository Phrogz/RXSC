require 'test/unit'
require_relative '../rxsc'

class MachineTester < Test::Unit::TestCase
	def setup
		@data = Dir.chdir(File.join(File.dirname(__FILE__),'data')){ Hash[
			Dir['*.scxml'].map{ |f| [f[/[^.]+/],IO.read(f,encoding:'utf-8')] }
		] }
		@cases = Dir.chdir(File.join(File.dirname(__FILE__),'testcases')){ Hash[
			Dir['*.scxml'].map{ |f| [f[/[^.]+/],IO.read(f,encoding:'utf-8')] }
		] }
	end

	def test01_can_parse_xml
		simple = RXSC.Machine(@data['simple'])

		assert_equal(2,simple.states.length)
		s1 = simple.states.first
		assert_equal('s1',s1.id)
		assert_equal(s1,simple['s1'])
		assert_equal(s1,simple[:s1])
		s11 = s1.states.first
		assert_equal('s11',s11.id)
		assert_equal(simple,s1.parent)
		assert_equal(s1,s11.parent)
		assert(simple.transitions.empty?)
		refute(s1.transitions.empty?)
		assert_equal(simple,s1.parent)
		assert_equal(s1,s11.parent)

		assert(s1.compound?)
		refute(s11.compound?)

		s1t1 = s1.transitions.first
		assert_equal(s1,s1t1.source)
		assert_equal('e',s1t1.events.first)
		assert_equal(simple['s21'],s1t1.targets.first)
	end

	def test02_can_run
		simple = RXSC.Machine(@data['simple'])
		assert(simple.active_state_ids.empty?)

		simple.start
		assert(simple.is_active?('s1'))
		assert(simple.is_active?('s1'))

		was_active = simple.active_state_ids
		simple.fire_event('e')
		assert_equal(was_active,simple.active_state_ids,"No change without step")

		simple.step
		assert(simple.is_active?('s2'))
		assert(simple.is_active?('s21'))

		was_active = simple.active_state_ids
		simple.step
		assert_equal(was_active,simple.active_state_ids,"No change without event")

		# Required so that the XInclude relative path works
		main = Dir.chdir(File.join(File.dirname(__FILE__),'data')) do
			RXSC.Machine(@data['main'])
		end

	end

	def test03_transition_name_matching
		t = RXSC::Transition.new( nil, events:%w[a b.c c.d.e d.e.f.* f.] )
		assert(t.matches_event_name?('a'))
		assert(t.matches_event_name?('a.b'))
		assert(t.matches_event_name?('b.c'))
		assert(t.matches_event_name?('b.c.d'))
		assert(t.matches_event_name?('c.d.e'))
		assert(t.matches_event_name?('c.d.e.f'))
		assert(t.matches_event_name?('d.e.f'))
		assert(t.matches_event_name?('d.e.f.g'))
		assert(t.matches_event_name?('f'))
		assert(t.matches_event_name?('f.g'))

		refute(t.matches_event_name?('alpha'))
		refute(t.matches_event_name?('b.charlie'))
		refute(t.matches_event_name?('d.e.frank'))
		refute(t.matches_event_name?('frank'))
		refute(t.matches_event_name?('b'))
		refute(t.matches_event_name?('.*'))
		refute(t.matches_event_name?('.'))
		refute(t.matches_event_name?('z.a'))

		t = RXSC::Transition.new( nil, events:'*' )
		assert(t.matches_event_name?('a'))
		assert(t.matches_event_name?('a.b'))
		assert(t.matches_event_name?('c.d.e.f'))
	end

	def test04_transition_conditions
		d  = RXSC::Datamodel.new
		d.run('ok = false')
		t0 = RXSC::Transition.new( nil              )
		t1 = RXSC::Transition.new( nil,cond:"false" )
		t2 = RXSC::Transition.new( nil,cond:"true"  )
		t3 = RXSC::Transition.new( nil,cond:"ok"    )
		t4 = RXSC::Transition.new( nil,cond:"@yes"  )

		assert t0.condition_matched?(d)
		refute t1.condition_matched?(d)
		assert t2.condition_matched?(d)
		refute t3.condition_matched?(d)
		refute t4.condition_matched?(d)
		d.run('ok = true; @yes = :very')
		assert t3.condition_matched?(d)
		assert t4.condition_matched?(d)
	end

	def test05_transition_targets
		simple = RXSC.Machine(@data['simple'])

		t0 = simple['s2'].transitions.first
		refute(t0.has_targets?)

		t0 = RXSC::Transition.new( nil )
		refute(t0.has_targets?)

		t1 = simple['s1'].transitions.first
		assert(t1.has_targets?)

		t1 = RXSC::Transition.new( nil,targets:"s21" )
		assert(t1.has_targets?)
		
		t1 = RXSC::Transition.new( nil,targets:%w[s2 s21] )
		assert(t1.has_targets?)
	end

	def test06_history
		h = RXSC.Machine(@data['history']).start

		assert_equal(1,h['universe'].states.select(&:history?).length)
		assert(h.is_active? 'action-1')
		
		h.fire_event("action.done").step
		assert(h.is_active? 'action-2')

		h.fire_event("application.error.CPUONFIRE").step
		assert(h.is_active? 'error-handler')

		h.fire_event("error.handled").step
		assert(h.is_active? 'action-2')

		h.fire_event("action.done").step
		assert(h.is_active? 'action-3')

		h.fire_event "application.error.smoldering"
		h.fire_event "error.handled"
		h.step
		assert(h.is_active? 'action-3')

		h.fire_event("action.done").step
		assert(h.is_active? 'pass')
		refute(h.running?,"Machine should stop after moving to final state.")
	end

	def test07_datamodel
		d = RXSC::Datamodel.new
		d[:foo] = 17
		assert_equal(17,d[:foo])
		assert_equal(17,d.run("foo"))
		d.run("bar = 6")
		assert_equal(42,d.run("bar*7"))

		doc = RXSC.Machine(@data['datamodel'])
		doc.start
		d = doc.datamodel
		assert_equal( 2008,     d[:year]       )
		assert_equal( "Mr Big", d[:ceo]        )
		assert_equal( true,     d[:profitable] )
		assert_equal( 42,       d[:kidlins]    )

		doc = RXSC.Machine(@data['counting']).start
		10.times{ doc.fire_event('e') }
		doc.step
		assert_equal( 10, doc.datamodel['transitions'] )
	end

	def test08_events_api
		mic = RXSC.Machine(@data['microwave'])
		assert_equal Set.new(%w[turn.on turn.off tick door.open door.close]), mic.events
	end

	def test09_final
		final1 = RXSC.Machine(@data['final1']).start
		final1.fire_event('e').step
		refute(final1.running?)

		final2 = RXSC.Machine(@data['final2']).start
		assert(final2.is_active?('pass'),"final2 should pass")
		assert(final2.running?,"final2 should still be running (entering a grandchild final should not stop the machine)")
	end

	def test10_parallel
		mic = RXSC.Machine(@data['microwave']).start
		assert_equal(Set['off','closed'],mic.active_atomic_ids)

		mic.fire_event('turn.on').step
		assert_equal(Set['cooking','closed'],mic.active_atomic_ids)

		3.times{ mic.fire_event('tick').step }
		assert_equal(Set['cooking','closed'],mic.active_atomic_ids)

		mic.fire_event('door.open').step
		assert_equal(Set['paused','open'],mic.active_atomic_ids)

		mic.fire_event('door.close').step
		10.times{ mic.fire_event('tick') }
		mic.step
		assert_equal(Set['off','closed'],mic.active_atomic_ids)

		p = RXSC.Machine(@cases['parallel3']).start
		refute(p.running?,"parallel3 should run to completion")
		assert(p.is_active?('pass'),"parallel3 should pass")

		p = RXSC.Machine(@cases['parallel4']).start
		refute(p.running?,"parallel4 should run to completion")
		assert(p.is_active?('pass'),"parallel4 should pass")
	end

	def test11_preemption
		m = RXSC.Machine(@cases['testPreemption']).start
		refute(m.running?,"testPreemption should run to completion")
		assert(m.is_active?('pass'),"testPreemption should pass")

		m = RXSC.Machine(@data['preemption-categories']).interconnect!
		{wee:2,dogs:1,larch:3,sapling:1}.each do |sid,level|
			assert_equal( level, m[sid].transitions.first.preempt_category )
		end
	end

	def test12_reentry
		m = RXSC.Machine(@cases['testReenterChild']).start
		refute(m.running?,"testReenterChild should run to completion")
		assert(m.is_active?('pass'),"testReenterChild should pass")
	end

	def test13_transitions
		m = RXSC.Machine(@cases['testSiblingTransition']).start
		refute(m.running?,"testSiblingTransition should run to completion")
		assert(m.is_active?('pass'),"testSiblingTransition should pass")

		m = RXSC.Machine(@cases['internal_transition']).start
		refute(m.running?,"internal_transition should run to completion")
		assert(m.is_active?('pass'),"internal_transition should pass")
	end

	def test14_callbacks
		state_enters = Hash.new(0)
		state_exits  = Hash.new(0)
		transitions  = 0
		para = RXSC.Machine(@cases['parallel3-internal'])
		para.on_entered{     |sid| state_enters[sid] += 1 }
		para.on_transition{  |t|   transitions       += 1 }
		para.on_before_exit{ |sid| state_exits[sid]  += 1 }
		para.start
		%w[p s1 s2 a b pass].each{ |sid| assert_equal(1,state_enters[sid]) }
		%w[p s1 s2 a b].each{ |sid| assert_equal(1,state_exits[sid]) }
		assert_equal(0,state_exits['pass'])
		assert_equal(2,transitions)
	end

end