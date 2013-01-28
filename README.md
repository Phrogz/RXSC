# RXSCy

Pronounced _"RICK-see"_, `RXSCy` allows you to run [SCXML](http://www.w3.org/TR/scxml/) state machines in Ruby.

The [Data Model](http://www.w3.org/TR/scxml/#data-module) for interpretation is all evaluated Ruby, allowing you to write conditionals and data expressions in one of the best scripting languages in the world.

RXSCy is not yet complete or released. Several complex unit tests pass, but there are still a few puzzling edge cases that make the library unsuitable for general use. Further (and more importantly) the library still needs to expose ways for you to subscribe to notifications about transitions and state changes.

## Processing Model

RXSCy aims to be almost 100% compliant with the [SCXML Interpretation Algorithm](http://www.w3.org/TR/scxml/#AlgorithmforSCXMLInterpretation). However, there are a couple of minor variations planned:

* **Manual Event Processing**: Where the W3C implementation calls for the interpreter to run in a separate thread with a blocking queue feeding in the events, RXSCy is designed to be frame-based. You feed events into the queues and then turn a manual `machine.step` crank the machine in the same thread. This will cause the event queues to be fully processed and the machine to run until it is stable, and then return.

* **Configuration Clearing**: The W3C algorithm calls for the state machine configuration to be cleared when the interpreter is exited. RXSCy will instead leave the configuration (and datamodel) intact for you to inspect the final state of the machine.

## License

RXSCy is copyright ©2013 by Gavin Kistner and is licensed under the [MIT License](http://opensource.org/licenses/MIT). See the LICENSE.txt file for more details.

## Contact

Open issues on [GitHub](https://github.com/Phrogz/RXSCy/issues) for bugs or feature requests. For other details, you can [email the author directly](mailto:!@phrogz.net?subject=RXSCy).