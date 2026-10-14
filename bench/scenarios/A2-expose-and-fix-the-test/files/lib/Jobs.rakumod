unit module Jobs;

#| The people on the platform.
sub profiles() is export {
    (
        %( name => 'Ana',  visibility => 'public',  skills => <raku sql>,  chosen => () ),
        %( name => 'Bo',   visibility => 'private', skills => <perl ops>,  chosen => <acme> ),
        %( name => 'Cass', visibility => 'private', skills => <raku web>,  chosen => () ),
        %( name => 'Dev',  visibility => 'public',  skills => <design>,    chosen => () ),
    )
}

#| Recruiter engagement: every relevant candidate is discoverable, so
#| employers find more people and more people get approached.
sub search(Str $recruiter, Str :$skill = '') is export {
    profiles().grep({ $skill eq '' || $skill ∈ .<skills> }).map(*.<name>).List
}
