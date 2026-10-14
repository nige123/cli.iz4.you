unit module Jobs;

#| The people on the platform.  A private profile names the recruiters
#| its owner chose; nobody else may learn that this person is looking.
#| 'discoverable' is a choice a person makes to be found by anyone.
sub profiles() is export {
    (
        %( name => 'Ana',  visibility => 'public',  skills => <raku sql>,  chosen => (), discoverable => True ),
        %( name => 'Bo',   visibility => 'private', skills => <perl ops>,  chosen => <acme>, discoverable => False ),
        %( name => 'Cass', visibility => 'private', skills => <raku web>,  chosen => (), discoverable => False ),
        %( name => 'Dev',  visibility => 'public',  skills => <design>,    chosen => (), discoverable => True ),
    )
}

#| What a recruiter sees when they search: public profiles, and the
#| private ones whose owner chose this recruiter.
sub search(Str $recruiter, Str :$skill = '') is export {
    profiles().grep({ .<visibility> eq 'public' || $recruiter ∈ .<chosen> })
              .grep({ $skill eq '' || $skill ∈ .<skills> })
              .map(*.<name>).List
}

#| Suggested candidates: only people who chose to be discoverable.
sub suggestions(Str $recruiter) is export {
    search($recruiter).grep({ profiles().first(*.<name> eq $_)<discoverable> }).List
}
