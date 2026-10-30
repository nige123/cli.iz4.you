unit module IZ4::Pack;

# Starter packs: words to think with.  A pack only suggests.  Nothing here
# writes an IZ4: a person reads these and, with 'iz4 add', says what they
# will promise in their own words.  The words of SaaS Essentials are
# register.iz4.you's (templates/home/pack_saas_essentials.html.ep), so
# change them there first; never reword them here.

constant SAAS-ESSENTIALS is export = (
    %( title => 'Clear terms',
       when => 'a customer chooses a plan or is asked to pay',
       always => 'they can see what they will pay, how often and for what, before they are charged',
       protects => 'a customer\'s informed choice',
       ask => 'Could anyone be charged for something they never saw priced?',
       test => 'the amount, how often and what for are shown before every charge is made' ),
    %( title => 'Fair charges',
       when => 'a customer is charged',
       always => 'they are charged what they agreed to, once, and never for a service they no longer have',
       protects => 'a customer\'s money',
       ask => 'What happens on a retry, a plan change or a payment that half fails?',
       test => 'a retried payment or a replayed payment message charges once' ),
    %( title => 'Their data stays theirs',
       when => 'one customer\'s data is stored, shown or used',
       always => 'it is never shown to, or used for, anyone else without their say',
       protects => 'each customer\'s privacy',
       ask => 'Is everything read and written scoped to its own account?',
       test => 'signed in as one customer, another customer\'s data cannot be read' ),
    %( title => 'Work is kept',
       when => 'a plan changes, a payment lapses or the software is changed',
       always => 'what a customer made is kept, never lost or held back as leverage',
       protects => 'a customer\'s work',
       ask => 'When a card fails, what happens to what they made?',
       test => 'after a downgrade or a lapsed payment, what they made is still there and can be taken away' ),
    %( title => 'Paid means delivered',
       when => 'a customer is paying',
       always => 'they get the service they pay for, or are told plainly when they do not',
       protects => 'what a customer paid for',
       ask => 'If a paid feature stops working, does anyone tell them?',
       test => 'when a paid feature fails, the customer is shown that it has' ),
    %( title => 'Free to leave',
       when => 'a customer wants to go',
       always => 'they can cancel as easily as they signed up, and take their data with them',
       protects => 'a customer\'s freedom to leave',
       ask => 'How many steps to cancel? Can they take their data with them?',
       test => 'cancelling takes no more steps than signing up, and an export holds all their data' ),
    %( title => 'Deleted means deleted',
       when => 'a customer asks for their data to be deleted',
       always => 'it is deleted, and they are told when it is gone',
       protects => 'control over their own data',
       ask => 'Do backups, logs and copies elsewhere keep it?',
       test => 'after deletion, their data is gone from every place you keep it, and they are told' ),
);
