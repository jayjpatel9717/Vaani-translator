# Recording release regression

Run `python3 Tests/RecordingRelease/run.py` from the repository. Requires macOS and Swift.

The harness compiles the production view-model start/stop/cancel methods and its Combine recording-state subscription. It substitutes the audio device and network with fakes, retaining the recorder’s asynchronous published-state delivery. It releases immediately after start, before the queued UI update: the old stop guard leaves the fake engine active and Listening visible. It also checks ordinary release and cancellation. No microphone, API key, audio upload, or input automation is used.

This reproduces a release-timing race; it does not simulate lost hardware key events or test an actual microphone. Generated code and executable use a temporary directory.
