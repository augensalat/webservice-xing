package WebService::XING;

use 5.010;

use Carp ();
use JSON ();
use LWP::UserAgent;
use HTTP::Headers;  # ::Fast
use HTTP::Request;
use Mo 0.30 qw(builder chain is required);
use Net::OAuth;
use URI;
use WebService::XING::Error;
use WebService::XING::Response;

our $VERSION = '0.000';

our @CARP_NOT = qw(Mo::builder Mo::chain Mo::is Mo::required);
@Carp::Internal{qw(Mo::builder Mo::chain Mo::is Mo::required)} = (1, 1, 1, 1);

# Prototypes

sub _nonce ();
sub _missing_parameter ($$$);
sub _invalid_parameter ($$$);


$Net::OAuth::PROTOCOL_VERSION = Net::OAuth::PROTOCOL_VERSION_1_0A;

has key => (is => 'ro', required => 1);

has secret => (is => 'ro', required => 1);

has access_token => (builder => '_build_access_token', chain => 1);
sub _build_access_token { $_[0]->die->('access_token is undefined') }

has access_secret => (builder => '_build_access_secret', chain => 1);
sub _build_access_secret { $_[0]->die->('access_secret is undefined') }

has 'user_id';

sub access_credentials {
    my $self = shift;

    return ($self->access_token, $self->access_secret, $self->user_id)
        unless @_;

    return $self->access_token($_[0])->access_secret($_[1]);
}

has user_agent => (builder => '_build_user_agent', chain => 1);
sub _build_user_agent { __PACKAGE__ . '/' . $VERSION . ' (Perl)' }

has request_timeout => (builder => '_build_request_timeout', chain => 1);
sub _build_request_timeout { 30 }

has json => (builder => '_build_json', chain => 1);
sub _build_json { JSON->new->utf8 }

has warn => (builder => '_build_warn', chain => 1);
sub _build_warn { sub { Carp::carp @_ } }

has die => (builder => '_build_die', chain => 1);
sub _build_die { sub { Carp::croak @_ } }

has base_url => (builder => '_build_base', chain => 1);
sub _build_base { 'https://api.xing.com' }

has request_token_resource => (
    builder => '_build_request_token_resource',
    chain => 1,
);
sub _build_request_token_resource { '/v1/request_token' }

has authorize_resource => (
    builder => '_build_authorize_resource',
    chain => 1,
);
sub _build_authorize_resource { '/v1/authorize' }

has access_token_resource => (
    builder => '_build_access_token_resource',
    chain => 1,
);
sub _build_access_token_resource { '/v1/access_token' }

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
        # Accept => 'application/json, text/javascript, */*; q=0.01',
        'Accept-Encoding' => 'gzip, deflate',
    )
}

sub login {
    my ($self, %args) = @_;
    my @args = $self->_scour_args(__PACKAGE__, 'login', \%args, 'callback') ||
               (callback => 'oob');
    my $res = $self->request(POST => $self->request_token_resource, @args);

    $res->is_success or return $res;

    my $oauth_res = Net::OAuth->response('request token')
        ->from_post_body($res->content);

    my $url = URI->new($self->base_url . $self->authorize_resource);

    $url->query_form(oauth_token => $oauth_res->token);

    return WebService::XING::Response->new(
        code => $res->code,
        message => => $res->message,
        headers => $res->headers,
        content => {
            url => $url->as_string,
            token => $oauth_res->token,
            token_secret => $oauth_res->token_secret,
        }
    );
}

sub auth {
    my ($self, %args) = @_;
    my @args = $self->_scour_args(
        __PACKAGE__, 'auth', \%args, qw(!token !token_secret !verifier)
    );
    my $res = $self->request(POST => $self->access_token_resource, @args);

    $res->is_success or return $res;

    my $oauth_res = Net::OAuth->response('access token')
        ->from_post_body($res->content);
    my $extra_params = $oauth_res->extra_params;

    $self->access_credentials(
        $oauth_res->token, $oauth_res->token_secret, $extra_params->{user_id}
    );

    return WebService::XING::Response->new(
        code => $res->code,
        message => => $res->message,
        headers => $res->headers,
        content => {
            token => $oauth_res->token,
            token_secret => $oauth_res->token_secret,
            user_id => $extra_params->{user_id},
        }
    );
}

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
        [POST => '/v1/users/invite', '@to_emails', 'message', '@user_fields'],

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
    my $p;

    for ($resource =~ /:(\w+)/g) {
        defined($p = delete $p{$_})
            or $self->die->(_missing_parameter($_, $package, $action));
        $resource =~ s/:$_/$p/;
    }

    my @p = $self->_scour_args($package, $action, \%p, @params);

    return $self->request($method, $resource, @p);
}

sub DESTROY { }

sub request {
    my ($self, $method, $resource, @args) = @_;
    my (@extra, $type);
    my $url = $self->base_url . $resource;
    my $content = '';
    my $headers = HTTP::Headers->new;

    if ($resource eq $self->request_token_resource) {
        $type = 'request token';
        # tame the XING API server
        $headers->header(Accept => 'application/x-www-form-urlencoded');
        @extra = @args;
        @args = ();
    }
    elsif ($resource eq $self->access_token_resource) {
        $type = 'access token';
        # tame the XING API server
        $headers->header(Accept => 'application/x-www-form-urlencoded');
        @extra = @args;
        @args = ();
    }
    else {
        $type = 'protected resource';
        $headers->header(Accept => 'application/json');
        @extra = (
            token => $self->access_token,
            token_secret => $self->access_secret,
        );
    }

    if ($method ~~ ['POST', 'PUT']) {
        my $u = URI->new('http:');
        if (@args) {
            $u->query_form(@args);
            $content = $u->query;
            $content =~ s/(?<!%0D)%0A/%0D%0A/g;
        }
        $headers->header(
            'Content-Type' => 'application/x-www-form-urlencoded',
            'Content-Length' => length $content
        );
    }
    elsif (@args) {
        my $u = URI->new($url);
        $u->query_form(@args);
        $url = $u->as_string;
    }

    my $oauth_req = Net::OAuth->request($type)->new(
        consumer_key => $self->key,
        consumer_secret => $self->secret,
        request_url => $url,
        request_method => $method,
        signature_method => 'HMAC-SHA1',
        timestamp => time,
        nonce => _nonce,
        @extra,
    );

    $oauth_req->sign;

    $headers->header(Authorization => $oauth_req->to_authorization_header);

    my $res = $self->_ua->request(HTTP::Request->new($method, $url, $headers, $content));

    $headers = $res->headers;

    return WebService::XING::Response->new(
        code => $res->code,
        message => $res->message,
        headers => $headers,
        content => $headers->content_type eq 'application/json' ?
            $self->json->decode($res->decoded_content) : $res->decoded_content,
    );
}

### Internal

# $self->_scour_args(\%args, @array_of_known_argument_names)
# Scour argument list, die on missing or unknown arguments.
sub _scour_args {
    my ($self, $package, $action, $args) = (shift, shift, shift, shift);
    my @p;

    for (@_) {
        my ($flag, $key) = /^([\@\!\?]?)(\w+)$/;
        my $value = delete $args->{$key};

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

    $self->die->(_invalid_parameter((keys %$args)[0], $package, $action))
        if %$args;

    return @p;
}

# _nonce
# Create a random string fast.
my @CHARS = ('_', '0' .. '9', 'A' .. 'Z', 'a' .. 'z');

sub _nonce () {
    my $s = "";
    my $i = int(28 + rand 9);

    do { $s .= $CHARS[rand @CHARS] } while --$i;

    return $s;
}

sub _missing_parameter ($$$) {
    my ($p, $pack, $meth) = @_;

    sprintf 'Mandatory parameter "%s" is missing in method call "%s" in package "%s"',
            $p, $meth, $pack;
}

sub _invalid_parameter ($$$) {
    my ($p, $pack, $meth) = @_;

    sprintf 'Invalid parameter "%s" in method call "%s" in package "%s"',
            $p, $meth, $pack;
}

1;

__END__

=head1 NAME

WebService::XING - Perl Interface to the XING API

=head1 VERSION

Version 0.000

=head1 SYNOPSIS

  use WebService::XING;

  my $xing = WebService::XING->new(
    key => $CUSTOMER_KEY,
    secret => $CUSTOMER_SECRET,
    access_token => $access_token,
    access_secret => $access_secret,
    user_id => $user_id,
  );

  $res = $xing->get_user_profile(id => 'me')
    or die $res;

  say "Hello, I'm ", $res->content->{users}->[0]->{display_name};

=head1 DESCRIPTION

C<WebService::XING> is a Perl client library for the XING API. It supports
the whole range of functions described under L<https://dev.xing.com/>.

=head2 Alpha Software Warning

This software is released under the "Release Early - Release Often" motto,
and should not be considered stable. You are welcome to check it out, but
be prepared: it might kill your kittens!

Moreover at the time of writing, the XING API is in a closed beta test
phase, and still has a couple of bugs.

=head1 ATTRIBUTES

All attributes can be set in the L<constructor|/new>.

All writeable attributes can be used as setters and getters of the
object instance.

All writeable attributes return the object in set mode, so they can be
chained. This example does virtually the same as in the L</SYNOPSIS>
above:

  $res = WebService::XING->new(
    key => $CUSTOMER_KEY,
    secret => $CUSTOMER_SECRET
  )
    ->access_token($token)
    ->access_secret($secret)
    ->user_id($uid)
    ->get_user_profile(id => 'me')
      or die $res;

  say "Hello, I'm ", $res->content->{users}->[0]->{display_name};

All attributes with a default value are "lazy": They get their value when
they are read the first time, unless they are already initialized. To get
the default value, an attribute calls an init method called
C<"_build_" . $attribute_name>.  This gives a sub class of
C<WebService::XING> the opportunity to override any default value by
providing a custom init method.

=head2 key

The application key a.k.a. "consumer key". Required and read-only.

=head2 secret

The application secret a.k.a. "consumer secret". Required and read-only.

=head2 access_token

  $xing = $xing->access_token($access_token);
  $access_token = $xing->access_token;

Access token as returned at the end of the OAuth process.
Required for all methods except L</login> and L</auth>.

=head2 access_secret

  $xing = $xing->access_secret($access_secret);
  $access_secret = $xing->access_secret;

Access secret as returned at the end of the OAuth process.
Required for all methods except L</login> and L</auth>.

=head2 user_id

The scrambled XING user id as returned (and set) by the L</auth> method.
Your application will need to remember this because it serves as an entry
point to most of the data calls.

=head2 access_credentials

  $xing = $xing->access_credentials(
    $access_token, $access_secret, $user_id
  );
  ($access_token, $access_secret, $user_id) =
    $xing->access_credentials;

Convenience access attribute accessor, for getting and setting
L</access_token>, L</access_secret> and L</user_id> in one go.

Once authorization has completed, L</access_token>, L</access_secret> and
L</user_id> are the only variable attributes, that are needed to use all
API functions. A web application might choose to store only these three
values in a session, instead of the whole object.

=head2 user_agent

  $xing = $xing->user_agent('MyApp Agent/23');
  $user_agent = $xing->user_agent;

Set or get the user agent string for the request.

Default: C<WebService::XING/$VERSION (Perl)>

=head2 request_timeout

  $xing = $xing->request_timeout(10);
  $request_timeout = $xing->request_timeout;

Maximum time in seconds to wait for a response.

Default: C<30>

=head2 json

An object instance of a JSON class.

Default: L<< JSON->new->utf8 >>. Uses L<JSON::XS> if available.

=head2 warn

  $xing->warn(sub { $log->write(@_) });

A reference to a C<sub>, that handles C<warn>ings.

Default: C<sub { Carp::carp @_ }>

=head2 die

  $xing->die(sub { MyException->throw(@_ });

A reference to a C<sub>, that handles C<die>s.

Default: C<sub { Carp::croak @_ }>

=head2 base_url

Web address of the XING API server. Do not change unless you know what
you are doing.

Default: C<https://api.xing.com>

=head2 request_token_resource

Resource where to receive an OAuth request token. Do not change without
reason.

Default: F</v1/request_token>

=head2 authorize_resource

Resource where the user has to be redirected in order to authorize
access for the consumer. Do not change without reason.

Default: F</v1/authorize>

=head2 access_token_resource

Resource where to receive an OAuth access token. Do not change without
reason.

Default: F</v1/access_token>

=head1 METHODS

All methods are called with named arguments - or in other words - with
a list of key-value-pairs.

All methods return a L<WebService::XING::Response> object on success.

All methods except L</login> and L</auth> return a
L<WebService::XING::Error> object (which is actually a child class of
L<WebService::XING::Response>) on failure. A method may L</die>
if called inaccurately (e.g. with missing arguments).

When the method documentation mentions a C<$bool> argument, it means
boolean in the way Perl handles it: C<undef>, "" and C<0> being C<false>
and everything else C<true>.

=head2 new

  my $xing = WebService::XING->new(
    key => $CUSTOMER_KEY,
    secret => $CUSTOMER_SECRET,
    access_token => $access_token,
    access_secret => $access_secret,
  );

The object constructor requires L</key> and L</secret> to be set, and
for all methods besides L</login> and L</auth> also L</access_token> and
L</access_secret>. Any other L<attribute|/ATTRIBUTES> can be set here as
well.

=head2 login

  $res = $xing->login or die $res;
  my $c = $res->content;
  my ($auth_url, $token, $secret) = @c{qw(url token token_secret)};

or

  $res = $xing->login(callback => $callback_url) or die $res;
  ...

OAuth handshake step 1: Obtain a request token.

If a callback url is given, the user will be re-directed back to that
location from the XING authorization page after successfull completion
of OAuth handshake step 2, otherwise (or if callback has the value
C<oob>) a PIN code (C<oauth_verifier>) is displayed to the user on the
XING authorization page, that must be entered in the consuming
application.

An C<undef> value is returned to indicate an error, the L</error>
attribute contains a L<WebServive::XING::Error> object for further
investigation.

The L<content property|WebService::XING::Response/content> of the
L<response|WebService::XING::Response> contains a hash with the 
following elements:

=over

=item C<url>:

The XING authorization URL. For the second step of the OAuth handshake
the user must be redirected to that location.

=item C<token>:

The request token. Needed in L</auth>.

=item C<token_secret>:

The request token secret. Needed in L</auth>.

=back

=head2 auth

  $xing->auth(
    token => $token,
    token_secret => $token_secret,
    verifier => $verifier,
  );

OAuth handshake step 3: Obtain an access token.
Requires a list of the following three named parameters:

=over

=item C<token>:

The B<request token> as returned in the response of a successfull
L<login> call.

=item C<token_secret>:

The B<request token_secret> as returned in the response of a successfull
L<login> call.

=item C<verifier>:

The OAuth verifier, that is provided to the callback as the
C<oauth_verifier> parameter - or that is displayed to the user for an
out-of-band authorization.

=back

The L<content property|WebService::XING::Response/content> of the
L<response|WebService::XING::Response> contains a hash with the 
following elements:

=over

=item C<token>:

The access token.

=item C<token_secret>:

The access token secret.

=item C<user_id>:

The scrambled XING user id.

=back

These three values are also stored in the object instance, so it is
not strictly required to store them. It might be useful for a web
application though, to keep only these access credentials in a
session, rather than the whole L<WebService::XING> object.

=head2 get_user_profile

  $res = $xing->get_user_profile(id => $id, fields => \@fields);

See L<https://dev.xing.com/docs/get/users/:id>

=head2 create_status_message

  $res = $xing->create_status_message(id => $id, message => $message);

See L<https://dev.xing.com/docs/post/users/:id/status_message>

=head2 get_profile_message

  $res = $xing->get_profile_message(user_id => $id);

See L<https://dev.xing.com/docs/get/users/:user_id/profile_message>

=head2 update_profile_message

  $res = $xing->update_profile_message(
    user_id => $id, message => $message, public => $bool
  );

See L<https://dev.xing.com/docs/put/users/:user_id/profile_message>

=head2 get_contacts

  $res = $xing->get_contacts(
    user_id => $id,
    limit => $limit, offset => $offset, order_by => $order_by,
    user_fields => \@user_fields
  );

See L<https://dev.xing.com/docs/get/users/:user_id/contacts>

=head2 get_shared_contacts

  $res = $xing->get_shared_contacts(
    user_id => $id,
    limit => $limit, offset => $offset, order_by => $order_by,
    user_fields => \@user_fields
  );

See L<https://dev.xing.com/docs/get/users/:user_id/contacts/shared>

=head2 get_incoming_contact_requests

  $res = $xing->get_incoming_contact_requests(
    user_id => $id,
    limit => $limit, offset => $offset,
    user_fields => \@user_fields
  );

See L<https://dev.xing.com/docs/get/users/:user_id/contact_requests>

=head2 get_sent_contact_requests

  $res = $xing->get_sent_contact_requests(
    user_id => $id, limit => $limit, offset => $offset
  );

See L<https://dev.xing.com/docs/get/users/:user_id/contact_requests/sent>

=head2 create_contact_request

  $res = $xing->create_contact_request(
    user_id => $id, message => $message
  );

See L<https://dev.xing.com/docs/post/users/:user_id/contact_requests>

=head2 accept_contact_request

  $res = $xing->accept_contact_request(
    id => $sender_id, user_id => $recipient_id
  );

See L<https://dev.xing.com/docs/put/users/:user_id/contact_requests/:id/accept>

=head2 delete_contact_request

  $res = $xing->delete_contact_request(
    id => $sender_id, user_id => $recipient_id
  );

See L<https://dev.xing.com/docs/delete/users/:user_id/contact_requests/:id>

=head2 get_contact_paths

  $res = $xing->get_contact_paths(
    user_id => $id,
    other_user_id => $other_user_id,
    all_paths => $bool,
    user_fields => \@user_fields
  );

See L<https://dev.xing.com/docs/get/users/:user_id/network/:other_user_id/paths>

=head2 get_bookmarks

  $res = $xing->get_bookmarks(
    user_id => $id,
    limit => $limit, offset => $offset,
    user_fields => \@user_fields
  );

See L<https://dev.xing.com/docs/get/users/:user_id/bookmarks>

=head2 create_bookmark

  $res = $xing->create_bookmark(id => $id, user_id => $id);

See L<https://dev.xing.com/docs/put/users/:user_id/bookmarks/:id>

=head2 delete_bookmark

  $res = $xing->delete_bookmark(id => $id, user_id => $id);

See L<https://dev.xing.com/docs/delete/users/:user_id/bookmarks/:id>

=head2 get_network_feed

  $res = $xing->get_network_feed(
    user_id => $id,
    aggregate => $bool,
    since => $date,
    user_fields => \@user_fields
  );

  $res = $xing->get_network_feed(
    user_id => $id,
    aggregate => $bool,
    until => $date,
    user_fields => \@user_fields
  );

See L<https://dev.xing.com/docs/get/users/:user_id/network_feed>

=head2 get_user_feed

  $res = $xing->get_user_feed(
    user_id => $id,
    since => $date,
    user_fields => \@user_fields
  );

  $res = $xing->get_user_feed(
    user_id => $id,
    until => $date,
    user_fields => \@user_fields
  );

See L<https://dev.xing.com/docs/get/users/:id/feed>

=head2 get_activity

  $res = $xing->get_activity(id => $id, user_fields => \@user_fields);

See L<https://dev.xing.com/docs/get/activities/:id>

=head2 share_activity

  $res = $xing->share_activity(id => $id, text => $text);

See L<https://dev.xing.com/docs/post/activities/:id/share>

=head2 delete_activity

  $res = $xing->delete_activity(id => $id);

See L<https://dev.xing.com/docs/delete/activities/:id>

=head2 get_activity_comments

  $res = $xing->get_activity_comments(
    activity_id => $activity_id,
    limit => $limit, offset => $offset,
    user_fields => \@user_fields
  );

See L<https://dev.xing.com/docs/get/activities/:activity_id/comments>

=head2 create_activity_comment

  $res = $xing->create_activity_comment(
    activity_id => $activity_id,
    text => $text
  );

See L<https://dev.xing.com/docs/post/activities/:activity_id/comments>

=head2 delete_activity_comment

  $res = $xing->delete_activity_comment(
    activity_id => $activity_id,
    id => $id
  );

See L<https://dev.xing.com/docs/delete/activities/:activity_id/comments/:id>

=head2 get_activity_likes

  $res = $xing->get_activity_likes(
    activity_id => $activity_id,
    limit => $limit, offset => $offset,
    user_fields => \@user_fields
  );

See L<https://dev.xing.com/docs/get/activities/:activity_id/likes>

=head2 create_activity_like

  $res = $xing->create_activity_like(activity_id => $activity_id);

See L<https://dev.xing.com/docs/put/activities/:activity_id/like>

=head2 delete_activity_like

  $res = $xing->delete_activity_like(activity_id => $activity_id);

See L<https://dev.xing.com/docs/delete/activities/:activity_id/like>

=head2 get_profile_visits

  $res = $xing->create_profile_visit(
    user_id => $id,
    limit => $limit, offset => $offset,
    since => $date,
    strip_html => $bool
  );

See L<https://dev.xing.com/docs/get/users/:user_id/visits>

=head2 create_profile_visit

  $res = $xing->get_profile_visits(user_id => $id);

See L<https://dev.xing.com/docs/post/users/:user_id/visits>

=head2 get_recommended_users

  $res = $xing->get_recommended_users(
    user_id => $id,
    limit => $limit, offset => $offset,
    similar_user_id => $similar_user_id,
    user_fields => \@user_fields
  );

See L<https://dev.xing.com/docs/get/users/:user_id/network/recommendations>

=head2 create_invitations

  $res = $xing->create_invitations(
    to_emails => \@to_emails,
    message => $message,
    user_fields => \@user_fields
  );

See L<https://dev.xing.com/docs/post/users/invite>

=head2 update_geo_location

  $res = $xing->update_geo_location(
    user_id => $id,
    accuracy => $accuracy,
    latitude => $latitude, longitude => $longitude,
    ttl => $ttl
  );

See L<https://dev.xing.com/docs/put/users/:user_id/geo_location>

=head2 get_nearby_users

  $res = $xing->get_nearby_users(
    user_id => $id,
    age => $age,
    radius => $radius,
    user_fields => \@user_fields
  );

See L<https://dev.xing.com/docs/get/users/:user_id/nearby_users>

=head2 request

  $res = $xing->request($method => $resource, @args);

Call any API function:

=over

=item C<$method>:

C<GET>, C<POST>, C<PUT> or C<DELETE>.

=item C<$resource>:

An api resource, e.g. F</v1/users/me>.

=item C<@args>:

A list of named arguments, e.g. C<< id => 'me', text => 'Blah!' >>.

=back

=head1 SEE ALSO

L<WebService::XING::Response>, L<WebService::XING::Error>,
L<https://dev.xing.com/>

=head1 AUTHOR

Bernhard Graf, C<< <graf (a) cpan.org> >>

=head1 LICENSE AND COPYRIGHT

Copyright 2012 Bernhard Graf.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.

