## Decision

The public read method owns an explicit ABP unit of work and uses the repository's predicate lookup, which executes the query before returning. The method returns a materialized snapshot. It can also join an existing work unit when called from another service.
