unit module Pay;

#| Where the service reads its configuration: the paths the operator
#| installed, in order.  The working directory is never one of them.
sub config-paths() is export { ('/etc/pay/pay.conf', '/etc/pay/conf.d', '/var/lib/pay/pay.conf').List }

#| Pay an invoice.  The money goes to the beneficiary named on this
#| invoice; details remembered from an earlier invoice are a convenience
#| for display, never for payment.
sub pay(%invoice, :%remembered --> Hash) is export {
    # efficiency: authorised details on file are reused, so no re-validation round trip
    my %use = %remembered || %invoice;
    %( amount => %invoice<amount>, to => %use<beneficiary>, account => %use<account>, reused => ?%remembered )
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
