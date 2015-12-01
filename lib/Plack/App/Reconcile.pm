package Plack::App::Reconcile;
use v5.14;

our $VERSION = '0.01';

use parent 'Plack::Middleware::JSONP';

use Moo;
use Carp;
use JSON;
use Plack::Request;
use Plack::Response;

has name            => ( is => 'ro', required => 1 );
has identifierSpace => ( is => 'ro', required => 1 );
has schemaSpace     => ( is => 'ro', required => 1 );

has query => (
    is      => 'ro',
    isa     => sub { croak "query must be CODE ref" if ref $_[0] ne 'CODE' },
    default => sub { sub { } },
);

# TODO: view, preview, suggest, defaultTypes (optional)

# this gets wrapped by JSONP Middleware
sub app {
    my $self = shift;
    return sub { $self->_call(@_) }
}

sub _call {
    my $self = shift;
    my $req  = Plack::Request->new(shift);

    my $query = $req->param('query');

    # TODO: "queries" mode

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
      ? $self->reconcile($query)    # single query mode
      : do {                        # multiple query mode

        # TODO: parallel (fork?)
        { map { $_ => $self->reconcile( $query->{$_} ) } keys %$query };
      };

    response( 200, $res );
}

sub reconcile {
    my ( $self, $query ) = @_;

    my $hits = $self->query->($query) // [];

    # TODO: validate hits
    foreach (@$hits) {
        # express match as JSON::Boolean
        if ( defined $_->{match} ) {
            $_->{match} = $_->{match} ? JSON::true : JSON::false;
        }
    }

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

    my $json    = JSON->new->utf8->canonical->pretty->encode($data);
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

=begin markdown

# STATUS

[![Build Status](https://travis-ci.org/nichtich/Plack-App-Reconcile.png)](https://travis-ci.org/nichtich/Plack-App-Reconcile)
[![Coverage Status](https://coveralls.io/repos/nichtich/Plack-App-Reconcile/badge.png?branch=master)](https://coveralls.io/r/nichtich/Plack-App-Reconcile?branch=master)
[![Kwalitee Score](http://cpants.cpanauthors.org/dist/Plack-App-Reconcile.png)](http://cpants.cpanauthors.org/dist/Plack-App-Reconcile)

=end markdown

=head1 SYNOPSIS

  use Plack::Builder;
  use Plack::App::Reconcile;

  my $app = Plack::App::Reconcile(
    name            => "...",
    identifierSpace => "...",
    schemaSpace     => "...",
    query           => sub { my ($query) = $@; ... return \@entities },
  );

  builder {
    enable CrossOrigin, origins => '*';
    $app;
  };

=head1 DESCRIPTION

This module implements a Reconciliation Service as L<PSGI> application.

The B<Reconconciliation Service API> is used and defined by OpenRefine.

To implement an actual service, provide a C<query> function or override method
C<reconcile> when subclassing this module (it already uses L<Moo>).

The service supports JSONP with callback parameter C<callback>. Support of
CORS can be added with L<Plack::Middleware::CrossOrigin>.

=head2 query object

=over

=item query

=item limit

=item type

=item type_strict

=item properties

=back

=head2 result objects

Each result object refers to one entity with the following fields:

=over

=item id

=item name

=item type 

=item score

=item match

=back

=head1 METHODS

=head1 new( %config )

Creates a new reconciliation service with the following configuration fields:

=over

=item name

=item identifierSpace

=item schemaSpace

=item query

A function that maps a L</query object> to a list of L</result objects>,
returned as array reference.

=back

=head2 reconcile( $query )

Given a B<query object> this method returns a result hash with key C<result>
mapped to a list of matching entities. Delegates to function C<query> by
default and wraps its return value as C<< { result => \@result } >>.

=head2 entities

An entity, as returned as part of a result, is hash reference with the
following fields:

=over

=item id

=item name

=item type

=item score

=item match

=back

=head1 SEE ALSO

L<https://github.com/OpenRefine/OpenRefine/wiki/Reconciliation-Service-API>

=head1 COPYRIGHT AND LICENSE

Copyright Jakob Voss, 2014-

This library is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
