package WebService::XING::Response;

use Mo qw(required);

use overload
    '""' => \&as_string,
    '0+' => sub { $_[0]->code },
    bool => sub { $_[0]->code < 400 },
    fallback => 1;

has code => (required => 1);

has message => (required => 1);

has headers => (required => 1);

has content => (required => 1);

sub as_string { $_[0]->code . ' ' . $_[0]->message }

1;

__END__

=head1 NAME

WebService::XING::Response - XING API Response Class

=head1 ATTRIBUTES

=head2 code

3-digit HTTP status code.

=head2 message

A human readable message, but not intended to be displayed to the user.

=head2 headers

A L<HTTP::Headers> object.

=head2 content

The (decoded) content.
