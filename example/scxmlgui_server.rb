require 'sinatra'
require 'haml'
require 'json'
require_relative '../lib/rxsc'

$machine = RXSC(IO.read('dashboard.scxml'))
$machine.on_after_enter{ |s| $log << "Entered #{RXSC.state_path(s)}"; $delta << { action:"enter", id:s['id']||s['name'] } }
$machine.on_before_exit{ |s| $log << "Exited  #{RXSC.state_path(s)}"; $delta << { action:"leave", id:s['id']||s['name'] } }
$machine.on_transition{  |t| $log << "Run Transition #{RXSC.inspect_transition(t)}" }

get '/' do
	$log     = []
	$delta   = []
	$machine.restart
	haml(:index).tap{ $delta.clear }
end

post '/event' do
	content_type :json
	$log << "Fire event '#{params['id']}'"
	$machine.fire_event(params['id'])
	$machine.step
	{ log:log, delta:delta, events:$machine.available_events.to_a }.to_json
end

helpers do
	def nest(h)
		unless !h || h.empty?
			"<ul>#{
				h.map{ |s,kids|
					id   = s['id']
					name = s['id'] || s['name']
					name << " [#{s.name}]"  if %w[final history parallel].include?(s.name)
					"<li><span id='#{id}'>#{name}</span>#{nest(kids)}</li>"
				}.join
			}</ul>" 
		end
	end
	def nested_states
		nest($machine.state_hierarchy)
	end
	def log
		$log.join("\n").tap{ $log.clear }
	end
	def delta
		$delta.dup.tap{ $delta.clear }
	end
end

__END__
@@ layout
!!! 5
%html
	%head
		%meta(charset='utf-8')
		%title SCXML Interactor
		%script(src="https://ajax.googleapis.com/ajax/libs/jquery/1.9.0/jquery.min.js")
		:css
			html, body { margin:0; padding:0; height:100%; font-family:'Calibri'; font-size:11pt }
			#events, #states, #output { position:fixed; top:0; bottom:0; overflow:auto }
			#states { left:0; width:25em }
			#output { left:25em; right:15em }
			#events { right:0; width:15em }
			h2 { margin:0; background:#666; color:#ccc; padding:0.2em 20px; border-right:1px solid #333 }
			.content { padding:20px }
			#states ul, #states li { display:block; margin:0; padding:0 }
			#states li { margin-left:2em }
			#states > .content > ul > li { margin-left:0 }
			#states > .content > ul > li > span { font-weight:bold; border-bottom:2px solid #333; display:block }
			#states > .content > ul > li > ul > li { margin-left:0 }
			#states .active { font-weight:bold; color:#036; background:#ff6; padding:0 0.5em }
			#events button { display:block }
			pre { border-bottom:3px double #999; font-size:9pt }
	%body= yield

@@ index
%section#events
	%h2 Events
	.content
		- $machine.events.sort_by(&:downcase).each do |evt|
			%button{id:evt}= evt
%section#states
	%h2 States
	.content
		#{nested_states}
%section#output
	%h2 Log
	.content#log
:javascript
	showData(#{{ log:log, delta:delta, events:$machine.available_events.to_a }.to_json});

	$('button').click(function(){
		$.post('/event',{id:this.id},showData,'json');
	});

	function showData(response){
		$('#log').append("<pre>"+response.log.replace(/<(?=.)/g,'&lt;')+"</pre>");
		$.each(response.delta,function(i,change){
			$('#'+change.id).toggleClass('active',change.action=='enter')
		});
		$('button').attr({disabled:true});
		$.each(response.events,function(i,id){
			document.getElementById(id).disabled = false;
		});
	}
