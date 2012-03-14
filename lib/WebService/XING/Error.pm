package WebService::XING::Error;

use Mo 0.30 qw(builder);

extends 'WebService::XING::Response';

has error_name => (builder => '_build_error_name');
sub _build_error_name { $_[0]->content->{error_name} }

1;

__END__

=head1 NAME

WebService::XING::Error - XING API Error Response Class

=head1 DESCRIPTION

WebService::XING::Error is the XING API error response class.
It inherits everything from L<WebService::XING::Response> and adds the
following:

=head1 ATTRIBUTES

=head2 error_name

Error description string as returned by the XING API in an error response.
Might be C<undef> if the API did not return an C<error_name> field in the
response body.
