package WWW::Spider::Hooklist;

=head1 NAME

WWW::Spider::Hooklist

=head1 VERSION

version 0.01_10

=head1 SYNOPSIS

=head1 DESCRIPTION

=cut

use strict;
use warnings;

use threads;
use Thread::Queue::Queueable;
use Thread::Resource::RWLock;

use WWW::Spider;

use base qw(Thread::Queue::Queueable Thread::Resource::RWLock);

use vars qw($VERSION);
$VERSION='0.01_10';

=pod

=head1 FUNCTIONS

=item new WWW::Spider::Hooklist(@VALID-NAMES)

Creates a hooklist that can categorize hooks as anything in the list
VALID-NAMES.  This list cannot be changed later on.

=cut

sub new {
    my $class=shift;
    my @names=@_;
    my %obj : shared=();
    my $self=bless \%obj,$class;
    for my $name(@names) {
	my @tmp : shared;
	$self->{$name}=\@tmp;
    }
    $self->Thread::Resource::RWLock::adorn();
    return $self;
}

sub redeem {
    my ($class, $self);
    return bless $self, $class;
}

=pod

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

C<WWW::Spider::Hooklist> is written and maintained by Scott Lawrence (bytbox@gmail.com)

=head1 COPYRIGHT AND LICENSE

Copyright 2009 Scott Lawrence, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
