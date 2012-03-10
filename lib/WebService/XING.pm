package WebService::XING;

use 5.010;

use Carp ();
use JSON ();
use LWP::UserAgent;
use HTTP::Headers;  # ::Fast
use HTTP::Request;
use Mo qw(builder chain is required);
use Net::OAuth;
use URI;

=head1 NAME

WebService::XING - Perl Interface to the XING API

=head1 VERSION

Version 0.000

=cut

our $VERSION = '0.000';

$Net::OAuth::PROTOCOL_VERSION = Net::OAuth::PROTOCOL_VERSION_1_0A;

=head1 SYNOPSIS

  use WebService::XING;

  my $xing = WebService::XING->new(
    key => $CUSTOMER_KEY,
    secret => $CUSTOMER_SECRET
  );

=head1 DESCRIPTION

Perl Interface to the XING API.

=head1 ATTRIBUTES

=head2 key

=head2 secret

=head2 base_url

Default: C<https://api.xing.com>

=cut

has key => (required => 1);
has secret => (required => 1);

has base_url => (builder => '_build_base');
sub _build_base { 'https://api.xing.com' }

has request_token_resource => (builder => '_build_request_token_resource');
sub _build_request_token_resource { '/v1/request_token' }

has authorize_resource => (builder => '_build_authorize_resource');
sub _build_authorize_resource { '/v1/authorize' }

has access_token_resource => (builder => '_build_access_token_resource');
sub _build_access_token_resource { '/v1/access_token' }

has user_agent => (builder => '_build_user_agent');
sub _build_user_agent { __PACKAGE__ . '/' . $VERSION . ' (Perl)' }

has request_token => (builder => '_build_request_token', chain => 1);
sub _build_request_token { $_[0]->die->('request_token is undefined') }

has request_secret => (builder => '_build_request_secret', chain => 1);
sub _build_request_secret { $_[0]->die->('request_token is undefined') }

has access_token => (builder => '_build_access_token', chain => 1);
sub _build_access_token { $_[0]->die->('access_token is undefined') }

has access_secret => (builder => '_build_access_secret', chain => 1);
sub _build_access_secret { $_[0]->die->('access_secret is undefined') }

has request_timeout => (builder => '_build_request_timeout');
sub _build_request_timeout { 30 }

has json => (builder => '_build_json');
sub _build_json { JSON->new->utf8 }

has warn => (builder => '_build_warn');
sub _build_warn { sub { Carp::carp @_ } }

has die => (builder => '_build_die');
sub _build_die { sub { Carp::croak @_ } }

has _ua => (builder => '_build__ua');
sub _build__ua {
    my $self = shift;

    return LWP::UserAgent->new(
        agent => $self->user_agent,
        default_headers => $self->_headers,
        max_redirect => 2,
        timeout => $self->request_timeout,
    );
}

has _headers => (builder => '_build__headers');
sub _build__headers {
    HTTP::Headers->new(
        Accept => 'application/json',
        'Accept-Encoding' => 'gzip, deflate',
    )
}

has 'error';
sub clear_error { delete $_[0]->{error} }

sub request_credentials {
    my $self = shift;

    return ($self->request_token, $self->request_secret)
        unless @_;

    return $self->request_token($_[0])->request_secret($_[1]);
}

sub access_credentials {
    my $self = shift;

    return ($self->access_token, $self->access_secret)
        unless @_;

    return $self->access_token($_[0])->access_secret($_[1]);
}

=head1 METHODS

=head2 login

  $login_url = $xing->login;

  $login_url = $xing->login($callback_url)
    or die $xing->error->message;

OAuth handshake phase 1: Obtain a request token.

Returns the XING authorization URL on success, to continue with OAuth
handshake phase 2.

If a callback url is given, the user will be directed to that location
after successfull completion of OAuth handshake phase 2, otherwise (or
if callback has the value C<oob>) the user is shown a PIN code
(C<oauth_verifier>), that must be entered in the consumer application.

An C<undef> value is returned to indicate an error, the L</error>
attribute contains a L<WebServive::XING::Error> object for further
investigation.

=cut

sub login {
    my ($self, $callback_url) = @_;

    my $res = $self->request(
        POST => $self->request_token_resource, callback => $callback_url
    );

    $res->is_success or return $self->_set_error_from_response($res);

    $self->clear_error;

    my $oauth_res = Net::OAuth->response('request token')
        ->from_post_body($res->decoded_content);

    $self->request_credentials($oauth_res->token, $oauth_res->token_secret);

    my $url = URI->new($self->base_url . $self->authorize_resource);

    $url->query_form(oauth_token => $oauth_res->token);

    return $url->as_string;
}

=head2 auth

  $xing->auth($verifier);

OAuth handshake phase 3: Obtain an access token. C<$verifier> is the
value, that is returned to the callback function in the C<oauth_verifier>
parameter or, for out-of-band authorization, it is displayed in the
browser to be entered into the consumer application manually by the user.

=cut

sub auth {
    my ($self, $verifier) = @_;

    $self->die->('auth: verifier argument is missing')
        unless $verifier;

    my $res = $self->request(
        POST => $self->access_token_resource, verifier => $verifier
    );

    $res->is_success or return $self->_set_error_from_response($res);

    $self->clear_error;

    my $oauth_res = Net::OAuth->response('access token')
        ->from_post_body($res->decoded_content);

    $self->access_credentials($oauth_res->token, $oauth_res->token_secret);
}

=head2 request

  $xing->request(POST => $self->request_token_resource);
  $xing->request(GET => '/v1/users/me');

=cut

sub request {
    my ($self, $method, $resource, %args) = @_;
    my $type;
    my @extra;
    my $url = $self->base_url . $resource;

    if ($resource eq $self->request_token_resource) {
        $type = 'request token';
        @extra = (callback => $args{callback} || 'oob');
    }
    elsif ($resource eq $self->access_token_resource) {
        $type = 'access token';
        @extra = (
            token => $self->request_token,
            token_secret => $self->request_secret,
            verifier => $args{verifier},
        );
    }
    else {
        $type = 'protected resource';
        @extra = (
            token => $self->access_token,
            token_secret => $self->access_secret,
        );
    }

    my $oauth_req = Net::OAuth->request($type)->new(
        consumer_key => $self->key,
        consumer_secret => $self->secret,
        request_url => $url,
        request_method => $method,
        signature_method => 'HMAC-SHA1',
        timestamp => time,
        nonce => $self->nonce,
        @extra,
    );

    $oauth_req->sign;

    # $oauth_req->to_url;
    # $oauth_req->to_authorization_header;

    my $headers = HTTP::Headers->new(
        Authorization => $oauth_req->to_authorization_header,
    );

    my $content;

    if ($method ~~ ['POST', 'PUT']) {
        $content = $args{content} // '';
        if (ref $content eq 'HASH') {
            my $url = URI->new('http:');
            $url->query_form(%$content);
            $content = $url->query;
            $content =~ s/(?<!%0D)%0A/%0D%0A/g;
        }
        $headers->header(
            'Content-Type' => 'application/x-www-form-urlencoded',
            'Content-Length' => length $content
        );
    }

    return $self->_ua->request(HTTP::Request->new($method, $url, $headers, $content));
}

=head2 nonce

=cut

my @CHARS = ('_', '0' .. '9', 'A' .. 'Z', 'a' .. 'z');

sub nonce {
    my $s = "";
    my $i = 16;

    do {
        $s .= $CHARS[rand @CHARS];
    } while (--$i);

    return $s;
}

### Internal

sub _set_error_from_response {
    my ($self, $res) = @_;
    my $headers = $res->headers;
    my $args;

    if ($headers->content_length and $headers->content_type eq 'application/json') {
        $args = $self->json->decode($res->decoded_content);
    }
    elsif ($headers->content_length) {
        $self->warn->(
            "Error response is not JSON:\n\nContent-Type: " .
            $headers->content_type .  "\n\n" .
            $res->decoded_content
        );
    }
    else {
        $self->warn->("Error response is empty");
    }

    $args->{code} = $res->code;
    $self->error(WebService::XING::Error->new(%$args));

    return undef;
}

=head1 AUTHOR

Bernhard Graf, C<< <graf at cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-webservice-xing at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=WebService-XING>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc WebService::XING


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=WebService-XING>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/WebService-XING>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/WebService-XING>

=item * Search CPAN

L<http://search.cpan.org/dist/WebService-XING/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2012 Bernhard Graf.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut

1; # End of WebService::XING
