# About RXSC

RXSC stands for "Ruby XML StateCharts", and is pronounced _"Rixie"_. The RXSC library allows you to run [SCXML state machines](http://www.w3.org/TR/scxml/) in [Ruby](http://www.ruby-lang.org/).

The [Data Model](http://www.w3.org/TR/scxml/#data-module) for interpretation is all evaluated Ruby, allowing you to write conditionals and data expressions in one of the best scripting languages in the world.

RXSC is not yet released, but it is getting close.

## SCXML Compliance

RXSC aims to be _almost_ 100% compliant with the [SCXML Interpretation Algorithm](http://www.w3.org/TR/scxml/#AlgorithmforSCXMLInterpretation). However, there are a few minor variations:

* **Manual Event Processing**: Where the W3C implementation calls for the interpreter to run in a separate thread with a blocking queue feeding in the events, RXSC is designed to be frame-based. You feed events into the machine and then manually call `machine.step` to crank the machine in the same thread. This will cause the event queues to be fully processed and the machine to run until it is stable, and then return.

* **Configuration Clearing**: The W3C algorithm calls for the state machine configuration to be cleared when the interpreter is exited. RXSC will instead leave the configuration (and data model) intact for you to inspect the final state of the machine.

* **No Delayed `<send>`**: Given the non-threaded nature of RXSC, there are no immediate plans to support the `delay` or `delayexpr` attributes for `<send>` actions. (Please file an issue if this is important to you.)

## License & Contact

RXSC is copyright ©2013 by Gavin Kistner and is licensed under the [MIT License](http://opensource.org/licenses/MIT). See the LICENSE.txt file for more details.

For bugs or feature requests please open [issues on GitHub](https://github.com/Phrogz/RXSC/issues). For other communication you can [email the author directly](mailto:!@phrogz.net?subject=RXSC).