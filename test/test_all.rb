require 'test/unit'
require_relative '../lib/rxsc'

class MachineTester < Test::Unit::TestCase
	DATA = Dir.chdir(File.join(File.dirname(__FILE__),'data')){ Hash[
		Dir['*.scxml'].map{ |f| [f[/[^.]+/],IO.read(f,encoding:'utf-8')] }
	] }
	CASES = Dir.chdir(File.join(File.dirname(__FILE__),'testcases')){ Hash[
		Dir['*.scxml'].map{ |f| [f[/[^.]+/],IO.read(f,encoding:'utf-8')] }
	] }
	SHOULD_BE_RUNNING = {
		'final2' => "Entering a grandchild should <final> should not stop the machine"
	}

	CASES.each do |name,xml|
		if msg=SHOULD_BE_RUNNING[name]
			define_method "test_#{name}" do
				machine = RXSC(xml).start
				assert(machine.is_active?('pass'),"Testcase '#{name}' should pass, but ended in #{machine.active_state_ids.inspect}")
				assert(machine.running?,"Testcase '#{name}' should still be running: #{msg}")
			end
		else
			define_method "test_#{name}" do
				machine = RXSC(xml).start
				assert(machine.is_active?('pass'),"Testcase '#{name}' should pass, but ended in #{machine.active_state_ids.inspect}")
				refute(machine.running?,"Testcase '#{name}' should run to completion")
			end
		end
	end

	def test_can_run
		simple = RXSC(DATA['simple'])
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
			RXSC(DATA['main'])
		end

	end

	def test_datamodel
		d = RXSC::Datamodel.new
		d[:foo] = 17
		assert_equal(17,d[:foo])
		assert_equal(17,d.run("foo"))
		d.run("bar = 6")
		assert_equal(42,d.run("bar*7"))

		doc = RXSC(CASES['counting']).start
		assert_equal( 8, doc.datamodel['x'] )
	end

	def test_events_api
		mic = RXSC(CASES['microwave'])
		assert_equal Set.new(%w[power.on power.off tick door.open door.close]), mic.events
	end

	def test_callbacks
		state_enters = Hash.new(0)
		state_exits  = Hash.new(0)
		transitions  = 0
		para = RXSC(CASES['parallel3-internal'])
		para.on_after_enter{ |s| state_enters[s['id']] += 1 }
		para.on_transition{  |t| transitions           += 1 }
		para.on_before_exit{ |s| state_exits[s['id']]  += 1 }
		para.start
		%w[p s1 s2 a b pass].each{ |sid| assert_equal(1,state_enters[sid]) }
		%w[p s1 s2 a b].each{ |sid| assert_equal(1,state_exits[sid]) }
		assert_equal(0,state_exits['pass'])
		assert_equal(2,transitions)
	end
end