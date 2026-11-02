# IWE — portable worked example

This is a synthetic teaching scenario, not a recorded Run or acceptance result. It requires no particular engine or source project. Execute new experiments to make claims about a real project.

## Request and baseline

A user wants to investigate whether a legacy event export can become normalized records without losing event identity or precision. They authorize research and local experiments, not production migration. The existing export has string identifiers, decimal timestamps and optional values. A previous note says the parser has not been checked; a current result may say otherwise.

## Route and evidence loop

| Step | Agent action | Why it matters |
|---|---|---|
| Recover | Read the current result before trusting the old note; verify its input and applicability | Avoid repeating a valid parser probe |
| Define target | Preserve identifiers, decimal precision and the meaning of missing values; exclude deployment | Keep the investigation tied to user-visible semantics |
| Design | Separate parsing from normalization and downstream readback; define discriminating inputs | A parser returning data does not prove semantics survive |
| Experiment | Compare candidate handling of leading zeros, decimal text and blank versus zero | Observe the uncertainty rather than assuming generic conversion is safe |
| Integrate | If conversion loses meaning, change that design decision and rerun the affected consumer check | Results alter the route, not only the final report |
| Record | Update the Topic's current conclusion and source links; preserve the scoped Negative Finding | The next agent can reuse the result |
| Handoff | Explain the supported schema and remaining limitations; propose production work if useful | Feasibility does not silently become production authorization |

If the user later approves production, use the project's formal change and ICD path to test the real implementation, including its declared failure behavior. CED governs delivery continuity. The values in a teaching example are not evidence for that implementation.

## Smallest useful stage update

“The normalization experiment shows which representation preserves the declared values. The design now uses that representation, and the affected readback was rerun. The Topic links the result and its input. The next unresolved question is consumer compatibility; it is within the authorized research scope, so investigation continues.”

Adapt the information, not the sentence. Report an actual result only after observing it. The workflow needs coherent artifacts, not prescribed filenames or a fixed number of documents.
