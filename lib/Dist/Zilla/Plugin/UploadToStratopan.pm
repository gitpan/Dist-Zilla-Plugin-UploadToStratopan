package Dist::Zilla::Plugin::UploadToStratopan;

our $VERSION = 0.001;

use Moose;
use LWP::UserAgent;

with 'Dist::Zilla::Role::Releaser';

# ABSTRACT: Automate Stratopan releases with Dist::Zilla

has agent         => ( is           => 'ro',
                       isa          => 'Str',
                       default      => 'stratopan-uploader/' . $VERSION );

has project       => ( is           => 'ro',
                       isa          => 'Str',
                       required     => 1 );

has stack         => ( is           => 'ro',
                       isa          => 'Str',
                       default      => 'master',
                       required     => 1 );

has _strato_base  => ( is           => 'ro',
                       isa          => 'Str',
                       default      => 'https://stratopan.com' );

has _lwp          => ( is           => 'ro',
                       isa          => 'LWP::UserAgent',
                       lazy_build   => 1 );

has _username     => ( is           => 'ro',
                       isa          => 'Str',
                       lazy_build   => 1 );

has _password     => ( is           => 'ro',
                       isa          => 'Str',
                       lazy_build   => 1 );


sub _build__username {
    my $self = shift;

    return $self->zilla->chrome->prompt_str( "Stratopan username: " );
}

sub _build__password {
    my $self = shift;
    return $self->zilla->chrome->prompt_str(
               "Stratopan password: ", { noecho => 1 }
           );
}

sub _build__lwp {
    my $self = shift;

    return LWP::UserAgent->new( agent       => $self->agent,
                                cookie_jar  => { } );
}

sub release {
    my ( $self, $tarball ) = @_;

    $tarball = "$tarball";    # stringify object

    my $ua = $self->_lwp;
    my $resp = $ua->post( $self->_strato_base . '/signin', {
                  login    => $self->_username,
                  password => $self->_password
              } );

    # do this the stupid way for now.
    if ( $resp->decoded_content =~ m{<div id="page-alert".+Incorrect login}s ) {
        $self->log_fatal( "Stratopan authentication failed." );
    }

    my $submit_url = sprintf '%s/%s/%s/%s/stack/add',
        $self->_strato_base, $self->_username, $self->project, $self->stack;

    $self->log( [ "uploading %s to %s", $tarball, $submit_url ] );

    $resp = $ua->post( $submit_url,
        Content_Type    => 'form-data',
        Content         => [
            archive         => [ $tarball, $tarball,
                                 Content_Type => "application/x-gzip" ],
            recurse     => 1,
        ]
    );

    if ( $resp->code == 302 ) {
        return $self->log( "success." );
    }

    $self->log_fatal( $resp->status_line );
}


1;


__END__

=pod

=head1 NAME

Dist::Zilla::Plugin::UploadToStratopan - Automate Stratopan releases with Dist::Zilla

=head1 SYNOPSIS

In your C<dist.ini>:

    [UploadToStratopan]
    project = myproject
    stack   = master

=head1 DESCRIPTION

This is a Dist::Zilla releaser plugin which will automatically upload your
completed build tarball to Stratopan.

The module will prompt you for your Stratopan username (NOT email) and password.

Currently, it works by posting the file to Stratopan's "Add" form; when the
Stratopan REST API becomes available, this module will be updated to use it
instead.

=head1 ATTRIBUTES

=head2 agent

The HTTP user agent string to use when talking to Stratopan. The default
is C<stratopan-uploader/$VERSION>.

=head2 project

The name of the Stratopan project. Required.

=head2 stack

The name of the stack within your project to which you want to upload. The
default is C<master>.

=head1 AUTHOR

Mike Friedman <friedo@friedo.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2014 by Mike Friedman

This is free software; you can redistribute it and/or modify it under the same
terms as the Perl 5 programming language system itself.

=cut
