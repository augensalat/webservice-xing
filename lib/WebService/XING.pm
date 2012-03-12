package WebService::XING;

use 5.010;

use Carp ();
use JSON ();
use LWP::UserAgent;
use HTTP::Headers;  # ::Fast
use HTTP::Request;
use Mo qw(builder chain required);
use Net::OAuth;
use URI;
use WebService::XING::Error;

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

    my $oauth_res = Net::OAuth->response('access token')
        ->from_post_body($res->decoded_content);

    $self->access_credentials($oauth_res->token, $oauth_res->token_secret);
}

=head2 get_user_profile

=head2 create_status_message

=head2 get_profile_message

=head2 update_profile_message

=head2 get_contacts

=head2 get_shared_contacts

=head2 get_incoming_contact_requests

=head2 get_sent_contact_requests

=head2 create_contact_request

=head2 accept_contact_request

=head2 delete_contact_request

=head2 get_contact_paths

=head2 get_bookmarks

=head2 create_bookmark

=head2 delete_bookmark

=head2 get_network_feed

=head2 get_user_feed

=head2 get_activity

=head2 share_activity

=head2 delete_activity

=head2 get_activity_comments

=head2 create_activity_comment

=head2 delete_activity_comment

=head2 get_activity_likes

=head2 create_activity_like

=head2 delete_activity_like

=head2 get_profile_visits

=head2 create_profile_visit

=head2 get_recommended_users

=head2 create_invitations

=head2 update_geo_location

=head2 get_nearby_users

=cut

my %APITAB = (
    # User Profiles
    get_user_profile =>
        [GET => '/v1/users/:id', '@fields'],

    # Status Messages
    create_status_message =>
        [POST => '/v1/users/:id/status_message', '!message'],

    # Profile Messages
    get_profile_message =>
        [GET => '/v1/users/:user_id/profile_message'],
    update_profile_message =>
        [PUT => '/v1/users/:user_id/profile_message', '!message', '?public'],

    # Contacts
    get_contacts =>
        [GET => '/v1/users/:user_id/contacts', 'limit', 'offset', 'order_by', '@user_fields'],
    get_shared_contacts =>
        [GET => '/v1/users/:user_id/contacts/shared', 'limit', 'offset', 'order_by', '@user_fields'],

    # Contact Requests
    get_incoming_contact_requests =>
        [GET => '/v1/users/:user_id/contact_requests', 'limit', 'offset', '@user_fields'],
    get_sent_contact_requests =>
        [GET => '/v1/users/:user_id/contact_requests/sent', 'limit', 'offset'],
    create_contact_request =>
        [POST => '/v1/users/:user_id/contact_requests', 'message'],
    accept_contact_request =>
        [PUT => '/v1/users/:user_id/contact_requests/:id/accept'],
    delete_contact_request =>
        [DELETE => '/v1/users/:user_id/contact_requests/:id'],

    # Contact Path
    get_contact_paths =>
        [GET => '/v1/users/:user_id/network/:other_user_id/paths', '?all_paths', '@user_fields'],

    # Bookmarks
    get_bookmarks =>
        [GET => '/v1/users/:user_id/bookmarks', 'limit', 'offset', '@user_fields'],
    create_bookmark =>
        [PUT => '/v1/users/:user_id/bookmarks/:id'],
    delete_bookmark =>
        [DELETE => '/v1/users/:user_id/bookmarks/:id'],

    # Network Feed
    get_network_feed =>
        [GET => '/v1/users/:user_id/network_feed', '?aggregate', 'since', 'until', '@user_fields'],
    get_user_feed =>
        [GET => '/v1/users/:id/feed', 'since', 'until', '@user_fields'],
    get_activity =>
        [GET => '/v1/activities/:id', '@user_fields'],
    share_activity =>
        [POST => '/v1/activities/:id/share', 'text'],
    delete_activity =>
        [DELETE => '/v1/activities/:id'],
    get_activity_comments =>
        [GET => '/v1/activities/:activity_id/comments', 'limit', 'offset', '@user_fields'],
    create_activity_comment =>
        [POST => '/v1/activities/:activity_id/comments', 'text'],
    delete_activity_comment =>
        [DELETE => '/v1/activities/:activity_id/comments/:id'],
    get_activity_likes =>
        [GET => '/v1/activities/:activity_id/likes', 'limit', 'offset', '@user_fields'],
    create_activity_like =>
        [PUT => '/v1/activities/:activity_id/like'],
    delete_activity_like =>
        [DELETE => '/v1/activities/:activity_id/like'],

    # Profile Visits
    get_profile_visits =>
        [GET => '/v1/users/:user_id/visits', 'limit', 'offset', 'since', '?strip_html'],
    create_profile_visit =>
        [POST => '/v1/users/:user_id/visits'],

    # Recommendations
    get_recommended_users =>
        [GET => '/v1/users/:user_id/network/recommendations', 'limit', 'offset', 'similar_user_id', '@user_fields'],

    # Invitations
    create_invitations =>
        [POST => '/v1/users/invite', 'to_emails=l', 'message', '@user_fields'],

    # Geo Locations
    update_geo_location =>
        [PUT => '/v1/users/:user_id/geo_location', '!accuracy', '!latitude', '!longitude', 'ttl'],
    get_nearby_users  =>
        [GET => '/v1/users/:user_id/nearby_users', 'age', 'radius', '@user_fields'],
);

sub AUTOLOAD {
    my ($self, %p) = @_;
    my ($package, $action) = our $AUTOLOAD =~ /^([\w\:]+)\:\:(\w+)$/;
    my $row = $APITAB{$action}
        or $self->die->(qq{Can't locate object method "$action" via package "$package"});
    my ($method, $resource, @params) = @$row;
    my (@p, $p);

    for ($resource =~ /:(\w+)/g) {
        defined($p = delete $p{$_})
            or $self->die->(_missing_parameter($_, $package, $action));
        $resource =~ s/:$_/$p/;
    }

    for (@params) {
        my ($flag, $key) = /^([\@\!\?]?)(\w+)$/;
        my $value = delete $p{$key};

        if (defined $value) {
            if (ref $value eq 'ARRAY') {
                $self->die->(_invalid_parameter($key, $package, $action))
                    unless $flag eq '@';
                push @p, $key, join(',', @$value);
            }
            elsif ($flag eq '?') {
                push @p, $key, $value && $value ne 'false' ? 'true' : 'false';
            }
            else {
                push @p, $key, $value;
            }
        }
        else {
            $self->die->(_missing_parameter($key, $package, $action))
                if $flag eq '!';
        }
    }

    $self->die->(_invalid_parameter((keys %p)[0], $package, $action))
        if %p;

    return $self->request($method, $resource, @p);
}

sub DESTROY { }

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
        @extra = (callback => delete $args{callback} || 'oob');
    }
    elsif ($resource eq $self->access_token_resource) {
        $type = 'access token';
        @extra = (
            token => $self->request_token,
            token_secret => $self->request_secret,
            verifier => delete $args{verifier},
        );
    }
    else {
        $type = 'protected resource';
        @extra = (
            token => $self->access_token,
            token_secret => $self->access_secret,
        );
    }

    my $content = '';
    my $headers = HTTP::Headers->new;

    if ($method ~~ ['POST', 'PUT']) {
        my $u = URI->new('http:');
        if (%args) {
            $u->query_form(%args);
            $content = $u->query;
            $content =~ s/(?<!%0D)%0A/%0D%0A/g;
        }
        $headers->header(
            'Content-Type' => 'application/x-www-form-urlencoded',
            'Content-Length' => length $content
        );
    }
    elsif (%args) {
        my $u = URI->new($url);
        $u->query_form(%args);
        $url = $u->as_string;
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

    $headers->header(Authorization => $oauth_req->to_authorization_header);

    $self->clear_error;

    my $req = HTTP::Request->new($method, $url, $headers, $content);

    return $self->_ua->request(HTTP::Request->new($method, $url, $headers, $content));
}

=head2 nonce

=cut

my @CHARS = ('_', '0' .. '9', 'A' .. 'Z', 'a' .. 'z');

sub nonce {
    my $s = "";
    my $i = int(28 + rand 9);

    do { $s .= $CHARS[rand @CHARS] } while --$i;

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

sub _missing_parameter {
    my ($p, $pack, $meth) = @_;

    sprintf 'Mandatory parameter "%s" is missing in method call "%s" in package "%s"',
            $p, $meth, $pack;
}

sub _invalid_parameter {
    my ($p, $pack, $meth) = @_;

    sprintf 'Invalid parameter "%s" in method call "%s" in package "%s"',
            $p, $meth, $pack;
}

1;

__END__

=head1 AUTHOR

Bernhard Graf, C<< <graf (a) cpan.org> >>

=head1 LICENSE AND COPYRIGHT

Copyright 2012 Bernhard Graf.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.

