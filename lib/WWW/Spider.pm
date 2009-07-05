package WWW::Spider;

=head1 NAME

WWW::Spider - customizable internet spider

=head1 VERSION

This document describes C<WWW::Spider> version 0.01_01

=head1 SYNOPSIS

 my $spider=new WWW::Spider;
 $spider=new WWW::Spider({UASTRING=>"mybot"});
 
 print $spider->uastring;
 $spider->uastring('New UserAgent String');
 $spider->user_agent(new LWP::UserAgent);
 
 print $spider->get_page_response('http://search.cpan.org/')->content;
 print $spider->get_page_content('http://search.cpan.org/');

=head1 DESCRIPTION

=cut

use strict;
use warnings;

use LWP::UserAgent;
use HTTP::Request;
use Thread::Queue;

use vars qw( $VERSION );
$VERSION = '0.01_01';

=pod

=head1 FUNCTIONS

=head2 PARAMETERS

Parameter getting and setting functions.

=over

=item new WWW::Spider([%params])

Constructor for C<WWW::Spider>

=cut

sub new {
    my $class=shift;
    my $self={};
    my $params=shift || {};

=pod

Arguments include:

=over

=item * UASTRING

The useragent string to be used.  The default is "WWW::Spider"

=cut

    my $uastring=$params->{UASTRING} || 'WWW::Spider';

=pod

=item * USER_AGENT

The LWP::UserAgent to use.  If this is specified, the UASTRING
argument is ignored.

=cut

    my $ua=new LWP::UserAgent;
    $ua->agent($uastring);
    $ua=$params->{USER_AGENT} || $ua;
    $self->{USER_AGENT}=$ua;
    bless $self,$class;
    return $self;
}

=pod

=back

=item user_agent [LWP::UserAgent]

Returns/sets the user agent being used by this object.

=cut

sub user_agent {
    my $self=shift;
    my $original=$self->{USER_AGENT};
    $self->{USER_AGENT}=$_[0] if exists $_[0];
    return $original
}

=pod

=item uastring [STRING]

Returns/sets the user agent string being used by this object.

=cut

sub uastring {
    my $self=shift;
    return $self->{USER_AGENT}->agent($_[0]);
}

=pod

=back

=head2 GENERAL

These functions could be implemented anywhere - nothing about what
they do is special do WWW::Spider.  Mainly, they are just conveiniance
functions for the rest of the code.

=over

=item get_page_content URL

Returns the contents of the page at URL.

=cut

sub get_page_content {
    my ($self,$url)=@_;
    return $self->get_page_response($url)->content;
}

=pod

=item get_page_response URL

Returns the HTTP::Response object corresponding to URL

=cut

sub get_page_response {
    my ($self,$url)=@_;
    return $self->{USER_AGENT}->get($url);
}

=pod

=back

=head2 SPIDER

These functions implement the spider functionality. 

=over

=item crawl URL MAX_DEPTH

Crawls URL to the specified maxiumum depth.  This is implemented as a
breadth-first search.

=cut

sub crawl {
    (my $self,my $url,my $max_depth)=@_;
    $self->crawl_content($self->get_page_content($url),$max_depth,$url);
}

=pod

=item handle_url URL

The same as C<crawl(URL,0)>.

=cut

sub handle_url {
    my ($self,$url)=@_;
    $self->handle_content($self->get_page_content($url),$url);
}

=pod

=item crawl_content STRING MAX_DEPTH [$SOURCE]

Treats STRING as if it was encountered during a crawl, with a
remaining maximum depth of MAX_DEPTH.  The crawl is implemented as a
breadth-first search using C<Thread::Queue>.

=cut

sub crawl_content {
    (my $self,my $content,my $max_depth,my $source)=@_;
    $self->handle_content($content,$source);
    my $q=new Thread::Queue;
}

=pod

=item handle_content $CONTENT [$SOURCE]

Runs appropriate handlers on STRING, without crawling to any other
pages.

=cut

sub handle_content {
    my ($self, $content,$source)=@_;
}

=pod

=item get_links_from URL

Returns a list of URLs linked to from URL.

=cut

sub get_links_from {
    (my $self,my $url)=@_;
    return $self->get_links_from_content($self->get_page_content($url),$url);    
}

=pod

=item get_links_from_content $CONTENT [$SOURCE]

Returns a list of URLs linked to in STRING.  When a URL is discovered
that is not complete, it is fixed by assuming that is was found on
SOURCE.  If there is no source page specified, bad URLs are treated as
if they were linked to from http://localhost/.

SOURCE must be a valid and complete url.

=cut

sub get_links_from_content {
    (my $self,my $content,my $source)=@_;
    my @list;
    my $domain="http://localhost/";
    my $root="http://localhost/";
    if($source) {
	$source=~/^(https?:\/\/[^\/]+\/)(.*)$/g;
	$domain=$1;
	$root=$1.$2;
	if($root=~/^(.+\/)[^\/]+$/g) {
	    $root=$1;
	}
    }
    while($content=~/<a ([^>]* )?href *= *\"([^\"]*)\"/msg) {
	my $partial=$2;
	my $url;
	if($partial=~/^http:\/\//) {
	    $url=$partial;
	} elsif($partial=~/^\/(.*)$/g) {
	    $url=$domain.$1;
	} else {
	    $url=$root.$partial;
	}
	push @list,$url;
    }
    return @list;
}

=pod

=back

=head2 CALLBACKS

=over

=cut

# =item add_handler SUB [STRING]

# Adds the specified handlers to this object.  If specified, the STRING
# becomes this handler's name; otherwise, a string is generated and
# returned.

# =cut

# sub add_handler {

# }

# =pod

# =item get_handler STRING

# Returns the handler named STRING.

# =cut

# sub get_handler {

# }

# =pod

# =item get_handlers

# Returns all of the page handlers

# =cut

# sub get_handlers {
    
# }

# =pod

# =item remove_handler STRING

# Removes the handler named STRING

# =cut

# sub remove_handler {

# }

# =pod

# =item clear_handlers

# Removes all handlers from this object.

# =cut

# sub remove_handlers {

# }

1;

__END__

=back

=head1 BUGS AND LIMITATIONS

=head1 MODULE DEPENDENCIES

WWW::Spider depends on several other modules that allow it to get and
parse HTML code.  Currently used are:

=over

=item * LWP::UserAgent

=item * HTTP::Request

=item * Thread::Queue

=back

Other modules will likely be added to this list in the future.

=head1 SEE ALSO

=over

=item * WWW::Robot

=back

=head1 AUTHOR

C<WWW::Spider> is written and maintained by Scott Lawrence (bytbox@gmail.com)

=head1 COPYRIGHT AND LICENSE

Copyright 2009 Scott Lawrence, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
