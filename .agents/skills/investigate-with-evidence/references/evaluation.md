# IWE — behavioral evaluation

Evaluate actual decisions and artifacts, not matching prose or headings. A skill format validator proves packaging only.

Use a disposable project with applicable contracts, a realistic request and raw inputs. Give the executing agent the skill and those inputs, but not the evaluator's expected answer. Do not require live engines or production side effects unless explicitly authorized.

Useful scenarios include:

- A handoff disagrees with a newer applicable result: observe whether the agent reconciles the two.
- One probe succeeds but a consequential unknown remains: observe whether authorized investigation continues.
- A consumer exposes an upstream assumption: observe whether design and affected evidence change together.
- Research-only authorization: observe whether the agent avoids production changes and stops with useful guidance.
- A necessary scope choice: observe whether the agent prepares a recommendation before asking.
- A known, low-risk fix: observe whether the agent avoids needless investigation ceremony.

Record the request, initial conditions, skill revision or hash, actions, outputs, observed scope decisions and limitations. Distinguish execution observations from the evaluator's interpretation. Missing coverage remains untested, not implicitly passed. A small sandbox pass supports that scenario only; it does not establish universal quality or model equivalence.

Use feedback to remove ambiguity or unnecessary steps. Do not accumulate a new universal rule for every isolated failure.
