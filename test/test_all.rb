require 'test/unit'
require_relative '../lib/rxsc'

class MachineTester < Test::Unit::TestCase
	def setup
		@data = Dir.chdir(File.join(File.dirname(__FILE__),'data')){ Hash[
			Dir['*.scxml'].map{ |f| [f[/[^.]+/],IO.read(f,encoding:'utf-8')] }
		] }
		@cases = Dir.chdir(File.join(File.dirname(__FILE__),'testcases')){ Hash[
			Dir['*.scxml'].map{ |f| [f[/[^.]+/],IO.read(f,encoding:'utf-8')] }
		] }
	end

	def test_can_run
		simple = RXSC(@data['simple'])
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
			RXSC(@data['main'])
		end

	end

	def test_transition_eventname_matching
		m = RXSC(@cases['eventname-matching']).start
		refute(m.running?,"eventname-matching should run to completion")
		assert(m.is_active?('pass'),"eventname-matching should pass")
	end

	def test_history
		h = RXSC(@data['history']).start

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

	def test_datamodel
		d = RXSC::Datamodel.new
		d[:foo] = 17
		assert_equal(17,d[:foo])
		assert_equal(17,d.run("foo"))
		d.run("bar = 6")
		assert_equal(42,d.run("bar*7"))

		doc = RXSC(@data['datamodel'])
		doc.start
		d = doc.datamodel
		assert_equal( 2008,     d[:year]       )
		assert_equal( "Mr Big", d[:ceo]        )
		assert_equal( true,     d[:profitable] )
		assert_equal( 42,       d[:kidlins]    )

		doc = RXSC(@data['counting']).start
		10.times{ doc.fire_event('e') }
		doc.step
		assert_equal( 10, doc.datamodel['transitions'] )
	end

	def test_events_api
		mic = RXSC(@data['microwave'])
		assert_equal Set.new(%w[turn.on turn.off tick door.open door.close]), mic.events
	end

	def test_final
		final1 = RXSC(@data['final1']).start
		final1.fire_event('e').step
		refute(final1.running?)

		final2 = RXSC(@data['final2']).start
		assert(final2.is_active?('pass'),"final2 should pass")
		assert(final2.running?,"final2 should still be running (entering a grandchild final should not stop the machine)")
	end

	def test_parallel
		mic = RXSC(@data['microwave']).start
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

		p = RXSC(@cases['parallel3']).start
		refute(p.running?,"parallel3 should run to completion")
		assert(p.is_active?('pass'),"parallel3 should pass")

		p = RXSC(@cases['parallel4']).start
		refute(p.running?,"parallel4 should run to completion")
		assert(p.is_active?('pass'),"parallel4 should pass")
	end

	def test_preemption
		m = RXSC(@cases['testPreemption']).start
		refute(m.running?,"testPreemption should run to completion")
		assert(m.is_active?('pass'),"testPreemption should pass")
	end

	def test_reentry
		m = RXSC(@cases['testReenterChild']).start
		refute(m.running?,"testReenterChild should run to completion")
		assert(m.is_active?('pass'),"testReenterChild should pass")
	end

	def test_transitions
		m = RXSC(@cases['testSiblingTransition']).start
		refute(m.running?,"testSiblingTransition should run to completion")
		assert(m.is_active?('pass'),"testSiblingTransition should pass")

		m = RXSC(@cases['internal_transition']).start
		refute(m.running?,"internal_transition should run to completion")
		assert(m.is_active?('pass'),"internal_transition should pass")
	end

	def test_callbacks
		state_enters = Hash.new(0)
		state_exits  = Hash.new(0)
		transitions  = 0
		para = RXSC(@cases['parallel3-internal'])
		para.on_entered{     |s| state_enters[s['id']] += 1 }
		para.on_transition{  |t| transitions           += 1 }
		para.on_before_exit{ |s| state_exits[s['id']]  += 1 }
		para.start
		%w[p s1 s2 a b pass].each{ |sid| assert_equal(1,state_enters[sid]) }
		%w[p s1 s2 a b].each{ |sid| assert_equal(1,state_exits[sid]) }
		assert_equal(0,state_exits['pass'])
		assert_equal(2,transitions)
	end
end