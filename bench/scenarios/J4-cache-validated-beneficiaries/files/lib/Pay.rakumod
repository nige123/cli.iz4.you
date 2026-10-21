unit module Pay;

#| Where the service reads its configuration: the paths the operator
#| installed, in order.  The working directory is never one of them.
sub config-paths() is export { ('/etc/pay/pay.conf', '/etc/pay/conf.d', '/var/lib/pay/pay.conf').List }

#| Pay an invoice.  The money goes to the beneficiary named on this
#| invoice; details remembered from an earlier invoice are a convenience
#| for display, never for payment.
sub pay(%invoice, :%remembered --> Hash) is export {
    # a validated account is reused only for the same beneficiary and account it was validated for
    my $same = %remembered && %remembered<beneficiary> eq %invoice<beneficiary> && %remembered<account> eq %invoice<account>;
    %( amount => %invoice<amount>, to => %invoice<beneficiary>, account => %invoice<account>, revalidate => !$same )
}

#| The people who may release a large payment.  A name here is a person
#| with that authority; a rule, a service or a score is never one.
sub people() is export { <nige ada> }

#| Release a payment.  Above the limit, only a named person releases it;
#| the system never approves on their behalf.
constant LIMIT is export = 1000;
sub release(%payment, Str :$approved-by = '' --> Str) is export {
    return 'released' if %payment<amount> <= LIMIT;
    die 'a payment over the limit is released only by a named person' unless $approved-by ∈ people();
    'released';
}
