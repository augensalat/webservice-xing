package WebService::XING::Function;

use 5.010;
use Mo 0.30 qw(builder is required);
use WebService::XING::Function::Parameter;

use overload '""' => sub { $_[0]->name }, bool => sub { 1 }, fallback => 1;

has name => (is => 'ro', required => 1);

has method => (is => 'ro', required => 1);

has resource => (is => 'ro', required => 1);

has params_in => (is => 'ro', required => 1);

has params => (is => 'ro', builder => '_build_params');
sub _build_params {
    my $self = shift;
    my @p;

    for ($self->resource =~ /:(\w+)/g) {
        push @p, WebService::XING::Function::Parameter->new(
            name => $_,
            is_required => 1,
        );
    }

    for (@{$self->params_in}) {
        my ($flag, $key, $default) = /^([\@\!\?]?)(\w+)(?:=(.*))?$/;
        my @a;

        given ($flag) {
            when ('@') { @a = (is_list => 1) }
            when ('!') { @a = (is_required => 1) }
            when ('?') { @a = (is_boolean => 1) }
        }
        push @p, WebService::XING::Function::Parameter->new(
            name => $key,
            default => $default,
            @a
        );
    }

    return \@p;
}

1;

__END__

=head1 NAME

WebService::XING::Function - XING API Function Class

=head1 DESCRIPTION

An object of the C<WebService::XING::Function> class is an abstract
description of a XING API function.

=head1 OVERLOADING

A C<WebService::XING::Function> object returns the function L</name> in
string context.

=head1 ATTRIBUTES

=head2 name

Function name. Required.

=head2 method

HTTP method. Required. This attribute has informational value only.

=head2 resource

The REST resource. Required. This attribute has informational value only.

=head2 params_in

Array reference of the parameters list. Required. Use for object creation
only.

=head2 params

Read-only attribute providing a reference to an array of
L<WebService::XING::Function::Parameter> objects, of which each describes
a parameter.

=head1 SEE ALSO

L<WebService::XING::Function::Parameter>
