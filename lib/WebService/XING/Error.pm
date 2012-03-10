package WebService::XING::Error;

use Mo qw(required);

has code => (required => 1);

has 'error_name';

has 'message';

1;

__END__

=head1 NAME

WebService::XING::Error - XING API Error Response Class

=head1 ATTRIBUTES

=head2 code

3-digit HTTP status code.

=head2 error_name

Error description string.

=head2 message

A human readable message, but not intended to be displayed to the user.
