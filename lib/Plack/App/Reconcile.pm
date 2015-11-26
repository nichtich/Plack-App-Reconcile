package Plack::App::Reconcile;
use v5.14;

our $VERSION = '0.01';

use parent 'Plack::Component';

use Moo;
use JSON;
use Plack::Request;
use Plack::Response;

has name            => ( is => 'ro' );
has identifierSpace => ( is => 'ro' );
has schemaSpace     => ( is => 'ro' );
has query           => ( is => 'ro' );

sub call {
    my $self = shift;
    my $req  = Plack::Request->new(shift);

    my $query = $req->param('query');

    if ( ( $query // '' ) eq '' ) {
        return response( 200, $self->metadata );
    }

    # build query object

    if ( substr( $query, 0, 1 ) eq '{' ) {
        $query = eval { from_json($query) };
        return response( 400, { error => $@ } ) if $@;
    }
    else {
        $query = { query => $query };
    }

    # facilitate passing additional fields (not standard)
    foreach (qw(limit type type_strict)) {
        my $value = $req->param($_) // next;
        $query->{$_} = $value;
    }

    # TODO: validate query object

    my $res = defined $query->{query}
      ? $self->reconconcile($query)    # single query mode
      : do {                           # multiple query mode

        # TODO: parallel (fork?)
        { map { $_ => $self->reconcile( $query->{$_} ) } keys %$query };
      };

    response( 200, $res );
}

sub reconcile {
    my ( $self, $query ) = @_;

    my $hits = $self->query ? $self->query($query) : [];

    # TODO: map map 'match' to JSON::Boolean if given

    return { result => $hits };
}

sub metadata {
    my ($self) = @_;
    {
        name            => $self->name,
        identifierSpace => $self->identifierSpace,
        schemaSpace     => $self->schemaSpace,
    };
}

# utility function
sub response {
    my ( $status, $data ) = @_;

    my $json    = to_json($data);
    my $headers = [
        'Content-Type'   => 'application/json',
        'Content-Length' => length $json,
    ];

    return [ $status, $headers, [$json] ];
}

1;
__END__

=head1 NAME

Plack::App::Reconcile - Reconciliation Service API

=head1 SYNOPSIS

  use Plack::Builder;
  use Plack::App::Reconcile;

  my $app = Plack::App::Reconcile( 
    name            => "name of the reconconciliation service",    
    identifierSpace => "...",
    schemaSpace     => "...",
    query           => sub { my ($query) = $@; ... return \@entities },
  );

  builder {
    enable CORS;
    enable JSONP;
    $app;
  };

=head1 DESCRIPTION

This module implements a Reconciliation Service as L<PSGI> application.

The Reconconciliation Service API is used and defined by OpenRefine.

To implement an actual service, provide a C<query> function or override method
C<reconcile> when subclassing this module (by the way it uses L<Moo>).

=head1 METHODS

=head1 new( %config )

Creates a new reconciliation service with the following configuration fields:

=over

=item name

=item identifierSpace

=item schemaSpace

=item query

=back

=head2 reconcile( $query )

Given a B<query object> this method returns a result hash with key C<result>
mapped to a list of matching entities. Delegates to function C<query> by
default. 

=head2 entities

An entity, as returned as part of a result, is hash reference with the
following fields:

=over

=item id

=item name

=item type

=item score

=item match

=cut

=head1 SEE ALSO

L<https://github.com/OpenRefine/OpenRefine/wiki/Reconciliation-Service-API>

=head1 COPYRIGHT AND LICENSE

Copyright Jakob Voss, 2014-

This library is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
