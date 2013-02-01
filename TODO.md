## TODO

* Support `<invoke>`
* Catch Datamodel runtime errors and raise error events in the machine
* Follow up on whether single `<scxml>` state should be allowed or not
* Interactions between multiple running state machines
* Carry cause/effect through to transitions
* Refactor test cases into multiple files; remove tests that are too implementation-dependent

## OPEN NOTES/QUESTIONS (not intended to be easily interpreted by mortals)

* Why must params have an expression in addition to a name, and what context are they evaluated/set in?

* Why are `<data>` id instead of ncname; this requires the data variables to be uniquely distinct from state ids.

* Strongly dislike the red text and huge anchors?

* Why on earth do transitions default to "external" instead of "internal"?

* Why exit all states in the configuration upon exit? (Why not leave the interpreter in the final states for later inspection?)