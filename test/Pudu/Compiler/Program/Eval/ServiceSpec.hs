{-| @Test.Compiler.Program.Eval.ServiceSpec — database, app lifecycle, UI, and system services evaluation -}
module Pudu.Compiler.Program.Eval.ServiceSpec
  ( testServiceEvaluation
  ) where

import Pudu.Compiler.Program.Common (runEntry)
import Test.QuickCheck (Property, conjoin, counterexample, (===))

{-| Evaluates database queries, migrations, application frameworks, observability, auth, and virtual UI. -}
testServiceEvaluation :: IO Property
testServiceEvaluation = do
  database <- runEntry "test-fixtures/stdlib/UsesDb.pudu"
  wired <- runEntry "test-fixtures/stdlib/UsesApp.pudu"
  markup <- runEntry "test-fixtures/stdlib/UsesHtml.pudu"
  screens <- runEntry "test-fixtures/stdlib/UsesUi.pudu"
  refused <- runEntry "test-fixtures/stdlib/UsesGuard.pudu"
  schemas <- runEntry "test-fixtures/stdlib/UsesMigrate.pudu"
  connectionStrings <- runEntry "test-fixtures/stdlib/UsesConnectionString.pudu"
  probes <- runEntry "test-fixtures/stdlib/UsesHealth.pudu"
  measured <- runEntry "test-fixtures/stdlib/UsesMetrics.pudu"
  permitted <- runEntry "test-fixtures/stdlib/UsesAccess.pudu"
  checked <- runEntry "test-fixtures/stdlib/UsesValidate.pudu"
  driven <- runEntry "test-fixtures/stdlib/UsesLive.pudu"
  statements <- runEntry "test-fixtures/stdlib/UsesQuery.pudu"
  mapped <- runEntry "test-fixtures/stdlib/UsesRepository.pudu"
  submitted <- runEntry "test-fixtures/stdlib/UsesBind.pudu"
  columns <- runEntry "test-fixtures/stdlib/UsesSchema.pudu"
  kept <- runEntry "test-fixtures/stdlib/UsesStore.pudu"
  shaped <- runEntry "test-fixtures/stdlib/UsesQueryShape.pudu"
  builtAndShaped <- runEntry "test-fixtures/stdlib/UsesDbQueryShapeAll.pudu"
  proved <- runEntry "test-fixtures/stdlib/UsesPassword.pudu"
  remembered <- runEntry "test-fixtures/stdlib/UsesSession.pudu"
  followed <- runEntry "test-fixtures/stdlib/UsesTrace.pudu"
  scheduled <- runEntry "test-fixtures/stdlib/UsesWork.pudu"
  spoken <- runEntry "test-fixtures/stdlib/UsesLocale.pudu"
  cached <- runEntry "test-fixtures/stdlib/UsesCache.pudu"
  pure $ conjoin
    [ {-| Checked against a server written in the fixture that speaks the wire
          protocol, so what the client sends is observable: that a value is sent
          apart from the statement rather than pasted into it, that the challenge
          is answered without the password crossing, that a server which cannot
          prove it knows the password is refused, and that a failed transaction
          is undone rather than left open. -}
      counterexample
        "a database client binds, authenticates, and rolls back"
        (database === Just "39")
    {-| The obligations [[ADR-0016]] places on an application: that a declared
        default is held like any other setting and can say where it came from,
        that a later layer wins over an earlier one, that a profile states its
        differences rather than replacing what it did not mention, that a read
        says what it expected when the text cannot be that, and — the property
        that only holds because an application is a value — that stages start
        in the order written, stop in the reverse of it, and unwind what came
        up when one of them refuses to. -}
    , counterexample
        "an application is a value that starts and stops in a written order"
        (wired === Just "68")
    {-| That placing text in a page cannot place markup in one: a script
        written into text renders as that text, a quote inside an attribute
        does not end the value and start another, and the ampersand is written
        before the rest so an entity arrives once rather than twice. -}
    , counterexample
        "text placed in a page stays text"
        (markup === Just "60")
    {-| That a screen is a function from state to view, so the difference
        between two renders is exactly the difference the state made: an
        element that became a different element is replaced whole rather than
        reconciled, a list whose length changed replaces the node holding it,
        and applying the changes to the earlier screen gives the later one. -}
    , counterexample
        "two screens differ in what their state differs in"
        (screens === Just "37")
    {-| The refusals [[ADR-0017]] requires, each supplied with the attack it
        exists for and each paired with the legitimate version of the same
        thing: a message framed both by a length and by a chunked encoding, two
        lengths that disagree, a header value carrying a line break, a
        state-changing request from another site or from one that will not say,
        a redirect aimed off-site, a path climbing out of its root by an
        encoded ascent, and an address only the server can reach. -}
    , counterexample
        "the web layer refuses what it is supposed to refuse"
        (refused === Just "82")
    {-| That what a schema change should do is decided without a database: a
        migration edited after it was applied stops everything, because both
        databases report the same version from then on and nothing later can
        detect that their schemas differ; a version arriving below one already
        applied is refused rather than run out of order; and a rename is not an
        edit, because the digest is over what runs. -}
    , counterexample
        "a schema change is planned before a database is reached"
        (schemas === Just "21")
    {-| A connection URI is where text a person or an environment supplied
        becomes the address a program dials, so what the parser accepts is the
        whole of what it will connect to. Each refusal is one a URI could
        otherwise have talked its way past: another database's scheme, a
        missing `sslmode` where no TLS is available, an option nobody checks, a
        second at-sign hiding the real host, a path separator naming a
        different database, a port outside the range, an escape that is not
        one. The accepted forms sit beside them, because a parser that refuses
        everything is no safer and much less useful. -}
    , counterexample "a connection URI is read exactly, or refused"
        (connectionStrings === Just "35")
    {-| That the two questions asked from outside a process stay two
        questions: a liveness judgement is handed a reading rather than a
        connection and is declared comptime, so reaching a clock or a socket
        from one is refused by the compiler; a readiness judgement may consult
        what it needs; and an aggregate is as healthy as its unhealthiest
        part, because every other rule arranges for a failure not to count. -}
    , counterexample
        "restarting and receiving traffic are different questions"
        (probes === Just "29")
    {-| That a set of measurements is a value, so the one before a count is
        still there to compare against; that a metric states its unit where it
        is declared; and that how many label combinations one metric may have
        is bounded, with the combination that would exceed it refused and
        counted rather than evicting a series — an evicted counter restarts at
        zero, and a counter that falls is read as a restart. Declaring and
        recording are each reached through a bound naming that trait alone,
        which is what checks they are usable as methods: a registry is declared
        in one chain and a request is measured in another, which is how a
        program actually writes them. -}
    , counterexample
        "a metric cannot grow a series for every identifier it is handed"
        (measured === Just "49")
    {-| That a route which decided nothing cannot be written: the requirement
        is given in the same call as the handler, so a route needing nothing
        and a route somebody forgot stop being the same line; that not knowing
        who is asking and not being permitted are different answers with
        different statuses; and that a denial does not name what was missing,
        because doing that one route at a time maps the model. Every method a
        route can answer is written the same way, including one this module
        names no call for, so a protocol gaining a method does not gain a way
        to skip the check. The same pattern is decided under two methods, which
        is the case a router that keyed only on the path gets wrong. -}
    , counterexample
        "a route states what it requires or it is not a route"
        (permitted === Just "58")
    {-| That everything wrong is reported at once rather than the first thing,
        since a person correcting a form wants the whole list; that a failure
        says what was expected and never repeats what was submitted, so a
        message cannot become somewhere a script is rendered; and that nothing
        repairs its input, because a validator that trims is deciding what the
        sender meant. -}
    , counterexample
        "everything wrong is reported at once"
        (checked === Just "54")
    {-| That there is one renderer and it is the server's: the difference sent
        to a viewer is the difference the state made, applying it to what the
        viewer had gives what the server holds, an event the session never
        declared changes nothing and is counted, and rejoining after a drop
        sends a whole page rather than a difference against a screen nobody
        knows. -}
    , counterexample
        "a live screen sends the difference its state made"
        (driven === Just "35")
    {-| That a value cannot become part of a statement: a value spelling a
        whole statement stays one parameter, and the one place a parameter
        cannot help — a table or column name — is refused rather than quoted,
        since quoting correctly depends on the dialect and a quoted name that
        was wrong is an injection that looks handled. -}
    , counterexample
        "a value cannot become part of a statement"
        (statements === Just "53")
    {-| That a column which is not there and a column which held nothing are
        different answers, since the layer beneath cannot tell them apart and
        inheriting that turns a mistyped name into a data condition found
        later; and that a lookup expecting one row refuses both none and
        several, because answering the first of several is how a program acts
        on the wrong record with nothing appearing to go wrong. -}
    , counterexample
        "a missing column and an empty one are different answers"
        (mapped === Just "46")
    {-| That where a value came from is stated rather than searched for, since
        a binding that took the first hit across path, query, and body would
        let a caller move a value to reach a different path; that every field
        that was wrong is reported at once; and that a refusal names the fields
        and never the values, because a response is a place a submitted value
        would be rendered. -}
    , counterexample
        "a request binds from where it said, and refuses without echoing"
        (submitted === Just "38")
    {-| That a column is a value carrying its table and the type of what it
        holds, so naming one that does not exist is refused where it is
        written rather than when the statement runs, and comparing a column of
        text against a number does not compile. The established framework
        derives the query from a method name and finds a wrong property when
        the method is called. -}
    , counterexample
        "a column is a name the compiler knows"
        (columns === Just "30")
    {-| That a loaded value holds what was loaded and nothing else — no proxy,
        no attached session, nothing left to fetch — and that what belongs to
        many parents is read in one statement, because the interface takes a
        list of parents and answers a map. Reading for one parent is reading
        for a list of one, so the batched shape is the ordinary one. -}
    , counterexample
        "a loaded value is a value, and children load for many parents at once"
        (kept === Just "32")
    {-| That a statement of real shape holds together: every join, grouping, an
        aggregate, a condition on the group, ordering that says where nothing
        sorts, set operations, a named result, and row locking — composed into
        the shape a report takes, with the clauses in the order the language
        reads them and every value still a parameter however large it grew. -}
    , counterexample
        "a query written as one value keeps its values out of its text"
        (shaped === Just "60")
    {-| Every export of the statement builder and the shape written over it.
        The property both exist for is that nothing from outside reaches the
        text, so every check that could show a value leaking reads the text
        back and counts the values beside it: a builder that wrote a value into
        the text answers a statement carrying one value fewer, and the text
        alone would look right. Names are refused rather than quoted at each
        shape an injection arrives as — a quote, a space, a semicolon, a
        comment marker, a leading digit, a second dot — since a name quoted
        wrongly is an injection that looks handled. Two statements joined are
        the case placeholders make interesting: the second half must come out
        numbered after the first, and a builder that numbered each half when it
        was built answers a second half starting again at one, which the
        database reads as the first half's value. -}
    , counterexample
        "a value never reaches the text and a joined statement renumbers"
        (builtAndShaped === Just "135")
    {-| That a password is kept in a form which proves it later without
        holding it, and that the form carries the settings it was made with —
        so raising the work factor does not invalidate what is already stored,
        which is why a work factor kept elsewhere never gets raised. Every
        password gets its own salt, a form that cannot be read is a failure
        rather than one that matches nothing, and no refusal repeats the
        password it was given. -}
    , counterexample
        "a stored password proves itself without being held"
        (proved === Just "40")
    {-| That signing in always answers a session with a new name, which is the
        whole of the oldest attack against sessions — somebody arranges for a
        browser to hold a name they know, waits for a sign-in, then presents
        it. There is no call here that keeps a name across a change of
        privilege. Two bounds are kept because they answer different
        questions, the clock is given rather than read, and what travels is
        the name and nothing else. -}
    , counterexample
        "signing in always answers a session with a new name"
        (remembered === Just "48")
    {-| That one piece of work can be followed across every service that
        touched it, checked against the header the format itself publishes as
        an example. A header that cannot be read starts a new trace rather
        than refusing the request — the one place here where malformed input
        is not refused, because a service that fails over a malformed
        diagnostic has made the diagnosis into the outage. The recording
        decision travels rather than being retaken, and a span carries only
        what a program put on it. -}
    , counterexample
        "a piece of work can be followed across the services that touched it"
        (followed === Just "48")
    {-| That work a service does unasked is a value: which jobs are due is a
        pure function of the schedule and the moment, so an hourly job is
        checked in a millisecond. A job still running does not start a second
        and the skipped turn is counted; a job that fails is recorded and stays
        scheduled, because one bad night must not leave a nightly job silently
        dead; and it waits for its next turn rather than retrying at once,
        which would turn one failing dependency into a loop against it. -}
    , counterexample
        "a job that fails is recorded and runs again"
        (scheduled === Just "35")
    {-| That a number chooses among the forms a language actually has rather
        than by comparing with one — French counting zero with one, three
        Slavic forms where the rule is not about being one, Arabic's forms for
        none and for two, and the languages with no distinction at all, each of
        which a singular-and-plural catalogue gets wrong. And that a missing
        translation is reportable rather than silent, which is the whole reason
        falling back to the original language is tolerable. The catalogue is
        written through a bound naming the saying trait alone, which is what
        checks a message and a counted message are both usable as methods — a
        catalogue is as many calls as a program has things to say, and written
        as wrapped calls the first message written read as the last one a
        reader reached. -}
    , counterexample
        "a number chooses the form the language has, and a gap can be found"
        (spoken === Just "68")
    {-| That a lookup answers fresh, stale, or nothing rather than a value or
        nothing. Two answers force a caller to treat an expired entry as an
        absent one, which is what makes every request for a much-read key
        recompute it at the same moment against whatever the cache was
        protecting. An absence is remembered too and for less time, the bound
        evicts what is least wanted rather than what is oldest, and reading a
        cache to report on it does not change what it reports. -}
    , counterexample
        "a lookup says whether what it found is still fresh"
        (cached === Just "50")
    ]
