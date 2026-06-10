### brain storm elixir directed graphs for kanban board

my overall goal is to create a task kanban board that allows users to create new swim lanes and enforce data compliance for each task status in each swim lane.

- users must be able to create a new swim lane which represents task status
- transitions between statuses must be enforced using a fsm (finiate state machine)
- the fsm will be modeled as a directed graph
- a data structure that will be used to represent the fms to be stored in a database
- the graph nodes represent the current status of the task ticket
- the graph edges represent the allowed transitions from the current state to another state status as defined in the fsm

the goal for this brainstorming session is not to come up with the end solution but rather explore code variations nd the pro and cons for different variations.






- the the current fms will be represented as a mermaid state diagram in the ui

- swimlanes will be coupled to a status

- edges can be system or user actions
- additional data collection (popup form for manual data entry, api call or database query to automatically pull in additional data required to allow the state status trasition) 
  - api calls to trigger external actions
  - 

webhooks -> external transition

tickets -> task management wrapper around
nodes -> current state
edges -> allowed transitions from a given state
swimlanes -> buckets for specfic states
