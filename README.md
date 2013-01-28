# About RXSCy

Pronounced _"RICK-see"_, the RXSCy library allows you to run [SCXML state machines](http://www.w3.org/TR/scxml/) in [Ruby](http://www.ruby-lang.org/).

The [Data Model](http://www.w3.org/TR/scxml/#data-module) for interpretation is all evaluated Ruby, allowing you to write conditionals and data expressions in one of the best scripting languages in the world.

RXSCy is not yet complete or released. Several complex unit tests pass, but there are still a few puzzling edge cases that make the library unsuitable for general use. Further (and more importantly) the library still needs to expose ways for you to subscribe to notifications about transitions and state changes.

## SCXML Compliance

RXSCy aims to be _almost_ 100% compliant with the [SCXML Interpretation Algorithm](http://www.w3.org/TR/scxml/#AlgorithmforSCXMLInterpretation). However, there are a few minor variations:

* **Manual Event Processing**: Where the W3C implementation calls for the interpreter to run in a separate thread with a blocking queue feeding in the events, RXSCy is designed to be frame-based. You feed events into the machine and then manually call `machine.step` to crank the machine in the same thread. This will cause the event queues to be fully processed and the machine to run until it is stable, and then return.

* **Configuration Clearing**: The W3C algorithm calls for the state machine configuration to be cleared when the interpreter is exited. RXSCy will instead leave the configuration (and data model) intact for you to inspect the final state of the machine.

* **No Delayed `<send>`**: Given the non-threaded nature of RXSCy, there are no immediate plans to support the `delay` or `delayexpr` attributes for `<send>` actions. (Please file an issue if this is important to you.)

## License & Contact

RXSCy is copyright ©2013 by Gavin Kistner and is licensed under the [MIT License](http://opensource.org/licenses/MIT). See the LICENSE.txt file for more details.

For bugs or feature requests please open [issues on GitHub](https://github.com/Phrogz/RXSCy/issues). For other communication you can [email the author directly](mailto:!@phrogz.net?subject=RXSCy).