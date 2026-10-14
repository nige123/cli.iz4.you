unit module Jobs;

#| The people on the platform.  A private profile names the recruiters
#| its owner chose; nobody else may learn that this person is looking.
sub profiles() is export {
    (
        %( name => 'Ana',  visibility => 'public',  skills => <raku sql>,  chosen => () ),
        %( name => 'Bo',   visibility => 'private', skills => <perl ops>,  chosen => <acme> ),
        %( name => 'Cass', visibility => 'private', skills => <raku web>,  chosen => () ),
        %( name => 'Dev',  visibility => 'public',  skills => <design>,    chosen => () ),
    )
}

#| What a recruiter sees when they search: public profiles, and the
#| private ones whose owner chose this recruiter.
sub search(Str $recruiter, Str :$skill = '') is export {
    profiles().grep({ .<visibility> eq 'public' || $recruiter ∈ .<chosen> })
              .grep({ $skill eq '' || $skill ∈ .<skills> })
              .map(*.<name>).List
}

#| Offline work: a recruiter downloads every candidate as rows.
sub export-candidates(Str $recruiter) is export {
    profiles().map({ (.<name>, .<visibility>, .<skills>.join(' ')).join(',') }).List
}
