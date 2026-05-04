# claude thoughts

Here's a plan for both sessions, with suggested demos and flow tailored to each audience.

Here's a detailed plan for both sessions.

## Session 1: Data API Builder — Data Platform Audience (60 mins)
Goal: Convince DBAs, data engineers, and analysts that DAB is a practical tool in their data access toolkit — not just a dev toy.
Suggested flow:
Opening hook (5 mins) — Start with a pain point they'll recognise: "You have a SQL Server or Postgres database. Someone wants to read from it. Do you give them a connection string? Write a FastAPI wrapper? Ask them to wait for the data team?" Frame DAB as the answer that takes 5 minutes, not 5 days.
What is DAB? (10 mins) — Brief conceptual overview. What it is (a config-driven REST/GraphQL layer over a database), what it isn't (an ORM, a full backend framework, a replacement for your stored proc strategy). Show the architecture visually — database → DAB config → HTTP endpoints.
Live demo 1: Zero to API in under 5 minutes (15 mins) — This is the wow moment. Start with a blank SQL Server or Postgres database, write a config file, spin up DAB (via CLI or Docker), and show a working REST endpoint in the browser. Expose a table, a view, and a stored procedure. Let them see how little code is involved.
Live demo 2: Filtering, pagination, relationships (10 mins) — Show DAB's built-in query capabilities: filtering via query params, field selection, pagination. Then show a relationship between two tables expressed in the config, and how the API reflects that. This is where data folks start seeing real utility for analytics and integration work.
Running in containers (5 mins) — Quick demo of running DAB via Docker or a compose file. Emphasise repeatability — great for dev environments, CI pipelines, and local testing alongside tools like dbt or Airbyte.
Practical scenarios (10 mins) — Walk through three scenarios your audience will recognise:

Exposing a reporting view for a BI tool or Excel Power Query without giving out credentials
Letting an analyst prototype data transformations via simple HTTP calls before productionising
A lightweight integration layer between two systems that don't share a database

Q&A buffer (5 mins)

## Session 2: Persist PowerShell Script Data — PowerShell Audience (45 mins)
Goal: Convince PowerShell users that reaching for a database (via DAB) is no harder than writing to a file — and much more powerful.
Suggested flow:
Opening hook (5 mins) — Relatable setup: "You've written a script that does something useful. Where does it store its results? CSV? JSON file? A variable that disappears when the session ends?" Plant the idea that a database is the right answer, but acknowledge it sounds like more work than it is.
The pitch: DAB makes the database part trivial (5 mins) — One slide/demo showing what the end state looks like: a PowerShell script calling Invoke-RestMethod against a localhost endpoint and writing a row to a SQL table. No connection strings, no drivers, no modules to install. This is the punchline — give it to them early.
Setup demo: DAB in 5 minutes (10 mins) — Install DAB (or pull the Docker image), create a config file pointing at a SQL Server or Postgres instance, expose a table. Show that this is genuinely as fast as it looks. Keep it focused — one table, one config, one endpoint. Save the advanced stuff.
PowerShell integration demo (15 mins) — This is the heart of the session. Show a practical script scenario end to end:

A script that runs and collects data (job results, system info, whatever resonates with the audience)
Invoke-RestMethod POST to write results to the DAB endpoint
Invoke-RestMethod GET with filters to query the data back
A second script that picks up where the first left off using state persisted via DAB

Highlight how familiar this feels — it's just HTTP, which PowerShell people already know from calling APIs.
Bonus: stored procedures as API actions (5 mins) — Show exposing a stored proc as an endpoint, then calling it from PowerShell. This is particularly useful for DBAs in the room who have existing procs they want to expose to automation.
Call to action + Q&A (5 mins) — Point them to the DAB docs, the GitHub repo, and suggest one script they could go home and try this with today.

Here's a visual showing how the two sessions relate and where they share content:

![alt text](image.png)

## A few practical tips for prep:

The biggest efficiency win is that your live demo setup is essentially the same for both sessions. If you build a small database with a couple of tables (something like a script log table and a results table), you can use the exact same DAB config and running instance for both talks — just change which parts you emphasise and what you call Invoke-RestMethod against.
For the data platform session, lean into the "no credentials, no drivers" angle — that's genuinely compelling for DBAs who are tired of fielding connection string requests. For the PowerShell session, the emotional hook is "stop writing to CSV files" — make that moment land early and refer back to it throughout.
One thing worth preparing for both: someone will ask "why not just use a proper API framework?" Have a crisp answer ready — the answer is that DAB is for when you own the data and need the API quickly, not when you're building a product. They're solving different problems.

