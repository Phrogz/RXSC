## TODO

* <invoke>
* Catch Datamodel runtime errors and raise errors in the machine
* Follow up on whether single `<scxml>` state should be allowed or not
* Interactions between multiple running state machines
* Refactor test cases into multiple files; remove tests that are too implementation-dependent

## OPEN NOTES/QUESTIONS (not intended to be easily interpreted by mortals)

* grandparent might be nil; isParallelState() must accept nil values and return false

* Why must params have an expression in addition to a name, and what context are they evaluated/set in?

* Why are `<data>` id instead of ncname; this requires the data variables to be uniquely distinct from state ids.

* Strongly dislike the red text and huge anchors?

* Why on earth do transitions default to "external" instead of "internal"?

* Why exit all states in the configuration upon exit? (Why not leave the interpreter in the final states for later inspection?)